# external-linux-example

这是一个可直接运行、也可作为接入模板的 仲景 security 远程验证环境 示例。它用一个
Docker 容器扮演远端 SSH 测试主机；容器内部提供两个独立 QEMU slot。Agent 和 bundle hooks
都通过 SSH 进入该主机执行命令，从而展示 external 环境的远程形态。

## 目录

```text
runtime/             仓库内压缩保存的 guest kernel 与干净 rootfs 模板
payloads/            预编译模块与 PoC；setup 会复制到远端共享目录
src/                 payload 参考源码，不包含平台接入逻辑
compose.yaml         单个 SSH 测试主机容器，并把 SSH 发布到宿主机端口
docker/              SSH 主机镜像与容器内 slot 命令
environment_bundle/  bundle manifest、唯一入口文档、handbooks 和 SSH hooks
scripts/             依赖检查、setup、校验、运行、清理、打包辅助脚本
slots/slots.jsonl    setup 生成的双 slot inventory，不提交
artifacts/           setup 生成的 SSH 材料、解压 runtime、slot rootfs、日志和上传包，不提交
```

## 依赖

宿主机只需要能运行 Docker 容器并具备常见 CLI：

- Docker Engine 与 Docker Compose v2；
- `bash`、`python3`、`jq`、`xz`、`git`、`sha256sum`、GNU coreutils；
- OpenSSH client 工具：`ssh`、`scp`、`ssh-keygen`、`ssh-keyscan`；
- 提交前完整校验额外使用 `rg` 和 `strings`。

QEMU、OpenSSH server、远端 jq 等运行时依赖由 `docker/Dockerfile` 安装在容器内，客户机器不需要单独安装 QEMU。

```bash
./scripts/check-deps.sh
```

## 统一 external 远程模式

`slots.jsonl` 必须写入 zhongjing-sec 执行器可访问的宿主机 IP 或 DNS，而不是 Docker bridge 内网地址。示例容器 SSH 固定发布到宿主机端口，默认端口是 `2222`：

```bash
ZHONGJING_SEC_PUBLIC_HOST=<执行器可访问的宿主机IP或DNS> ./scripts/setup-slots.sh
```

可选参数：

```bash
ZHONGJING_SEC_PUBLIC_PORT=2222      # 写入 slots.jsonl 的 SSH 端口，也是宿主机发布端口
ZHONGJING_SEC_BIND_HOST=0.0.0.0     # Docker 监听地址；需要跨机器访问时保持默认或绑定到可达网卡
```

同机验证和跨机器验证都走这条路径：只要把 `ZHONGJING_SEC_PUBLIC_HOST` 设置成执行器能访问的地址即可。跨机器时，还需要防火墙或安全组允许访问 `ZHONGJING_SEC_PUBLIC_PORT`。

## Slot 模型

`./scripts/setup-slots.sh` 一次完成：检查依赖、解压 runtime 到 `artifacts/shared/`、生成 SSH key、启动容器、创建两个 slot 工作区、写出 `slots/slots.jsonl`、打包前端上传文件。两个 slot 位于同一个 SSH 主机内：

| 内容 | slot 1 | slot 2 |
| --- | --- | --- |
| SSH endpoint | 同一个宿主机发布地址 | 同一个宿主机发布地址 |
| Kernel | `/srv/zhongjing-sec/shared/runtime/Image`（共享只读） | 同左 |
| 干净 rootfs 模板 | `/srv/zhongjing-sec/shared/runtime/rootfs.cpio`（共享只读） | 同左 |
| 工作 rootfs | `/srv/zhongjing-sec/slots/qemu-arm64-ctf-1/rootfs.cpio` | `/srv/zhongjing-sec/slots/qemu-arm64-ctf-2/rootfs.cpio` |
| 日志/证据 | slot 1 私有目录 | slot 2 私有目录 |

cleanup 只停止引用当前 slot 工作 rootfs 的 QEMU，并从共享模板原子恢复该 slot 的 rootfs。

## 快速开始

```bash
./scripts/check-deps.sh
ZHONGJING_SEC_PUBLIC_HOST=<执行器可访问的宿主机IP或DNS> ./scripts/setup-slots.sh
./scripts/validate-example.sh
SLOT_ID=qemu-arm64-ctf-1 QEMU_TIMEOUT_SECONDS=90 ./scripts/smoke-test.sh
```

成功标记包括 `dependency-check=ok`、`setup=ok`、`example-validation=ok`、`healthcheck=ok` 和 `smoke-test=ok`。

## 上传文件语义

setup/package 会生成两份前端上传文件：

```text
/tmp/external-linux-example-environment-bundle.zip
/tmp/external-linux-example-slots.jsonl
```

| 文件 | 语义 | 客户迁移时替换什么 |
| --- | --- | --- |
| `environment-bundle.zip` | 环境控制面：`bundle.yaml`、唯一入口文档、生命周期 hooks、SSH helper、登录 key/known_hosts | 替换 hooks、文档、SSH 连接辅助逻辑 |
| `slots.jsonl` | 可租用资源池：一行一个 slot；本例两行表示同一台 SSH 主机里的两个独立 QEMU 工作区 | 替换 `ssh.*`、`workspace`、`work_dir`、runtime、payload、日志和 cleanup 字段 |

租用时只会选中一行 slot。Agent 和 hooks 应只使用选中的 slot 对象，不扫描或占用其他行。

## 脚本用途

| 脚本 | 用途 |
| --- | --- |
| `scripts/check-deps.sh` | 检查宿主依赖和 Docker 可用性，并提示候选 public host |
| `scripts/setup-slots.sh` | 一条命令完成 runtime 解压、SSH key、容器、两个 slot rootfs、`slots.jsonl` 和上传包准备 |
| `scripts/validate-example.sh` | 提交前总检查：bundle 引用、文档链接、脚本语法、slot schema、远端资产、远程 endpoint、品牌和绝对路径 hygiene |
| `scripts/validate-slot.sh` | 校验单个选中 slot，并通过 SSH 执行远端 verify |
| `scripts/health-check.sh` | 本地触发 bundle 的轻量 lease healthcheck，只检查 SSH、远端命令和必要资产 |
| `scripts/run.sh` | 通过 SSH 运行选中的远端 QEMU slot |
| `scripts/collect-evidence.sh` | 从远端 slot 拉取串口日志并生成 evidence index |
| `scripts/cleanup-slot.sh` | 通过 SSH 清理选中 slot，恢复干净 rootfs |
| `scripts/package-upload.sh` | 重新生成 `artifacts/upload/` 和 `/tmp` 下的上传文件 |
| `scripts/teardown-slots.sh` | 停止示例 SSH 容器 |

## SSH key 权限排查

如果 healthcheck 报 `permissions are too open`，通常是 bundle 解压后 SSH identity 权限过宽，或误把 `.pub` 当作私钥使用。本项目上传包只包含 `ssh/id_ed25519` 私钥和 `ssh/known_hosts`；SSH helper 会在执行前自动修正私钥权限为 `0600`，并拒绝 `.pub` identity。重新运行 `./scripts/package-upload.sh` 后上传新的 bundle zip。

完整合同见 [`ENVIRONMENT_GUIDE.md`](environment_bundle/docs/ENVIRONMENT_GUIDE.md)。

内网不能直接拉取 `debian:bookworm-slim` 时，使用仓库内 `base-images/debian-bookworm-slim-docker-image.tar.gz`，导入和切源步骤见 [`INTERNAL_DEBIAN_IMAGE.md`](docs/INTERNAL_DEBIAN_IMAGE.md)。
