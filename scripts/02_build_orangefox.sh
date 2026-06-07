#!/usr/bin/env bash
# Build OrangeFox recovery for NX779J.
# Strategy: TWRP-16.0 bootable/recovery (Android 16 compatible) + OrangeFox fox_16.0 vendor overlay.
# The Makefile hooks in build/make/core/Makefile (applied by 00_setup.sh) call
# OrangeFox_A16.sh at the right build stages.
# Usage: bash scripts/02_build_orangefox.sh [build_root]
set -euo pipefail

KITCHEN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${1:-$KITCHEN_DIR/twrp-build}"
LOG="$KITCHEN_DIR/logs/orangefox_build.log"
DEST="$KITCHEN_DIR/builds/orangefox_NX779J.img"

OF_VENDOR_URL="https://gitlab.com/OrangeFox/vendor/recovery.git"
OF_VENDOR_BRANCH="fox_16.0"

cd "$BUILD_DIR"

# Restore TWRP bootable/recovery if a third-party fork is present
_remote="$(git -C bootable/recovery remote get-url origin 2>/dev/null || true)"
if echo "$_remote" | grep -qi "orangefox\|pitchblack"; then
    echo "==> Restoring TWRP bootable/recovery from manifest..."
    rm -rf bootable/recovery
    repo sync bootable/recovery --no-tags --no-clone-bundle -j"$(nproc)"
fi

# OrangeFox vendor/recovery overlay (provides OrangeFox_A16.sh)
if [ ! -d vendor/recovery/.git ]; then
    echo "==> Cloning OrangeFox vendor/recovery ($OF_VENDOR_BRANCH)..."
    git clone "$OF_VENDOR_URL" -b "$OF_VENDOR_BRANCH" --depth=1 vendor/recovery
else
    echo "==> OrangeFox vendor/recovery already present."
fi

# Remove legacy Soong hook if present (not needed with Makefile-based approach)
SOONG_MK="vendor/twrp/config/BoardConfigSoong.mk"
[ -f "$SOONG_MK" ] && sed -i '\|-include bootable/recovery/orangefox_soong.mk|d' "$SOONG_MK"

# Clean recovery staging to avoid rsync conflicts with stale OrangeFox artifacts
rm -rf "$BUILD_DIR/out/target/product/NX779J/recovery/" \
       "$BUILD_DIR/out/target/product/NX779J/obj/PACKAGING/recovery_intermediates/" 2>/dev/null || true

export FOX_BUILD_DEVICE=NX779J
export FOX_DEVICE=NX779J
export FOX_AB_DEVICE=1
export FOX_BUILD_TYPE=Unofficial
export FOX_VARIANT=eng
export OF_DISABLE_UPDATEZIP=1
export ALLOW_MISSING_DEPENDENCIES=true
unset NOT_ORANGEFOX   # ensure Makefile hooks are active

# shellcheck disable=SC1091
unset -f grep 2>/dev/null || true
source build/envsetup.sh
lunch twrp_NX779J-bp2a-eng

mkdir -p "$KITCHEN_DIR/logs"
echo "==> Building OrangeFox (log: $LOG)..."
mka recoveryimage 2>&1 | tee "$LOG"

# OrangeFox_A16.sh saves the final image to /tmp/OrangeFox_<DEVICE>/
OFX_TMP="$(find /tmp -maxdepth 2 -name 'OrangeFox*.img' 2>/dev/null | sort -V | tail -1)"
SRC="${OFX_TMP:-$BUILD_DIR/out/target/product/NX779J/recovery.img}"

[ -f "$SRC" ] || { echo "ERROR: OrangeFox image not found — check $LOG"; exit 1; }
mkdir -p "$KITCHEN_DIR/builds"
cp "$SRC" "$DEST"
echo ""
echo "==> OrangeFox build complete: $DEST ($(du -sh "$DEST" | cut -f1))"
