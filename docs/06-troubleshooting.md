# 06 · 排错手册

按现象索引。命令以 Linux/macOS 为例；Windows 把 `adb`/`fastboot` 换成 exe 即可。

## 1. `fastboot devices` 为空

- 确认已进 bootloader（`adb reboot bootloader`）；屏幕上应有 FASTBOOT 字样。
- Windows 需要装驱动（设备管理器里会出现带感叹号的 Android 设备）。
- 换线/换口；USB 3.0 口对某些机型不稳定。

## 2. `fastboot reboot fastboot` 后设备不出现

- 现象：`fastboot devices` 空、`is-userspace` 无法读取。
- 原因：fastbootd 由 recovery/vendor_boot 提供，这两个分区没刷好或与固件不匹配。
- 处理：重新刷 `recovery_b` / `vendor_boot_b`；确认镜像来自当前系统版本的全量包。

## 3. 刷写报 “not enough space” / 分区大小不足

- 逻辑分区（system/vendor/…）：fastbootd 会在刷写时自动扩容 super；
  若报空间不足，说明 super 总容量不够 —— 检查镜像是否属于该机型/该版本。
- 物理分区（boot/tz/abl/…）：镜像必须 ≤ 分区大小；本项目脚本刷前会打印大小，
  超限时 fastboot 会直接失败（不会写坏）。

## 4. `fastboot -w` 报 `metadata: Partition doesn't exist`

- 无害：userdata 已被 erase，首次开机会格式化。
- 若需要彻底清理：进 recovery 选「清除所有数据」。

## 5. 刷完卡开机动画 / bootloop

- 先切槽回退：`fastboot set_active a`（前提是 a 槽还保留旧系统）。
- 再检查是否漏刷固件分区（阶段 1）；跨大版本未清 data 也会卡开机。
- 仍失败：重刷阶段 1 + 阶段 2，并 `fastboot -w`。

## 6. 解锁后仍显示 locked / 写入没生效

- **先排除属性伪造**：装了 PlayIntegrityFix、Tricky Store 等模块后，
  `ro.boot.flash.locked=1`、`ro.boot.verifiedbootstate=green` 可能是被 resetprop 改过的假值。
  以 bootloader 为准：`adb reboot bootloader && fastboot getvar unlocked`。
- 回读 `devinfo` 的 `0x0d/0x0e` 是否真为 1；确认写到了 `by-name/devinfo` 而不是别的分区。
- 重启后必须完成一次「清除所有数据」，否则状态不会切换。
- 部分系统版本可能在 recovery 里提供「校验系统」并重置标志，不要执行它。

## 7. `su` 不存在 / `inaccessible or not found`

- KSU 内核模块已加载但用户态未初始化：安装管理器并启动一次，再执行
  `su -c "/data/adb/ksud install"`。
- 检查 `/system/bin/su` 是否存在；不存在时重跑上述命令。

## 8. 模块安装被拒：`Metamodule installation blocked`

- 原文：`A metamodule with custom installer is active / Current state: Pending changes /
  Reboot to apply changes first`。
- 原因：刚安装/更换 metamodule（如 mountify），需要重启一次让状态落定。
- 处理：重启后重试安装。

## 9. 直接往 `/data/adb/modules` 拷贝文件：Permission denied

- 即使 root 也会被 SELinux 拦。
- 正确做法：把模块打成 zip，用 `ksud module install <zip>`。

## 10. `adb install` 报 `INSTALL_FAILED_ABORTED: User rejected permissions`

- 设备锁屏或安装确认弹窗没人点。解锁屏幕，点「继续安装」。
- 有 root 时可绕过弹窗：`adb shell su -c "pm install -r -d /data/local/tmp/app.apk"`。

## 11. 系统更新器里抓不到下载地址

- 不要去 logcat/tcpdump 里找：下载器不打日志，流量是 HTTPS。
- 读更新器私有数据（需 root 或 permissive）：
  `/data/user_de/0/com.bbk.updater/shared_prefs/updater.xml` 与
  `databases/downloads.db`，里面有明文下载地址。

## 12. 内核提权（GhostLock）卡在 W2

- 5.15 vivo 上典型表现：`W2b` 之后没有下文、子进程 `State: R`、`SIGKILL` 无效。
- 根因：tagB 清零写到了 `task+0x2c`（对齐后 `task+0x28`），而 5.15 的
  `thread_info` 只有 40 字节，`task+0x28` 是 `task_struct.__state`，被清零后
  目标任务变成 state==0 的僵尸。
- 修复：5.15 跳过 tagB；verify 读加 poll 超时。补丁见 `patches/`。
