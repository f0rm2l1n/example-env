---
name: linux-run-poc
description: Run the PoC already prepared for the leased ARM64 QEMU slot.
---

# Run Linux PoC

The remote `run.poc_in` directory must contain a static ARM64 executable named
`poc`. Use `linux-compile-poc` for the sample, or upload your own binary:

```bash
poc_in="$(jq -r '.run.poc_in' "$BRAINAFK_ENV_SLOT_JSON")"
"$BRAINAFK_ENV_BUNDLE_ROOT/scripts/ssh-copy-to.sh" ./poc "$poc_in"
```

Run it in the leased QEMU guest:

```bash
set -euo pipefail
slot_id="$(jq -r '.slot_id' "$BRAINAFK_ENV_SLOT_JSON")"
mkdir -p "$BRAINAFK_ARTIFACT_ROOT"
set +e
"$BRAINAFK_ENV_BUNDLE_ROOT/scripts/ssh-exec.sh" \
  env QEMU_TIMEOUT_SECONDS="${QEMU_TIMEOUT_SECONDS:-90}" \
  zhongjing-sec-run --slot "$slot_id" \
  > "$BRAINAFK_ARTIFACT_ROOT/run.stdout.log" 2>&1
run_exit=$?
set -e
printf '%s\n' "$run_exit" > "$BRAINAFK_ARTIFACT_ROOT/run.exit"
test "$run_exit" -eq 0 || test "$run_exit" -eq 124
```

Next use `collect-evidence` to retrieve the guest output.
