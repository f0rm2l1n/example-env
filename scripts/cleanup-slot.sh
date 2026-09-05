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
export ZHONGJING_SEC_ENV_BUNDLE_ROOT="$repo_root/environment_bundle"
"$repo_root/environment_bundle/scripts/cleanup-slot.sh"
