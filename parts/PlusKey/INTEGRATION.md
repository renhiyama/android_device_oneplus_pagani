# Plus Key — custom-ROM integration guide

The OnePlus 13s (pagani) replaces the legacy alert-slider with a programmable
"Plus Key". Stock OOS surfaces it as a configurable shortcut (camera,
flashlight, sound profile, etc.) with its own first-class Settings page.

Bringing the same experience to a custom ROM takes **three independent
pieces** that together replace the AOSP / LineageOS "Assist key" plumbing:

| # | Piece | Lives in | Role |
|---|-------|----------|------|
| 1 | **PlusKey APK** | `parts/PlusKey/` (in-tree app) | User-facing UI + the action runner |
| 2 | **System Settings re-wiring** | `patches/0009` *(add)* + `overlay-lineage/.../config.xml` *(remove)* | New "Plus Key" root entry, old "Assist key" category hidden |
| 3 | **Framework key handler** | `patches/0010` (PhoneWindowManager + new `PaganiPlusKey` helper) | Routes `KEYCODE_ASSIST` to the APK via a broadcast |

The pieces are intentionally decoupled — if you're porting to a different
OnePlus model with the same hardware key behaviour, you can mostly reuse
piece 1 verbatim and only re-tune pieces 2 + 3 for the new device codename.

Hardware contract (verified on pagani): the key reports a standard Android
`KEYCODE_ASSIST` (long-press to fire), the same keycode the AOSP "Assist"
button family uses on legacy phones. Nothing kernel-side is special — all
the work is in userspace.

---

## Piece 1 — the PlusKey APK (`parts/PlusKey/`)

A small platform-signed app, installed to `/system_ext`, that owns the
runtime behaviour. The whole thing is in-tree source, no prebuilts.

```
parts/PlusKey/
├── Android.bp            # android_app, platform-signed, system_ext_specific
├── AndroidManifest.xml   # no MAIN/LAUNCHER, see "Entry points" below
├── com.oplus.pluskey.xml # privapp allowlist (signature perms)
├── res/                  # Material You UI, vector drawables, layouts
└── src/                  # Kotlin/Java sources
```

### Why platform-signed + privileged
The app needs:
- `WRITE_SECURE_SETTINGS` / `WRITE_SETTINGS` — saving the user's chosen
  action persists in `Settings.System` (the AOSP/Lineage long-press
  pipeline already reads from `Settings.System` for short/long press
  defaults; the PlusKey APK uses the same store for consistency).
- `ACCESS_NOTIFICATION_POLICY` — DND toggle action.
- `MODIFY_AUDIO_SETTINGS` — ringer-mode cycle action.
- `STATUS_BAR_SERVICE`, `CAPTURE_VIDEO_OUTPUT`, `MANAGE_INPUT_DEVICES`,
  `MONITOR_INPUT` — flashlight, screenshot, camera launch, etc.

All declared in `com.oplus.pluskey.xml` (privapp allowlist). The build
fails closed if any of these aren't present in the allowlist, which
catches "I forgot to copy the xml" regressions automatically.

### Entry points (no LAUNCHER)
There is **no `MAIN`/`LAUNCHER` activity** — by design. The app must be
unreachable from the Pixel/Lineage launcher because it has nothing
useful at the activity-root level; everything happens via three
explicit intents:

| Intent action | Target | Purpose |
|---------------|--------|---------|
| `com.oplus.pluskey.SETTINGS` | Settings activity | Opened from the "Plus Key" Settings entry (piece 2) |
| `com.oplus.pluskey.AI_SETTINGS` | AI settings stub activity | Opened from the "AI" Settings entry (piece 2) |
| `com.oplus.pluskey.LONG_PRESS` | Broadcast receiver | Fired by the framework key handler (piece 3) |

The receiver reads the user's saved action from `Settings.System` and
runs it (toggle flashlight, switch ringer, etc.). It does not start an
activity for headless actions, so a long-press on the lockscreen runs
the action without unlocking the device.

