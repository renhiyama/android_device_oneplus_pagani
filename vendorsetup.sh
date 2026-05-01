#!/usr/bin/env bash
# Auto-apply pagani upstream-tree patches on lunch.
# Patches live in device/oneplus/pagani/patches/ and target trees outside our
# device/vendor namespace (frameworks/base, hardware/qcom-caf, etc.). We keep
# the upstream trees pristine in git and apply on demand so the device tree
# stays self-contained and publishable.
#
# Idempotent: skips patches that are already applied.

PAGANI_DEVICE_DIR="$(dirname "${BASH_SOURCE[0]}")"
PAGANI_PATCHES_DIR="${PAGANI_DEVICE_DIR}/patches"
PAGANI_PATCH_MARKER="${PAGANI_DEVICE_DIR}/.patches-applied"

# Patches map: "<patch file>:<repo path relative to top>"
PAGANI_PATCH_MAP=(
    "0001-xbl_config_arb_check-tolerate-unsupported-header.patch:hardware/qcom-caf/common"
    "0002-vintf-bump-subsys_radio-to-1-9.patch:hardware/oplus"
)

if [ ! -f "${PAGANI_PATCH_MARKER}" ] || [ "${PAGANI_PATCHES_DIR}" -nt "${PAGANI_PATCH_MARKER}" ]; then
    echo "[pagani] applying upstream patches..."
    pagani_failed=0
    for entry in "${PAGANI_PATCH_MAP[@]}"; do
        patch_file="${entry%%:*}"
        repo_path="${entry##*:}"
        patch_path="${PAGANI_PATCHES_DIR}/${patch_file}"

        [ -f "${patch_path}" ] || { echo "[pagani] skip: ${patch_file} not found"; continue; }

        # Skip if already applied (git apply --check returns 1 if already applied)
        if (cd "${repo_path}" && git apply --check "${patch_path}" 2>/dev/null); then
            (cd "${repo_path}" && git apply "${patch_path}") && \
                echo "[pagani]   applied ${patch_file}" || \
                { echo "[pagani]   FAILED  ${patch_file}"; pagani_failed=1; }
        else
            # Either already applied (good), or context broken (bad) — distinguish
            if (cd "${repo_path}" && git apply --reverse --check "${patch_path}" 2>/dev/null); then
                echo "[pagani]   skip (already applied) ${patch_file}"
            else
                echo "[pagani]   FAILED (context mismatch) ${patch_file}"
                pagani_failed=1
            fi
        fi
    done

    if [ "${pagani_failed}" = "0" ]; then
        touch "${PAGANI_PATCH_MARKER}"
    else
        echo "[pagani] some patches did not apply; build may fail. Check messages above."
    fi
    unset pagani_failed
fi

unset PAGANI_DEVICE_DIR PAGANI_PATCHES_DIR PAGANI_PATCH_MARKER PAGANI_PATCH_MAP
