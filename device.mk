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

# LTPO daemon — keeps ADFR sa_min_fps pinned at 1Hz floor so the panel
# actually engages low-Hz hardware self-refresh on idle. Defeats the kernel's
# oplus_adfr_status_reset() that wipes sa_min_fps on every panel timing
# switch. Mirrors min_fps to vendor.display.backend_fps for the SF overlay.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/parts/ltpo/pagani-ltpo-daemon.sh:$(TARGET_COPY_OUT_VENDOR)/bin/pagani-ltpo-daemon \
    $(LOCAL_PATH)/parts/ltpo/init.pagani-ltpo.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/pagani-ltpo.rc \
    $(LOCAL_PATH)/parts/ltpo/pagani-ltpo.conf:$(TARGET_COPY_OUT_VENDOR)/etc/pagani-ltpo.conf

# Region overlay — pagani is sold as 13s in IN (CPH2723, project 24875)
# and as 13T in CN (PKX110, project 24821). Same hardware, different /odm
# tuning + HALs. The overlay script runs early-boot, reads ro.boot.prjname,
# and bind-mounts /odm/region/<prjname>/ files over their canonical /odm/
# twins. Per-region identity props + eSIM/eID HAL gating live in the .rc.
# CN-divergent /odm payload is pulled in via vendor/oneplus/pagani-cn.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/parts/region/init.pagani-region.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/pagani-region.rc \
    $(LOCAL_PATH)/parts/region/init.pagani-region-binds.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/pagani-region-binds.rc

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

# Plus Key — programmable side-button replacement (Settings UI + receiver
# APK). The button reports KEYCODE_ASSIST via gpio-keys.kl; PhoneWindowManager
# patch 0010 intercepts the long-press and broadcasts to PlusKey, which
# dispatches the user-configured action (sound profile, DND, camera, etc.).
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/keylayout/gpio-keys.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/gpio-keys.kl

PRODUCT_PACKAGES += \
    PlusKey

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

# CN-side region payload for unified pagani build (OnePlus 13T / project
# 24821). Adds CN-only /odm files at canonical paths and CN-version of
# diff-content files at /odm/region/24821/. Auto-applied at boot by
# init.pagani-region.rc when ro.boot.prjname=24821.
$(call inherit-product-if-exists, vendor/oneplus/pagani-cn/pagani-cn-vendor.mk)

# OEM Camera (OplusCamera) — dodge-camera-port pipeline, with their apktool
# typeface patch applied to our pagani extraction (removes OplusBase-
# Configuration smali ref so verifier doesn't reject the dex at load time).
$(call inherit-product-if-exists, vendor/oplus/camera/opluscamera.mk)
