#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
source_file="${1:-${ZHONGJING_SEC_ENV_SLOT_JSON:-$repo_root/slots/slots.jsonl}}"
selected="$(mktemp)"
trap 'rm -f "$selected"' EXIT
"$script_dir/select-slot.sh" "$source_file" "${SLOT_ID:-}" > "$selected"
export ZHONGJING_SEC_ENV_SLOT_JSON="$selected"
artifact_root="${2:-${ZHONGJING_SEC_ARTIFACT_ROOT:-$(jq -r .artifact_local_dir "$selected")}}"
case "$artifact_root" in /*) ;; *) artifact_root="$repo_root/$artifact_root" ;; esac
serial_log="$(jq -r .logs.serial_log "$selected")"
mkdir -p "$artifact_root"
"$repo_root/environment_bundle/scripts/ssh-copy-from.sh" "$serial_log" "$artifact_root/qemu-serial.log"
grep -q 'module inserted' "$artifact_root/qemu-serial.log" && module_inserted=yes || module_inserted=no
grep -q 'guest ready' "$artifact_root/qemu-serial.log" && guest_ready=yes || guest_ready=no
grep -q 'BUG: KASAN:' "$artifact_root/qemu-serial.log" && kasan=yes || kasan=no
printf 'slot_id=%s\nmodule_inserted=%s\nguest_ready=%s\nkasan=%s\ncollection=ok\n' "$(jq -r .slot_id "$selected")" "$module_inserted" "$guest_ready" "$kasan" > "$artifact_root/evidence-status.txt"
(cd "$artifact_root" && find . -maxdepth 1 -type f ! -name evidence-index.txt -print0 | sort -z | xargs -0 sha256sum) > "$artifact_root/evidence-index.txt"
cat "$artifact_root/evidence-status.txt"
