#!/usr/bin/env bash
# Stage ConsumerIRApp.apk from a stock OOS dump into this directory.
# Run once after cloning the tree, before building.
#
# Usage:
#   ./stage.sh /path/to/stock-oos-dump
#
# The dump must contain either:
#   - my_product/del-app/ConsumerIRApp/ConsumerIRApp.apk
#   - product/del-app/ConsumerIRApp/ConsumerIRApp.apk

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "usage: $0 <stock-oos-dump-root>" >&2
    exit 1
fi

DUMP_ROOT="${1%/}"
DST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK_REL="del-app/ConsumerIRApp/ConsumerIRApp.apk"

candidates=(
    "${DUMP_ROOT}/my_product/${APK_REL}"
    "${DUMP_ROOT}/product/${APK_REL}"
)

SRC=""
for c in "${candidates[@]}"; do
    if [ -f "${c}" ]; then
        SRC="${c}"
        break
    fi
done

if [ -z "${SRC}" ]; then
    echo "ConsumerIRApp.apk not found under ${DUMP_ROOT}" >&2
    echo "expected one of:" >&2
    printf '  %s\n' "${candidates[@]}" >&2
    exit 1
fi

cp -f "${SRC}" "${DST_DIR}/ConsumerIRApp.apk"
echo "[stage] copied ${SRC}"
echo "[stage] -> ${DST_DIR}/ConsumerIRApp.apk"
