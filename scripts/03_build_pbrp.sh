#!/usr/bin/env bash
# Build PitchBlack Recovery Project (PBRP) for NX779J.
# Note: PBRP android-14.0 is TWRP 14.1 based. If compilation fails against
# Android 16 bionic/libcxx headers, see README for known workarounds.
# Usage: bash scripts/03_build_pbrp.sh [build_root]
set -euo pipefail

KITCHEN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${1:-$KITCHEN_DIR/twrp-build}"
OUT_IMG="$BUILD_DIR/out/target/product/NX779J/recovery.img"
DEST="$KITCHEN_DIR/builds/pbrp_NX779J.img"
LOG="$KITCHEN_DIR/logs/pbrp_build.log"

PBRP_URL="https://github.com/PitchBlackRecoveryProject/android_bootable_recovery.git"
PBRP_BRANCH="android-14.0"

cd "$BUILD_DIR"

# Remove OrangeFox vendor/recovery
[ -d vendor/recovery ] && { echo "==> Removing OrangeFox vendor/recovery..."; rm -rf vendor/recovery; }

# Clone/update PBRP bootable/recovery
_remote="$(git -C bootable/recovery remote get-url origin 2>/dev/null || true)"
if ! echo "$_remote" | grep -qi "pitchblack\|PitchBlack"; then
    echo "==> Cloning PBRP bootable/recovery ($PBRP_BRANCH)..."
    rm -rf bootable/recovery
    git clone "$PBRP_URL" -b "$PBRP_BRANCH" --depth=1 bootable/recovery
else
    echo "==> PBRP bootable/recovery already present."
fi

export PB_DEVICE_NAME=NX779J
export PB_BUILD_TYPE=Unofficial
export PB_OFFICIAL=0
export ALLOW_MISSING_DEPENDENCIES=true
export NOT_ORANGEFOX=1   # disable OrangeFox Makefile hooks

# shellcheck disable=SC1091
source build/envsetup.sh
lunch twrp_NX779J-bp2a-eng

mkdir -p "$KITCHEN_DIR/logs"
echo "==> Building PBRP (log: $LOG)..."
mka recoveryimage 2>&1 | tee "$LOG"

[ -f "$OUT_IMG" ] || { echo "ERROR: recovery.img not found — check $LOG"; exit 1; }
mkdir -p "$KITCHEN_DIR/builds"
cp "$OUT_IMG" "$DEST"
echo ""
echo "==> PBRP build complete: $DEST ($(du -sh "$DEST" | cut -f1))"
