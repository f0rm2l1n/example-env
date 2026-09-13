# Environment Guide

你被分配到一个 `external`(SSH JSONL)远程验证环境。它的形态是:**远端一台 SSH 主机,背后托管若干独立、可租用的 slot —— 每个 slot 是一台跑在 QEMU 里的 ARM64 Linux 内核虚拟机(内核 `6.6.0`,架构 `aarch64`,开启 KASAN)**。

平台已经替你**租用了恰好一个 slot**,并把它的内容写成了 selected slot JSON,注入 `$BRAINAFK_ENV_SLOT_JSON`。你全程只跟**这一个** slot 打交道,通过 SSH 进出远端主机,不需要碰宿主机上的 Docker 或 QEMU 进程。

本文件是入口索引。先看「你在这个环境里做什么」建立直觉,再按需阅读 slots / handbooks / 编译 / 交互四节。

## 你在这个环境里做什么(一屏看清)

目标是:让远端某个 QEMU guest 里加载的易受攻击内核模块,在运行你**自己写的** poc 时触发一次 KASAN 崩溃。环境**只提供环境,不提供 poc**。一次典型会话是——

1. **已就绪**:平台已租用一个 slot(见 `$BRAINAFK_ENV_SLOT_JSON`),并通过 `activate_on_lease` 保证该 slot 的根文件系统是干净的。
2. **inspect**:按 [inspect-slot](../handbooks/inspect-slot/SKILL.md) 跑 `zhongjing-sec-verify`,确认远端资产可用、模块在位。
3. **compile**:按 [linux-compile-poc](../handbooks/linux-compile-poc/SKILL.md) 在远端 slot 宿主机编译静态 ARM64 程序。
4. **run**:按 [linux-run-poc](../handbooks/linux-run-poc/SKILL.md) 启动 QEMU guest 并执行 `/poc`。
5. **collect**:按 [collect-evidence](../handbooks/collect-evidence/SKILL.md) 拉取串口日志并检查运行结果。
6. **释放**:平台自动停止 QEMU 并恢复干净 rootfs。

## 1. selected slot 里有什么

`$BRAINAFK_ENV_SLOT_JSON` 指向一个只含**一行**(你所租用的那个 slot)的 JSON。它的关键字段:

| 字段 | 含义 |
| --- | --- |
| `ssh` | 进入远端主机的 SSH endpoint(`host` / `port` / `user` / `identity_file` / `known_hosts_file`) |
| `workspace` | 远端主机内的根目录 `/srv/zhongjing-sec` |
| `work_dir` | 本 slot 的独立工作目录 `/srv/zhongjing-sec/slots/<slot_id>` |
| `runtime` | 开这台 QEMU 要用的内核镜像与 rootfs:共享只读的 `kernel_image`、`rootfs_template`,以及本 slot 的 `rootfs_cpio` |
| `payloads` | 共享只读的 `module_ko`(有漏洞的模块) |
| `run.poc_in` | 本 slot 的上传 poc 目录;你把 `/poc`(可选)放进这里 |
| `logs` | 本 slot 的 `serial_log`(QEMU 串口输出)、`evidence_dir` |
| `build` / `run` / `healthcheck` / `cleanup` | 生命周期命令约定,见下 |

共享 vs 隔离:

- **共享只读**(所有 slot 一致):内核镜像、干净 rootfs 模板、预编译模块,位于远端 `/srv/zhongjing-sec/shared/`。你开机的内核就是这套共享内核。
- **按 slot 隔离**:每个 slot 自己的工作 rootfs、串口日志、evidence、上传 poc 的 `poc_in`,都在其 `work_dir/` 下。不要碰其他 slot 的路径。

## 2. handbooks 里有什么

四个 handbook 按顺序使用:

| handbook | 干什么 | 不跑会怎样 |
| --- | --- | --- |
| [inspect-slot](../handbooks/inspect-slot/SKILL.md) | 校验 slot、确认远端资产可用 | 直接 run 可能因缺资产失败 |
| [linux-compile-poc](../handbooks/linux-compile-poc/SKILL.md) | 在远端编译静态 ARM64 PoC | 没有可运行的 PoC |
| [linux-run-poc](../handbooks/linux-run-poc/SKILL.md) | 开机运行 PoC | 没有运行结果 |
| [collect-evidence](../handbooks/collect-evidence/SKILL.md) | 拉串口日志、生成证据索引 | 没有可比对的证据 |

