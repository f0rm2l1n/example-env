#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
inventory="$repo_root/slots/slots.jsonl"
cd "$repo_root"
for command_name in bash docker jq python3 sha256sum ssh scp rg git strings xz; do
  command -v "$command_name" >/dev/null || { echo "missing required command: $command_name" >&2; exit 2; }
done
docker compose version >/dev/null
docker compose -f compose.yaml config >/dev/null
required_paths=(
  compose.yaml docker/Dockerfile docker/entrypoint.sh docker/remote/slot-common.sh scripts/check-deps.sh
  docker/remote/zhongjing-sec-verify docker/remote/zhongjing-sec-run docker/remote/zhongjing-sec-healthcheck docker/remote/zhongjing-sec-cleanup
  environment_bundle/bundle.yaml environment_bundle/docs/ENVIRONMENT_GUIDE.md
  environment_bundle/handbooks/inspect-slot/SKILL.md environment_bundle/handbooks/linux-run-poc/SKILL.md environment_bundle/handbooks/collect-evidence/SKILL.md
  environment_bundle/scripts/ssh-common.sh environment_bundle/scripts/ssh-exec.sh environment_bundle/scripts/ssh-copy-from.sh environment_bundle/scripts/ssh-copy-to.sh
  environment_bundle/scripts/activate-on-lease.sh environment_bundle/scripts/healthcheck-on-lease.sh environment_bundle/scripts/cleanup-slot.sh
)
for path in "${required_paths[@]}"; do test -f "$path" || { echo "missing required path: $path" >&2; exit 2; }; done
for shell_file in scripts/*.sh environment_bundle/scripts/*.sh docker/entrypoint.sh docker/remote/*; do
  bash -n "$shell_file"
  test -x "$shell_file" || { echo "shell script is not executable: $shell_file" >&2; exit 2; }
done
for reference in docs/ENVIRONMENT_GUIDE.md scripts/activate-on-lease.sh scripts/healthcheck-on-lease.sh scripts/cleanup-slot.sh; do
  grep -Fq "$reference" environment_bundle/bundle.yaml || { echo "bundle manifest does not reference: $reference" >&2; exit 2; }
done
test -s "$inventory" || { echo "missing slot inventory; run scripts/setup-slots.sh" >&2; exit 2; }
jq -e -s '
  length == 2 and ([.[].slot_id] | sort == ["qemu-arm64-ctf-1", "qemu-arm64-ctf-2"]) and
  ([.[].ssh | {host,port,user}] | unique | length == 1) and
  all(.[]; (.ssh.host | type == "string" and length > 0 and . != "172.29.241.10" and . != "localhost" and . != "127.0.0.1") and (.ssh.port | type == "number" and . > 0 and . < 65536)) and
  ([.[].container.name] | unique == ["zhongjing-sec-external-linux-host"]) and
  ([.[].work_dir] | unique | length == 2) and
  ([.[].runtime.rootfs_cpio] | unique | length == 2) and
  ([.[].logs.serial_log] | unique | length == 2) and
  ([.[].run.poc_in] | unique | length == 2) and
  ([.[].runtime.kernel_image] | unique == ["/srv/zhongjing-sec/shared/runtime/Image"]) and
  ([.[].runtime.rootfs_template] | unique == ["/srv/zhongjing-sec/shared/runtime/rootfs.cpio"]) and
  all(.[]; . as $s | $s.transport.kind == "ssh" and ($s.runtime.rootfs_cpio | startswith($s.work_dir + "/")))
' "$inventory" >/dev/null || { echo "inventory must describe two isolated slots behind one published SSH endpoint" >&2; exit 2; }
while IFS= read -r row; do
  selected="$(mktemp)"; printf '%s\n' "$row" > "$selected"
  "$script_dir/validate-slot.sh" "$selected" >/dev/null
  rm -f "$selected"
done < "$inventory"
"$script_dir/verify-artifacts.sh" >/dev/null
python3 - "$repo_root/artifacts/upload/environment-bundle.zip" <<'PY'
from pathlib import Path
import sys, zipfile
zip_path = Path(sys.argv[1])
if zip_path.exists():
    with zipfile.ZipFile(zip_path) as archive:
        names = set(archive.namelist())
        required = {"bundle.yaml", "docs/ENVIRONMENT_GUIDE.md", "ssh/id_ed25519", "ssh/known_hosts"}
        missing = required - names
        if missing:
            raise SystemExit("missing files in bundle zip: " + ", ".join(sorted(missing)))
        if "ssh/id_ed25519.pub" in names:
            raise SystemExit("bundle zip must not include ssh/id_ed25519.pub")
PY
python3 - "$repo_root" <<'PY'
from pathlib import Path
import re, subprocess, sys
root = Path(sys.argv[1])
markdown = [root / "README.md", root / "AGENTS.md", *(root / "environment_bundle").rglob("*.md")]
missing=[]
for doc in markdown:
    text=doc.read_text(encoding="utf-8")
    for target in re.findall(r"]\(([^)]+)\)", text):
        part=target.split("#",1)[0]
        if part and "://" not in part and not (doc.parent/part).resolve().exists():
            missing.append(f"{doc.relative_to(root)} -> {target}")
if missing: raise SystemExit("missing Markdown links:\n"+"\n".join(missing))
names=subprocess.check_output(["git","ls-files","--cached","--others","--exclude-standard","-z"],cwd=root).split(b"\0")
patterns=[re.compile(r"/(?:home|Users)/[^\s'\"`]+"), re.compile(r"^[A-Za-z]:[\\/]"), re.compile(r"[\s'\"`(][A-Za-z]:[\\/]")]
violations=[]
for raw in names:
    if not raw: continue
    path=root/raw.decode()
    if not path.is_file(): continue
    data=path.read_bytes()
    if b"\0" in data: continue
    for n,line in enumerate(data.decode(errors="replace").splitlines(),1):
        if any(p.search(line) for p in patterns): violations.append(f"{path.relative_to(root)}:{n}:{line.strip()}")
if violations: raise SystemExit("machine-specific absolute paths found:\n"+"\n".join(violations))
PY
python3 - "$repo_root" <<'PY'
from pathlib import Path
import re, subprocess, sys
root = Path(sys.argv[1])
brand = "brain" + "afk"
path_patterns = [
    re.compile(r"/(?:home|Users)/[^\s'\"`]+"),
    re.compile(r"^[A-Za-z]:[\\/]"),
    re.compile(r"[\s'\"`(][A-Za-z]:[\\/]"),
]
asset_paths = [
    root / "payloads" / "vuln_misc.ko",
]
compressed_assets = [
    root / "runtime" / "rootfs.cpio.xz",
    root / "runtime" / "Image.xz",
]
violations=[]
for path in asset_paths:
    output = subprocess.check_output(["strings", "-a", str(path)], cwd=root, text=True, errors="replace")
    for n,line in enumerate(output.splitlines(),1):
        if brand in line.lower() or any(pattern.search(line) for pattern in path_patterns):
            violations.append(f"{path.relative_to(root)}:{n}:{line.strip()}")
for path in compressed_assets:
    data = subprocess.check_output(["xz", "-dc", str(path)], cwd=root)
    probe = subprocess.run(["strings", "-a"], input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    output = probe.stdout.decode(errors="replace")
    for n,line in enumerate(output.splitlines(),1):
        if brand in line.lower() or any(pattern.search(line) for pattern in path_patterns):
            violations.append(f"{path.relative_to(root)}(decompressed):{n}:{line.strip()}")
if violations:
    raise SystemExit("branded or machine-specific binary strings found:\n"+"\n".join(violations))
PY
if rg -n --glob '!scripts/validate-example.sh' '127\.0\.0\.1|localhost|172\.29\.241\.10|slots\.(example|localhost)\.jsonl|setup-local-example\.sh|EXTERNAL_LINUX_(SSH|SUBNET|WORKSPACE)' README.md AGENTS.md compose.yaml docker environment_bundle scripts src .gitignore >/dev/null; then
  echo "tracked text still references the old local transport or legacy inventory" >&2
  exit 2
fi
echo "bundle-references=ok"
echo "bundle-ssh-identity=ok"
echo "markdown-links=ok"
echo "shell-syntax=ok"
echo "slot-count=2"
echo "published-ssh-endpoint=ok"
echo "shared-ssh-endpoint=ok"
echo "slot-isolation=ok"
echo "asset-checksums=ok"
echo "absolute-path-hygiene=ok"
echo "binary-string-hygiene=ok"
echo "example-validation=ok"
