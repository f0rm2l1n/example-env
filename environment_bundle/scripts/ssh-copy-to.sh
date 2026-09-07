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
[ "$#" -eq 2 ] || { echo "usage: ssh-copy-to.sh [selected-slot.json] LOCAL_PATH REMOTE_DIR" >&2; exit 2; }
local_path="$1"
remote_dir="$2"
test -f "$local_path" || { echo "missing local file: $local_path" >&2; exit 2; }
remote_dir="${remote_dir%/}"
[[ "$remote_dir" == /srv/zhongjing-sec/slots/"$slot_id"/poc_in ]] || { echo "remote copy target must be the slot's poc_in dir: $remote_dir" >&2; exit 2; }
scp_options=("${ssh_options[@]}")
for ((i=0; i<${#scp_options[@]}; i++)); do
  if [ "${scp_options[$i]}" = -p ]; then scp_options[$i]=-P; fi
done
scp "${scp_options[@]}" "$local_path" "$ssh_target:$remote_dir/"
