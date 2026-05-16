#!/vendor/bin/sh
#
# Pagani LTPO daemon — keeps ADFR sa_min_fps pinned to a low floor so the
# panel's hardware engages low-Hz (down to 1Hz) self-refresh on idle.
#
# The kernel's oplus_adfr_status_reset() overwrites sa_min_fps to the current
# panel timing rate (60/90/120) on every timing switch, so we re-write our
# desired value right after each reset.
#
# Also publishes the active min_fps to vendor.display.backend_fps so
# SurfaceFlinger's RefreshRateOverlay can show the actual emitted rate
# instead of dashing during VRR idle (mirrors OPlus's AVT cache).
#
# Reads /vendor/etc/pagani-ltpo.conf for runtime tunables; defaults safe.

NODE=/sys/kernel/oplus_display/min_fps
ADFR_CONFIG=/sys/kernel/oplus_display/adfr_config
PROP=vendor.display.backend_fps
CONFIG=/vendor/etc/pagani-ltpo.conf
TAG=pagani_ltpo

# Defaults (overridden by config)
TARGET_MIN_FPS=1
INTERVAL=0.1
LOG_INTERVAL=300   # Log state every N iterations (300 * 0.1s = 30s)

[ -f "$CONFIG" ] && . "$CONFIG"

# Wait for the sysfs node to exist (early boot)
i=0
while [ ! -w "$NODE" ] && [ $i -lt 60 ]; do
    sleep 1
    i=$((i + 1))
done
[ ! -w "$NODE" ] && { log -t "$TAG" -p e "node not writable, exiting"; exit 1; }

log -t "$TAG" -p i "started, target=$TARGET_MIN_FPS interval=$INTERVAL"

ITER=0
while true; do
    # Re-read config every iteration so live edits take effect
    [ -f "$CONFIG" ] && . "$CONFIG"

    # Sanity-clamp to the panel's supported floors
    case "$TARGET_MIN_FPS" in
        1|10|20|30|60|90|120) ;;
        *) TARGET_MIN_FPS=1 ;;
    esac

    # Re-write min_fps if it drifted
    CUR=$(cat "$NODE" 2>/dev/null)
    [ "$CUR" != "$TARGET_MIN_FPS" ] && echo "$TARGET_MIN_FPS" > "$NODE" 2>/dev/null

    # Mirror to a sysprop SF can read (SELinux blocks SF from reading sysfs)
    [ "$(getprop $PROP)" != "$TARGET_MIN_FPS" ] && \
        setprop "$PROP" "$TARGET_MIN_FPS" 2>/dev/null

    # Periodic state log so users can verify in logcat: adb logcat -s pagani_ltpo
    ITER=$((ITER + 1))
    if [ $((ITER % LOG_INTERVAL)) -eq 0 ]; then
        ADFR_NOW=$(cat "$ADFR_CONFIG" 2>/dev/null)
        log -t "$TAG" -p i "state min_fps=$(cat $NODE 2>/dev/null) adfr_config=$ADFR_NOW backend_fps=$(getprop $PROP)"
    fi

    sleep "$INTERVAL"
done
