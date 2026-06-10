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

# Remove stale output image so a failed build can't be mistaken for a success
rm -f "$DEST"

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

# themes/navbar.xml — fox_14.1 ships navbar_disable=1 and screen_h=%screen_original_h%+96.
# screen_h is used in physical-pixel coordinate space by OrangeFox.  On NX779J the
# framebuffer is 2480px tall, so screen_h=%screen_original_h%+96 = 2576 causes the
# keyboard (positioned at screen_h-788) to be pushed 96px below the screen when
# tw_y_offset is applied by the gesture subsystem.  Fix: screen_h=2480 (framebuffer
# height, no extra offset) and navbar_disable=0 so the gesture bar is rendered within
# the area accounted for by screen_h.
NAVBAR_SRC="bootable/recovery/gui/theme/portrait_hdpi/themes/navbar.xml"
if [ -f "$NAVBAR_SRC" ] && grep -q 'navbar_disable" value="1"' "$NAVBAR_SRC"; then
    sed -i 's/navbar_disable" value="1"/navbar_disable" value="0"/' "$NAVBAR_SRC"
    sed -i 's/navbar_disable_add" value="96"/navbar_disable_add" value="0"/' "$NAVBAR_SRC"
    sed -i 's|screen_h" value="%screen_original_h%+96"|screen_h" value="2480"|' "$NAVBAR_SRC"
    echo "==> Patched themes/navbar.xml source: navbar_disable=0, screen_h=2480"
fi

# vars.xml — pre-set of_hw_control_mode=0 so the "Hardware GUI control" dialog never
# appears at startup.  Without this the binary shows the dialog on every first boot
# (of_hw_control_mode is unset), and if the user says No the gesture subsystem applies
# tw_y_offset which shifts all UI elements — a root cause of the PIN keyboard overflow.
# Setting it here before mka bakes the default into the image's ramdisk.
VARS_SRC="bootable/recovery/gui/theme/portrait_hdpi/resources/vars.xml"
if [ -f "$VARS_SRC" ] && ! grep -q 'of_hw_control_mode' "$VARS_SRC"; then
    # Insert the variable before the closing </variables> tag
    sed -i 's|</variables>|<variable name="of_hw_control_mode" value="0"/>\n\t</variables>|' "$VARS_SRC"
    echo "==> Patched vars.xml: of_hw_control_mode=0 (suppress HW GUI control dialog)"
fi

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

# ── Post-build: verify foxstart.sh is present; inject if PRODUCT_COPY_FILES was bypassed ──
# Primary mechanism: device.mk PRODUCT_COPY_FILES copies recovery/root/sbin/foxstart.sh
# before the build packs the ramdisk, so it should always be present.  This block is a
# fallback that catches the edge case where OrangeFox_A16.sh re-packs the ramdisk without
# our file.  When injection is needed, the AVB footer (OrangeFox appends one) is
# preserved by splicing it onto the end of the rebuilt boot image.
UNPACK_TMP="$(mktemp -d /tmp/of_foxstart_XXXXXX)"
echo "==> Verifying foxstart.sh in ramdisk..."
python3 system/tools/mkbootimg/unpack_bootimg.py \
    --boot_img "$SRC" --out "$UNPACK_TMP" > /dev/null 2>&1

RAMDISK_TMP="$UNPACK_TMP/rootfs"
mkdir -p "$RAMDISK_TMP"
lz4 -d "$UNPACK_TMP/ramdisk" - 2>/dev/null | cpio -i -D "$RAMDISK_TMP" 2>/dev/null || true

if [ -f "$RAMDISK_TMP/sbin/foxstart.sh" ]; then
    echo "==> foxstart.sh present in ramdisk — OK."
else
    echo "==> foxstart.sh absent — injecting no-op stub and repacking image..."
    mkdir -p "$RAMDISK_TMP/sbin"
    printf '#!/sbin/sh\nexit 0\n' > "$RAMDISK_TMP/sbin/foxstart.sh"
    chmod 755 "$RAMDISK_TMP/sbin/foxstart.sh"

    # Repack: newc cpio → LZ4 (legacy frame format, matching OrangeFox)
    NEW_RAMDISK="$UNPACK_TMP/ramdisk_new.lz4"
    (cd "$RAMDISK_TMP" && find . | sort | cpio -o -H newc 2>/dev/null) | \
        lz4 -l -BD -9 - "$NEW_RAMDISK" 2>/dev/null

    # Determine where the boot image ends in the original file (offset of AVB footer)
    # Boot image v4 layout: 1 header page + ceil(kernel/page) + ceil(ramdisk/page) pages
    BOOT_END="$(python3 - <<PYEOF
import struct
page = 4096
with open("$SRC", "rb") as f:
    f.seek(8)
    ksz = struct.unpack("<I", f.read(4))[0]
    rsz = struct.unpack("<I", f.read(4))[0]
kpages = (ksz + page - 1) // page if ksz else 0
rpages = (rsz + page - 1) // page
print((1 + kpages + rpages) * page)
PYEOF
)"

    # Rebuild boot image with the original header params + new ramdisk
    MKBOOT_ARGS="$(python3 system/tools/mkbootimg/unpack_bootimg.py \
        --boot_img "$SRC" --format mkbootimg 2>/dev/null)"
    MKBOOT_ARGS="$(echo "$MKBOOT_ARGS" | \
        sed "s|--ramdisk [^ ]*|--ramdisk $NEW_RAMDISK|")"
    KERNEL_FILE="$UNPACK_TMP/kernel"
    [ -f "$KERNEL_FILE" ] || touch "$KERNEL_FILE"
    MKBOOT_ARGS="$(echo "$MKBOOT_ARGS" | \
        sed "s|--kernel [^ ]*|--kernel $KERNEL_FILE|")"

    NEW_BOOT="$UNPACK_TMP/boot_new.img"
    # eval set -- properly parses shell quoting in unpack_bootimg output (e.g. --cmdline '')
    eval set -- "$MKBOOT_ARGS"
    python3 system/tools/mkbootimg/mkbootimg.py \
        "$@" --output "$NEW_BOOT" 2>&1 | tee -a "$LOG"

    if [ -f "$NEW_BOOT" ]; then
        # Append AVB footer from original image (bytes from BOOT_END to EOF)
        NEW_IMG="$UNPACK_TMP/output.img"
        cp "$NEW_BOOT" "$NEW_IMG"
        python3 - <<PYEOF
import os
src = open('$SRC', 'rb')
src.seek(int('$BOOT_END'))
avb = src.read()
src.close()
if avb:
    out = open('$NEW_IMG', 'ab')
    out.write(avb)
    out.close()
    print(f'==> AVB footer ({len(avb)} bytes) preserved.')
else:
    print('==> No AVB footer in original image.')
PYEOF
        mv "$NEW_IMG" "$SRC"
        echo "==> foxstart.sh stub injected into $(basename "$SRC")."
    else
        echo "==> WARNING: image rebuild failed — foxstart.sh not injected (check $LOG)"
    fi
fi
rm -rf "$UNPACK_TMP"
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p "$KITCHEN_DIR/builds"
cp "$SRC" "$DEST"
echo ""
echo "==> OrangeFox build complete: $DEST ($(ls -lh "$DEST" | awk '{print $5}'))"
