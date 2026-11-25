# 02 · Bootloader 解锁（devinfo 路线）

> 适用：vivo X Fold 2（PD2266）。原理同样适用于 iQOO 9T 等同代 vivo 机型，
> 但偏移需自行核对，**不要直接照抄到其他机型**。

## 原理

vivo 的 ABL（Android Bootloader）在启动时读取 `devinfo` 分区：

- 只校验前 13 字节 magic `ANDROID-BOOT!`（反汇编里是一个 `CompareMem(..., 13)` 调用）。
- magic 有效时，直接把 `0x0d` 当作 **unlocked** 标志、`0x0e` 当作 **critical unlocked** 标志。
- 该路径未见 CRT/签名校验（与公开的 9T 分析一致）。

因此：把 `0x0d`、`0x0e` 写为 `0x01`，重启后 ABL 认为设备已解锁，
但因 userdata 与新的验证状态不匹配，会进入「device is corrupt」界面；
在 recovery 里执行一次「清除所有数据」，即可正常开机并保持 orange 解锁状态。

原始值（本机 OS4/OS5/OS6 均相同）：

```
offset 0x00: "ANDROID-BOOT!"   (13 bytes)
offset 0x0d: 0x00   unlocked flag
offset 0x0e: 0x00   critical unlocked flag
offset 0x0f: 0x01
offset 0x90: 0x01
```

## 操作步骤

0. 完成 [01-prereq.md](01-prereq.md)，并备份 `devinfo`。
1. 取得临时 root（本机用 GhostLock；不同系统版本需自行确认提权方案）。
2. 确认当前状态：

```bash
adb shell su -c "dd if=/dev/block/by-name/devinfo bs=4096 count=1 2>/dev/null | od -An -tx1 -j13 -N2"
# 期望输出：00 00
```

3. 写入（脚本默认 dry-run，`--yes` 才执行）：

```bash
bash scripts/unlock_devinfo.sh --dry-run
bash scripts/unlock_devinfo.sh --yes
```

脚本会：备份到本地 → 校验 magic 与当前值 → 只写 `0x0d`/`0x0e` → 回读校验
（除这两个字节外不得有其他变化）。

4. 重启：

```bash
adb reboot
```

5. 屏幕会提示设备损坏/校验失败；进入 recovery，选 **清除数据 → 清除所有数据**
   （不要选「修复系统 / 安装系统软件 / 校验系统」）。完成后设备自动重启。

## 验证

```bash
adb shell getprop ro.boot.flash.locked        # 0
adb shell getprop ro.boot.verifiedbootstate   # orange
adb shell getprop ro.boot.vbmeta.device_state # unlocked
adb reboot bootloader
fastboot getvar unlocked                       # unlocked: yes
```

## 回滚

- 解锁后 `devinfo` 内容已被改写；只要还能进系统/root，就可以把备份写回：
  `su -c "dd if=/sdcard/devinfo.img of=/dev/block/by-name/devinfo bs=4096 count=1"`
  然后重启。写回后需要再次清数据才能使用。
- 若设备停在 corrupt 屏且 recovery 无法清数据：尝试重启到 bootloader、
  切槽（`fastboot set_active a`）或联系售后；9008 需要 vivo 签名 firehose，常规手段不可用。

## 已知风险

- 解锁会清空全部数据。
- 部分系统界面的完整性校验（Play Integrity、银行类 App）会失败。
- 不要使用官方更新器里的「修复系统」入口，它可能重刷并重置解锁状态。
