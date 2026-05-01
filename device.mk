#
# Copyright (C) 2021-2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# AAPT
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := xxhdpi

# Audio
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/audio/audio_policy_volumes.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes.xml \
    $(LOCAL_PATH)/configs/audio/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \
    $(LOCAL_PATH)/configs/audio/mixer_paths.xml:$(TARGET_COPY_OUT_ODM)/etc/mixer_paths.xml

# Boot animation
TARGET_SCREEN_HEIGHT := 2640
TARGET_SCREEN_WIDTH := 1216

# Display
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/display/displayconfig.xml:$(TARGET_COPY_OUT_VENDOR)/etc/displayconfig/display_id_4630946640660707475.xml

# Fingerprint
$(call soong_config_set,surfaceflinger,udfps_lib,//hardware/oplus:libudfps_extension.oplus)
$(call soong_config_set_bool,qtidisplay,oplus_udfps,true)

# LiveDisplay
$(call soong_config_set_bool,OPLUS_LINEAGE_LIVEDISPLAY_HAL,ENABLE_AF,true)
$(call soong_config_set_bool,OPLUS_LINEAGE_LIVEDISPLAY_HAL,ENABLE_DM,true)

# Overlays
DEVICE_PACKAGE_OVERLAYS += \
    $(LOCAL_PATH)/overlay-lineage

PRODUCT_PACKAGES += \
    FrameworksResTargetEuicc \
    OPlusFrameworksResTarget \
    OPlusSettingsProviderResTarget \
    OPlusSettingsResTarget \
    OPlusSystemUIResTarget

# Pluskey
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/keylayout/gpio-keys.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/gpio-keys.kl

# Regional properties
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/vendor/odm/etc/24821/build.default.prop:$(TARGET_COPY_OUT_ODM)/etc/24821/build.default.prop \
    $(LOCAL_PATH)/recovery/root/vendor/odm/etc/24875/build.IN.prop:$(TARGET_COPY_OUT_ODM)/etc/24875/build.IN.prop 

# Power
$(call soong_config_set,qtipower,mode_ext_lib,power-ext-oplus)

# Sensors
PRODUCT_PACKAGES += \
    sensors.oplus

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

# Telephony
PRODUCT_PACKAGES += \
    OplusEsimSwitcher \
    OplusEuicc

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.telephony.euicc.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/permissions/android.hardware.telephony.euicc.xml

# Touch features
$(call soong_config_set_bool,OPLUS_LINEAGE_TOUCH_HAL,ENABLE_GM,true)
$(call soong_config_set_bool,OPLUS_LINEAGE_TOUCH_HAL,ENABLE_HTPR,false)

# Vibrator
$(call soong_config_set_bool,OPLUS_LINEAGE_VIBRATOR_HAL,USE_EFFECT_STREAM,true)

# Inherit from the common OEM chipset makefile.
$(call inherit-product, device/oneplus/sm8750-common/common.mk)

# Inherit from the proprietary files makefile.
$(call inherit-product, vendor/oneplus/pagani/pagani-vendor.mk)

# OEM Camera (OplusCamera) — dodge-camera-port pipeline, with their apktool
# typeface patch applied to our pagani extraction (removes OplusBase-
# Configuration smali ref so verifier doesn't reject the dex at load time).
$(call inherit-product-if-exists, vendor/oplus/camera/opluscamera.mk)
