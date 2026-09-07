# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A template for a 仲景 (Zhongjing) Security **remote verification environment** using the "external" transport. A single Docker container acts as a remote SSH test host; inside it, two independent QEMU ARM64 slots boot a deliberately vulnerable kernel. The example demonstrates the whole loop — unpack assets, start the SSH host, allocate slots, then verify/run/collect-evidence/cleanup a leased slot entirely over SSH.

## Architecture: three layers joined over SSH

The repo splits into three layers that only make sense when read together:

1. **Local control** — `scripts/`, `runtime/`, `payloads/`, `compose.yaml`, `docker/`. This repo. `scripts/setup-slots.sh` decompresses `runtime/*.xz` into the gitignored `artifacts/shared/`, generates SSH keys, builds and starts the container via `docker compose`, creates two slot work dirs, and emits `slots/slots.jsonl`.

2. **Bundle control plane** — `environment_bundle/`. This is what gets zipped and uploaded to the executor. `bundle.yaml` declares three lifecycle hooks (`activate_on_lease`, `healthcheck_on_lease`, `cleanup_on_release`) and the entry document. `environment_bundle/scripts/` holds the SSH helpers (`ssh-common.sh`, `ssh-exec.sh`, `ssh-copy-from.sh`) and the hooks themselves; `environment_bundle/handbooks/*/SKILL.md` are the agent-facing runbooks.

3. **Remote commands** — `docker/remote/`. Four binaries installed inside the container (`zhongjing-sec-verify|run|healthcheck|cleanup`) that the hooks invoke over SSH. They all source `slot-common.sh`, which derives every per-slot path from a single `slot_id`.

The chain is: executor → bundle hook → `ssh-exec.sh` → `zhongjing-sec-*` inside the container. A "selected slot" is one JSON line from `slots.jsonl`, threaded through the whole chain by the `ZHONGJING_SEC_ENV_SLOT_JSON` env var.

## The slot contract

`slots/slots.jsonl` (gitignored, generated) is JSONL — one line per leaseable slot. Both slots point at the same published SSH endpoint but own distinct `work_dir` (`/srv/zhongjing-sec/slots/<slot_id>`), working rootfs, serial log, and evidence directory. Shared read-only assets (`runtime.kernel_image`, `runtime.rootfs_template`, payloads) live under `/srv/zhongjing-sec/shared/`.

`ZHONGJING_SEC_PUBLIC_HOST` must be an IP/DNS the executor can reach (never a Docker bridge address); it is baked into `slots.jsonl` and the SSH `known_hosts`. Same-machine and cross-machine use identical semantics — only the host value changes.

## Upload artifacts

`scripts/package-upload.sh` produces two files the executor consumes together:

- `environment-bundle.zip` — the control plane (manifest, docs, hooks, SSH helpers, private key `ssh/id_ed25519`, `known_hosts`). The `.pub` key is deliberately excluded.
- `slots.jsonl` — the resource pool.

## The deliberate vulnerability (what "success" means)

`src/vuln_misc.c` registers a misc device whose ioctl allocates a 64-byte heap buffer then copies `req.len` bytes into it with no bounds check (`src/vuln_misc.c:41-50`) — an intentional heap overflow. `payloads/vuln_misc.ko` and `payloads/poc` are prebuilt; `src/` is reference source only, with no build step in this repo. Success is *not* "no crash": the smoke test and handbooks assert the QEMU serial log contains both `module inserted` and `BUG: KASAN:`. Cleanup success is `rootfs_restored=yes`; `zhongjing-sec-verify` success is `remote-verification=ok`.

## Commands

There is no unit-test framework; `scripts/smoke-test.sh` is the primary end-to-end validation. Run checks in this order so dependency/doc/contract failures surface before QEMU boot.

```bash
./scripts/check-deps.sh                                  # host deps + docker reachability + candidate public host

ZHONGJING_SEC_PUBLIC_HOST=<executor-reachable-ip-or-dns> \
  ./scripts/setup-slots.sh                               # full setup: assets, keys, container, slots.jsonl, upload files

./scripts/validate-example.sh                            # pre-commit gate: bundle refs, links, schema, script syntax, asset checksums
./scripts/verify-artifacts.sh                            # verify runtime/payload files against ASSET_SHA256SUMS

# primary end-to-end validation (runs a single slot; auto-runs setup-slots.sh if slots.jsonl is missing)
SLOT_ID=qemu-arm64-ctf-1 QEMU_TIMEOUT_SECONDS=90 ./scripts/smoke-test.sh

# operate on a single selected slot (all accept SLOT_ID= to target slot 2)
./scripts/run.sh                 # boot the slot's QEMU over SSH
./scripts/health-check.sh        # bundle lease healthcheck over SSH
./scripts/collect-evidence.sh    # pull serial log + build evidence index
./scripts/cleanup-slot.sh        # kill slot QEMU, restore clean rootfs
./scripts/validate-slot.sh <single-slot.json>

./scripts/package-upload.sh      # regenerate artifacts/upload/ and /tmp upload files
./scripts/teardown-slots.sh      # stop the SSH container
```

### Configuration env vars

- `ZHONGJING_SEC_PUBLIC_HOST` (required) — executor-reachable IP/DNS written into `slots.jsonl`.
- `ZHONGJING_SEC_PUBLIC_PORT` (default `2222`) — host-published SSH port.
- `ZHONGJING_SEC_BIND_HOST` (default `0.0.0.0`) — Docker listen address.
- `QEMU_TIMEOUT_SECONDS` (default `120`; smoke test uses `90`), `QEMU_MEMORY_MB` (default `1024`).
- `DEBIAN_BASE_IMAGE`, `DEBIAN_APT_MIRROR`, `DEBIAN_SECURITY_APT_MIRROR` — offline/base-image overrides; see `docs/INTERNAL_DEBIAN_IMAGE.md`.
- `ZHONGJING_SEC_ENV_SLOT_JSON`, `ZHONGJING_SEC_ENV_BUNDLE_ROOT`, `ZHONGJING_SEC_ARTIFACT_ROOT` — the bundle-hook contract (set by the executor at runtime).

## Conventions

- Shell scripts use `bash`, `set -euo pipefail`, and lowercase `snake_case` variables. Keep SPDX headers in source and script files.
- Generated material is gitignored and must not be committed: `artifacts/`, `environment_bundle/ssh/`, `slots/slots.jsonl`.
- `environment_bundle/scripts/ssh-common.sh` resolves env vars through `zhongjing_sec_env`, which accepts a legacy `BRAINAFK_*` prefix as an alias for `ZHONGJING_SEC_*` — keep both working when touching that file.
- `README.md`, `AGENTS.md`, and the bundle docs are written in Chinese; code, headers, and comments are English.
