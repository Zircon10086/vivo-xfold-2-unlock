# 01 · 前置检查与备份

## 设备要求

- vivo X Fold 2（`ro.product.device` = `PD2266`，型号 V2266A），SM8550。
- 已验证构建：`PD2266_A_14.1.11.10.W10.V000L1`（OS4）、
  `PD2266_A_15.2.14.1.W10.V000L1`（OS5）、`PD2266_A_16.3.18.1.W10.V000L1`（OS6）。
- PC 工具：`adb`、`fastboot`（platform-tools）。
- 设备侧：能写 `/dev/block/by-name/devinfo` 的临时 root shell。

## 必须确认的四件事

1. **adbd 可用**：`adb devices` 能看到设备并已授权。
2. **电量 ≥ 60%**：写入与重启期间断电有变砖风险。
3. **Recovery 里有独立的「清除所有数据」**：解锁最后一步依赖它。
   本机菜单：安装系统软件 / 清除数据（含清除所有数据）/ 校验系统 / 安全模式 / 关机重启。
   只有「修复系统」而没有清数据入口的机型，请不要继续。
4. **临时 root 可用**：`adb shell su -c id` 能返回 `uid=0`。

## 只读体检

```bash
bash scripts/check_device.sh
```

输出：机型、构建号、当前槽位、`flash.locked`、`verifiedbootstate`、电量、
以及 `devinfo` 的前 16 字节与 `0x0d/0x0e` 当前值（需要 root）。

> 提示：`ro.boot.flash.locked` / `verifiedbootstate` 可能被 PlayIntegrityFix、
> Tricky Store 等模块伪造；真值以 `fastboot getvar unlocked` 为准。

## 必须备份

```bash
adb shell su -c "dd if=/dev/block/by-name/devinfo of=/data/local/tmp/devinfo.img bs=4096 count=1"
adb pull /data/local/tmp/devinfo.img
adb shell getprop > props-before.txt
```

`devinfo.img` 是解锁前唯一可回滚的原始状态，务必保存到 PC 并确认大小 4096 字节。

## 记录基线

| 项目 | 值 |
|---|---|
| 构建号 | `ro.build.display.id` |
| 槽位 | `ro.boot.slot_suffix` |
| devinfo 0x0d/0x0e | 00 00（未解锁） |
| recovery 清数据入口 | 有 / 无（无则停止） |

## 常见前置失败

- `adb devices` 为空：检查 USB 调试、驱动、数据线。
- `su` 不存在：没有 root，先解决临时提权。
- `fastboot devices` 为空：进 bootloader 后需要安装驱动。
- Recovery 没有清数据项：停止，不要继续解锁。
