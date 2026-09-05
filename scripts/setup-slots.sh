#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
inventory="$repo_root/slots/slots.jsonl"
ssh_dir="$repo_root/artifacts/ssh"
bundle_ssh_dir="$repo_root/environment_bundle/ssh"
shared_dir="$repo_root/artifacts/shared"
shared_runtime_dir="$shared_dir/runtime"
shared_payloads_dir="$shared_dir/payloads"
identity_file="$ssh_dir/id_ed25519"
known_hosts_file="$ssh_dir/known_hosts"
public_host="${ZHONGJING_SEC_PUBLIC_HOST:-}"
public_port="${ZHONGJING_SEC_PUBLIC_PORT:-2222}"
bind_host="${ZHONGJING_SEC_BIND_HOST:-0.0.0.0}"
ssh_user=zhongjing-sec

if [ -z "$public_host" ]; then
  cat >&2 <<'MSG'
missing required ZHONGJING_SEC_PUBLIC_HOST
example: ZHONGJING_SEC_PUBLIC_HOST=192.168.1.50 ./scripts/setup-slots.sh
Use an IP or DNS name reachable by the zhongjing-sec executor that will consume the uploaded slots.jsonl.
MSG
  exit 2
fi
[[ "$public_port" =~ ^[1-9][0-9]*$ ]] && [ "$public_port" -lt 65536 ] || { echo "ZHONGJING_SEC_PUBLIC_PORT must be 1..65535" >&2; exit 2; }

"$script_dir/check-deps.sh" >/dev/null
"$script_dir/verify-artifacts.sh" >/dev/null
mkdir -p "$ssh_dir" "$bundle_ssh_dir" "$repo_root/artifacts/slots" "$repo_root/slots" "$shared_runtime_dir" "$shared_payloads_dir"

xz -dc "$repo_root/runtime/Image.xz" > "$shared_runtime_dir/Image.tmp"
xz -dc "$repo_root/runtime/rootfs.cpio.xz" > "$shared_runtime_dir/rootfs.cpio.tmp"
mv -f "$shared_runtime_dir/Image.tmp" "$shared_runtime_dir/Image"
mv -f "$shared_runtime_dir/rootfs.cpio.tmp" "$shared_runtime_dir/rootfs.cpio"
chmod 0644 "$shared_runtime_dir/Image" "$shared_runtime_dir/rootfs.cpio"
cp "$repo_root/payloads/poc" "$shared_payloads_dir/poc"
cp "$repo_root/payloads/vuln_misc.ko" "$shared_payloads_dir/vuln_misc.ko"
chmod 0755 "$shared_payloads_dir/poc"
chmod 0644 "$shared_payloads_dir/vuln_misc.ko"
(cd "$shared_dir" && sha256sum runtime/Image runtime/rootfs.cpio payloads/poc payloads/vuln_misc.ko > ASSET_SHA256SUMS)
(cd "$shared_dir" && sha256sum --check --strict ASSET_SHA256SUMS >/dev/null)

if [ ! -s "$identity_file" ]; then
  ssh-keygen -q -t ed25519 -N '' -C zhongjing-sec-external-linux-example -f "$identity_file"
fi
ssh-keygen -y -f "$identity_file" | awk '{print $1" "$2}' > "$ssh_dir/authorized_keys"
chmod 0600 "$identity_file" "$ssh_dir/authorized_keys"
cp "$identity_file" "$bundle_ssh_dir/id_ed25519"
chmod 0600 "$bundle_ssh_dir/id_ed25519"

for slot_number in 1 2; do
  slot_id="qemu-arm64-ctf-$slot_number"
  slot_dir="$repo_root/artifacts/slots/$slot_id"
  mkdir -p "$slot_dir/run" "$slot_dir/healthcheck" "$slot_dir/evidence"
  rootfs_tmp="$(mktemp "$slot_dir/.rootfs.cpio.setup.XXXXXX")"
  cp --reflink=auto "$shared_runtime_dir/rootfs.cpio" "$rootfs_tmp"
  cmp "$shared_runtime_dir/rootfs.cpio" "$rootfs_tmp"
  mv -f "$rootfs_tmp" "$slot_dir/rootfs.cpio"
done

export ZHONGJING_SEC_UID="${ZHONGJING_SEC_UID:-$(id -u)}"
export ZHONGJING_SEC_GID="${ZHONGJING_SEC_GID:-$(id -g)}"
export ZHONGJING_SEC_PUBLIC_PORT="$public_port"
export ZHONGJING_SEC_BIND_HOST="$bind_host"
docker compose -f "$repo_root/compose.yaml" up -d --build --force-recreate

