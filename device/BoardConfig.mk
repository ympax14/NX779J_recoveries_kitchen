#
# Copyright (C) 2025 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/nubia/NX779J

# OrangeFox is enabled — set NOT_ORANGEFOX := 1 to disable hooks for pure TWRP builds

# Building with minimal manifest
ALLOW_MISSING_DEPENDENCIES := true

# Rules
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_NINJA_USES_ENV_VARS += RTIC_MPGEN
BUILD_BROKEN_PLUGIN_VALIDATION := soong-libaosprecovery_defaults soong-libguitwrp_defaults soong-libminuitwrp_defaults soong-vold_defaults
BUILD_BROKEN_SKIP_ABI_CHECKS := true

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a510

# Power
ENABLE_CPUSETS := true
ENABLE_SCHEDBOOST := true

# Bootloader
PRODUCT_PLATFORM := pineapple
TARGET_BOOTLOADER_BOARD_NAME := pineapple
TARGET_NO_BOOTLOADER := true
TARGET_USES_UEFI := true

# Platform
TARGET_BOARD_PLATFORM := pineapple
TARGET_BOARD_PLATFORM_GPU := qcom-adreno750
QCOM_BOARD_PLATFORMS += pineapple

# Kernel
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME := Image
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
TARGET_KERNEL_CLANG_COMPILE := true
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)

# Ramdisk
BOARD_RAMDISK_USE_LZ4 := true

# A/B
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    init_boot \
    vendor_boot \
    dtbo \
    vbmeta \
    vbmeta_system \
    odm \
    odm_dlkm \
    product \
    system \
    system_ext \
    system_dlkm \
    vendor \
    vendor_dlkm

# Verified Boot
BOARD_AVB_ENABLE := true
BOARD_AVB_ALGORITHM := SHA256_RSA4096
BOARD_AVB_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_ROLLBACK_INDEX_LOCATION := 1
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3

# Partitions
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true

TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_ODM := odm
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USES_VENDOR_DLKMIMAGE := true
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4

BOARD_RECOVERYIMAGE_PARTITION_SIZE := 104857600
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE := 25165824
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608

# Dynamic Partitions
BOARD_SUPER_PARTITION_SIZE := 17179869184
BOARD_SUPER_PARTITION_GROUPS := nubia_dynamic_partitions
BOARD_NUBIA_DYNAMIC_PARTITIONS_SIZE := 17175674880
BOARD_NUBIA_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system \
    system_ext \
    product \
    vendor \
    vendor_dlkm \
    odm \
    odm_dlkm

# File systems
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Extras
TARGET_SYSTEM_PROP += $(DEVICE_PATH)/system.prop

# Recovery
BOARD_HAS_LARGE_FILESYSTEM := true
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab

# Crypto
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
BOARD_USES_QCOM_FBE_DECRYPTION := true
BOARD_USES_METADATA_PARTITION := true
TW_USE_FSCRYPT_POLICY := 2
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
BOOT_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)

# Tools
TW_INCLUDE_7ZA := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_ENABLE_ALL_PARTITION_TOOLS := true

# F2FS
TW_ENABLE_FS_COMPRESSION := false

# Debug
TARGET_USES_LOGD := true
TWRP_INCLUDE_LOGCAT := true
TARGET_RECOVERY_DEVICE_MODULES += debuggerd
RECOVERY_BINARY_SOURCE_FILES += $(TARGET_OUT_EXECUTABLES)/debuggerd

# Fastbootd
TW_INCLUDE_FASTBOOTD := true

# TWRP Configuration
TW_THEME := portrait_hdpi
TW_FRAMERATE := 120
RECOVERY_SDCARD_ON_DATA := true
TARGET_RECOVERY_QCOM_RTC_FIX := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_INCLUDE_NTFS_3G := true
TW_NO_EXFAT_FUSE := true
TW_NO_SCREEN_BLANK := true
TW_USE_DMCTL := true
TW_USE_TOOLBOX := true
TARGET_USES_MKE2FS := true
TW_INCLUDE_FUSE_EXFAT := true
TW_INCLUDE_FUSE_NTFS := true
TW_INPUT_BLACKLIST := "hbtp_vm:goodix_fp:nubia_tgk_aw_sar0_ch0:nubia_tgk_aw_sar1_ch0:sun-mtp-snd-card Headset Jack:sun-mtp-snd-card Button Jack"
TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel0-backlight/brightness"
TW_MAX_BRIGHTNESS := 2047
TW_DEFAULT_BRIGHTNESS := 1200
TW_EXTRA_LANGUAGES := true
TW_EXCLUDE_APEX := true
TW_HAS_EDL_MODE := false
TW_SUPPORT_INPUT_AIDL_HAPTICS := false
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
# Modules loaded in dependency order (after vendor_boot first_stage_init).
# vendor_boot already loads: clk-qcom, gdsc, dispcc-pineapple, smem, gh_arm/dbl/msgq/rm_drv/cpusys_vm,
# qcom-scm, mem_buf_dev, secure_buffer, spmi-pmic-arb, qcom_aoss, pinctrl-msm, icc-*,
# qnoc-pineapple, qti-regmap-debugfs, qcom_iommu_util, etc.
# Only the remaining direct/indirect deps of msm_drm.ko are listed here.
TW_LOAD_VENDOR_MODULES := "llcc-qcom.ko sync_fence.ko qseecom_proxy.ko redriver.ko repeater.ko qmi_helpers.ko qcom_pil_info.ko qcom_glink.ko qcom_smd.ko qcom_glink_smem.ko rproc_qcom_common.ko pdr_interface.ko pmic_glink.ko ucsi_glink.ko wcd_usbss_i2c.ko dwc3-msm.ko smcinvoke_dlkm.ko hdcp_qseecom_dlkm.ko gh_irq_lend.ko gh_mem_notifier.ko msm_hw_fence.ko qcom_va_minidump.ko msm-mmrm.ko altmode-glink.ko nb7vpq904m.ko msm_ext_display.ko drm_dp_aux_bus.ko lt9611uxc.ko drm_display_helper.ko panel_event_notifier.ko msm_drm.ko zte_tpd.ko aw9620x.ko zte_led.ko max31760_fan.ko"
TW_LOAD_VENDOR_MODULES_EXCLUDE_GKI := true
TW_LOAD_PREBUILT_MODULES_AT_FIRST := true
TW_CUSTOM_CPU_TEMP_PATH := "/sys/class/thermal/thermal_zone1/temp"
TW_BACKUP_EXCLUSIONS := /data/fonts
TW_HAS_USB_OTG := true
TW_CUSTOM_BATTERY_PATH := "/sys/class/power_supply/battery"
