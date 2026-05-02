# Pagani upstream-tree patches

These are pagani-specific changes that live in upstream git trees outside of
the device/vendor directories — not overlay-able, can't be expressed in the
device tree as separate files. The upstream trees themselves stay pristine
in git; these patches are applied at `lunch` time by `vendorsetup.sh`.

## Auto-apply

`device/oneplus/pagani/vendorsetup.sh` runs on `lunch lineage_pagani-*` and
applies every patch in this directory to its target tree. Idempotent —
already-applied patches are skipped. A marker file `.patches-applied` is
touched after a clean run so subsequent lunches are instant; touching this
patches/ dir invalidates the marker and forces re-check.

## Manual apply

If you ever need to apply by hand:

```sh
cd ~/coding/pagani/custom_rom/evolutionx
git -C hardware/qcom-caf/common apply device/oneplus/pagani/patches/0001-xbl_config_arb_check-tolerate-unsupported-header.patch
git -C hardware/oplus apply device/oneplus/pagani/patches/0002-vintf-bump-subsys_radio-to-1-9.patch
git -C kernel/oneplus/sm8750-modules apply device/oneplus/pagani/patches/0003-oplus_chg_gki-populate-power-now-and-current-now.patch
git -C hardware/lineage/interfaces apply device/oneplus/pagani/patches/0004-lineage-health-bypass-via-plc.patch
```

## Patch index

| # | Path | What | Why |
|---|------|------|-----|
| 0001 | `hardware/qcom-caf/common/xbl_config_arb_check/main.cpp` | Treat unparseable XBL anti-rollback header as `OK` instead of fatal | Pagani XBL header layout differs; without this the boot-time ARB check fails install |
| 0002 | `hardware/oplus/vintf/device_framework_matrix.xml` | Bump `vendor.oplus.hardware.subsys_interface.subsys_radio` from `1-8` to `1-9` | OEM ships radio HAL v9 on pagani; matrix needs to allow it |
| 0003 | `kernel/oneplus/sm8750-modules/oplus/kernel/charger/v2/oplus_chg_gki.c` | Populate `POWER_SUPPLY_PROP_POWER_NOW` and `POWER_SUPPLY_PROP_CURRENT_NOW` from CPA topic instead of hardcoded 0 / broken gauge value | OPLUS hardcodes `POWER_NOW=0`, and SUPERVOOC/PPS charge pumps bypass the gauge so `CURRENT_NOW` reads near-zero during fast charge — making AOSP AOD/lockscreen/BatteryStats show "0.0W, 0mA" when actually charging at 33-80W. Patch derives both from the kernel's own `oplus_cpa_get_actual_used_power()` |
| 0004 | `hardware/lineage/interfaces/health/aidl/default/{Android.bp,ChargingControl.cpp,ChargingControl.h}` | Extend the Lineage health HAL `ChargingEnabledNode` struct with optional `value_true_read` / `value_false_read` fields and add matching soong config vars `charging_control_charging_enabled_read` / `charging_control_charging_disabled_read` | Pagani's true-bypass node `/sys/class/oplus_chg/common/plc` accepts writes in `switch=N\|callname=…` format but reports state as `status=N` — the upstream HAL assumes write and read formats match exactly, which causes `getChargingEnabled()` to fail with "Unknown value status=2". Patch lets a node declare a different read pattern. Backwards compatible — nodes that round-trip identically work unchanged. |
| ~~0006~~ | ~~UprobeStats~~ | (removed — patch caused apex containment fail; root cause is EvoX bp4a's `RELEASE_PLATFORM_SDK_FINAL` not flipping `Platform_sdk_final=true`, which would map `current`→36 in the codenames map and have bionic generate the `version:36` crt variant. EvoX upstream fix needed; not pagani's problem to solve) |

## Known incomplete (see `.todo-incomplete-diffs.txt`)

These are also locally modified, but `git diff` failed to render them due to
missing object IDs (incomplete repo state):

- `hardware/qcom-caf/sm8450-6.6/audio/primary-hal/hal/core/configs`
- `hardware/qcom-caf/sm8750/audio/primary-hal/hal/core/configs`
- `device/qcom/sepolicy_vndr/sm8750/generic/vendor/common/domain.te`

To regenerate after fixing the local clone (e.g. `git fetch --unshallow`),
re-run the diff commands documented in `.todo-incomplete-diffs.txt`.