ready=no
for _attempt in $(seq 1 60); do
  if ssh-keyscan -T 2 -p "$public_port" "$public_host" > "$known_hosts_file.tmp" 2>/dev/null && [ -s "$known_hosts_file.tmp" ]; then
    mv -f "$known_hosts_file.tmp" "$known_hosts_file"
    chmod 0600 "$known_hosts_file"
    if ssh -o BatchMode=yes -o ConnectTimeout=2 -o IdentitiesOnly=yes \
      -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$known_hosts_file" \
      -i "$identity_file" -p "$public_port" "$ssh_user@$public_host" -- true; then
      ready=yes
      break
    fi
  fi
  sleep 1
done
python3 - <<PY
from pathlib import Path
Path("$known_hosts_file.tmp").unlink(missing_ok=True)
PY
if [ "$ready" = yes ]; then
  cp "$known_hosts_file" "$bundle_ssh_dir/known_hosts"
  chmod 0644 "$bundle_ssh_dir/known_hosts"
fi
[ "$ready" = yes ] || { echo "SSH endpoint did not become ready: $public_host:$public_port" >&2; exit 2; }

inventory_tmp="$(mktemp "$repo_root/slots/.slots.jsonl.XXXXXX")"
trap 'rm -f "$inventory_tmp"' EXIT
python3 - "$public_host" "$public_port" "$ssh_user" > "$inventory_tmp" <<'PY'
import json
import sys
host, port, user = sys.argv[1:]
identity = "${ZHONGJING_SEC_ENV_BUNDLE_ROOT}/ssh/id_ed25519"
known_hosts = "${ZHONGJING_SEC_ENV_BUNDLE_ROOT}/ssh/known_hosts"
for number in (1, 2):
    slot_id = f"qemu-arm64-ctf-{number}"
    work_dir = f"/srv/zhongjing-sec/slots/{slot_id}"
    row = {
        "slot_id": slot_id,
        "transport": {"kind": "ssh"},
        "ssh": {"host": host, "port": int(port), "user": user, "identity_file": identity, "known_hosts_file": known_hosts},
        "workspace": "/srv/zhongjing-sec",
        "work_dir": work_dir,
        "artifact_local_dir": f"artifacts/slots/{slot_id}/evidence",
        "build": {"command": f"zhongjing-sec-verify --slot {slot_id}", "output_hint": "/srv/zhongjing-sec/shared/payloads/vuln_misc.ko"},
        "run": {"command": f"zhongjing-sec-run --slot {slot_id}", "evidence_hint": f"{work_dir}/run/qemu-serial.log"},
        "healthcheck": {"command": f"zhongjing-sec-healthcheck --slot {slot_id}", "status_hint": f"{work_dir}/healthcheck/healthcheck-status.txt"},
        "cleanup": {"command": f"zhongjing-sec-cleanup --slot {slot_id}"},
        "logs": {"serial_log": f"{work_dir}/run/qemu-serial.log", "evidence_dir": f"{work_dir}/evidence"},
        "runtime": {
            "kernel_image": "/srv/zhongjing-sec/shared/runtime/Image",
            "rootfs_template": "/srv/zhongjing-sec/shared/runtime/rootfs.cpio",
            "rootfs_cpio": f"{work_dir}/rootfs.cpio",
        },
        "payloads": {"module_ko": "/srv/zhongjing-sec/shared/payloads/vuln_misc.ko", "poc": "/srv/zhongjing-sec/shared/payloads/poc"},
        "container": {"name": "zhongjing-sec-external-linux-host"},
    }
    print(json.dumps(row, ensure_ascii=False, separators=(",", ":")))
PY
mv -f "$inventory_tmp" "$inventory"
trap - EXIT

while IFS= read -r row; do
  selected="$(mktemp)"
  printf '%s\n' "$row" > "$selected"
  "$script_dir/validate-slot.sh" "$selected" >/dev/null
  python3 - "$selected" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).unlink(missing_ok=True)
PY
done < "$inventory"
"$script_dir/package-upload.sh" >/dev/null

echo "setup=ok"
echo "ssh_endpoint=$ssh_user@$public_host:$public_port"
echo "public_host=$public_host"
echo "public_port=$public_port"
echo "bind_host=$bind_host"
echo "slot_count=2"
echo "slots=$inventory"
echo "bundle_zip=$repo_root/artifacts/upload/environment-bundle.zip"
