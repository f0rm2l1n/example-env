#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
source "$script_dir/ssh-common.sh"
slot_json="$(zhongjing_sec_env ENV_SLOT_JSON)"
test -n "$slot_json" || { echo "missing selected slot json" >&2; exit 2; }
artifact_root="$(zhongjing_sec_env ARTIFACT_ROOT "$(mktemp -d)")"
slot_id="$(jq -r -s '.[0].slot_id // empty' "$slot_json")"
remote_status="$(jq -r -s '.[0].healthcheck.status_hint // empty' "$slot_json")"
mkdir -p "$artifact_root"
set +e
"$bundle_root/scripts/ssh-exec.sh" zhongjing-sec-healthcheck --slot "$slot_id" \
  >"$artifact_root/healthcheck.stdout.log" 2>"$artifact_root/healthcheck.stderr.log"
healthcheck_exit=$?
set -e
printf 'healthcheck_exit=%s\n' "$healthcheck_exit" > "$artifact_root/healthcheck-hook-status.txt"
[ -z "$remote_status" ] || "$bundle_root/scripts/ssh-copy-from.sh" "$remote_status" "$artifact_root/healthcheck-status.txt" || true
cat "$artifact_root/healthcheck.stdout.log"
exit "$healthcheck_exit"
