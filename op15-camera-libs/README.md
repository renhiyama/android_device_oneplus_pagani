# OP15 SDK-36 camera lib swap

> **Note for cloners:** the donor `.so` files are OPLUS proprietary and are
> not checked in (see `.gitignore`). Run `./stage.sh /path/to/op15-dump`
> from this directory before building — see "How to obtain the donor libs"
> below.

OPLUS froze pagani's `/odm` at SDK 35 even on Android-16 OOS. EvolutionX rebuilds
`/vendor` at SDK 36, breaking the AOSP vendor-freeze contract. The mismatch
crashes the camera provider HAL on SAT engagement and crashes the camera app
on photo encode (10-bit P010 path).

OnePlus 15 (CPH2749, build 2026-04-10) is the first OPLUS device shipping
SDK-36 vendor. Its SoC-independent OEM camera libs drop in cleanly on pagani
because the OEM camera framework is identical across SM8850/SM8750 — only
sensor tuning data (which lives in `/odm/etc/camera/`, not in the libs) is
SoC-specific.

## Two-stage history

1. **2026-04-30** — first swap covered just the HAL provider crash:
   `libsharebuffer_impl.so` + `libapsultrahdr.so`. Fixed back-cam SAT path,
   OplusCamera launcher opened.
2. **2026-05-05** — extended swap to cover the photo-encode crash chain.
   Added 18 more SDK-36 donors that the camera app calls into via
   `libAlgoProcess` / `libAlgoInterface` / `libcam.oplus.3a.v3`.

## Donor inventory (18 libs)

| Lib | Why |
| --- | --- |
| `libAlgoProcess.so` | The actual SIGSEGV site (`p010LSB2MSBNeon`). Internal struct layouts hardcode SDK-35 wire format; OP15 build uses SDK-36 layout. |
| `libAlgoInterface.so` | Loads + dispatches into libAlgoProcess. Same internal struct concern. |
| `libsharebuffer_impl.so` | HAL provider crash fix from 2026-04-30. |
| `libsharebuffer.so` | Wrapper for libsharebuffer_impl; ABI must match. |
| `libapsultrahdr.so` | UltraHDR encode path; called from libAlgoInterface. |
| `libcam.odnn.interface.so` | Camera DNN interface. |
| `libdngsdkwrapper.so` | RAW DNG SDK wrapper; DT_NEEDED libAlgoProcess. |
| `libhwconfigurationutil.so` | Hardware config util (per-pipeline plumbing). |
| `libsensorbridge.so` | Camera sensor bridge to AOSP sensor service. |
| `libalog.so`, `libocompression.so`, `liboutils.so`, `libpngwrapper.so`, `libyuvwrapper.so` | Small support libs in the same camera lib graph; matched ABI for safety. |
| `vendor.oplus.hardware.camera.aon-service-impl.so` | Always-On camera service impl. |
| `vendor.oplus.hardware.camera_rfi-V1-service-impl.so` | Camera RFI service impl. |
| `vendor.oplus.hardware.cammidasservice-V1-ndk.so` | Camera Midas service AIDL bindings. |
| `vendor.oplus.hardware.sendextcamcmd-V2-ndk.so` | sendextcamcmd V2 AIDL bindings. |

All 18 libs go from `.note.android.ident` SDK marker `0x23` (35) to `0x24` (36).

## Skipped donors and why

| OP15 SDK-36 donor | Reason kept stock SDK-35 |
| --- | --- |
| `libextensionlayer.so` | OP15 build adds DT_NEEDED `libcamxasyncdumpmanager.so`, `libcamxmetadata.so`, `libcamxsocketserverutil.so`, `libchicore.so` — none ship on pagani stock. Loading the OP15 .so would fail at dlopen. |
| `vendor.oplus.hardware.sendextcamcmd-V1-service-impl.so` | OP15 build adds DT_NEEDED `libhcsfwk.so`, `libhcsutils.so` — also missing on pagani stock. |
| `com.oplus.mcx.linearmapper.so` | Same `libcamx*` chain missing. |
| `liboplusdfx.so` | OP15 changed `DfxQueueHalError`'s third arg from `char*` (mangled `Pcz`) to `const char*` (mangled `PKcz`). Different mangled symbol → SDK-35 callers compiled against the old signature can't find the export. The pagani-stock SDK-35 `camera.oemlayer.so` (NOT in our swap list) DT_NEEDS this symbol; swapping liboplusdfx makes camera.oemlayer fail to dlopen, which cascades into the QTI provider's `notifyDeviceStateChange()` null deref. Verified 2026-05-05 on KSU module test. |
| `libcam.oplus.3a.v3.so` | OP15 refactored the 3A wrapper API: removed C++ symbols `_ZN8AEWrapV3...getInstanceEi` (and AF/AWB/PD), replaced with C symbols `getAEC/AF/AWB/PDInstance`. SDK-35 `camera.qcom.so::BaseAFSequenceHandler::SetSingleParamToAlgorithm` calls the old C++ mangled names → returns NULL → SEGV on first AF param push. Verified 2026-05-05 on KSU module test. Means we *cannot* fix the photo-encode-side 3A without also swapping `camera.qcom.so` and the `com.oplus.stats.*` plugins, which would cascade further deps. |

