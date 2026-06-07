#
# Copyright (C) 2025 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/nubia/NX779J

# Inherit from device.mk configuration
$(call inherit-product, $(DEVICE_PATH)/device.mk)

# Device identifier
PRODUCT_DEVICE := NX779J
PRODUCT_NAME := twrp_NX779J
PRODUCT_BRAND := nubia
PRODUCT_MANUFACTURER := nubia
PRODUCT_MODEL := RedMagic 10 Air

# Assert
TARGET_OTA_ASSERT_DEVICE := NX779J

# Fingerprint — TODO: replace with the actual ro.build.fingerprint from your NX779J device
# Run: adb shell getprop ro.build.fingerprint
BUILD_FINGERPRINT := nubia/PQ83A06-EEA/PQ83A06:15/AQ3A.240812.002/20250916.230514:user/release-keys

# Theme
TW_STATUS_ICONS_ALIGN := center
