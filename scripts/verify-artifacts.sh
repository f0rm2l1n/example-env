#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
for command_name in sha256sum xz; do
  command -v "$command_name" >/dev/null || { echo "missing required command: $command_name" >&2; exit 2; }
done
for relative_path in ASSET_SHA256SUMS runtime/Image.xz runtime/rootfs.cpio.xz payloads/vuln_misc.ko payloads/poc; do
  test -s "$repo_root/$relative_path" || { echo "missing or empty runtime file: $relative_path" >&2; exit 2; }
done
test -x "$repo_root/payloads/poc"
(cd "$repo_root" && sha256sum --check --strict ASSET_SHA256SUMS)
xz -t "$repo_root/runtime/Image.xz" "$repo_root/runtime/rootfs.cpio.xz"
echo "artifact-verification=ok"
