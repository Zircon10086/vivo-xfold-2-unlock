# 99 · 研究笔记与证据索引

本文件记录关键结论的来源与可复核数据。**不包含**任何分区 dump、厂商二进制或 ROM。

## 1. ABL 与 devinfo

- `abl_a` 分区（16 MB）结构：ELF32（LOAD vaddr 0x9fa00000，4 MB）→ 固件卷 →
  LZMA 压缩段（GUID `EE4E5898-3914-4259-9C42-16D3B6D0E7B5`）→ 内层 FV →
  LinuxLoader PE32+（933,888 字节，`.text` 约 0xb8000）。
- 字符串（在 PE 中的 RVA）：
  - `ANDROID-BOOT!` @ RVA `0xabe22`
  - `Device is unlocked, Skipping boot verification` @ RVA `0xb09cc`
  - `bbk unlock_vivo`、`vivo_bsp lock_vivo`、`get_unlock_ability`、`IsAllowUnlock is %d`
- 交叉引用：VA `0x358ec` 处 `adrp x1, 0xab000` + `add x1, #0xe22` → `CompareMem(..., 13)`；
  命中后进入 devinfo 解析路径（`0x35ba4` 起）。
- 结论：有效 magic 时只读标志位，未发现 CRC/签名校验；与公开的 9T 分析一致。

## 2. devinfo 布局（PD2266，OS4/5/6 相同）

| 偏移 | 值（未解锁） | 含义 |
|---|---|---|
| 0x00 | `ANDROID-BOOT!` | magic（13 字节） |
| 0x0d | 0x00 | unlocked |
| 0x0e | 0x00 | critical unlocked |
| 0x0f | 0x01 | 未变 |
| 0x90 | 0x01 | 未变 |

写入后：仅 `0x0d`、`0x0e` 变为 `0x01`，其余字节不变（本项目脚本会逐字节比对）。

## 3. GhostLock 在 vivo 5.15 上的 tagB 问题

- 现象：W2 的 verify 读（pipe 读子进程 uid）永久阻塞；目标任务 `State: R`、`wchan=0`、
  SIGKILL 无效；日志停在 `W2b: firing prebuilt init_cred+8 repair` 之后。
- 根因：tagB 清零的目标是 `task+0x2c`，按 8 字节对齐后清 `task+0x28`。
  vivo 5.15 的 `thread_info` 为 40 字节（不是 32），因此 `task+0x28` 落在
  `task_struct.__state`，被写 0 后 wakeup 匹配失败，任务成为不可杀僵尸。
- 修复：
  1) `session.profile.release()` 以 `"5.15"` 开头时跳过 tagB；
  2) 三处 verify 读取改为 `poll()` 3 秒超时。
- 上游：
  - Ghostlock-vr PR <https://github.com/DONGDERS/Ghostlock-vr/pull/3>
  - ghostlock-app PR <https://github.com/YuKongA/ghostlock-app/pull/993>
  - 同诊断的 upstream issue #957 已被关闭（维护者计划插件化后支持 vr.ko）。

## 4. 关键验证命令

```bash
# devinfo 前后对比（root）
adb shell su -c "dd if=/dev/block/by-name/devinfo bs=4096 count=1 2>/dev/null" > devinfo.bin
cmp -l devinfo.before devinfo.after     # 期望只差 0x0d、0x0e 两个字节

# 解锁状态
adb shell getprop ro.boot.flash.locked ro.boot.verifiedbootstate ro.boot.vbmeta.device_state

# KSU 常驻
adb shell 'grep -a kernelsu /proc/modules; su -c id'

# 制造商组件行为（只读观察，不建议公开抓包内容）
adb shell su -c "ls -l /data/user/0/com.vivo.devicereg/databases/"
```

## 5. 方法论备注

- 版本号/大小等易变值不写死在文档里，执行时从设备或包内读取。
- 所有「不支持」结论都应给出**本机缺失的节点/配置**作为证据，而不是引用传言：
  - Droidspaces：`/proc/config.gz` 中 `CONFIG_PID_NS`、`CONFIG_IPC_NS`、`CONFIG_USER_NS`、
    `CONFIG_SYSVIPC` 均为 not set。
  - FreePPS：二进制依赖 `/sys/class/xm_power/*`、`/sys/class/qcom-battery/pd_verifed`、
    `/sys/class/Charging_Adapter/*`，本机全部不存在。
