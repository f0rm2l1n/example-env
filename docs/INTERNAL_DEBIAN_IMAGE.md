# Internal Debian Base Image and APT Mirror

本示例默认依赖 Docker 基镜像 `debian:bookworm-slim`。如果内网不能直接拉取外网镜像，可以把随本次准备的 tar.gz 导入内网 Docker 节点，或推送到内部镜像仓库；构建时也可以指定内部 Debian apt 源。

## 1. 导入基础镜像 tar.gz

仓库内已提交：

```text
base-images/debian-bookworm-slim-docker-image.tar.gz
base-images/debian-bookworm-slim-docker-image.tar.gz.sha256
```

在内网机器 clone 仓库后执行：

```bash
sha256sum -c base-images/debian-bookworm-slim-docker-image.tar.gz.sha256
docker load -i base-images/debian-bookworm-slim-docker-image.tar.gz
docker image ls debian:bookworm-slim
```

如果内网使用私有镜像仓库，可以再打 tag 并推送：

```bash
docker tag debian:bookworm-slim registry.internal.example.com/library/debian:bookworm-slim
docker push registry.internal.example.com/library/debian:bookworm-slim
```

之后构建示例容器时指定内部基础镜像：

```bash
DEBIAN_BASE_IMAGE=registry.internal.example.com/library/debian:bookworm-slim \
ZHONGJING_SEC_PUBLIC_HOST=<执行器可访问的宿主机IP或DNS> \
./scripts/setup-slots.sh
```

如果已在本机 `docker load` 为 `debian:bookworm-slim`，则不用设置 `DEBIAN_BASE_IMAGE`。

## 2. 切换 Debian apt 源

`docker/Dockerfile` 支持两个 build arg：

```text
DEBIAN_APT_MIRROR           # bookworm 与 bookworm-updates
DEBIAN_SECURITY_APT_MIRROR  # bookworm-security；缺省时复用 DEBIAN_APT_MIRROR
```

内网镜像源示例：

```bash
DEBIAN_BASE_IMAGE=registry.internal.example.com/library/debian:bookworm-slim \
DEBIAN_APT_MIRROR=http://apt-mirror.internal.example.com/debian \
DEBIAN_SECURITY_APT_MIRROR=http://apt-mirror.internal.example.com/debian-security \
ZHONGJING_SEC_PUBLIC_HOST=<执行器可访问的宿主机IP或DNS> \
./scripts/setup-slots.sh
```

如果你的内网源把 security 仓库也合并在同一个 URI 下，可以只设置：

```bash
DEBIAN_APT_MIRROR=http://apt-mirror.internal.example.com/debian \
ZHONGJING_SEC_PUBLIC_HOST=<执行器可访问的宿主机IP或DNS> \
./scripts/setup-slots.sh
```

Dockerfile 会写入 `/etc/apt/sources.list.d/debian.sources`，然后安装容器内依赖：`openssh-server`、`qemu-system-arm`、`jq`、`util-linux` 等。

## 3. 验证

```bash
./scripts/check-deps.sh
ZHONGJING_SEC_PUBLIC_HOST=<执行器可访问的宿主机IP或DNS> ./scripts/setup-slots.sh
./scripts/validate-example.sh
SLOT_ID=qemu-arm64-ctf-1 QEMU_TIMEOUT_SECONDS=90 QEMU_MEMORY_MB=512 ./scripts/smoke-test.sh
```

看到 `setup=ok`、`example-validation=ok`、`smoke-test=ok` 即可重新上传 `/tmp/external-linux-example-environment-bundle.zip` 和 `/tmp/external-linux-example-slots.jsonl`。
