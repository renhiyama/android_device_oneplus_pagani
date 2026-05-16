#!/usr/bin/env bash
# Capture an AutoFDO branch-trace profile from a running pagani kernel and
# convert it to the .afdo format consumed by clang's -fprofile-sample-use.
#
# Workflow:
#   1. Build + flash a debug kernel:  KERNEL_BUILD_DEBUG=true m evolution
#      (perf builds omit CORESIGHT_SOURCE_ETM4X, can't capture branch traces.)
#   2. Boot, exercise the device with representative apps for ~10 min.
#   3. Run this script. Output: device/oneplus/pagani/profiles/pagani_kernel.afdo
#   4. Rebuild without KERNEL_BUILD_DEBUG. The profile is consumed at compile.
#
# Host requirements:
#   - adb in PATH, device connected and authorized
#   - simpleperf (NDK ships it at simpleperf/bin/android/arm64/simpleperf)
#   - llvm-profgen (Arch: pacman -S llvm; Debian/Ubuntu: apt install llvm)
#     llvm-profgen --kernel is LLVM's official Linux-kernel AFDO converter,
#     supersedes autofdo's create_llvm_prof and is bundled with system LLVM.

set -euo pipefail

DEVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="${DEVICE_DIR}/profiles"
PERF_DATA_HOST="${PROFILE_DIR}/perf.data"
AFDO_OUT="${PROFILE_DIR}/pagani_kernel.afdo"
DURATION="${AUTOFDO_DURATION:-600}"
SIMPLEPERF_BIN="${SIMPLEPERF_BIN:-}"

mkdir -p "${PROFILE_DIR}"

if ! command -v adb >/dev/null; then
    echo "adb not in PATH" >&2; exit 1
fi
if ! adb get-state >/dev/null 2>&1; then
    echo "no device via adb" >&2; exit 1
fi

# Use on-device simpleperf if present (Android ships it at /system/bin/simpleperf).
# Falls back to host SIMPLEPERF_BIN or NDK if explicitly provided.
DEVICE_SIMPLEPERF=""
if [ -z "${SIMPLEPERF_BIN}" ] && adb shell '[ -x /system/bin/simpleperf ]' 2>/dev/null; then
    DEVICE_SIMPLEPERF=/system/bin/simpleperf
elif [ -z "${SIMPLEPERF_BIN}" ] && [ -n "${ANDROID_NDK_HOME:-}" ] && \
     [ -x "${ANDROID_NDK_HOME}/simpleperf/bin/android/arm64/simpleperf" ]; then
    SIMPLEPERF_BIN="${ANDROID_NDK_HOME}/simpleperf/bin/android/arm64/simpleperf"
elif [ -z "${SIMPLEPERF_BIN}" ]; then
    echo "no on-device /system/bin/simpleperf and no SIMPLEPERF_BIN/ANDROID_NDK_HOME set" >&2
    exit 1
fi

# Preflight: ETE/TRBE must be exposed on the running kernel. perf builds gate
# this off intentionally; bail loudly so we don't spend 10 min capturing junk.
if ! adb shell '[ -e /sys/bus/event_source/devices/cs_etm ]' 2>/dev/null; then
    echo "running kernel has no cs_etm event source — boot the consolidate (debug) kernel first" >&2
    exit 1
fi

if [ -z "${DEVICE_SIMPLEPERF}" ]; then
    echo "[autofdo] pushing simpleperf"
    adb push "${SIMPLEPERF_BIN}" /data/local/tmp/simpleperf >/dev/null
    adb shell chmod 755 /data/local/tmp/simpleperf
    DEVICE_SIMPLEPERF=/data/local/tmp/simpleperf
fi

echo "[autofdo] capturing ${DURATION}s — exercise the phone now (apps, scroll, camera, etc.)"
adb shell "${DEVICE_SIMPLEPERF}" record \
    -e cs-etm:k -a -b \
    --duration "${DURATION}" \
    -o /data/local/tmp/perf.data

echo "[autofdo] pulling perf.data"
adb pull /data/local/tmp/perf.data "${PERF_DATA_HOST}" >/dev/null

if ! command -v llvm-profgen >/dev/null; then
    echo "perf.data saved at ${PERF_DATA_HOST}" >&2
    echo "install llvm (Arch: pacman -S llvm) and rerun the convert step:" >&2
    echo "  llvm-profgen --kernel --binary=<vmlinux> --perfdata=${PERF_DATA_HOST} --output=${AFDO_OUT} --format=extbinary" >&2
    exit 0
fi

VMLINUX="${VMLINUX:-${DEVICE_DIR}/../../../out/target/product/pagani/obj/KERNEL_OBJ/vmlinux}"
if [ ! -f "${VMLINUX}" ]; then
    echo "vmlinux not found at ${VMLINUX}; pass VMLINUX=<path>" >&2
    exit 1
fi

echo "[autofdo] converting -> ${AFDO_OUT}"
llvm-profgen \
    --kernel \
    --binary="${VMLINUX}" \
    --perfdata="${PERF_DATA_HOST}" \
    --output="${AFDO_OUT}" \
    --format=extbinary

echo "[autofdo] done. Rebuild without KERNEL_BUILD_DEBUG to consume the profile."
