# 03 · 排错手册

按现象索引，只覆盖解锁流程。

## 1. `fastboot devices` 为空

- 现象：进 bootloader 后 PC 看不到设备。
- 处理：Windows 装好驱动（设备管理器里带感叹号的那项）；换线/换口；
  确认屏幕上是 FASTBOOT 界面而不是关机充电。

## 2. 没有 root，读/写 devinfo 失败

- `check_device.sh` 的 devinfo 段显示「无法读取」即没有 root。
- 解锁只需要一次能写分区的 root shell；临时提权方案见 README 的「关于临时 root」。
- 若使用 GhostLock 卡在 W2（`W2b` 之后没有下文、子进程 `State: R`），
  是 vivo 5.15 的 tagB 地雷，补丁见 `patches/` 与 [05-research-notes.md](05-research-notes.md)。

## 3. `unlock_devinfo.sh` 报 magic 不符

- 说明读到的 13 字节不是 `ANDROID-BOOT!`：可能读错了分区（不是 `by-name/devinfo`）
  或该机型布局不同。**不要写入**，先确认机型与分区。

## 4. 写入后回读不是 01 01

- 检查是否写到了 `by-name/devinfo`（脚本用的是这个路径）。
- 某些情况下 dd 被 SELinux 拦：确认 `su` 可用，必要时先 `setenforce 0` 再写、
  写完后恢复 `setenforce 1`。

## 5. 重启后没有出现 "device is corrupt"

- 可能 ABL 没有读新的 devinfo（确认已重启而不是热重启）。
- 可能写入没有真正落盘：回读 `0x0d/0x0e` 确认；`sync` 后再重启。
- 若直接正常开机且仍是 locked：说明该版本 ABL 行为不同，停止操作，先记录证据再研究。

## 6. 停在 corrupt 屏，但 recovery 里没有清数据选项

- **不要**选择「修复系统 / 安装系统软件 / 校验系统」，它们可能重刷并重置解锁标志。
- 若确认没有清数据入口，尝试长按电源重启、或进 bootloader 切槽；
  仍无法恢复时只能走售后（9008 需要厂商签名工具）。

## 7. 清除数据后卡开机动画 / 反复重启

- 清数据后首次开机需要几分钟（格式化 userdata），耐心等待。
- 超过 10 分钟仍无进展：进 recovery 再清一次；或进 bootloader 检查是否停在 fastboot。
- 保留了解锁前的系统镜像时，可回刷 `boot/init_boot/vbmeta` 恢复引导。

## 8. 解锁后 `getprop` 却显示 locked / green

- 先排除**属性伪造**：PlayIntegrityFix、Tricky Store 等模块会用 resetprop
  把 `ro.boot.flash.locked`、`ro.boot.verifiedbootstate` 改成「已锁」以过完整性检测。
- 以 bootloader 为准：

```bash
adb reboot bootloader
fastboot getvar unlocked     # unlocked: yes 才是真的解锁
```

- 同时回读 `devinfo` 的 `0x0d/0x0e` 是否为 `01 01`。

## 9. 验证清单

```bash
fastboot getvar unlocked                        # yes
adb shell getprop ro.boot.verifiedbootstate     # orange（无伪造模块时）
adb shell su -c "dd if=/dev/block/by-name/devinfo bs=4096 count=1 2>/dev/null | od -An -tx1 -j13 -N2"
# 期望：01 01
```