### First-run side-effects
On boot completion the app clears the system `ASSISTANT` role. The
framework would otherwise auto-launch Gemini (or whatever holds the
assistant role) on `KEYCODE_ASSIST` short-press, which conflicts with
piece 3's intercept logic. Clearing the role is idempotent and a no-op
if the role was already empty.

---

## Piece 2 — Settings integration (add + remove)

Two halves: **add** a dedicated "Plus Key" root entry, **remove** the
legacy LineageParts "Assist key" category so users don't see two ways
to configure the same hardware key.

### Add — `patches/0009-settings-pluskey-category.patch`

Patches `packages/apps/Settings`. Inserts a new `PreferenceCategory`
into `res/xml/top_level_settings.xml` at `order=-115` — between
"Personalize" (-120) and "System info" (-110), so it lands above
"Storage" in the homepage scroll.

Inside the category two `HomepagePreference`s:

```xml
<HomepagePreference
    android:icon="@drawable/ic_settings_pluskey"
    android:title="@string/top_level_pluskey_title"
    android:summary="@string/top_level_pluskey_summary"
    android:fragment=""
    android:order="-115">
    <intent
        android:action="com.oplus.pluskey.SETTINGS"
        android:targetPackage="com.oplus.pluskey" />
</HomepagePreference>
```

Same shape for the AI entry, just with `.AI_SETTINGS`. Two new vector
drawables (`ic_settings_pluskey.xml`, `ic_settings_ai.xml`) provide the
icons — a pill-with-plus and a sparkle.

Why a `HomepagePreference` with an explicit `<intent>` instead of a
fragment ref? Because the target lives in a separate APK (piece 1) and
must launch as an activity, not be embedded. The Settings homepage
respects the intent and starts the APK's settings activity inline,
matching the look-and-feel of the other root entries.

### Remove — `overlay-lineage/.../config.xml`

Drops the **Assist (8)** bit from `config_deviceHardwareKeys` and
`config_deviceHardwareWakeKeys`, leaving only Volume rocker (64):

```xml
<integer name="config_deviceHardwareKeys">64</integer>
<integer name="config_deviceHardwareWakeKeys">64</integer>
```

LineageParts uses these bitfields to decide which "Buttons" categories
to show under System → Buttons. Without the Assist bit it stops
rendering the "Assist key" category (`packages/apps/LineageParts:
res/xml/button_settings.xml`), so the legacy long/short-press action
pickers disappear cleanly.

This is purely cosmetic — the framework still receives the key event
regardless of this bitfield, and piece 3 intercepts it before the
LineageParts/AOSP long-press dispatch chain runs.

### Don't forget: the Lineage `KeyHandler`
On most LineageOS-supported phones, hardware-key tuning also goes
through `KeyHandler.java` in the device tree. Pagani's KeyHandler does
**not** need to touch `KEYCODE_ASSIST` because piece 3 owns it. Leave
the existing KeyHandler entries (volume, alert slider where present)
unchanged.

---

## Piece 3 — Framework key handler (`patches/0010-pwm-pluskey-handler.patch`)

Patches `frameworks/base/services/core/java/com/android/server/policy/
PhoneWindowManager.java` and adds a tiny helper class
`PaganiPlusKey.java` next to it.

### What it does
`PhoneWindowManager` is where AOSP's hard-coded assist-key behaviour
lives: `assistPress()` short-press, `assistLongPress()` long-press. The
patch wraps both with a pagani gate:

```java
private void assistPress() {
    if (PaganiPlusKey.isPagani()) {
        cancelPreloadRecentApps();
        return;        // short press = no-op
    }
    // ... untouched AOSP code below ...
}

private void assistLongPress() {
    if (PaganiPlusKey.isPagani()) {
        cancelPreloadRecentApps();
        performHapticFeedback(HapticFeedbackConstants.LONG_PRESS, "Plus Key - Long Press");
        PaganiPlusKey.fireLongPress(mContext);
        return;       // long press = broadcast to APK
    }
    // ... untouched AOSP code below ...
}
```

