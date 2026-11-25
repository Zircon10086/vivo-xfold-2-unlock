# vivo-xfold-2-unlock

Bootloader unlock for the **vivo X Fold 2 (PD2266 / V2266A, SM8550 "kalama")**.

> 本仓库只覆盖**解锁**：从「已锁定、无官方解锁入口」到
> 「devinfo 写入 → 重启进 corrupt 屏 → recovery 手动清除所有数据 → BL 解锁」。

## ⚠️ 风险声明

- 整个流程会**清空全部用户数据**（解锁的最后一步就是手动恢复出厂设置）。
- 解锁 Bootloader **失去官方保修**；操作不当可能变砖，本项目按现状提供，不承担任何后果。
- 涉及分区写入（`devinfo`）与不可逆的清数据操作，请先读完文档再执行。
- 仅在**你自己拥有**的设备上使用。

## 支持范围（实测）

| 系统 | 构建号 | 解锁结果 |
|---|---|---|
| OriginOS 4 | `PD2266_A_14.1.11.10.W10.V000L1` | ✅ |
| OriginOS 5 | `PD2266_A_15.2.14.1.W10.V000L1` | ✅ |
| OriginOS 6 | `PD2266_A_16.3.18.1.W10.V000L1` | ✅ |

原理上可能适用于同代 vivo 机型，但本项目**只在 PD2266 的三个构建上验证过**；
devinfo 偏移与 ABL 行为必须自行核对，**不可照抄**。

---

## 前置条件

1. 拿到**临时 root** —— 解锁的全部前提。本项目用 GhostLock（CVE-2026-43499）实现，
   构建、打补丁与踩坑说明见 **[docs/02-temp-root.md](docs/02-temp-root.md)**。
2. Recovery 里有**独立的「清除所有数据」**（不是只有「修复系统」）。
   菜单参考：安装系统软件 / 清除数据（含清除所有数据）/ 校验系统 / 安全模式 / 关机 / 重启。
3. 电量 ≥ 60%，已备份 `devinfo` 原始镜像（`scripts/check_device.sh` 会提示）。

## 快速开始

```bash
# 0) 只读体检：机型、构建号、槽位、解锁属性、电量、devinfo 当前字节
bash scripts/check_device.sh

# 1) 预览将要写入的内容（默认 dry-run）
bash scripts/unlock_devinfo.sh

# 2) 真正写入 devinfo 的 0x0d / 0x0e
bash scripts/unlock_devinfo.sh --yes

# 3) 重启后进入 corrupt 屏 → recovery「清除数据 → 清除所有数据」
adb reboot
```

## 原理速览

vivo 的 ABL 读取 `devinfo` 时只校验前 13 字节 magic `ANDROID-BOOT!`；
magic 有效时直接把 `0x0d` 当作 unlocked、`0x0e` 当作 critical unlocked。
把这两个字节置 1 后重启，ABL 认为已解锁，但 userdata 与新的验证状态不匹配，
于是进入 "device is corrupt" 并反复重启，最终进入 recovery 并提示数据损坏；
随后在 recovery 执行一次「清除所有数据」即可正常开机，并以 orange 状态保持解锁。

> 官方解锁通常由系统自动触发清数据；我们改的是 devinfo 标志位，不会触发自动擦除，
> 所以需要**手动**完成一次恢复出厂设置，状态才会正式切换。

证据与偏移见 [docs/03-unlock.md](docs/03-unlock.md) 与
[docs/05-research-notes.md](docs/05-research-notes.md)。

## 仓库结构

```
docs/01-prereq.md          前置检查与备份
docs/02-temp-root.md       临时 root：GhostLock 构建、补丁、踩坑与重试
docs/03-unlock.md          解锁步骤、验证与回滚
docs/04-troubleshooting.md 常见故障
docs/05-research-notes.md  ABL 反汇编要点与 devinfo 布局
scripts/check_device.sh    只读体检
scripts/unlock_devinfo.sh  写入 devinfo（默认 dry-run）
patches/tagb-gate.patch    临时 root：vivo 5.15 跳过 tagB
patches/verify-timeout.patch 临时 root：verify 读超时
```

## 关于临时 root

解锁需要往 `devinfo` 写两个字节，没有 root 就没有写权限——这是**实际会挡路的一步**，
不是可选项。本项目使用 GhostLock（CVE-2026-43499），它在 vivo 5.15 上有一个必须修的
「tagB 清零把任务打成僵尸」的问题（`patches/` 里两个补丁）。完整的构建、打补丁、
运行、重试与排错见 **[docs/02-temp-root.md](docs/02-temp-root.md)**。

本项目**不发布 APK 或任何预编译二进制**，只提供补丁；你也可以用任何能稳定拿到
root shell 的方案替代 GhostLock。

## 致谢

- [DemonKingSwarn/vivo-iqoo-9t-bootloader-unlock](https://github.com/DemonKingSwarn/vivo-iqoo-9t-bootloader-unlock)：devinfo 路线的公开参考。
- GhostLock / Ghostlock-vr：临时提权与 tagB 根因定位。

## 许可证

[GNU Affero General Public License v3.0](LICENSE)。