These three need either (a) full CamX SDK-36 lib chain pulled from OP15 too,
or (b) leaving SDK-35. Risk of (a) is uncontrolled — those libs depend on
their own deps recursively. Going with (b) means a small SDK-35/36 island
remains. The crash chain we know about (`libAlgoProcess::p010LSB2MSB`) does
NOT pass through any of the three skipped libs — verified via DT_NEEDED
graph — so the partial swap should still resolve the user-visible crash.

## How to obtain the donor libs

The 18 libs above come from a stock OnePlus 15 (CPH2749) build at SDK 36
or newer. There is no public mirror — you need to source them yourself:

1. Pull the latest CPH2749 OTA payload (oxygenos.net / similar) and
   extract `payload.bin` (`payload_dumper`).
2. Loop-mount `odm.img` (or extract via `lpunpack` if it's still inside
   `super.img`).
3. Run `./stage.sh /path/to/mounted/op15-dump` — the script copies the
   18 libs into `lib64/` and applies the required patchelf fixups.

Minimum dump layout expected by `stage.sh`:

```
<dump-root>/
└── odm/
    └── lib64/
        ├── libAlgoProcess.so
        ├── libAlgoInterface.so
        └── ...      (18 libs total)
```

A successful stage leaves `lib64/` populated and the staging script
exits with `18 donors staged`. Then run `extract-files.py` as usual —
its `__main__` hook auto-invokes `tools/apply_op15_camera_swap.sh`,
which copies the staged donors over the pagani SDK-35 stock blobs.

## After re-running extract-files.py

`extract-files.py` re-pulls stock SDK-35 versions and undoes the swap.
The hook in `extract-files.py` `__main__` auto-runs the script. To re-run
manually:

```
device/oneplus/pagani/tools/apply_op15_camera_swap.sh
```

The script is idempotent — running it on an already-swapped tree is a no-op.

## Per-lib blob fixups

Some donors need symbol or DT_NEEDED massaging at build time
(`device/oneplus/pagani/extract-files.py`):

**Important: donor binaries in `lib64/` are pre-patchelf'd**, NOT byte-identical
to OP15 stock. The patches needed:

- `libAlgoProcess.so` — `--replace-needed
  android.hardware.graphics.common-V5-ndk.so
  android.hardware.graphics.common-V7-ndk.so`. OP15 was built against AIDL
  V5; pagani's AOSP-16 platform builds V7.
- `vendor.oplus.hardware.camera.aon-service-impl.so` — `--replace-needed
  vendor.oplus.hardware.camera.aon-V1-ndk.so
  vendor.oplus.hardware.camera.aon-V1-ndk_platform.so`. OPLUS dropped the
  `_platform` suffix in the OP15 build. Unlike `vendor.oplus.hardware.performance`
  (also a `_platform`→no-suffix change), the `camera.aon` AIDL is OEM-private
  and **not built by AOSP-16** — only the pagani stock `_platform` version
  exists on-device. Without this patchelf, dlopen of aon-service-impl fails,
  the AON device handle never registers, and the QTI camera provider crashes
  on first `notifyDeviceStateChange()` AIDL call from the framework with a
  NULL device pointer (verified 2026-05-05 on KSU module test).

The pre-patchelf approach replaces the previous `extract-files.py` blob_fixup
strategy, because the swap script overwrites the post-extract proprietary copy
*after* `extract-files.py` already ran its fixups — so blob_fixups on the
swapped libs were silently lost. Patchelf'ing the donor once at staging time
solves that: the swap delivers an already-correct binary into the proprietary
tree and no build-time fixup is needed.

Apply / re-apply patchelf to the donors with:

```
patchelf --replace-needed android.hardware.graphics.common-V5-ndk.so \
    android.hardware.graphics.common-V7-ndk.so \
    device/oneplus/pagani/op15-camera-libs/lib64/libAlgoProcess.so

patchelf --replace-needed vendor.oplus.hardware.camera.aon-V1-ndk.so \
    vendor.oplus.hardware.camera.aon-V1-ndk_platform.so \
    device/oneplus/pagani/op15-camera-libs/lib64/vendor.oplus.hardware.camera.aon-service-impl.so
```

Verify with `readelf -d <lib> | grep NEEDED`.

## Coverage

13s and 13T ship byte-identical SDK-35 versions of all 20 libs, so the swap
fixes both phones from a single OTA. No per-region bind-mount needed.

## Known risk: libcam.oplus.3a.v3 and per-sensor tuning

OP15's `libcam.oplus.3a.v3.so` is 2.08 MB, pagani's stock is 1.27 MB — a
significant size delta. 3A (auto-exposure/focus/wb) is the most
sensor-tuning-sensitive of the swapped libs. If we see exposure or color
drift after flash, this is the first revert candidate. Tuning data files in
`/odm/etc/camera/` stay from pagani regardless.
