# 04 · 持久 Root（KernelSU / ReSukiSU）

> 解锁完成后，Root 不再需要内核漏洞：把 KSU 的 LKM 补丁打进原厂 `init_boot.img` 刷入即可。
> 本机验证：KernelSU v3.3.1 与 ReSukiSU v4.2.0-rc3 都能在 OS5/OS6 上常驻。

## 前提

- 已解锁（`ro.boot.flash.locked=0`）。
- 有对应系统版本的**原厂** `init_boot.img`（从全量包 payload 解出，见 03）。
- 有该 KSU 发行版的 `ksud`（通常在管理器 APK 的 `lib/arm64-v8a/libksud.so`，
  也可用 Release 里的独立二进制）。

## 步骤

1. 推送原厂 init_boot 与 ksud：

```bash
adb push init_boot.img /sdcard/Download/init_boot.img
adb push ksud /data/local/tmp/ksud
adb shell chmod 755 /data/local/tmp/ksud
```

2. 打补丁（KMI 为 `android13-5.15`；本机 5.15.x 全系适用）：

```bash
adb shell /data/local/tmp/ksud boot-patch \
  -b /sdcard/Download/init_boot.img \
  --kmi android13-5.15 --partition init_boot \
  --out-name ksu_patched.img -o /sdcard/Download --allow-shell
```

`--allow-shell` 让 `adb shell` 可以直接 `su`，方便自检；正式使用可去掉。

3. 刷入当前槽位（示例 b）：

```bash
adb pull /sdcard/Download/ksu_patched.img
adb reboot bootloader
fastboot flash init_boot_b ksu_patched.img
fastboot reboot
```

4. 安装管理器，然后初始化用户态：

```bash
adb install -r <KernelSU|ReSukiSU>.apk
adb shell su -c "/data/adb/ksud install"
adb shell su -c id      # uid=0 … context=u:r:ksu:s0
```

> 若提示 `/data/adb/ is not a regular directory`，先打开一次管理器再执行；
> 该命令的作用是安装 `/system/bin/su` 等用户态组件。

## 验证常驻

重启后：

```bash
adb shell 'grep -a kernelsu /proc/modules; su -c id'
# kernelsu ... Live
# uid=0(root) ... context=u:r:ksu:s0
```

## 模块系统（KSU 4.x / ReSukiSU）

- `/data/adb/modules` 在 SELinux 下**不能**用普通 root shell 直接写；
  必须用 `ksud module install <zip>` 安装（它会正确打 label）。
- 安装/更换 **metamodule**（如 mountify）后，KSU 需要**重启一次**；
  在 “Pending changes” 期间所有模块安装都会被拒绝（报
  “A metamodule with custom installer is active / Reboot to apply changes first”）。
- 普通模块安装后需要重启才生效；脚本类模块（`service.sh`）在开机后执行。

## Xposed

- 本机 OS6 上使用的是 [Vector](https://github.com/JingMatrix/Vector)（LSPosed 后继，
  libxposed API 102），配合 NeoZygisk 注入。
- 旧版 LSPosed 授权包会遇到类似
  `Server rejected: package version 7704 is less than minimum required 7901` 的报错，
  属于包自身授权过期，与 KSU 安装器无关。

## 回退

- 刷回原厂 `init_boot.img`（同槽位）即可彻底移除 root。
- 或 `ksud module disable` / 卸载管理器后重刷原厂 init_boot。
