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
[ "$#" -eq 2 ] || { echo "usage: ssh-copy-from.sh [selected-slot.json] REMOTE_PATH LOCAL_PATH" >&2; exit 2; }
remote_path="$1"
local_path="$2"
[[ "$remote_path" == /srv/zhongjing-sec/slots/"$slot_id"/* ]] || { echo "remote evidence path is outside selected slot: $remote_path" >&2; exit 2; }
mkdir -p "$(dirname "$local_path")"
scp_options=("${ssh_options[@]}")
for ((i=0; i<${#scp_options[@]}; i++)); do
  if [ "${scp_options[$i]}" = -p ]; then scp_options[$i]=-P; fi
done
scp "${scp_options[@]}" "$ssh_target:$remote_path" "$local_path"
