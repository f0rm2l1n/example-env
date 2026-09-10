---
name: collect-evidence
description: Retrieve the serial log after a full run and build the evidence index.
---

# Collect Evidence

Use this skill after a full run to retrieve the serial log and build an evidence
index. It records whether KASAN fired (from your own PoC), but does not require it.

```bash
set -euo pipefail
slot_json="${BRAINAFK_ENV_SLOT_JSON:?missing BRAINAFK_ENV_SLOT_JSON}"
bundle_root="${BRAINAFK_ENV_BUNDLE_ROOT:?missing BRAINAFK_ENV_BUNDLE_ROOT}"
artifact_root="${BRAINAFK_ARTIFACT_ROOT:?missing BRAINAFK_ARTIFACT_ROOT}"
remote_serial="$(jq -r '.logs.serial_log' "$slot_json")"
mkdir -p "$artifact_root"
"$bundle_root/scripts/ssh-copy-from.sh" "$remote_serial" "$artifact_root/qemu-serial.log"
sha256sum "$artifact_root/qemu-serial.log" > "$artifact_root/evidence-index.txt"
grep -q 'module inserted' "$artifact_root/qemu-serial.log" && module_inserted=yes || module_inserted=no
grep -q 'guest ready' "$artifact_root/qemu-serial.log" && guest_ready=yes || guest_ready=no
grep -q 'BUG: KASAN:' "$artifact_root/qemu-serial.log" && kasan=yes || kasan=no
printf 'module_inserted=%s\nguest_ready=%s\nkasan=%s\ncollection=ok\n' \
  "$module_inserted" "$guest_ready" "$kasan" > "$artifact_root/evidence-status.txt"
```

Success: `evidence-status.txt` records the markers and `evidence-index.txt`
hashes the copied log. `kasan=yes` is your exploit's result, not an environment
requirement.
