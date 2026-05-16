# OPLUS ConsumerIRApp prebuilt

Userspace UI for the Kookong IR blaster on pagani. The
`android.hardware.ir@V1` AIDL HAL itself (`android.hardware.ir-service.oplus`)
ships from `device/oneplus/sm8750-common`; this APK is the only missing
piece for an end-to-end IR remote experience.

> **Note for cloners:** the APK is OPLUS proprietary and is not checked
> in (see `.gitignore`). Run `./stage.sh /path/to/stock-oos-dump` from
> this directory before building.

## Source

- App: `com.oplus.consumerIRApp` v16.3.5
- Build: OPLUS stock OOS 16.0 (pagani CPH2723 or any 13-series OOS that
  ships the same APK — they're identical)
- Path in the stock dump: `my_product/del-app/ConsumerIRApp/ConsumerIRApp.apk`
- Compile / target SDK: 36

## Staging

`stage.sh` accepts a stock OOS dump root and copies the APK into place:

```
./stage.sh /path/to/stock-oos-dump
```

The dump root must contain
`my_product/del-app/ConsumerIRApp/ConsumerIRApp.apk` (or
`product/del-app/ConsumerIRApp/ConsumerIRApp.apk` — both layouts are
checked). For a typical workflow:

1. Pull stock OOS payload, extract via `payload_dumper`.
2. Loop-mount or extract `system.img` and `product.img` to a single
   tree, e.g. `/tmp/oos-dump/{system,product,...}`.
3. Run `./stage.sh /tmp/oos-dump`.

## Signing

The APK is `presigned: true` in `Android.bp` — kept with its original
OPLUS Android Team signature. The runtime permission gates we care
about (`android.permission.TRANSMIT_IR`) are normal-protection, so
the signing scheme doesn't gate IR functionality. OEM-only signature
permissions (e.g. `oplus.permission.OPLUS_COMPONENT_SAFE`) silently
no-op without affecting the user-visible IR path.
