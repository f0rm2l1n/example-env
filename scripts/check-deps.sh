#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail

missing=()
for command_name in bash docker ssh ssh-keygen ssh-keyscan scp python3 jq sha256sum xz cp cmp awk git; do
  command -v "$command_name" >/dev/null || missing+=("$command_name")
done
if [ "${#missing[@]}" -gt 0 ]; then
  printf 'missing required commands:' >&2
  printf ' %s' "${missing[@]}" >&2
  printf '\n' >&2
  exit 2
fi

docker compose version >/dev/null || { echo 'missing Docker Compose v2 plugin' >&2; exit 2; }
docker info >/dev/null || { echo 'Docker daemon is not reachable by current user' >&2; exit 2; }

if command -v rg >/dev/null && command -v strings >/dev/null; then
  validation_extras=yes
else
  validation_extras=no
fi

candidate_hosts=""
if command -v ip >/dev/null; then
  candidate_hosts="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}')"
fi
if [ -z "$candidate_hosts" ]; then
  candidate_hosts="$(hostname -I 2>/dev/null | tr ' ' '\n' | awk 'NF && $1 !~ /^127\./ {print; exit}')"
fi

echo 'dependency-check=ok'
echo 'docker-compose=ok'
echo "validation_extras=$validation_extras"
echo "public_host_required=yes"
[ -z "$candidate_hosts" ] || echo "candidate_public_hosts=$candidate_hosts"
echo 'setup_example=ZHONGJING_SEC_PUBLIC_HOST=<executor-reachable-ip-or-dns> ./scripts/setup-slots.sh'
