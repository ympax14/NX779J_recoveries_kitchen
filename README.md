# NX779J Recoveries Kitchen

Build kitchen for **TWRP**, **OrangeFox**, and **PitchBlack (PBRP)** recovery images for the **Nubia RedMagic 10 Air (NX779J)** — Snapdragon 8 Gen 3 (SM8650), Android 15/16, Virtual A/B.

## Requirements

- Linux x86_64 (Ubuntu 22.04+ recommended)
- ~250 GB free disk space
- `repo`, `git`, `python3`, `curl`, build-essential, OpenJDK 21
- Lunch target: `twrp_NX779J-bp2a-eng`

```bash
sudo apt install git-core python3 curl repo default-jdk-headless \
  build-essential gcc g++ libssl-dev libncurses-dev bc flex bison
```

## Quick Start

```bash
# 1. Clone this kitchen
git clone https://github.com/ympax14/NX779J_recoveries_kitchen
cd NX779J_recoveries_kitchen

# 2. One-time setup (sync ~120 GB, ~30-60 min)
bash scripts/00_setup.sh

# 3. Build any recovery (each ~15-20 min after initial sync)
bash scripts/01_build_twrp.sh
bash scripts/02_build_orangefox.sh
bash scripts/03_build_pbrp.sh
```

Output images land in `builds/`:
| Recovery | Output file |
|---|---|
| TWRP | `builds/twrp_NX779J.img` |
| OrangeFox | `builds/orangefox_NX779J.img` |
| PBRP | `builds/pbrp_NX779J.img` |

## Custom build root

By default the build tree is created at `twrp-build/` inside this repo.
Pass a custom path as the first argument to any script:

```bash
bash scripts/00_setup.sh /path/to/build
bash scripts/01_build_twrp.sh /path/to/build
```

## How it works

### Base: `twrp-16.0` manifest

All three recoveries share the same TWRP-Test `twrp-16.0` manifest
(`https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git`).

### Clang 20 (`clang-r547379`)

`build/soong` hardcodes `clang-r547379` (Clang 20). The manifest ships only
`clang-r536225` (Clang 19), so `00_setup.sh` fetches `clang-r547379` from
AOSP `main` via a sparse git checkout.

### OrangeFox strategy

OrangeFox uses TWRP's `bootable/recovery` (Android 16 compatible) plus
the `fox_16.0` vendor overlay from `vendor/recovery`. The overlay's
`OrangeFox_A16.sh` script is invoked via hooks added to
`build/make/core/Makefile` (see `patches/makefile_orangefox_hooks.patch`).

The `NOT_ORANGEFOX=1` env variable disables the hooks for TWRP/PBRP builds.

### Flashing

```bash
fastboot flash recovery builds/twrp_NX779J.img
# or flash to both A/B slots:
fastboot flash recovery_a builds/twrp_NX779J.img
fastboot flash recovery_b builds/twrp_NX779J.img
```

## Device tree

The device tree in `device/` is installed by `00_setup.sh` to
`device/nubia/NX779J` inside the build tree.

Key flags:
- `TARGET_ARCH := arm64`, platform `pineapple` (SM8650)
- Virtual A/B (`BOARD_VIRTUAL_AB_OTA := true`)
- `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true`
- `TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888`
