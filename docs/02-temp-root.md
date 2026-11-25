# 02 · 获取临时 root（解锁的前置条件）

> 解锁需要往 `/dev/block/by-name/devinfo` 写两个字节。没有 root 就没有写权限，
> 所以**临时 root 是解锁流程的一部分**，不是可选项。本文说明我们在 PD2266 上
> 实际使用的方案（GhostLock）以及踩过的坑。

## 0. 先明确边界

- 本项目的目标是解锁，不是长期 root。临时 root 只需在**一次开机会话**里有效：
  写入 devinfo → 重启 → 清数据 → 完成解锁。
- 解锁完成后，临时 root 就不再需要了（后续是否刷 KernelSU 属于其它项目的事）。
- 本项目**不发布任何 APK、可执行文件或预编译产物**，只提供补丁（`patches/`）。
  你需要自己从上游源码构建，或使用你信任的、能稳定拿到 root 的方案。

## 1. 可用方案

| 方案 | 说明 | 状态 |
|---|---|---|
| GhostLock（CVE-2026-43499） | futex PI requeue UAF 提权；本项目实测可用 | ✅ OS4/OS5/OS6 均验证 |
| 其他内核提权 | 任何能稳定拿到 `uid=0` 且可执行 shell 的方案均可替代 | 自行确认 |
| 已解锁设备的持久 root | 不适用：解锁前没有 BL，刷不了 `init_boot` | — |

> 不要使用来源不明的「一键 root APK」。提权本身就会改内核状态，
> 再加上不可信的二进制，风险叠加。

## 2. GhostLock 是什么

- 上游：[DONGDERS/Ghostlock-vr](https://github.com/DONGDERS/Ghostlock-vr)
  （vivo/vr.ko 适配分支）、[YuKongA/ghostlock-app](https://github.com/YuKongA/ghostlock-app)（GUI）。
- 利用链：`futex PI requeue` 的 UAF → 改写 `task->cred` 指向 `init_cred` →
  绕过 seccomp → 执行 root 脚本。内部阶段：
  - **W1**：把 SELinux 打到 permissive（页选择有概率，失败会 panic 重启）；
  - **W1c**：零写 `__tracepoint_sys_exit->funcs`，让 vivo 的 `vr.ko` 探针失联
    （否则 root 会在进程退出时被回滚）；
  - **W2 / W2b**：写 cred 并修复引用计数；
  - **W3**：绕过 app 的 seccomp；
  - 最后 handoff 到 root 脚本（我们用它启动一个命令通道）。

## 3. vivo 5.15 必须打的补丁

`patches/` 里的两个补丁是**在 vivo 5.15 上能用**的关键，缺一不可（否则会卡死）：

### 3.1 `tagb-gate.patch`

- 问题：GhostLock 在 W1c 之后有一段「清 tagB」的写入（`task+0x2c`，按 8 字节对齐后清 `task+0x28`）。
- vivo 5.15 的 `thread_info` 是 **40 字节**（不是 32），`task+0x28` 是 `task_struct.__state`。
  被清零后目标任务无法被唤醒，变成 `State: R`、`wchan=0`、`SIGKILL` 无效的僵尸；
  随后 W2 的 verify 读（pipe 读子进程 uid）永久阻塞。
- 补丁：当 `session.profile.release()` 以 `"5.15"` 开头时**跳过 tagB**。

### 3.2 `verify-timeout.patch`

- 问题：三处 verify 读取是阻塞读，遇到上面的僵尸就永远卡住。
- 补丁：改为 `poll()` 3 秒超时，超时后报错退出，而不是挂死。

> 这两个补丁适用于 `Ghostlock-vr` 与 `ghostlock-app`（文件路径一致）。如果你的内核
> release 字符串不是 `5.15` 开头，请按实际版本调整判断条件。

## 4. 构建与运行（实测流程）

### 4.1 环境

- Linux 或 Windows + MSYS/Cygwin（本项目在 Windows + Android NDK 27 上构建），
  或者 Linux 交叉编译。
- JDK 21 + Android SDK（仅构建 APK 时需要；CLI 不需要）。
- Android NDK（`clang++`），我们直接用它编译 24 个 `.cpp` 源文件。

### 4.2 应用补丁并构建 CLI

```bash
git clone https://github.com/DONGDERS/Ghostlock-vr
cd Ghostlock-vr
git apply /path/to/vivo-xfold-2-unlock/patches/tagb-gate.patch
git apply /path/to/vivo-xfold-2-unlock/patches/verify-timeout.patch
# 按上游 README 构建 native CLI（我们使用的是 clang++ 直接编译，NDK r27）
```

注意：

- 上游若使用 Makefile，Windows 上注意 CRLF（`sed -i 's/\r$//' Makefile`）。
- NDK r27 下可能遇到 `PAGE_SIZE` 宏冲突，可在 `constants.hpp` 里 `#undef PAGE_SIZE`。

### 4.3 生成设备 profile

GhostLock 需要与目标内核匹配的 profile（偏移量）。上游提供生成方式（CLI/工具）；
本项目使用的做法是把已生成的 `profile.bin` 与 CLI 一起推到设备。
**profile 必须对应你当前系统的内核构建**，换系统版本要重新生成。

### 4.4 运行

```bash
adb push ghostlock /data/local/tmp/ghostlock
adb push profile.bin /data/local/tmp/profile.bin
adb push glk-hook.sh /data/local/tmp/glk-hook.sh   # 你的 root 命令通道（可选）
adb shell chmod 755 /data/local/tmp/ghostlock
adb shell /data/local/tmp/ghostlock --profile /data/local/tmp/profile.bin
```

- 成功时日志会出现 `exploit complete`、`handoff: root script ...`，随后 root 命令通道可执行。
- 验证：`adb shell su -c id`（若用了 KSU hook）或通过你自己的命令通道。

### 4.5 W1 的概率性失败

- W1 的页选择是概率事件；失败会 **kernel panic 并重启**。这是预期行为，不是变砖。
- 重启后等 1–2 分钟再重试；不要在开机后立刻跑。
- 本机 OS4 上曾连续 3 次 panic、第 4 次成功；OS5/OS6 上多数 1–2 次内成功。
- 重试前确认：`adb devices` 在线、系统已完全启动、电量充足。

## 5. 拿到 root 之后

```bash
# 确认 devinfo 可读（这一步不需要写入）
adb shell su -c "dd if=/dev/block/by-name/devinfo bs=4096 count=1 2>/dev/null | od -An -tx1 -j13 -N2"
# 回到主流程：
bash scripts/unlock_devinfo.sh --dry-run
```

## 6. 常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| W2b 之后没有下文，子进程 `State: R`、杀不掉 | tagB 地雷（见 3.1） | 打上 `tagb-gate.patch` + `verify-timeout.patch` |
| 跑几次都 panic | W1 概率 | 重启后等待 1–2 分钟再试；降低后台负载 |
| root 拿到后立刻消失 | vivo `vr.ko` 探针回滚 | W1c 必须成功（`sys_exit tracepoint disarmed` 日志） |
| `su` 命令不存在 | 没有安装 KSU 用户态 | 本项目不需要 KSU；用 handoff 的 root 命令通道即可 |

## 7. 安全提醒

- 提权会改运行中的内核状态，可能触发重启或临时不稳定；**先备份、再操作**。
- 解锁本来就会清数据，建议在「准备清数据」的时间点做，避免白折腾。
- 只用你信任的源码与构建产物；本项目只提供补丁，不提供二进制。
