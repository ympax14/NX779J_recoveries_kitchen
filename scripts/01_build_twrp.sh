#!/usr/bin/env bash
# Build TWRP recovery for NX779J (RedMagic 10 Air, SM8650).
# Usage: bash scripts/01_build_twrp.sh [build_root]
set -eo pipefail

KITCHEN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${1:-$(cd "$KITCHEN_DIR/../TWRP" 2>/dev/null && pwd || echo "$KITCHEN_DIR/twrp-build")}"
OUT_IMG="$BUILD_DIR/out/target/product/NX779J/recovery.img"
DEST="$KITCHEN_DIR/builds/twrp_NX779J.img"
LOG="$KITCHEN_DIR/logs/twrp_build.log"

cd "$BUILD_DIR"

# Remove stale output image so a failed build can't be mistaken for a success
rm -f "$DEST"

# Restore TWRP bootable/recovery if OrangeFox or PBRP fork is present
_remote="$(git -C bootable/recovery remote get-url origin 2>/dev/null || true)"
if echo "$_remote" | grep -qi "orangefox\|pitchblack"; then
    echo "==> Restoring TWRP bootable/recovery from manifest..."
    rm -rf bootable/recovery
    repo sync bootable/recovery --no-tags --no-clone-bundle -j"$(nproc)"
fi

# Remove OrangeFox vendor/recovery
[ -d vendor/recovery ] && { echo "==> Removing OrangeFox vendor/recovery..."; rm -rf vendor/recovery; }

# Clean stale recovery staging (previous OrangeFox/PBRP builds leave real dirs where
# the system rootfs has symlinks, causing rsync to fail on the next build)
rm -rf out/target/product/NX779J/recovery/ \
       out/target/product/NX779J/obj/PACKAGING/recovery_intermediates/ 2>/dev/null || true
# nano_twrp's LOCAL_POST_INSTALL_CMD copies to recovery/root/system/etc/ without a
# mkdir guard — create it here so the step doesn't fail on a clean staging tree.
mkdir -p out/target/product/NX779J/recovery/root/system/etc

# Remove legacy Soong hook if present
SOONG_MK="vendor/twrp/config/BoardConfigSoong.mk"
[ -f "$SOONG_MK" ] && sed -i '\|-include bootable/recovery/orangefox_soong.mk|d' "$SOONG_MK"

# Fix libtar/extract.c to use the unified lookup_ref_tar(fscrypt_policy *fep, ...) signature.
# system/vold/fscrypt_policy.h declares the new API; TWRP's extract.c passes just the key field.
EXTRACT_C="bootable/recovery/libtar/extract.c"
if grep -q 'lookup_ref_tar(t->th_buf\.fep->master_key' "$EXTRACT_C" 2>/dev/null; then
    echo "==> Fixing libtar lookup_ref_tar call sites for fscrypt_policy * API..."
    sed -i 's/lookup_ref_tar(t->th_buf\.fep->master_key_descriptor,/lookup_ref_tar(t->th_buf.fep,/g' "$EXTRACT_C"
    sed -i 's/lookup_ref_tar(t->th_buf\.fep->master_key_identifier,/lookup_ref_tar(t->th_buf.fep,/g' "$EXTRACT_C"
fi

# shellcheck disable=SC1091
unset -f grep 2>/dev/null || true   # undo any grep wrapper (e.g. Claude Code ugrep shim)
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
export NOT_ORANGEFOX=1          # disable OrangeFox Makefile hooks

lunch twrp_NX779J-bp2a-eng

mkdir -p "$KITCHEN_DIR/logs"
echo "==> Building TWRP (log: $LOG)..."
mka recoveryimage 2>&1 | tee "$LOG"

[ -f "$OUT_IMG" ] || { echo "ERROR: recovery.img not found — check $LOG"; exit 1; }
mkdir -p "$KITCHEN_DIR/builds"
cp "$OUT_IMG" "$DEST"
echo ""
echo "==> TWRP build complete: $DEST ($(du -sh "$DEST" | cut -f1))"
