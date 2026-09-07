# Inspect Slot

Use this skill before running the PoC. Inspect only the leased slot through SSH.

```bash
set -euo pipefail
slot_json="${BRAINAFK_ENV_SLOT_JSON:?missing BRAINAFK_ENV_SLOT_JSON}"
bundle_root="${BRAINAFK_ENV_BUNDLE_ROOT:?missing BRAINAFK_ENV_BUNDLE_ROOT}"
artifact_root="${BRAINAFK_ARTIFACT_ROOT:?missing BRAINAFK_ARTIFACT_ROOT}"
slot_id="$(jq -r '.slot_id' "$slot_json")"
mkdir -p "$artifact_root"
jq -S . "$slot_json" > "$artifact_root/selected-slot.json"
"$bundle_root/scripts/ssh-exec.sh" zhongjing-sec-verify --slot "$slot_id" \
  | tee "$artifact_root/slot-validation.log"
printf 'inspect=ok\n' > "$artifact_root/inspect-status.txt"
```

Success: `slot-validation.log` contains `remote-verification=ok`.

The environment's shared assets (kernel image, rootfs template, vulnerable
module) and the slot's working rootfs must all be present and valid, but no PoC
is expected — a PoC is your own work, provided later via `ssh-copy-to.sh`.
