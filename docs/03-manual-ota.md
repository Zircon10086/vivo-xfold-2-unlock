# 03 · 手动 OTA：payload 解包与分阶段刷写

> 目标：不经过系统更新器的「修复系统」入口，自己把官方全量包刷进设备。
> 适用于 OS4 ↔ OS5 ↔ OS6 的跨版本升级/降级（需自行准备对应版本的全量包）。

## 1. 获取全量包

官方更新器把下载信息明文写在应用私有数据里（需要 root 或 permissive）：

```
/data/user_de/0/com.bbk.updater/shared_prefs/updater.xml
/data/user_de/0/com.bbk.updater/databases/downloads.db
```

其中包含 `*.zip` 的下载地址与文件大小。打开系统更新、开始下载后立即暂停，
再读取上述文件即可拿到地址（地址带签名参数，有时效，**不要公开分享**）。

> 本项目不提供任何下载链接，也不分发 ROM。

## 2. 解包 payload

```bash
7z e <update.zip> payload.bin payload_properties.txt -o<outdir>
payload-dumper-go -o <outdir>/images <outdir>/payload.bin
```

校验：

- zip 的 MD5/SHA256 应与服务端/更新器记录一致；
- `payload.bin` 的 SHA256 应与 `payload_properties.txt` 中的 `FILE_HASH`（base64 解码后）一致。

## 3. 分阶段刷写

### 阶段 1：固件 + boot 链（bootloader fastboot）

镜像按 `_a/_b` 分区存在，刷**非活动槽**以外的当前活动槽；本项目默认刷 `b` 槽，
保留 `a` 槽旧系统作为退路。

```bash
bash scripts/flash_ota_stage1.sh --images rom/images --slot b --dry-run
bash scripts/flash_ota_stage1.sh --images rom/images --slot b
```

覆盖分区：`xbl xbl_config xbl_ramdump abl aop aop_config tz hyp devcfg keymaster
qupfw uefi uefisecapp shrm cpucp featenabler imagefv multiimgoem multiimgqti
storage bluetooth modem dsp vm-bootsys boot init_boot vendor_boot dtbo recovery
vbmeta vbmeta_system`（按镜像是否存在自动跳过）。

### 阶段 2：逻辑分区（fastbootd）

```bash
fastboot reboot fastboot
bash scripts/flash_ota_stage2.sh --images rom/images --slot b --dry-run
bash scripts/flash_ota_stage2.sh --images rom/images --slot b
```

覆盖：`system vendor product odm system_ext system_dlkm vendor_dlkm`。
fastbootd 会在刷写时自动扩容 super 内的逻辑分区（本机 super 15 GB，OS6 合计约 10.4 GB）。

### 阶段 3：清数据与切槽

跨大版本必须清 userdata：

```bash
fastboot -w            # 会 erase userdata（metadata 不存在时报警属正常）
fastboot set_active b
fastboot reboot
```

首次开机会格式化 userdata，耗时数分钟。

## 4. 回退

- 槽 a 若仍保留旧系统：`fastboot set_active a` + 重启。
- 若两个槽都被刷成新版本：用旧版本的 `boot/init_boot/vbmeta` 至少可以恢复引导，
  但系统分区需整包回刷。
- 保留每个版本解包出的 `boot.img`、`init_boot.img`、`vbmeta.img`，这是最低成本的救命镜像。

## 5. 注意事项

- 刷写期间不要断电、不要拔线；阶段 1 中断有变砖风险。
- 镜像大小必须 ≤ 分区大小；fastboot 会直接报错，不会写坏。
- vbmeta 请刷官方镜像；解锁状态下验证被跳过，但不要在未解锁设备上这样做。
- 解锁与 OTA 互不影响：OTA 不会重置 `devinfo`。
