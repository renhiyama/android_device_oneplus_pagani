#!/usr/bin/env bash
# Stage OP15 SDK-36 camera donor libs from a user-supplied OnePlus 15
# (CPH2749) stock dump into this tree's lib64/ directory, applying the
# patchelf fixups described in README.md.
#
# Usage:
#   ./stage.sh /path/to/op15/dump
#
# The dump must contain odm/lib64/ (and the requested libs inside it).
# Typical sources:
#   - mounted /odm partition image from CPH2749 OTA payload
#   - extracted super.img → odm.img → loop-mounted
#   - existing tree like vendor/oneplus/op15/proprietary/odm/lib64/
#
# Idempotent. Re-running is safe.

set -euo pipefail

if [ $# -lt 1 ]; then
    cat <<EOF
usage: $0 <op15-dump-root>

The dump root must contain odm/lib64/<lib>.so for each of the donors below.
EOF
    exit 1
fi

DUMP_ROOT="$1"
SRC_DIR="${DUMP_ROOT%/}/odm/lib64"
DST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib64"

if [ ! -d "${SRC_DIR}" ]; then
    echo "no odm/lib64/ under ${DUMP_ROOT}" >&2
    exit 1
fi

mkdir -p "${DST_DIR}"

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

missing=0
for lib in "${LIBS[@]}"; do
    if [ ! -f "${SRC_DIR}/${lib}" ]; then
        echo "[stage] missing in dump: ${SRC_DIR}/${lib}" >&2
        missing=1
    fi
done
if [ ${missing} -ne 0 ]; then
    echo "[stage] aborting — incomplete donor set" >&2
    exit 1
fi

if ! command -v patchelf >/dev/null; then
    echo "patchelf not found in PATH" >&2
    exit 1
fi

for lib in "${LIBS[@]}"; do
    cp -f "${SRC_DIR}/${lib}" "${DST_DIR}/${lib}"
done

# See README "Per-lib blob fixups" — replicates the post-extract patchelf
# that the swap script previously needed.
patchelf --replace-needed \
    android.hardware.graphics.common-V5-ndk.so \
    android.hardware.graphics.common-V7-ndk.so \
    "${DST_DIR}/libAlgoProcess.so"

patchelf --replace-needed \
    vendor.oplus.hardware.camera.aon-V1-ndk.so \
    vendor.oplus.hardware.camera.aon-V1-ndk_platform.so \
    "${DST_DIR}/vendor.oplus.hardware.camera.aon-service-impl.so"

echo "[stage] ${#LIBS[@]} donors staged into ${DST_DIR}"
echo "[stage] next: run tools/apply_op15_camera_swap.sh after extract-files.py"
