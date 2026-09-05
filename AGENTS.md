# Repository Guidelines

## Project Structure & Module Organization
This repository packages a 仲景 security 远程验证环境 as separated parts: `runtime/` for guest assets, `payloads/` for prebuilt test payloads, `environment_bundle/` for the bundle contract, `docker/` for the SSH test host, `slots/` for generated inventories, and `scripts/` for setup and validation helpers. Generated SSH keys, slot workspaces, logs, evidence, and upload packages belong only under `artifacts/` or ignored `environment_bundle/ssh/`.

## Build, Test, and Development Commands
- `ZHONGJING_SEC_PUBLIC_HOST=<executor-reachable-ip-or-dns> ./scripts/setup-slots.sh` — start the SSH container, publish SSH through the host, prepare two remote QEMU slots, generate `slots/slots.jsonl`, and package upload files.
- `./scripts/validate-example.sh` — validate bundle references, Markdown links, SSH slot schema, scripts, container config, and runtime assets.
- `./scripts/validate-slot.sh <selected-slot.json>` — validate one selected SSH slot and remote workspace assets.
- `./scripts/verify-artifacts.sh` — verify runtime and payload files against `ASSET_SHA256SUMS`.
- `./scripts/health-check.sh` — run the bundle lease health check through SSH.
- `./scripts/run.sh` — run the selected remote QEMU slot through SSH.
- `QEMU_TIMEOUT_SECONDS=90 ./scripts/smoke-test.sh` — primary end-to-end validation.
- `./scripts/package-upload.sh` — write upload-ready bundle and slots files to `artifacts/upload/` and `/tmp`.

## Coding Style & Naming Conventions
Shell scripts use `bash`, `set -euo pipefail`, and lowercase snake_case variables. Keep bundle-facing docs and handbooks under `environment_bundle/`. Keep slot JSONL files under `slots/`. Preserve SPDX headers in source and script files.

## Testing Guidelines
There is no separate unit test framework. Use `scripts/smoke-test.sh` as the primary validation. Do not commit `artifacts/`, generated `environment_bundle/ssh/`, or generated `slots/slots.jsonl`. Run `scripts/check-deps.sh` and `scripts/validate-example.sh` before the smoke test so dependency, documentation, and contract failures are reported before QEMU boot.
