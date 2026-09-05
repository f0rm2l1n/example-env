#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
inventory="${1:-$repo_root/slots/slots.jsonl}"
requested_slot_id="${2:-${SLOT_ID:-}}"

test -f "$inventory" || {
  echo "missing slot inventory: $inventory" >&2
  exit 2
}
command -v jq >/dev/null || {
  echo "missing required command: jq" >&2
  exit 2
}

jq -e -s '
  length > 0 and ([.[].slot_id] | length == (unique | length))
' "$inventory" >/dev/null || {
  echo "slot inventory is empty or contains duplicate slot_id values: $inventory" >&2
  exit 2
}

if [ -n "$requested_slot_id" ]; then
  jq -ce -s --arg slot_id "$requested_slot_id" '
    [.[] | select(.slot_id == $slot_id)]
    | if length == 1 then .[0]
      elif length == 0 then error("slot_id not found: " + $slot_id)
      else error("duplicate slot_id: " + $slot_id)
      end
  ' "$inventory"
else
  jq -ce -s '
    if length > 0 then .[0] else error("slot inventory is empty") end
  ' "$inventory"
fi
