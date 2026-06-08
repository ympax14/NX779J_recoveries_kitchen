#!/usr/bin/env bash
# Build PitchBlack Recovery Project (PBRP) for NX779J.
# PBRP android-14.0 is TWRP 14.1 based; this script patches it for Android 16
# compatibility before building against the twrp-16.0 build tree.
# Usage: bash scripts/03_build_pbrp.sh [build_root]
set -eo pipefail

KITCHEN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${1:-$(cd "$KITCHEN_DIR/../TWRP" 2>/dev/null && pwd || echo "$KITCHEN_DIR/twrp-build")}"
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

# ── Android 16 compatibility patches ─────────────────────────────────────────

# 1. bootable/recovery: PBRP android-14.0 → Android 16 compat
PATCH_REC="$KITCHEN_DIR/patches/pbrp_android16_compat.patch"
if [ -f "$PATCH_REC" ]; then
    if git -C bootable/recovery apply --check --whitespace=nowarn "$PATCH_REC" 2>/dev/null; then
        echo "==> Applying PBRP bootable/recovery Android 16 compat patch..."
        git -C bootable/recovery apply --whitespace=nowarn "$PATCH_REC"
    else
        echo "==> PBRP bootable/recovery compat patch already applied."
    fi
fi

# 2. system/vold: fscrypt_policy.h typedefs + lookup_ref_tar signature for PBRP libtar
PATCH_VOLD="$KITCHEN_DIR/patches/pbrp_vold_compat.patch"
if [ -f "$PATCH_VOLD" ]; then
    if git -C system/vold apply --check --whitespace=nowarn "$PATCH_VOLD" 2>/dev/null; then
        echo "==> Applying PBRP system/vold compat patch..."
        git -C system/vold apply --whitespace=nowarn "$PATCH_VOLD"
    else
        echo "==> PBRP system/vold compat patch already applied."
    fi
fi

# 3. system/core: fs_mgr_priv_boot_config.h shim (removed in Android 14, needed by PBRP code)
FS_MGR_SHIM="system/core/fs_mgr/include/fs_mgr_priv_boot_config.h"
if [ ! -f "$FS_MGR_SHIM" ]; then
    echo "==> Creating $FS_MGR_SHIM compat shim..."
    cat > "$FS_MGR_SHIM" << 'EOF'
/* Compatibility shim: fs_mgr_priv_boot_config.h was removed in Android 14.
 * fs_mgr_get_boot_config() is now declared in libfstab/fstab_priv.h. */
#pragma once

#include <string>

bool fs_mgr_get_boot_config(const std::string& key, std::string* out_val);
EOF
fi

# 4. build/make/core/Makefile: exclude real dirs in recovery rootfs from rsync overwrite
#    (system rootfs has symlinks; recovery has real dirs populated by install steps)
MAKEFILE="build/make/core/Makefile"
if ! grep -q -- '--exclude=/root/etc' "$MAKEFILE"; then
    echo "==> Patching Makefile rsync to add recovery rootfs excludes..."
    sed -i 's|rsync -a --exclude=sdcard \$(IGNORE_RECOVERY_SEPOLICY)|rsync -a --exclude=sdcard --exclude=/root/etc --exclude=/root/odm/etc $(IGNORE_RECOVERY_SEPOLICY)|' "$MAKEFILE"
elif ! grep -q -- '--exclude=/root/odm/etc' "$MAKEFILE"; then
    echo "==> Patching Makefile rsync to add /root/odm/etc exclude..."
    sed -i 's|--exclude=/root/etc \$(IGNORE_RECOVERY_SEPOLICY)|--exclude=/root/etc --exclude=/root/odm/etc $(IGNORE_RECOVERY_SEPOLICY)|' "$MAKEFILE"
fi

# ─────────────────────────────────────────────────────────────────────────────

export PB_DEVICE_NAME=NX779J
export PB_BUILD_TYPE=Unofficial
export PB_OFFICIAL=0
export ALLOW_MISSING_DEPENDENCIES=true
export NOT_ORANGEFOX=1   # disable OrangeFox Makefile hooks

# shellcheck disable=SC1091
unset -f grep 2>/dev/null || true
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
