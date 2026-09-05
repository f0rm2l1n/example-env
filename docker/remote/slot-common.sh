#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Zhongjing Security Team
# SPDX-License-Identifier: LicenseRef-Zhongjing-Security-Proprietary
zhongjing_sec_load_slot() {
  slot_id="${1:-}"
  [[ "$slot_id" =~ ^qemu-arm64-ctf-[1-9][0-9]*$ ]] || { echo "invalid slot id: $slot_id" >&2; return 2; }
  shared_dir=/srv/zhongjing-sec/shared
  slot_dir="/srv/zhongjing-sec/slots/$slot_id"
  kernel_image="$shared_dir/runtime/Image"
  rootfs_template="$shared_dir/runtime/rootfs.cpio"
  rootfs_cpio="$slot_dir/rootfs.cpio"
  run_dir="$slot_dir/run"
  health_dir="$slot_dir/healthcheck"
  evidence_dir="$slot_dir/evidence"
  serial_log="$run_dir/qemu-serial.log"
  pid_file="$run_dir/qemu.pid"
  lock_file="$run_dir/qemu.lock"
}
zhongjing_sec_require_slot_files() {
  test -s "$kernel_image" || { echo "missing kernel: $kernel_image" >&2; return 2; }
  test -s "$rootfs_template" || { echo "missing rootfs template: $rootfs_template" >&2; return 2; }
  test -s "$rootfs_cpio" || { echo "missing working rootfs: $rootfs_cpio" >&2; return 2; }
  case "$rootfs_cpio" in "$slot_dir"/*) ;; *) echo "working rootfs escaped slot" >&2; return 2 ;; esac
}
