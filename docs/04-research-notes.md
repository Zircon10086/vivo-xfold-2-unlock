# 04 · 研究笔记与证据

本文件记录解锁结论的来源与可复核数据。**不包含**任何分区 dump、厂商二进制或 ROM。

## 1. ABL 结构（PD2266，`abl_a` 分区 16 MB）

- ELF32，LOAD 段 vaddr `0x9fa00000`，大小 4 MB；
- 固件卷（FV）→ LZMA 压缩段（GUID `EE4E5898-3914-4259-9C42-16D3B6D0E7B5`）→ 内层 FV
  → LinuxLoader PE32+（933,888 字节，`.text` 约 `0xb8000`）。

关键字符串（PE 内 RVA）：

| 字符串 | RVA |
|---|---|
| `ANDROID-BOOT!` | `0xabe22` |
| `Device is unlocked, Skipping boot verification` | `0xb09cc` |
| `bbk unlock_vivo` / `vivo_bsp lock_vivo` | 邻近区域 |
| `get_unlock_ability` / `IsAllowUnlock is %d` | 邻近区域 |

magic 比较点：VA `0x358ec`

```
adrp x1, 0xab000        ; 0xab000 + 0xe22 -> "ANDROID-BOOT!"
add  x1, x1, #0xe22
...
bl   CompareMem(..., 13)
cbz  x0, <devinfo 解析路径>
```

命中后进入 devinfo 解析（`0x35ba4` 起）。在该路径中未发现 CRC/签名校验，
与公开的 iQOO 9T 分析一致。

## 2. devinfo 布局（PD2266，OS4/5/6 相同）

| 偏移 | 未解锁值 | 解锁后 | 含义 |
|---|---|---|---|
| 0x00 | `ANDROID-BOOT!` | 不变 | magic（13 字节） |
| 0x0d | `0x00` | `0x01` | unlocked |
| 0x0e | `0x00` | `0x01` | critical unlocked |
| 0x0f | `0x01` | 不变 | 未使用/固定 |
| 0x90 | `0x01` | 不变 | 未使用/固定 |

写入后应逐字节比对：除 `0x0d`、`0x0e` 外不得有任何变化。

## 3. 临时 root 的 tagB 问题（GhostLock）

- 现象：`W2b` 之后没有下文；子进程 `State: R`、`wchan=0`、`SIGKILL` 无效；
  verify 读永久阻塞。
- 根因：GhostLock 的 tagB 清零目标是 `task+0x2c`，按 8 字节对齐后清 `task+0x28`。
  vivo 5.15 的 `thread_info` 为 40 字节（不是 32），因此 `task+0x28` 是
  `task_struct.__state`；被清零后任务无法被唤醒，变成不可杀僵尸。
- 修复（见 `patches/`）：
  1. `session.profile.release()` 以 `"5.15"` 开头时跳过 tagB；
  2. 三处 verify 读取改为 `poll()` 3 秒超时。
- 上游 PR：Ghostlock-vr #3、ghostlock-app #993。

## 4. 验证命令

```bash
# 解锁状态（bootloader 为准）
fastboot getvar unlocked

# devinfo 前后比对
adb shell su -c "dd if=/dev/block/by-name/devinfo bs=4096 count=1 2>/dev/null" > devinfo.bin
cmp -l devinfo.before devinfo.bin     # 期望只差 0x0d、0x0e

# 注意：ro.boot.* 可能被 PIF/TrickyStore 伪造，不能单独作为判据
```

## 5. 方法论

- 结论必须落到「本机可复核的证据」：偏移、字节、反汇编地址、命令输出。
- 不引用无法复核的传言；不同机型/版本的差异要单独标注。
- 本项目只对 PD2266 的三个构建号负责，其它机型请自行核对后再操作。
