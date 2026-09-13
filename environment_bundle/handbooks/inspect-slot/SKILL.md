---
name: inspect-slot
description: Validate the leased external Linux slot before using it.
---

# Inspect Slot

Inspect only the leased slot:

```bash
set -euo pipefail
slot_id="$(jq -r '.slot_id' "$BRAINAFK_ENV_SLOT_JSON")"
mkdir -p "$BRAINAFK_ARTIFACT_ROOT"
"$BRAINAFK_ENV_BUNDLE_ROOT/scripts/ssh-exec.sh" \
  zhongjing-sec-verify --slot "$slot_id" \
  | tee "$BRAINAFK_ARTIFACT_ROOT/slot-validation.log"
```

Continue only when the output contains `remote-verification=ok`.
