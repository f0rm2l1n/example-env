# Collect Evidence

Use this skill after a full run.

```bash
set -euo pipefail
slot_json="${ZHONGJING_SEC_ENV_SLOT_JSON:?missing ZHONGJING_SEC_ENV_SLOT_JSON}"
bundle_root="${ZHONGJING_SEC_ENV_BUNDLE_ROOT:?missing ZHONGJING_SEC_ENV_BUNDLE_ROOT}"
artifact_root="${ZHONGJING_SEC_ARTIFACT_ROOT:?missing ZHONGJING_SEC_ARTIFACT_ROOT}"
remote_serial="$(jq -r '.logs.serial_log' "$slot_json")"
mkdir -p "$artifact_root"
"$bundle_root/scripts/ssh-copy-from.sh" "$remote_serial" "$artifact_root/qemu-serial.log"
sha256sum "$artifact_root/qemu-serial.log" > "$artifact_root/evidence-index.txt"
grep -q 'module inserted' "$artifact_root/qemu-serial.log" && module_inserted=yes || module_inserted=no
grep -q 'BUG: KASAN:' "$artifact_root/qemu-serial.log" && kasan=yes || kasan=no
printf 'module_inserted=%s\nkasan=%s\ncollection=ok\n' "$module_inserted" "$kasan" \
  > "$artifact_root/evidence-status.txt"
```

Success: `evidence-status.txt` records the markers and `evidence-index.txt` hashes the copied log.
