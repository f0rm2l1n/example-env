# Inspect Slot

Use this skill before running the PoC. Inspect only the leased slot through SSH.

```bash
set -euo pipefail
slot_json="${ZHONGJING_SEC_ENV_SLOT_JSON:?missing ZHONGJING_SEC_ENV_SLOT_JSON}"
bundle_root="${ZHONGJING_SEC_ENV_BUNDLE_ROOT:?missing ZHONGJING_SEC_ENV_BUNDLE_ROOT}"
artifact_root="${ZHONGJING_SEC_ARTIFACT_ROOT:?missing ZHONGJING_SEC_ARTIFACT_ROOT}"
slot_id="$(jq -r '.slot_id' "$slot_json")"
mkdir -p "$artifact_root"
jq -S . "$slot_json" > "$artifact_root/selected-slot.json"
"$bundle_root/scripts/ssh-exec.sh" zhongjing-sec-verify --slot "$slot_id" \
  | tee "$artifact_root/slot-validation.log"
printf 'inspect=ok\n' > "$artifact_root/inspect-status.txt"
```

Success: `slot-validation.log` contains `remote-verification=ok`.
