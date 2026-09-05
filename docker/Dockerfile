# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
ARG DEBIAN_BASE_IMAGE=debian:bookworm-slim
FROM ${DEBIAN_BASE_IMAGE}

ARG DEBIAN_APT_MIRROR=""
ARG DEBIAN_SECURITY_APT_MIRROR=""
RUN if [ -n "$DEBIAN_APT_MIRROR" ]; then \
      security_mirror="${DEBIAN_SECURITY_APT_MIRROR:-$DEBIAN_APT_MIRROR}"; \
      printf '%s\n' \
        'Types: deb' \
        "URIs: $DEBIAN_APT_MIRROR" \
        'Suites: bookworm bookworm-updates' \
        'Components: main' \
        'Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg' \
        '' \
        'Types: deb' \
        "URIs: $security_mirror" \
        'Suites: bookworm-security' \
        'Components: main' \
        'Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg' \
        > /etc/apt/sources.list.d/debian.sources; \
    fi \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       bash ca-certificates coreutils grep jq openssh-server procps qemu-system-arm util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /srv/zhongjing-sec/home /srv/zhongjing-sec/slots \
    && useradd --home-dir /srv/zhongjing-sec/home --shell /bin/bash zhongjing-sec \
    && mkdir -p /run/sshd /run/zhongjing-sec /usr/local/lib/zhongjing-sec

COPY remote/ /usr/local/lib/zhongjing-sec/
COPY entrypoint.sh /usr/local/sbin/zhongjing-sec-entrypoint
RUN chmod 0755 /usr/local/sbin/zhongjing-sec-entrypoint /usr/local/lib/zhongjing-sec/* \
    && for command_name in verify run healthcheck cleanup; do \
         ln -s "/usr/local/lib/zhongjing-sec/zhongjing-sec-${command_name}" "/usr/local/bin/zhongjing-sec-${command_name}"; \
       done \
    && printf '%s\n' \
       'PasswordAuthentication no' \
       'KbdInteractiveAuthentication no' \
       'PermitRootLogin no' \
       'PubkeyAuthentication yes' \
       'AllowUsers zhongjing-sec' \
       'AuthorizedKeysFile /run/zhongjing-sec/authorized_keys' \
       'StrictModes no' \
       > /etc/ssh/sshd_config.d/zhongjing-sec.conf

EXPOSE 22
ENTRYPOINT ["/usr/local/sbin/zhongjing-sec-entrypoint"]
