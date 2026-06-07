#!/usr/bin/env bash
# Run all build steps in sequence: setup → TWRP → OrangeFox → PBRP.
# Run from the kitchen root or pass the build root as argument.
# Usage: bash scripts/build_all.sh [build_root] [--skip-setup]
set -euo pipefail

KITCHEN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${1:-$KITCHEN_DIR/twrp-build}"
SCRIPTS_DIR="$KITCHEN_DIR/scripts"

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

if [[ "${2:-}" != "--skip-setup" ]]; then
    run_step "Setup (sync + patches)" "00_setup.sh"
fi

run_step "Build TWRP"        "01_build_twrp.sh"
run_step "Build OrangeFox"   "02_build_orangefox.sh"
run_step "Build PitchBlack"  "03_build_pbrp.sh"

echo "========================================"
echo "  All builds complete!"
echo "========================================"
ls -lh "$KITCHEN_DIR/builds/" 2>/dev/null || echo "(no builds/ dir yet)"
