#!/usr/bin/env bash
# One-time setup: sync TWRP-16.0 manifest, place device tree, fetch Clang 20, apply patches.
# Run from the kitchen root (parent of this scripts/ directory).
# Usage: bash scripts/00_setup.sh [build_root]
#   build_root defaults to ./twrp-build
set -eo pipefail

KITCHEN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${1:-$(cd "$KITCHEN_DIR/../TWRP" 2>/dev/null && pwd || echo "$KITCHEN_DIR/twrp-build")}"
JOBS="$(nproc)"

MANIFEST_URL="https://github.com/TWRP-Test/platform_manifest_twrp_aosp.git"
MANIFEST_BRANCH="twrp-16.0"

echo "==> Build root: $BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# ── Repo init + sync ──────────────────────────────────────────────────────────
if [ ! -d .repo ]; then
    echo "==> Initialising repo ($MANIFEST_BRANCH)..."
    repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --depth=1
fi

echo "==> Syncing (this takes ~30 min on first run)..."
repo sync -j"$JOBS" --no-tags --no-clone-bundle --force-sync

# ── Device tree ───────────────────────────────────────────────────────────────
DEVICE_DST="device/nubia/NX779J"
if [ ! -d "$DEVICE_DST" ]; then
    echo "==> Installing device tree -> $DEVICE_DST"
    mkdir -p "$(dirname "$DEVICE_DST")"
    cp -r "$KITCHEN_DIR/device" "$DEVICE_DST"
else
    echo "==> Device tree already in place, skipping."
fi

# ── Clang 20 (clang-r547379) ─────────────────────────────────────────────────
# The twrp-16.0 manifest ships only clang-r536225 (Clang 19), but build/soong
# hardcodes clang-r547379 (Clang 20). Fetch it from AOSP main.
CLANG_DIR="prebuilts/clang/host/linux-x86"
CLANG_VER="clang-r547379"
if [ ! -d "$CLANG_DIR/$CLANG_VER" ]; then
    echo "==> Fetching $CLANG_VER from AOSP (sparse checkout)..."
    if ! git -C "$CLANG_DIR" remote get-url aosp &>/dev/null; then
        git -C "$CLANG_DIR" remote add aosp \
            https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86
    fi
    git -C "$CLANG_DIR" fetch aosp main --depth=10 --no-tags
    git -C "$CLANG_DIR" checkout aosp/main -- "$CLANG_VER"
    echo "==> Clang 20 ready."
else
    echo "==> $CLANG_VER already present, skipping."
fi

# ── Makefile patch (OrangeFox hooks) ─────────────────────────────────────────
PATCH="$KITCHEN_DIR/patches/makefile_orangefox_hooks.patch"
MAKEFILE="build/make/core/Makefile"
if ! grep -q "Fox_Before_Recovery_Image" "$MAKEFILE"; then
    echo "==> Applying OrangeFox Makefile hooks..."
    git -C build/make apply --whitespace=nowarn < <(
        # Strip the a/b prefix from the patch so it applies from build/make root
        sed 's|^--- a/|--- |; s|^+++ b/|+++ |' "$PATCH"
    )
    echo "==> Makefile patched."
else
    echo "==> OrangeFox Makefile hooks already applied, skipping."
fi

echo ""
echo "==> Setup complete. Build root: $BUILD_DIR"
echo "    TWRP:       bash scripts/01_build_twrp.sh $BUILD_DIR"
echo "    OrangeFox:  bash scripts/02_build_orangefox.sh $BUILD_DIR"
echo "    PitchBlack: bash scripts/03_build_pbrp.sh $BUILD_DIR"
