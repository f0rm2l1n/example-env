#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
source "$script_dir/ssh-common.sh"
slot_json="$(zhongjing_sec_env ENV_SLOT_JSON)"
test -n "$slot_json" || { echo "missing selected slot json" >&2; exit 2; }
slot_id="$(jq -r -s '.[0].slot_id // empty' "$slot_json")"
"$bundle_root/scripts/ssh-exec.sh" zhongjing-sec-cleanup --slot "$slot_id"
