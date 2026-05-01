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
```

## Patch index

| # | Path | What | Why |
|---|------|------|-----|
| 0001 | `hardware/qcom-caf/common/xbl_config_arb_check/main.cpp` | Treat unparseable XBL anti-rollback header as `OK` instead of fatal | Pagani XBL header layout differs; without this the boot-time ARB check fails install |
| 0002 | `hardware/oplus/vintf/device_framework_matrix.xml` | Bump `vendor.oplus.hardware.subsys_interface.subsys_radio` from `1-8` to `1-9` | OEM ships radio HAL v9 on pagani; matrix needs to allow it |
| ~~0006~~ | ~~UprobeStats~~ | (removed — patch caused apex containment fail; root cause is EvoX bp4a's `RELEASE_PLATFORM_SDK_FINAL` not flipping `Platform_sdk_final=true`, which would map `current`→36 in the codenames map and have bionic generate the `version:36` crt variant. EvoX upstream fix needed; not pagani's problem to solve) |

## Known incomplete (see `.todo-incomplete-diffs.txt`)

These are also locally modified, but `git diff` failed to render them due to
missing object IDs (incomplete repo state):

- `hardware/qcom-caf/sm8450-6.6/audio/primary-hal/hal/core/configs`
- `hardware/qcom-caf/sm8750/audio/primary-hal/hal/core/configs`
- `device/qcom/sepolicy_vndr/sm8750/generic/vendor/common/domain.te`

To regenerate after fixing the local clone (e.g. `git fetch --unshallow`),
re-run the diff commands documented in `.todo-incomplete-diffs.txt`.
