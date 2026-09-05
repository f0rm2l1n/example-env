#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
inventory="$repo_root/slots/slots.jsonl"
out_dir="$repo_root/artifacts/upload"
bundle_zip="$out_dir/environment-bundle.zip"
slots_out="$out_dir/slots.jsonl"
tmp_bundle_zip=/tmp/external-linux-example-environment-bundle.zip
tmp_slots=/tmp/external-linux-example-slots.jsonl
bundle_ssh_dir="$repo_root/environment_bundle/ssh"

test -s "$inventory" || { echo "run scripts/setup-slots.sh first" >&2; exit 2; }
test -s "$bundle_ssh_dir/id_ed25519" || { echo "run scripts/setup-slots.sh first: missing bundle SSH identity" >&2; exit 2; }
test -s "$bundle_ssh_dir/known_hosts" || { echo "run scripts/setup-slots.sh first: missing bundle known_hosts" >&2; exit 2; }
mkdir -p "$out_dir"
python3 - "$repo_root/environment_bundle" "$bundle_zip" <<'PY'
from pathlib import Path
import sys, zipfile
bundle, output = map(Path, sys.argv[1:])
with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    excluded = {"ssh/id_ed25519.pub"}
    for path in sorted(bundle.rglob("*")):
        if path.is_file():
            rel = path.relative_to(bundle).as_posix()
            if rel in excluded:
                continue
            archive.write(path, rel)
with zipfile.ZipFile(output) as archive:
    names = set(archive.namelist())
    required = {"bundle.yaml", "docs/ENVIRONMENT_GUIDE.md", "ssh/id_ed25519", "ssh/known_hosts"}
    missing = required - names
    if missing:
        raise SystemExit("missing files in bundle zip: " + ", ".join(sorted(missing)))
PY
cp "$inventory" "$slots_out"
cp "$bundle_zip" "$tmp_bundle_zip"
cp "$slots_out" "$tmp_slots"
chmod 0600 "$tmp_slots"
echo "bundle_zip=$bundle_zip"
echo "slots=$slots_out"
echo "tmp_bundle_zip=$tmp_bundle_zip"
echo "tmp_slots=$tmp_slots"
