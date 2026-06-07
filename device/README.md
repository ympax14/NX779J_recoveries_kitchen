# Device tree — RedMagic 10 Air (NX779J)

| | |
|---|---|
| **Device** | Nubia RedMagic 10 Air |
| **Codename** | NX779J |
| **SoC** | Qualcomm Snapdragon 8 Elite (SM8650 / pineapple) |
| **Android** | 16 (API 36) |
| **Partition scheme** | Virtual A/B + dynamic partitions |
| **Encryption** | Hardware-wrapped key FBE + metadata encryption |
| **Maintainer** | [Ympax](https://github.com/ympax14) |

Shared device tree for TWRP, OrangeFox, PitchBlack, and future AOSP ROM builds.

---

## Status

| Feature | Status |
|---|---|
| Booting to recovery | ✅ |
| ADB | ✅ |
| Display (DRM atomic) | ✅ |
| Fastbootd | ✅ |
| Flashing (zip / image) | ✅ |
| MTP | ✅ |
| USB-OTG | ✅ |
| Data decryption (FBE + metadata) | 🔧 WIP |
| Vibrator | 🔧 WIP |

---

## Related repositories

| Repo | Description |
|---|---|
| [NX779J_device_tree](https://github.com/ympax14/NX779J_device_tree) | This repo — shared device tree |

---

## Prerequisites

- Linux build environment with Android build dependencies (`git`, `repo`, `python3`, `ccache`, …)
- ~200 GB free disk space, 16 GB RAM minimum

### Sync the TWRP Android 16 build tree

```bash
mkdir TWRP && cd TWRP
repo init -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp -b twrp-16.0 --depth=1
repo sync -j$(nproc) --no-tags --no-clone-bundle
```

### Clone this device tree

```bash
git clone https://github.com/ympax14/NX779J_device_tree device/nubia/NX779J
```

### Build TWRP

```bash
export ALLOW_MISSING_DEPENDENCIES=true
source build/envsetup.sh
lunch twrp_NX779J-bp2a-eng
mka recoveryimage
```

### Build OrangeFox

```bash
# Replace bootable/recovery with OrangeFox fork
git clone https://gitlab.com/OrangeFox/bootable/recovery -b fox_14.1 bootable/recovery
# Add OrangeFox vendor overlay (Android 16 support)
git clone https://gitlab.com/OrangeFox/vendor/recovery -b fox_16.0 vendor/recovery

export FOX_BUILD_DEVICE=NX779J FOX_AB_DEVICE=1 FOX_BUILD_TYPE=Unofficial
export ALLOW_MISSING_DEPENDENCIES=true
source build/envsetup.sh
lunch twrp_NX779J-bp2a-eng
mka recoveryimage
```

### Build PitchBlack

```bash
# Replace bootable/recovery with PBRP fork
git clone https://github.com/PitchBlackRecoveryProject/android_bootable_recovery -b android-14.0 bootable/recovery

export PB_DEVICE_NAME=NX779J PB_BUILD_TYPE=Unofficial
export ALLOW_MISSING_DEPENDENCIES=true
source build/envsetup.sh
lunch twrp_NX779J-bp2a-eng
mka recoveryimage
```

---

## Flashing

> **Important:** NX779J uses A/B slots — flash to **both** slots.

### Manual

```bash
adb reboot bootloader
fastboot flash recovery_a out/target/product/NX779J/recovery.img
fastboot flash recovery_b out/target/product/NX779J/recovery.img
fastboot reboot recovery
```

---

## Technical notes

- Adapted from the NX789J Pro (RedMagic 10 Pro) device tree
- DRM display requires `drmSetMaster()` before each atomic commit (SM8650 driver rejects commits without DRM master)
- `servicemanager` needs `libperfetto_c.so` to start in recovery — bundled in the ramdisk
- `ssgtzd` (Qualcomm SSG TZ Daemon) needs `Utils_getTrace` — provided by `libminkdescriptor_shim.so`
- Metadata decryption uses a 60 s timeout to avoid indefinite hang on `smcinvoke_ioctl` when TrustZone is not ready

---

## Credits

- [OrangeFox Recovery Project](https://orangefox.tech)
- [TWRP Team](https://github.com/TeamWin)
- [Reminon, Adapted from NX789J Pro device tree](https://github.com/reminon/twrp_device_nubia_nx789j)
