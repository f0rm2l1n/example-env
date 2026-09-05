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
slot_id="$(jq -r .slot_id "$selected")"
"$repo_root/environment_bundle/scripts/ssh-exec.sh" env \
  QEMU_TIMEOUT_SECONDS="${QEMU_TIMEOUT_SECONDS:-120}" \
  QEMU_MEMORY_MB="${QEMU_MEMORY_MB:-1024}" \
  zhongjing-sec-run --slot "$slot_id"
