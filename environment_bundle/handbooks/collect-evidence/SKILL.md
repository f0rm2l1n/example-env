---
name: collect-evidence
description: Retrieve the leased slot's serial log and summarize its evidence.
---

# Collect Evidence

Collect the latest QEMU serial output:

```bash
set -euo pipefail
mkdir -p "$BRAINAFK_ARTIFACT_ROOT"
remote_serial="$(jq -r '.logs.serial_log' "$BRAINAFK_ENV_SLOT_JSON")"
"$BRAINAFK_ENV_BUNDLE_ROOT/scripts/ssh-copy-from.sh" \
  "$remote_serial" "$BRAINAFK_ARTIFACT_ROOT/qemu-serial.log"
sha256sum "$BRAINAFK_ARTIFACT_ROOT/qemu-serial.log" \
  > "$BRAINAFK_ARTIFACT_ROOT/evidence-index.txt"
grep -q 'module inserted' "$BRAINAFK_ARTIFACT_ROOT/qemu-serial.log" && module=yes || module=no
grep -q 'guest ready' "$BRAINAFK_ARTIFACT_ROOT/qemu-serial.log" && guest=yes || guest=no
grep -q 'BUG: KASAN:' "$BRAINAFK_ARTIFACT_ROOT/qemu-serial.log" && kasan=yes || kasan=no
printf 'module_inserted=%s\nguest_ready=%s\nkasan=%s\n' "$module" "$guest" "$kasan" \
  > "$BRAINAFK_ARTIFACT_ROOT/evidence-status.txt"
```

`kasan=yes` is the PoC result; it is not required for environment health.