A third tweak fixes `supportLongPress()` in the assist-key
`KeyRule` inner class:

```java
boolean supportLongPress() {
    // On pagani the Plus Key always wants long-press detection so the
    // PlusKey APK can dispatch its configured action; ignore whatever
    // the system assist setting is.
    return PaganiPlusKey.isPagani()
            || mAssistLongPressAction != Action.NOTHING;
}
```

Without this, the framework would refuse to even *detect* a long-press
if the user's assist setting was "do nothing", and piece 1's broadcast
would never fire.

### Why a helper class?
Two reasons:

1. Keeps the patch surface tiny. `PaganiPlusKey.java` is a separate
   new file; the changes to `PhoneWindowManager.java` are only the
   three intercept blocks shown above. Easier to review, easier to
   rebase across `framework/base` updates.
2. Gives the device check (`isPagani()`) and the broadcast send
   (`fireLongPress`) one home, with proper caching of the device-prop
   read (`ro.lineage.device` / `ro.evolution.device`) so we don't stat
   the prop on every key press.

### Why not soong config / a per-device subclass?
Both would be cleaner in isolation, but soong config can't gate Java
code paths cheaply, and a `PhoneWindowManager` subclass would require a
much bigger frameworks/base diff (factory + binding). The
`SystemProperties.get()` check on first use is essentially free.

### Why broadcast and not a direct method call?
`PhoneWindowManager` runs in `system_server`; the PlusKey APK is a
separate process at `system_ext`. Sending an Intent broadcast is the
cleanest IPC across that boundary — no AIDL contract to maintain, no
runtime-permission dance, and the broadcast survives APK upgrades
without restarting `system_server`.

The broadcast carries no extras; the APK reads the current configured
action from `Settings.System` and runs it. That keeps the action store
authoritative regardless of which side (Settings UI or framework
handler) was last updated.

---

## Porting to another OnePlus device

If you're bringing this to a different OnePlus model with the same
hardware-key behaviour:

1. **Piece 1 (APK):** copy `parts/PlusKey/` verbatim. The only
   device-specific assumption is that the platform certificate of the
   target ROM signs it; that's handled automatically by `Android.bp`'s
   `certificate: "platform"`.
2. **Piece 2 (Settings):**
   - Re-apply `patches/0009` to your `packages/apps/Settings` clone —
     no device-specific bits, the strings + drawables are generic.
   - Drop the Assist bit in **your** device's
     `overlay-lineage/.../config.xml` (or whatever overlay your ROM
     uses for `config_deviceHardwareKeys` /
     `config_deviceHardwareWakeKeys`). The pagani overlay file is just
     a template — every device has its own.
3. **Piece 3 (framework):**
   - Re-apply `patches/0010` to your `frameworks/base`.
   - Update `PaganiPlusKey.isPagani()` to recognise your device
     codename — either rename the class to your device or extend the
     check to multiple codenames. Don't bypass the gate; that would
     break every non-pagani OnePlus build sharing the same
     frameworks/base.

For a device that does NOT report `KEYCODE_ASSIST` for its side button,
none of this applies — you'd need a `KeyHandler` mapping in the device
tree first.

---

## Smoke test

After flashing, verify each piece independently:

1. **Piece 1 (APK):** `pm list packages | grep pluskey` shows the
   package; `dumpsys package com.oplus.pluskey | grep flags` shows
   `SYSTEM` + `PRIVILEGED`.
2. **Piece 2 (Settings):** Settings homepage shows the **Plus Key**
   entry. System → Buttons no longer shows the Assist-key category.
3. **Piece 3 (framework):** `adb shell input keyevent --longpress
   KEYCODE_ASSIST` runs the configured action. `logcat -s PaganiPlusKey`
   shows `fireLongPress` when you press-and-hold the physical key.

If any piece fails, the others fall back gracefully — a missing APK
makes the broadcast no-op, a missing PhoneWindowManager patch still
leaves the APK reachable from Settings, and so on. That's intentional:
the loose coupling lets you debug one at a time without a brick risk.
