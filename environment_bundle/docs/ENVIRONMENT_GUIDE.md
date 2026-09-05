# Environment Guide

本 bundle 展示 仲景 security 远程验证环境 的远程接入方式：一台 Docker 容器扮演 SSH 测试主机，主机内提供两个可并发租用的 QEMU slot。zhongjing-sec 只需要上传 bundle zip 和 `slots.jsonl`。

## 准备与上传

在示例仓库执行：

```bash
./scripts/check-deps.sh
ZHONGJING_SEC_PUBLIC_HOST=<执行器可访问的宿主机IP或DNS> ./scripts/setup-slots.sh
./scripts/validate-example.sh
```

默认 SSH 发布端口是 `2222`。如需改端口：

```bash
ZHONGJING_SEC_PUBLIC_HOST=<执行器可访问的宿主机IP或DNS> \
ZHONGJING_SEC_PUBLIC_PORT=2222 \
./scripts/setup-slots.sh
```

输出文件：

```text
/tmp/external-linux-example-environment-bundle.zip
/tmp/external-linux-example-slots.jsonl
```

把这两个文件提供给 zhongjing-sec。bundle zip 根目录包含 `bundle.yaml`；`documents.guide` 只指向本文件。

## 两个上传文件

| 文件 | 含义 |
| --- | --- |
| `environment-bundle.zip` | 环境控制面：manifest、本文档、hooks、SSH helper、key/known_hosts。它回答“怎么进入远端、怎么验证、怎么清理”。 |
| `slots.jsonl` | 资源清单：一行一个可租用 slot。它回答“有哪些机器/工作区可以被租用”。 |

租用流程只会把其中一行 slot 写成 selected slot JSON。后续命令都围绕该 selected slot 执行。

## Slot 结构

`slots.jsonl` 有两行，表示同一台 SSH 主机上的两个 slot：

- `transport.kind=ssh`；
- `ssh.host`、`ssh.port`、`ssh.user` 指向宿主机发布出来的 SSH endpoint；
- `ssh.identity_file` 和 `ssh.known_hosts_file` 使用 `${ZHONGJING_SEC_ENV_BUNDLE_ROOT}/ssh/...`；
- `workspace=/srv/zhongjing-sec` 是容器内根目录；
- `runtime.kernel_image` 和 `runtime.rootfs_template` 为共享只读资产；
- `runtime.rootfs_cpio`、`logs.serial_log`、`logs.evidence_dir` 按 slot 分开。

仓库中的 `runtime/*.xz` 是为了降低 Git 体积；`setup-slots.sh` 会解压到 ignored 的 `artifacts/shared/runtime/`，容器再把该目录作为远端共享只读资产挂载到 `/srv/zhongjing-sec/shared/runtime/`。

## 统一 external endpoint

同机验证和跨机器验证都使用同一种语义：`slots.jsonl` 里的 `ssh.host` 必须是执行器能访问的宿主机 IP 或 DNS，`ssh.port` 是宿主机发布端口。不要把 Docker bridge 内网地址写入上传文件。

跨机器时确认三件事：

1. `ZHONGJING_SEC_PUBLIC_HOST` 从执行器机器可达；
2. 防火墙或安全组允许访问 `ZHONGJING_SEC_PUBLIC_PORT`；
3. 重新执行 `setup-slots.sh`，让 `known_hosts` 和 `slots.jsonl` 与该 endpoint 一致。

## 生命周期

1. zhongjing-sec 租用一行 slot，并把该对象写入 `$ZHONGJING_SEC_ENV_SLOT_JSON`。
2. `activate_on_lease` 通过 SSH 调用 `zhongjing-sec-cleanup --slot <id>`，保证工作 rootfs 干净。
3. `healthcheck_on_lease` 通过 SSH 调用 `zhongjing-sec-healthcheck --slot <id>`，只确认 SSH 可达、远端命令可用、共享 runtime/payload 与当前 slot 工作 rootfs 存在，并把状态复制到 `$ZHONGJING_SEC_ARTIFACT_ROOT`。
4. Agent 执行任务时应通过 bundle scripts 进入远端，例如：

```bash
export ZHONGJING_SEC_ENV_SLOT_JSON=/path/to/selected-slot.json
export ZHONGJING_SEC_ENV_BUNDLE_ROOT=/path/to/unpacked-bundle
export ZHONGJING_SEC_ARTIFACT_ROOT=/path/to/evidence

$ZHONGJING_SEC_ENV_BUNDLE_ROOT/scripts/ssh-exec.sh zhongjing-sec-verify --slot qemu-arm64-ctf-1
QEMU_TIMEOUT_SECONDS=90 $ZHONGJING_SEC_ENV_BUNDLE_ROOT/scripts/ssh-exec.sh env QEMU_TIMEOUT_SECONDS=90 zhongjing-sec-run --slot qemu-arm64-ctf-1
$ZHONGJING_SEC_ENV_BUNDLE_ROOT/scripts/ssh-copy-from.sh /srv/zhongjing-sec/slots/qemu-arm64-ctf-1/run/qemu-serial.log "$ZHONGJING_SEC_ARTIFACT_ROOT/qemu-serial.log"
```

5. `cleanup_on_release` 只清理当前 slot：停止引用该 slot rootfs 的 QEMU、从模板复制新 rootfs、用 `cmp` 验证恢复。

## SSH key 权限排查

如果 healthcheck 报 `permissions are too open`，先确认 selected slot 的 `ssh.identity_file` 指向 `${ZHONGJING_SEC_ENV_BUNDLE_ROOT}/ssh/id_ed25519`，不是 `.pub` 文件。bundle SSH helper 会在连接前执行 `chmod 0600` 修正私钥权限；上传包不包含 `ssh/id_ed25519.pub`，避免平台误选公钥。

## 成功标记

- `zhongjing-sec-verify` 输出 `remote-verification=ok`；
- healthcheck 状态文件输出 `healthcheck=ok`；
- 完整 run 或 smoke test 的 QEMU 串口日志包含 `module inserted` 和 `BUG: KASAN:`；
- cleanup 输出 `rootfs_restored=yes`。

## 迁移规则

替换成自己的业务环境时按这个顺序做：

1. 准备一个可 SSH 登录的测试主机或容器；
2. 在远端放置共享只读资产，例如 kernel、基础镜像、测试工具或业务服务包；
3. 为每个并发 slot 准备独立工作目录，至少包含可恢复的工作镜像、日志目录和 evidence 目录；
4. 修改 `slots.jsonl` 生成逻辑，让每行指向一个独立 slot；
5. 修改远端 `verify/run/healthcheck/cleanup` 命令，让 verify 检查资产，run 启动业务测试，healthcheck 只做轻量可用性判定，cleanup 恢复干净状态；
6. 修改本文档中的成功标记，使 Agent 能判断测试是否完成。

保留四个约束：一行 JSONL 表示一个可租用资源；不可变资产共享；可变 rootfs/log/evidence 按 slot 隔离；cleanup 必须恢复到干净状态。若 clone 路径、宿主机地址或发布端口变化，重新运行 `setup-slots.sh` 即可。
