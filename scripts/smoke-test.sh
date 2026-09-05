#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
slot_source="${1:-$repo_root/slots/slots.jsonl}"
if [ ! -f "$slot_source" ]; then
  "$script_dir/setup-slots.sh" >/dev/null
fi
selected_slot="$(mktemp)"
cleanup_on_exit() {
  exit_code=$?
  if [ -s "$selected_slot" ]; then
    SLOT_ID= "$script_dir/cleanup-slot.sh" "$selected_slot" >/dev/null 2>&1 || true
  fi
  rm -f "$selected_slot"
  exit "$exit_code"
}
trap cleanup_on_exit EXIT
"$script_dir/select-slot.sh" "$slot_source" "${SLOT_ID:-}" > "$selected_slot"
"$script_dir/validate-slot.sh" "$selected_slot" >/dev/null

slot_id="$(jq -r '.slot_id' "$selected_slot")"
artifact_root="${ZHONGJING_SEC_ARTIFACT_ROOT:-$repo_root/artifacts/slots/$slot_id/evidence}"
mkdir -p "$artifact_root"

"$script_dir/verify-artifacts.sh" >/dev/null
"$script_dir/cleanup-slot.sh" "$selected_slot" >/dev/null
set +e
QEMU_TIMEOUT_SECONDS="${QEMU_TIMEOUT_SECONDS:-90}" QEMU_MEMORY_MB="${QEMU_MEMORY_MB:-1024}" "$script_dir/run.sh" "$selected_slot" > "$artifact_root/run.stdout.log" 2>&1
run_exit=$?
set -e
if [ "$run_exit" -ne 0 ] && [ "$run_exit" -ne 124 ]; then
  cat "$artifact_root/run.stdout.log" >&2
  exit "$run_exit"
fi
ZHONGJING_SEC_ARTIFACT_ROOT="$artifact_root" "$script_dir/collect-evidence.sh" "$selected_slot" >/dev/null
grep -q 'module inserted' "$artifact_root/qemu-serial.log"
grep -q 'BUG: KASAN:' "$artifact_root/qemu-serial.log"
cleanup_output="$("$script_dir/cleanup-slot.sh" "$selected_slot")"
printf '%s\n' "$cleanup_output" > "$artifact_root/cleanup.log"
grep -q 'rootfs_restored=yes' "$artifact_root/cleanup.log"
rm -f "$selected_slot"
trap - EXIT
echo "slot_id=$slot_id"
echo "run_exit=$run_exit"
echo 'module_inserted=yes'
echo 'kasan=yes'
echo 'rootfs_restored=yes'
echo 'smoke-test=ok'
