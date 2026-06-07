#!/usr/bin/env bash
# Flash recovery.img to both A/B slots on NX779J.
# Run from the TWRP build root after a successful mka recoveryimage.
set -euo pipefail

DEVICE=NX779J
IMG="${1:-out/target/product/$DEVICE/recovery.img}"

if [ ! -f "$IMG" ]; then
    echo "ERROR: Image not found: $IMG"
    echo "Usage: $0 [path/to/recovery.img]"
    exit 1
fi

echo "==> Rebooting to bootloader..."
adb reboot bootloader
echo "    Waiting for fastboot..."
fastboot wait-for-device

echo "==> Flashing $IMG to slot A..."
fastboot flash recovery_a "$IMG"
echo "==> Flashing $IMG to slot B..."
fastboot flash recovery_b "$IMG"

echo "==> Rebooting to recovery..."
fastboot reboot recovery

echo "Done. Watch the screen — recovery should start in a few seconds."
