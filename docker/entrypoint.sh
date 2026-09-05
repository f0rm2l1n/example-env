#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
set -euo pipefail

uid="${ZHONGJING_SEC_UID:-1000}"
gid="${ZHONGJING_SEC_GID:-1000}"
[[ "$uid" =~ ^[1-9][0-9]*$ && "$gid" =~ ^[1-9][0-9]*$ ]] || {
  echo "ZHONGJING_SEC_UID and ZHONGJING_SEC_GID must be positive integers" >&2
  exit 2
}
current_gid="$(id -g zhongjing-sec)"
current_uid="$(id -u zhongjing-sec)"
[ "$current_gid" = "$gid" ] || groupmod --gid "$gid" zhongjing-sec
[ "$current_uid" = "$uid" ] || usermod --uid "$uid" --gid "$gid" zhongjing-sec

test -s /run/zhongjing-sec/input_authorized_keys || { echo "missing SSH authorized key" >&2; exit 2; }
install -m 0600 -o zhongjing-sec -g zhongjing-sec /run/zhongjing-sec/input_authorized_keys /run/zhongjing-sec/authorized_keys
mkdir -p /srv/zhongjing-sec/home /srv/zhongjing-sec/slots
chown zhongjing-sec:zhongjing-sec /srv/zhongjing-sec/home /srv/zhongjing-sec/slots
ssh-keygen -A
exec /usr/sbin/sshd -D -e
