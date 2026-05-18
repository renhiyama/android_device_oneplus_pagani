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
    "0003-oplus_chg_gki-populate-power-now-and-current-now.patch:kernel/oneplus/sm8750-modules"
    "0004-lineage-health-bypass-via-plc.patch:hardware/lineage/interfaces"
    "0005-systemui-aod-bypass-charging-label.patch:frameworks/base"
    "0006-lineage-sdk-bypass-charging-setting-and-controller.patch:lineage-sdk"
    "0007-lineageparts-bypass-charging-toggle.patch:packages/apps/LineageParts"
    "0008-settings-show-real-charging-power.patch:packages/apps/Settings"
    "0009-settings-pluskey-category.patch:packages/apps/Settings"
    "0010-pwm-pluskey-handler.patch:frameworks/base"
    "0011-surfaceflinger-synthetic-vrr-fallback.patch:frameworks/native"
    "0012-surfaceflinger-overlay-show-backend-fps.patch:frameworks/native"
    "0013-settings-display-ltpo-idle-toggle.patch:packages/apps/Settings"
    "0014-kernel-pagani-release-fragment.patch:kernel/oneplus/sm8750"
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
            # Forward check failed — either fully reverse-applicable (already applied),
            # or partial state because a later patch in the chain disturbed our trailing
            # context. Probe both: clean reverse, then "+added lines already present".
            if (cd "${repo_path}" && git apply --reverse --check "${patch_path}" 2>/dev/null); then
                echo "[pagani]   skip (already applied) ${patch_file}"
            else
                # Heuristic: count +added non-empty payload lines from the patch and
                # check how many are already present verbatim in their target files.
                pagani_added_total=0
                pagani_added_present=0
                pagani_current_target=""
                while IFS= read -r line; do
                    case "$line" in
                        "+++ b/"*)
                            pagani_current_target="${repo_path}/${line#+++ b/}"
                            ;;
                        +++*|+) ;;
                        +*)
                            payload="${line:1}"
                            # ignore pure-whitespace adds and patch metadata
                            [ -z "${payload// /}" ] && continue
                            pagani_added_total=$((pagani_added_total + 1))
                            if [ -n "${pagani_current_target}" ] && [ -f "${pagani_current_target}" ] && \
                               grep -qF -- "${payload}" "${pagani_current_target}" 2>/dev/null; then
                                pagani_added_present=$((pagani_added_present + 1))
                            fi
                            ;;
                    esac
                done < "${patch_path}"

                if [ "${pagani_added_total}" -gt 0 ] && \
                   [ "${pagani_added_present}" -eq "${pagani_added_total}" ]; then
                    echo "[pagani]   skip (applied, context drifted) ${patch_file}"
                else
                    echo "[pagani]   FAILED (context mismatch) ${patch_file} (${pagani_added_present}/${pagani_added_total} added lines present)"
                    pagani_failed=1
                fi
                unset pagani_added_total pagani_added_present pagani_current_target payload line
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
