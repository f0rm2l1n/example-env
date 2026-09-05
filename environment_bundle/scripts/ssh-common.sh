#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
legacy_prefix="BRAIN""AFK"

zhongjing_sec_env() {
  local suffix="$1"
  local default_value="${2:-}"
  local modern="ZHONGJING_SEC_${suffix}"
  local legacy="${legacy_prefix}_${suffix}"
  printf '%s' "${!modern:-${!legacy:-$default_value}}"
}

bundle_root="$(zhongjing_sec_env ENV_BUNDLE_ROOT "$(cd "$script_dir/.." && pwd)")"

zhongjing_sec_resolve_bundle_path() {
  local value="$1"
  local legacy_token='${'"$legacy_prefix"'_ENV_BUNDLE_ROOT}'
  case "$value" in
    '${ZHONGJING_SEC_ENV_BUNDLE_ROOT}'/*) printf '%s/%s\n' "$bundle_root" "${value#'${ZHONGJING_SEC_ENV_BUNDLE_ROOT}'/}" ;;
    '$ZHONGJING_SEC_ENV_BUNDLE_ROOT'/*) printf '%s/%s\n' "$bundle_root" "${value#'$ZHONGJING_SEC_ENV_BUNDLE_ROOT'/}" ;;
    "$legacy_token"/*) printf '%s/%s\n' "$bundle_root" "${value#"$legacy_token"/}" ;;
    /*) printf '%s\n' "$value" ;;
    *) printf '%s/%s\n' "$bundle_root" "$value" ;;
  esac
}

zhongjing_sec_load_ssh_slot() {
  slot_json="${1:-$(zhongjing_sec_env ENV_SLOT_JSON)}"
  test -f "$slot_json" || { echo "missing selected slot json: $slot_json" >&2; return 2; }
  jq -e -s 'length == 1 and (.[0].transport.kind == "ssh") and
    all(.[0].ssh.host, .[0].ssh.user, .[0].ssh.identity_file, .[0].ssh.known_hosts_file;
      type == "string" and length > 0) and
    (.[0].ssh.port | type == "number" and . > 0 and . < 65536) and
    (.[0].slot_id | type == "string" and test("^[A-Za-z0-9._-]+$"))' "$slot_json" >/dev/null || {
      echo "selected slot does not satisfy the SSH contract: $slot_json" >&2
      return 2
    }
  slot_id="$(jq -r -s '.[0].slot_id' "$slot_json")"
  ssh_host="$(jq -r -s '.[0].ssh.host' "$slot_json")"
  ssh_port="$(jq -r -s '.[0].ssh.port' "$slot_json")"
  ssh_user="$(jq -r -s '.[0].ssh.user' "$slot_json")"
  identity_file="$(zhongjing_sec_resolve_bundle_path "$(jq -r -s '.[0].ssh.identity_file' "$slot_json")")"
  known_hosts_file="$(zhongjing_sec_resolve_bundle_path "$(jq -r -s '.[0].ssh.known_hosts_file' "$slot_json")")"
  test -s "$identity_file" || { echo "missing SSH identity: $identity_file" >&2; return 2; }
  test -s "$known_hosts_file" || { echo "missing SSH known_hosts: $known_hosts_file" >&2; return 2; }
  case "$identity_file" in
    *.pub) echo "SSH identity must be the private key, not a .pub file: $identity_file" >&2; return 2 ;;
  esac
  chmod 0600 "$identity_file" 2>/dev/null || true
  chmod 0644 "$known_hosts_file" 2>/dev/null || true
  ssh_options=(
    -o BatchMode=yes
    -o ConnectTimeout="$(zhongjing_sec_env SSH_CONNECT_TIMEOUT 10)"
    -o IdentitiesOnly=yes
    -o StrictHostKeyChecking=yes
    -o UserKnownHostsFile="$known_hosts_file"
    -i "$identity_file"
    -p "$ssh_port"
  )
  ssh_target="$ssh_user@$ssh_host"
}
