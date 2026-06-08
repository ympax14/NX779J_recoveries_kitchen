#!/usr/bin/env bash
# Build OrangeFox recovery for NX779J.
# Strategy: OrangeFox fox_14.1 bootable/recovery (patched for Android 16 compat)
#           + OrangeFox fox_16.0 vendor overlay (OrangeFox_A16.sh hooks).
# The Makefile hooks in build/make/core/Makefile (applied by 00_setup.sh) call
# OrangeFox_A16.sh at the right build stages.
# Usage: bash scripts/02_build_orangefox.sh [build_root]
set -eo pipefail

KITCHEN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${1:-$(cd "$KITCHEN_DIR/../TWRP" 2>/dev/null && pwd || echo "$KITCHEN_DIR/twrp-build")}"
LOG="$KITCHEN_DIR/logs/orangefox_build.log"
DEST="$KITCHEN_DIR/builds/orangefox_NX779J.img"

OF_RECOVERY_URL="https://gitlab.com/OrangeFox/bootable/recovery.git"
OF_RECOVERY_BRANCH="fox_14.1"
OF_VENDOR_URL="https://gitlab.com/OrangeFox/vendor/recovery.git"
OF_VENDOR_BRANCH="fox_16.0"

cd "$BUILD_DIR"

# bootable/recovery: OrangeFox fox_14.1 (provides OrangeFox UI)
_remote="$(git -C bootable/recovery remote get-url origin 2>/dev/null || true)"
if ! echo "$_remote" | grep -qi "OrangeFox/bootable"; then
    echo "==> Cloning OrangeFox bootable/recovery ($OF_RECOVERY_BRANCH)..."
    rm -rf bootable/recovery
    git clone "$OF_RECOVERY_URL" -b "$OF_RECOVERY_BRANCH" --depth=1 bootable/recovery
else
    echo "==> OrangeFox bootable/recovery already present."
fi

# Apply Android 16 compatibility patches to fox_14.1
PATCH="$KITCHEN_DIR/patches/fox14_android16_compat.patch"
if [ -f "$PATCH" ]; then
    if git -C bootable/recovery apply --check --whitespace=nowarn "$PATCH" 2>/dev/null; then
        echo "==> Applying fox_14.1 Android 16 compat patches..."
        git -C bootable/recovery apply --whitespace=nowarn "$PATCH"
    else
        echo "==> fox_14.1 Android 16 compat patches already applied (or not needed)."
    fi
fi

# Fix libtar/extract.c: system/vold/fscrypt_policy.h now declares lookup_ref_tar(fscrypt_policy *),
# but fox_14.1 extract.c passes just the raw key field — update both call sites.
EXTRACT_C="bootable/recovery/libtar/extract.c"
if grep -q 'lookup_ref_tar(t->th_buf\.fep->master_key' "$EXTRACT_C" 2>/dev/null; then
    echo "==> Fixing libtar lookup_ref_tar call sites for fscrypt_policy * API..."
    sed -i 's/lookup_ref_tar(t->th_buf\.fep->master_key_descriptor,/lookup_ref_tar(t->th_buf.fep,/g' "$EXTRACT_C"
    sed -i 's/lookup_ref_tar(t->th_buf\.fep->master_key_identifier,/lookup_ref_tar(t->th_buf.fep,/g' "$EXTRACT_C"
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

# Clean recovery staging to avoid rsync conflicts with stale artifacts
rm -rf "$BUILD_DIR/out/target/product/NX779J/recovery/" \
       "$BUILD_DIR/out/target/product/NX779J/obj/PACKAGING/recovery_intermediates/" 2>/dev/null || true
# nano_twrp's LOCAL_POST_INSTALL_CMD copies to recovery/root/system/etc/ without a
# mkdir guard — create it here so the step doesn't fail on a clean staging tree.
mkdir -p "$BUILD_DIR/out/target/product/NX779J/recovery/root/system/etc"

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

SRC="$BUILD_DIR/out/target/product/NX779J/OrangeFox-R11.3-Unofficial-NX779J.img"
[ -f "$SRC" ] || SRC="$BUILD_DIR/out/target/product/NX779J/recovery.img"
[ -f "$SRC" ] || { echo "ERROR: OrangeFox image not found — check $LOG"; exit 1; }
mkdir -p "$KITCHEN_DIR/builds"
cp "$SRC" "$DEST"
echo ""
echo "==> OrangeFox build complete: $DEST ($(ls -lh "$DEST" | awk '{print $5}'))"
