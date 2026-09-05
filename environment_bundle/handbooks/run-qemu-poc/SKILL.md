# Run QEMU PoC

Use this skill after inspection. Run only the leased remote slot.

```bash
set -euo pipefail
slot_json="${ZHONGJING_SEC_ENV_SLOT_JSON:?missing ZHONGJING_SEC_ENV_SLOT_JSON}"
bundle_root="${ZHONGJING_SEC_ENV_BUNDLE_ROOT:?missing ZHONGJING_SEC_ENV_BUNDLE_ROOT}"
artifact_root="${ZHONGJING_SEC_ARTIFACT_ROOT:?missing ZHONGJING_SEC_ARTIFACT_ROOT}"
slot_id="$(jq -r '.slot_id' "$slot_json")"
remote_serial="$(jq -r '.logs.serial_log' "$slot_json")"
mkdir -p "$artifact_root"
set +e
"$bundle_root/scripts/ssh-exec.sh" env QEMU_TIMEOUT_SECONDS="${QEMU_TIMEOUT_SECONDS:-90}" \
  zhongjing-sec-run --slot "$slot_id" > "$artifact_root/run.stdout.log" 2>&1
run_exit=$?
set -e
"$bundle_root/scripts/ssh-copy-from.sh" "$remote_serial" "$artifact_root/qemu-serial.log"
grep -q 'module inserted' "$artifact_root/qemu-serial.log"
grep -q 'BUG: KASAN:' "$artifact_root/qemu-serial.log"
printf 'run_exit=%s\nmodule_inserted=yes\nkasan=yes\nrun=ok\n' "$run_exit" \
  > "$artifact_root/run-status.txt"
```

Success: markers appear in the copied serial log. `run_exit` may be `0` or `124` if the timeout stops QEMU after the markers are written.