每个 runbook 都依赖 `$BRAINAFK_ENV_SLOT_JSON`、`$BRAINAFK_ENV_BUNDLE_ROOT`、`$BRAINAFK_ARTIFACT_ROOT` 三个环境变量,缺一个就 `:?` 报错退出。

## 3. 如何编译 poc

你的 PoC 是运行在 ARM64 QEMU guest 中的 userspace 程序。远端 slot 宿主机提供交叉编译器。

- **目标平台**:aarch64 Linux,内核 `6.6.0`,已开 KASAN。guest rootfs 是最小 busybox,没有共享库,**必须静态链接**,否则 guest 加载不了你的程序。
- **交叉编译**:

```bash
aarch64-linux-gnu-gcc -static -o <poc> <poc.c>
```

- **目标接口**:guest 加载的模块注册了 misc 设备 `/dev/zhongjing-sec_misc`,通过 ioctl 交互。ioctl ABI 如下:

```c
#define ZHONGJING_SEC_VULN_IOCTL_MAGIC    0xBA
#define ZHONGJING_SEC_VULN_IOCTL_TRIGGER  \
    _IOW(ZHONGJING_SEC_VULN_IOCTL_MAGIC, 0x1, struct zhongjing_sec_vuln_req)

struct zhongjing_sec_vuln_req {
    unsigned int        len;
    unsigned int        reserved;
    unsigned long long  user_ptr;
};
```

模块二进制在远端 `payloads.module_ko` 路径,可用 `ssh-exec.sh` 读取反汇编进一步分析。这里只描述环境暴露了什么;**漏洞怎么定位、poc 怎么构造利用——都由你完成**。

## 4. 如何与远程环境交互

### 环境变量

平台注入(前缀 `BRAINAFK_`);bundle 侧脚本(`ssh-common.sh`)按 `ZHONGJING_SEC_*` 优先、`BRAINAFK_*` 兜底读取,所以这两个前缀都指向同一批变量:

- `BRAINAFK_ENV_SLOT_JSON` — 你所租用的 selected slot JSON 路径。
- `BRAINAFK_ENV_BUNDLE_ROOT` — 解包后的 bundle 根目录。
- `BRAINAFK_ARTIFACT_ROOT` — 本地产物/证据输出目录。

对应到脚本里就是 `ZHONGJING_SEC_ENV_SLOT_JSON` / `ZHONGJING_SEC_ENV_BUNDLE_ROOT` / `ZHONGJING_SEC_ARTIFACT_ROOT`。

### SSH helper(在 `$BRAINAFK_ENV_BUNDLE_ROOT/scripts/`)

- `ssh-exec.sh [slot.json] CMD...` — 在远端主机执行命令。
- `ssh-copy-from.sh [slot.json] REMOTE_PATH LOCAL_PATH` — 从远端拉文件(只允许拉本 slot `work_dir` 下的路径)。
- `ssh-copy-to.sh [slot.json] LOCAL_PATH` — 把本地文件推到本 slot 的 `poc_in/`,guest 开机时会作为 `/poc` 执行(可选)。

### 远端命令

| 命令 | 作用 | 你据此判断 |
| --- | --- | --- |
| `zhongjing-sec-verify --slot <id>` | 校验共享资产与本 slot 工作 rootfs | 输出 `remote-verification=ok` |
| `zhongjing-sec-run --slot <id>` | 开一台 QEMU arm64 VM 跑该 slot,串口写到 `logs.serial_log` | 跑完看串口日志 |
| `zhongjing-sec-healthcheck --slot <id>` | 轻量可用性检查 | 输出 `healthcheck=ok` |
| `zhongjing-sec-cleanup --slot <id>` | 停该 slot 的 QEMU、恢复干净 rootfs | 输出 `rootfs_restored=yes` |

### 生命周期 hook 映射(`bundle.yaml` 声明,由平台驱动,你一般不动)

- `activate_on_lease` → 远端 `zhongjing-sec-cleanup`(保证工作 rootfs 干净)
- `healthcheck_on_lease` → 远端 `zhongjing-sec-healthcheck`
- `cleanup_on_release` → 远端 `zhongjing-sec-cleanup`

### 成功标记

- verify 输出 `remote-verification=ok`
- healthcheck 输出 `healthcheck=ok`
- 完整 run 的串口日志包含 `module inserted` 和 `guest ready`;若你注入的 `/poc` 触发崩溃,还会出现 `BUG: KASAN:`(那是你的结果,不是环境要求)
- cleanup 输出 `rootfs_restored=yes`
