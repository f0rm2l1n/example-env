#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
source "$script_dir/ssh-common.sh"
slot_json="$(zhongjing_sec_env ENV_SLOT_JSON "${1:-}")"
if [ -n "$(zhongjing_sec_env ENV_SLOT_JSON)" ]; then shift_count=0; else shift_count=1; fi
zhongjing_sec_load_ssh_slot "$slot_json"
[ "$shift_count" -eq 0 ] || shift
[ "$#" -gt 0 ] || { echo "usage: ssh-exec.sh [selected-slot.json] COMMAND [ARG...]" >&2; exit 2; }
printf -v remote_command '%q ' "$@"
ssh "${ssh_options[@]}" "$ssh_target" -- "$remote_command"
