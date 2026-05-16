#
# Copyright (C) 2021-2025 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Partitions
BOARD_SUPER_PARTITION_SIZE := 13329498112

# Include the common OEM chipset BoardConfig.
include device/oneplus/sm8750-common/BoardConfigCommon.mk

DEVICE_PATH := device/oneplus/pagani

# Assert
TARGET_OTA_ASSERT_DEVICE := OP60F5L1,OP612BL1

# Display
TARGET_SCREEN_DENSITY := 480

# Kernel
TARGET_KERNEL_ADDITIONAL_FLAGS += CONFIG_PAGANI_DTB=y

# Release-build perf strip (skipped when KERNEL_BUILD_DEBUG=true). Fragment is
# added to the kernel tree by patches/0014-kernel-pagani-release-fragment.patch
# at lunch time. Debug builds also swap perf->consolidate variant to get
# CORESIGHT_SOURCE_ETM4X=m for simpleperf cs-etm:k branch capture (AutoFDO).
ifeq ($(KERNEL_BUILD_DEBUG),true)
# sun_consolidate.config is a fragment that layers on top of sun_perf.config —
# it adds debug bits (ETM4X, CMA_DEBUG, DEBUG_PAGEALLOC), it does not replace
# perf. Dropping perf would leak header stubs (e.g. battery_charger.h's
# CONFIG_QTI_BATTERY_CHARGER fallbacks) into oplus_hal_adsp.c → redefinition.
TARGET_KERNEL_CONFIG := \
    gki_defconfig \
    vendor/sun_perf.config \
    vendor/sun_consolidate.config \
    vendor/oplus/sun_perf.config
else
TARGET_KERNEL_CONFIG += vendor/oplus/pagani_release.config
endif

# AutoFDO. Profile is collected on-device with tools/autofdo_capture.sh and
# placed at $(DEVICE_PATH)/profiles/pagani_kernel.afdo. If the file is absent
# or KERNEL_BUILD_DEBUG=true, the kernel builds without sample-PGO. The flag
# does not change KMI; vendor modules built without FDO load fine alongside
# an FDO'd vmlinux. Single space-free KCFLAGS — make→shell re-tokenization
# clobbers values with embedded whitespace.
PAGANI_AFDO_PROFILE := $(abspath $(DEVICE_PATH)/profiles/pagani_kernel.afdo)
ifneq ($(KERNEL_BUILD_DEBUG),true)
ifneq ($(wildcard $(PAGANI_AFDO_PROFILE)),)
TARGET_KERNEL_ADDITIONAL_FLAGS += KCFLAGS=-fprofile-sample-use=$(PAGANI_AFDO_PROFILE)
endif
endif

# Properties
TARGET_ODM_PROP += $(DEVICE_PATH)/odm.prop
TARGET_SYSTEM_EXT_PROP += $(DEVICE_PATH)/system_ext.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# SELinux — pagani-specific (LTPO daemon, etc.)
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# Recovery
TARGET_RECOVERY_UI_MARGIN_HEIGHT := 103


# Include the proprietary files BoardConfig.
include vendor/oneplus/pagani/BoardConfigVendor.mk

# Allow vendor property_contexts to label ro.oplus.camera.* (which OplusCamera
# reads at runtime). Vendor partition's strict prefix policy normally blocks
# anything outside ro.vendor./vendor./persist.vendor./etc. Dodge sm8750-common
# tree relies on this escape hatch.
BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE := true

# Disable LineageOS-built generic NXP JavaCard StrongBox HAL service. OEM
# libjc_keymint3.nxp is keymint AIDL V3, our tree is V4 → unbridgeable without
# shadowing half the upstream keymaster lib chain. Use TEE StrongBox instead.
TARGET_NO_JAVACARD_STRONGBOX := true
