#!/usr/bin/env bash
# Run all build steps in sequence: setup → TWRP → OrangeFox → PBRP.
# Usage:
#   bash scripts/build_all.sh                            # auto-detect build root
#   bash scripts/build_all.sh /path/to/build             # explicit build root
#   bash scripts/build_all.sh [build_root] --skip-setup  # skip repo sync
set -eo pipefail

KITCHEN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$KITCHEN_DIR/scripts"

# Parse args: first non-flag arg is build root, flags can appear anywhere
SKIP_SETUP=0
BUILD_DIR=""
for arg in "$@"; do
    case "$arg" in
        --skip-setup) SKIP_SETUP=1 ;;
        --*)          echo "Unknown flag: $arg"; exit 1 ;;
        *)            BUILD_DIR="$arg" ;;
    esac
done
[ -z "$BUILD_DIR" ] && BUILD_DIR="$(cd "$KITCHEN_DIR/../TWRP" 2>/dev/null && pwd || echo "$KITCHEN_DIR/twrp-build")"

echo "========================================"
echo "  NX779J Recovery Build Suite"
echo "  Build root: $BUILD_DIR"
echo "========================================"
echo ""

run_step() {
    local name="$1"
    local script="$2"
    echo "──────────────────────────────────────"
    echo "  Step: $name"
    echo "──────────────────────────────────────"
    bash "$SCRIPTS_DIR/$script" "$BUILD_DIR"
    echo ""
}

if [ "$SKIP_SETUP" -eq 0 ]; then
    run_step "Setup (sync + patches)" "00_setup.sh"
fi

run_step "Build TWRP"        "01_build_twrp.sh"
run_step "Build OrangeFox"   "02_build_orangefox.sh"
run_step "Build PitchBlack"  "03_build_pbrp.sh"

echo "========================================"
echo "  All builds complete!"
echo "========================================"
ls -lh "$KITCHEN_DIR/builds/" 2>/dev/null || echo "(no builds/ dir yet)"
