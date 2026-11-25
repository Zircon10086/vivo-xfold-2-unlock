# 01 · 前置检查与备份

## 设备要求

- vivo X Fold 2（`ro.product.device` = `PD2266`，型号 V2266A），SM8550。
- 已验证系统：`PD2266_A_14.1.11.10.W10.V000L1`（OS4）、`PD2266_A_15.2.14.1.W10.V000L1`（OS5）、
  `PD2266_A_16.3.18.1.W10.V000L1`（OS6）。
- PC 侧工具：`adb`、`fastboot`（platform-tools）、`7z`、`payload-dumper-go`、
  可选 `ksud`（来自 KernelSU / ReSukiSU 的管理器 APK）。

## 必须确认的四件事

1. **adbd 可用**：`adb devices` 能看到设备，且已授权。
2. **电量 ≥ 60%**：解锁与刷机中途断电有变砖风险。
3. **Recovery 里有独立的「清除所有数据」**：解锁流程最后一步依赖它；
   只有「修复系统 / 安装系统软件」而没有清数据选项的机型，请不要走 devinfo 路线。
   （本机 OS4 recovery 菜单：安装系统软件 / 清除数据（含清除所有数据）/ 校验系统 / 安全模式 / 关机重启）
4. **有临时 root**：解锁需要写 `devinfo` 分区。本机通过 GhostLock（CVE-2026-43499）获得；
   没有 root 时无法执行解锁步骤。

## 只读体检

```bash
bash scripts/check_device.sh
```

它会打印：机型、构建号、当前槽位、`flash.locked`、`verifiedbootstate`、
电量、devinfo 当前字节（需要 root）、以及 `fastboot` 是否在线。

## 备份清单（强烈建议）

| 项目 | 命令/位置 | 说明 |
|---|---|---|
| devinfo 原始镜像 | `su -c "dd if=/dev/block/by-name/devinfo of=/data/local/tmp/devinfo.img bs=4096 count=1"` 后 pull 到 PC | 解锁前唯一原始状态 |
| 当前槽位 boot/init_boot/vendor_boot/dtbo/vbmeta | 同上，按分区 dd | 回滚用 |
| OS 全量包与解包镜像 | 见 `docs/03-manual-ota.md` | 跨版本回退 |
| 本机属性快照 | `getprop > props.txt` | 记录基线 |

> 本项目**不包含**任何分区 dump、ROM 包或带签名的下载链接；这些需要你自己从设备/官方渠道获取。

## 常见前置失败

- `adb devices` 为空：检查 USB 调试、驱动、数据线。
- `su` 不存在：说明还没有 root，先解决提权。
- `fastboot devices` 为空：进 bootloader 后 Windows 需要装驱动。
- Recovery 没有清数据项：停止，不要继续解锁。
