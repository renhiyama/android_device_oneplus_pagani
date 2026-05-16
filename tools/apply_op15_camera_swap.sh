#!/usr/bin/env bash
# Apply OP15 SDK-36 camera libs over the SDK-35 stock blobs in the proprietary
# tree. Run after every extract-files.py invocation, or when bringing up a
# fresh tree. Idempotent — re-running on an already-swapped tree is a no-op.
#
# See device/oneplus/pagani/op15-camera-libs/README.md for the why.

set -euo pipefail

DEVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOP="$(cd "${DEVICE_DIR}/../../.." && pwd)"

SRC="${DEVICE_DIR}/op15-camera-libs/lib64"
DST="${TOP}/vendor/oneplus/pagani/proprietary/odm/lib64"

LIBS=(
    libAlgoInterface.so
    libAlgoProcess.so
    libalog.so
    libapsultrahdr.so
    libcam.odnn.interface.so
    libdngsdkwrapper.so
    libhwconfigurationutil.so
    libocompression.so
    liboutils.so
    libpngwrapper.so
    libsensorbridge.so
    libsharebuffer_impl.so
    libsharebuffer.so
    libyuvwrapper.so
    vendor.oplus.hardware.camera.aon-service-impl.so
    vendor.oplus.hardware.camera_rfi-V1-service-impl.so
    vendor.oplus.hardware.cammidasservice-V1-ndk.so
    vendor.oplus.hardware.sendextcamcmd-V2-ndk.so
)

if [ ! -d "${DST}" ]; then
    echo "[op15-swap] proprietary tree missing at ${DST}"
    echo "[op15-swap] run extract-files.py first"
    exit 1
fi

changed=0
for lib in "${LIBS[@]}"; do
    if [ ! -f "${SRC}/${lib}" ]; then
        echo "[op15-swap] missing donor: ${SRC}/${lib}"
        exit 1
    fi
    if cmp -s "${SRC}/${lib}" "${DST}/${lib}"; then
        echo "[op15-swap] ${lib} already swapped"
    else
        cp "${SRC}/${lib}" "${DST}/${lib}"
        echo "[op15-swap] ${lib} swapped (sha256 $(sha256sum "${DST}/${lib}" | cut -c1-12)...)"
        changed=1
    fi
done

if [ ${changed} -eq 0 ]; then
    echo "[op15-swap] tree already up to date"
fi
