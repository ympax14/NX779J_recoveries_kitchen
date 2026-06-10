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

# Remove stale output image so a failed build can't be mistaken for a success
rm -f "$DEST"

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

# 1b. bootable/recovery: NX779J-specific bug fixes (applied after compat patch)
#   - libtar: fix fscrypt v2 buffer overflow → FORTIFY SIGABRT on nandroid backup
#   - graphics_drm: O_CLOEXEC + drmSetMaster retry (PBRP two-phase exec DRM master race)
#   - twrp-functions: markBootSuccessful() before rb_system (A/B slot reboot-to-recovery loop)
_apply_patch bootable/recovery \
    "0001-libtar-fix-fscrypt-policy-buffer-overflow-FORTIFY-SI.patch" \
    "libtar: fix fscrypt policy buffer overflow (FORTIFY SIGABRT)"
_apply_patch bootable/recovery \
    "0002-NX779J-fix-DRM-master-ownership-and-A-B-boot-success.patch" \
    "NX779J: fix DRM master ownership + A/B boot-success on system reboot"

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

# 2b. system/vold: skip BootControl WaitForService() in recovery (blocks indefinitely
#     on NX779J — BootControl HAL declared in VINTF but not started in recovery).
_apply_patch() {
    local repo="$1" patch="$KITCHEN_DIR/patches/$2" label="$3"
    [ -f "$patch" ] || { echo "==> WARNING: patch not found: $2"; return 0; }
    if git -C "$repo" apply --check --whitespace=nowarn "$patch" 2>/dev/null; then
        echo "==> Applying $label..."
        git -C "$repo" apply --whitespace=nowarn "$patch"
    else
        echo "==> $label already applied."
    fi
}
_apply_patch system/vold \
    "0001-vold-skip-BootControl-WaitForService-in-recovery-con.patch" \
    "vold: skip BootControl WaitForService (NX779J recovery hang fix)"

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

# Clean stale recovery artifacts before build.
# - recovery.img: leftover from a previous TWRP/OF build would cause false-success detection.
# - recovery/ staging: real dirs from a prior PBRP build conflict with system rootfs symlinks.
rm -f  "$OUT_IMG"
rm -rf out/target/product/NX779J/recovery/ \
       out/target/product/NX779J/obj/PACKAGING/recovery_intermediates/ 2>/dev/null || true

# 5. hardware/interfaces/weaver/aidl/Android.bp: add recovery_available: true so
#    android.hardware.weaver-V2-ndk.so is staged into the recovery ramdisk.
#    Without it PBRP's recovery binary crashes with "library not found" at startup.
WEAVER_BP="hardware/interfaces/weaver/aidl/Android.bp"
if ! grep -q "recovery_available" "$WEAVER_BP"; then
    sed -i 's/vendor_available: true,/vendor_available: true,\n    recovery_available: true,/' "$WEAVER_BP"
    echo "==> Patched weaver Android.bp: added recovery_available: true"
fi

mkdir -p "$KITCHEN_DIR/logs"
echo "==> Building PBRP (log: $LOG)..."
# CleanSpec.mk changes when bootable/recovery switches from OrangeFox/TWRP to PBRP.
# The Android build system then cleans Soong intermediates (incl. make_vars-twrp_NX779J.mk),
# causing ckati to fail on the first run.  A second run regenerates all missing files.
mka recoveryimage 2>&1 | tee "$LOG" || {
    echo "==> mka pass 1 failed (likely CleanSpec.mk Soong clean) — retrying..."
    mka recoveryimage 2>&1 | tee -a "$LOG"
}

# ── Ensure libraries missing from the recovery ramdisk are injected ───────────
# Soong only stages a lib in recovery when recovery_available is set in its Android.bp
# AND it's reachable from the recovery variant build graph.  ALLOW_MISSING_DEPENDENCIES=true
# lets the build succeed without them; direct-copy is the reliable fallback.
# All copies happen together so only one mka repack pass is needed.
SYSLIB="$BUILD_DIR/out/target/product/NX779J/system/lib64"
RECLIB="$BUILD_DIR/out/target/product/NX779J/recovery/root/system/lib64"
_need_repack=0
for _lib in \
    android.hardware.weaver-V2-ndk.so \
    libzstd.so \
    libapexsupport.so \
    android.security.aaid_aidl-cpp.so
do
    if [ -f "$SYSLIB/$_lib" ] && [ ! -f "$RECLIB/$_lib" ]; then
        cp "$SYSLIB/$_lib" "$RECLIB/$_lib"
        echo "==> Copied $_lib to recovery ramdisk."
        _need_repack=1
    fi
done
if [ "$_need_repack" -eq 1 ]; then
    echo "==> Repacking recovery image with injected libraries..."
    rm -f "$OUT_IMG"
    mka recoveryimage 2>&1 | tee -a "$LOG"
fi

[ -f "$OUT_IMG" ] || { echo "ERROR: recovery.img not found — check $LOG"; exit 1; }
mkdir -p "$KITCHEN_DIR/builds"
cp "$OUT_IMG" "$DEST"
echo ""
echo "==> PBRP build complete: $DEST ($(du -sh "$DEST" | cut -f1))"
