#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail
usage() { echo "usage: $0 <single-slot.json>" >&2; exit 2; }
slot_json="${1:-${ZHONGJING_SEC_ENV_SLOT_JSON:-}}"
[ -n "$slot_json" ] || usage
test -f "$slot_json" || { echo "missing slot json: $slot_json" >&2; exit 2; }
command -v jq >/dev/null || { echo "missing required command: jq" >&2; exit 2; }
jq -e -s '
  length == 1 and (.[0] | type == "object") and
  (.[0].slot_id | type == "string" and test("^qemu-arm64-ctf-[1-9][0-9]*$")) and
  (.[0].transport.kind == "ssh") and
  (.[0].ssh.host | type == "string" and length > 0) and
  (.[0].ssh.port | type == "number" and . > 0 and . < 65536) and
  (.[0].ssh.user | type == "string" and length > 0) and
  (.[0].ssh.identity_file | type == "string" and length > 0) and
  (.[0].ssh.known_hosts_file | type == "string" and length > 0) and
  (.[0].workspace == "/srv/zhongjing-sec") and
  all(.[0].work_dir, .[0].artifact_local_dir, .[0].build.command, .[0].run.command,
      .[0].run.poc_in, .[0].healthcheck.command, .[0].cleanup.command, .[0].logs.serial_log,
      .[0].logs.evidence_dir, .[0].runtime.kernel_image, .[0].runtime.rootfs_template,
      .[0].runtime.rootfs_cpio, .[0].payloads.module_ko;
      type == "string" and length > 0) and
  (.[0] as $s | ($s.work_dir == ("/srv/zhongjing-sec/slots/" + $s.slot_id)) and
    ($s.runtime.rootfs_cpio == ($s.work_dir + "/rootfs.cpio")) and
    ($s.logs.serial_log == ($s.work_dir + "/run/qemu-serial.log")) and
    ($s.logs.evidence_dir == ($s.work_dir + "/evidence")) and
    ($s.run.poc_in == ($s.work_dir + "/poc_in")) and
    ($s.runtime.kernel_image == "/srv/zhongjing-sec/shared/runtime/Image") and
    ($s.runtime.rootfs_template == "/srv/zhongjing-sec/shared/runtime/rootfs.cpio"))
' "$slot_json" >/dev/null || { echo "slot does not satisfy the remote SSH contract: $slot_json" >&2; exit 2; }
export ZHONGJING_SEC_ENV_BUNDLE_ROOT="${ZHONGJING_SEC_ENV_BUNDLE_ROOT:-$(cd "$(dirname "$0")/../environment_bundle" && pwd)}"
slot_id="$(jq -r -s '.[0].slot_id' "$slot_json")"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
"$repo_root/environment_bundle/scripts/ssh-exec.sh" "$slot_json" zhongjing-sec-verify --slot "$slot_id" >/dev/null
echo "slot-validation=ok"
echo "slot_id=$slot_id"
echo "transport=ssh"
echo "ssh_endpoint=$(jq -r -s '.[0].ssh.user + "@" + .[0].ssh.host + ":" + (.[0].ssh.port|tostring)' "$slot_json")"
echo "work_dir=$(jq -r -s '.[0].work_dir' "$slot_json")"
