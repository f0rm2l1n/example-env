---
name: linux-compile-poc
description: Compile and run a static ARM64 Hello World PoC in the leased slot.
---

# Compile Linux PoC

Compile on the remote slot host, which provides the ARM64 cross compiler:

```bash
set -euo pipefail
mkdir -p "$BRAINAFK_ARTIFACT_ROOT"
poc_in="$(jq -r '.run.poc_in' "$BRAINAFK_ENV_SLOT_JSON")"
cat > "$BRAINAFK_ARTIFACT_ROOT/hello-poc.c" <<'EOF'
#include <stdio.h>

int main(void) {
    puts("hello from aarch64 poc");
    return 0;
}
EOF
"$BRAINAFK_ENV_BUNDLE_ROOT/scripts/ssh-copy-to.sh" \
  "$BRAINAFK_ARTIFACT_ROOT/hello-poc.c" "$poc_in"
"$BRAINAFK_ENV_BUNDLE_ROOT/scripts/ssh-exec.sh" sh -c '
  set -eu
  poc_in="$1"
  aarch64-linux-gnu-gcc -static -O2 \
    -o "$poc_in/poc.tmp" "$poc_in/hello-poc.c"
  chmod 0755 "$poc_in/poc.tmp"
  mv -f "$poc_in/poc.tmp" "$poc_in/poc"
  file "$poc_in/poc"
' sh "$poc_in" | tee "$BRAINAFK_ARTIFACT_ROOT/compile.log"
grep -q 'ARM aarch64' "$BRAINAFK_ARTIFACT_ROOT/compile.log"
grep -q 'statically linked' "$BRAINAFK_ARTIFACT_ROOT/compile.log"
```

Then use `linux-run-poc`, followed by `collect-evidence`. Confirm the program ran:

```bash
grep -q 'hello from aarch64 poc' "$BRAINAFK_ARTIFACT_ROOT/qemu-serial.log"
```
