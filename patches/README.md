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
git -C frameworks/base apply device/oneplus/pagani/patches/0005-systemui-aod-bypass-charging-label.patch
```

## Patch index

| # | Path | What | Why |
|---|------|------|-----|
| 0001 | `hardware/qcom-caf/common/xbl_config_arb_check/main.cpp` | Treat unparseable XBL anti-rollback header as `OK` instead of fatal | Pagani XBL header layout differs; without this the boot-time ARB check fails install |
| 0002 | `hardware/oplus/vintf/device_framework_matrix.xml` | Bump `vendor.oplus.hardware.subsys_interface.subsys_radio` from `1-8` to `1-9` | OEM ships radio HAL v9 on pagani; matrix needs to allow it |
| 0003 | `kernel/oneplus/sm8750-modules/oplus/kernel/charger/v2/oplus_chg_gki.c` | Populate `POWER_SUPPLY_PROP_POWER_NOW` and `POWER_SUPPLY_PROP_CURRENT_NOW` from CPA topic instead of hardcoded 0 / broken gauge value | OPLUS hardcodes `POWER_NOW=0`, and SUPERVOOC/PPS charge pumps bypass the gauge so `CURRENT_NOW` reads near-zero during fast charge — making AOSP AOD/lockscreen/BatteryStats show "0.0W, 0mA" when actually charging at 33-80W. Patch derives both from the kernel's own `oplus_cpa_get_actual_used_power()` |
| 0004 | `hardware/lineage/interfaces/health/aidl/default/{Android.bp,ChargingControl.cpp,ChargingControl.h}` | Extend the Lineage health HAL `ChargingEnabledNode` struct with optional `value_true_read` / `value_false_read` fields and add matching soong config vars `charging_control_charging_enabled_read` / `charging_control_charging_disabled_read` | Pagani's true-bypass node `/sys/class/oplus_chg/common/plc` accepts writes in `switch=N\|callname=…` format but reports state as `status=N` — the upstream HAL assumes write and read formats match exactly, which causes `getChargingEnabled()` to fail with "Unknown value status=2". Patch lets a node declare a different read pattern. Backwards compatible — nodes that round-trip identically work unchanged. |
| 0005 | `frameworks/base/packages/SystemUI/{src/.../KeyguardIndicationController.java, src/.../qs/tiles/BypassChargingTile.java (new), src/com/android/systemui/lineage/LineageModule.kt, res/values/evolution_strings.xml}` | (a) AOD lockscreen label "X% • Bypass Charging" when PLC bypass is active. (b) Quick Settings tile `bypass_charging` that toggles the manual override via the new `HealthInterface.setBypassChargingEnabled` API (added in patch 0006). | (a) When patch 0004's bypass kicks in, kernel still reports `POWER_SUPPLY_STATUS=Charging` → AOD would show misleading generic text. Patch reads `/sys/class/oplus_chg/common/plc`; when `status=3`, swaps to bypass-specific label. Falls through silently on non-OPLUS hardware. (b) Mirror of the LineageParts preference (patch 0007) so users can flip bypass from the QS panel without diving into Settings. Tile self-hides via `isAvailable()` if HAL doesn't support BYPASS. |
| 0006 | `lineage-sdk/{sdk/src/java/lineageos/providers/LineageSettings.java, sdk/src/java/lineageos/health/HealthInterface.java, sdk/src/java/lineageos/health/IHealthInterface.aidl, lineage/lib/main/java/org/lineageos/platform/internal/health/{ChargingControlController,HealthInterfaceService}.java}` | Add `Settings.System.BYPASS_CHARGING_ENABLED` constant, `IHealthInterface` AIDL methods (`isBypassChargingSupported` / `getBypassChargingEnabled` / `setBypassChargingEnabled`), and a `ChargingControlController` ContentObserver that forces the HAL into bypass when the setting flips on (overrides the auto Toggle/Limit logic) and releases the FET when it flips off. | The framework's existing Toggle provider periodically re-evaluates `setChargingEnabled` based on its own SoC vs limit logic, so any direct write to PLC would get reverted within seconds. This patch makes the manual override sticky by checking the setting at the top of `updateChargeControl()` and short-circuiting before the provider runs. New AIDL methods are appended at the end of `IHealthInterface` (transaction-code-positional ABI compat). |
| 0007 | `packages/apps/LineageParts/{res/xml/charging_control_settings.xml, res/values/strings.xml, src/.../health/ChargingControlSettings.java}` | Add a "Bypass charging" `LineageSystemSettingSwitchPreference` to the Charging Control page (Settings → Battery → Charging Control) with a clear description. Hides itself if the HAL doesn't support BYPASS. | Provides the user-facing surface that flips `BYPASS_CHARGING_ENABLED`. The Settings preference and the QS tile (patch 0005) share the same setting via the framework controller (patch 0006), so they stay in sync regardless of which side the user touches. Also added to the search index's non-indexable-keys when bypass isn't supported, so it doesn't surface bogus results. |
| ~~0006~~ | ~~UprobeStats~~ | (removed — patch caused apex containment fail; root cause is EvoX bp4a's `RELEASE_PLATFORM_SDK_FINAL` not flipping `Platform_sdk_final=true`, which would map `current`→36 in the codenames map and have bionic generate the `version:36` crt variant. EvoX upstream fix needed; not pagani's problem to solve) |
| 0009 | `packages/apps/Settings/res/{xml/top_level_settings.xml,values/strings.xml,drawable/ic_settings_pluskey.xml,drawable/ic_settings_ai.xml}` | Insert a new "Plus Key & AI" PreferenceCategory at order=-115 (between Personalize at -120 and System Info at -110, so it lands above Storage). Two HomepagePreferences inside dispatch to PlusKey APK via `com.oplus.pluskey.SETTINGS` and `com.oplus.pluskey.AI_SETTINGS` actions. Two new vector drawables — pill-with-plus + sparkle — provide the category icons. | Pagani's hardware Plus Key needs a first-class settings entry. Putting it under the existing System > Buttons screen would bury it; the OnePlus stock UI surfaced it as its own root-level page so we mirror that. The PlusKey APK itself (in `parts/PlusKey/`) clears the system ASSISTANT role on first run so the framework's default key handler stops auto-launching Gemini, leaving long-press exclusively to our service. |
| 0012 | `frameworks/native/services/surfaceflinger/RefreshRateOverlay.cpp` | In `getOrCreateBuffers()`, when the framework is in VRR idle and `SetByHwc` isn't owning the overlay, read sysprop `vendor.display.backend_fps` (published by the LTPO KSU daemon as a mirror of `/sys/kernel/oplus_display/min_fps`) and substitute it for `refreshRate`, clearing `idle` so `drawDash` is skipped. Result: overlay shows the panel's actual ADFR floor (e.g. "1") instead of "--" during VRR idle. | OPlus's OOS replaces AOSP's "VRR idle = dash" with their AVT (Adaptive Vsync Time) cache: their SF binary has `cacheAvtRefreshRate fps:%d` / `applyAvtRefreshRate` — they always show a real number tracking the panel's emission rate. Without this, our overlay shows "--" during idle even though the panel is genuinely emitting at 1Hz, which makes LTPO invisible to the user. SF can't read the kernel sysfs directly (SELinux), hence the daemon-published sysprop bridge. |
| 0013 | `packages/apps/Settings/{res/xml/display_settings.xml, res/values/evolution_strings.xml, src/.../display/PaganiLtpoIdleController.java}` | Adds a `SwitchPreferenceCompat` to Settings → Display titled "Reduce idle display power". Controller writes `persist.sys.pagani_ltpo_idle` (0/1) via `SystemProperties.set`. `init.pagani-ltpo.rc` (in-tree under `device/oneplus/pagani/parts/ltpo/`) reacts to the property and writes `0x3041` (off) or `0x3051` (on, with bit 4 = `OPLUS_ADFR_CONFIG_IDLE_MODE`) to `/sys/kernel/oplus_display/adfr_config`. Toggle is hidden on devices other than `OP612BL1`/`OP60F5L1` via `getAvailabilityStatus`. | Bit 4 of adfr_config gates the panel's ability to fully drop the MIPI DSI link during sustained idle (see `oplus_adfr.c:262 oplus_adfr_idle_mode_is_enabled`). Adds another ~3-5 mW of savings on top of the 1Hz ADFR floor. Behind a user toggle because it has a tiny first-touch latency cost (DSI link wake) which some users might notice. Verifiable in logcat under tag `pagani_ltpo` (daemon prints adfr_config every 30s). |
| 0011 | `frameworks/native/services/surfaceflinger/DisplayHardware/HWComposer.cpp` | In `getModesFromDisplayConfigurations()`, after copying `vrrConfig` from the AIDL composer3 v3 config: if it's empty AND the sysprop `ro.vendor.display.synthetic_vrr_min_hz` is set, synthesize a `VrrConfig` with `minFrameIntervalNs = vsyncPeriod` so the framework treats the mode as VRR-capable. Also guards the existing `hwcMode.vrrConfig->notifyExpectedPresentConfig = {}` deref with a null check (latent bug for any HAL not advertising VRR). | Pagani's panel hardware supports 1-120Hz LTPO via ADFR (kernel sends `qcom,mdss-dsi-adfr-min-fps-5-command` for 1Hz, verified). The QTI composer-service implements composer3 v3 but does NOT populate `VrrConfig` in `getDisplayConfigurations`, so the framework sees `vrrConfig=N/A` and refuses to request below the panel's DSI timing rate (60/90/120). Synthesizing the VrrConfig at the SF←HWC boundary lets `RefreshRateSelector` pick true variable rates, makes the dev-options refresh-rate overlay report effective rate, and unlocks per-layer FrameRateOverride for sub-60Hz. Combined with `frame_rate_category_min=1` soong config (in `sm8750-common/common.mk`), allows down to 1Hz. |

## Known incomplete (see `.todo-incomplete-diffs.txt`)

These are also locally modified, but `git diff` failed to render them due to
missing object IDs (incomplete repo state):

- `hardware/qcom-caf/sm8450-6.6/audio/primary-hal/hal/core/configs`
- `hardware/qcom-caf/sm8750/audio/primary-hal/hal/core/configs`
- `device/qcom/sepolicy_vndr/sm8750/generic/vendor/common/domain.te`

To regenerate after fixing the local clone (e.g. `git fetch --unshallow`),
re-run the diff commands documented in `.todo-incomplete-diffs.txt`.
