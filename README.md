# vivo-xfold-2-unlock

Bootloader unlock, manual OTA flashing, persistent root and debloat for the
**vivo X Fold 2 (PD2266 / V2266A, SM8550 "kalama")**.

> 单机型优先项目：所有步骤在 PD2266 的 OriginOS 4 / 5 / 6 上实测通过。
> 其他 vivo 机型仅作参考，devinfo 偏移与 ABL 行为需自行核对。

## ⚠️ 风险声明（先读这一段）

- 解锁会**清空全部用户数据**，并让设备进入 orange 状态；Play Integrity 等会失败。
- 解锁 Bootloader **失去官方保修**，操作不当可能变砖；本项目按现状提供，不承担任何后果。
- 文中涉及分区写入、`fastboot -w`、devinfo 修改等不可逆操作，请先读完对应文档再执行。
- 仅在**你自己拥有**的设备上使用；不同地区对运营商组件的处置规定不同，由使用者自行判断。

## 状态矩阵（实测）

| 项目 | OriginOS 4 (`14.1.11.10.W10`) | OriginOS 5 (`15.2.14.1.W10`) | OriginOS 6 (`16.3.18.1.W10`) |
|---|---|---|---|
| devinfo 解锁 | ✅ | ✅（解锁后升级） | ✅（解锁状态保留） |
| payload 手动刷写 | ✅ | ✅ | ✅ |
| KernelSU / ReSukiSU | ✅（LKM） | ✅ | ✅ |
| 去臃肿模块 | — | — | ✅（31 项） |

## 快速开始

```bash
# 0) 只读体检：机型、版本、槽位、解锁状态、电量
bash scripts/check_device.sh

# 1) 解锁（需要临时 root；先读 docs/02-unlock.md）
bash scripts/unlock_devinfo.sh --dry-run     # 看它将写什么
bash scripts/unlock_devinfo.sh --yes         # 真正写入

# 2) 手动升级（先解包 payload，读 docs/03-manual-ota.md）
bash scripts/flash_ota_stage1.sh --images /path/to/images --slot b --dry-run
bash scripts/flash_ota_stage2.sh --images /path/to/images --slot b --wipe --dry-run

# 3) Root（读 docs/04-root.md）
bash scripts/ksu_install.sh --init-boot /path/to/init_boot.img --slot b

# 4) 去臃肿（读 docs/05-debloat.md）
bash scripts/debloat_module.sh --packages packages.example.tsv --dry-run
```

## 原理速览

1. **解锁**：vivo ABL 读取 `devinfo` 分区时只校验 magic `ANDROID-BOOT!`；
   把 `0x0d`（unlocked）与 `0x0e`（critical unlocked）置 1，重启后进入
   "device is corrupt"，在 recovery 执行「清除所有数据」即完成解锁。
   详见 [docs/02-unlock.md](docs/02-unlock.md)。
2. **升级**：官方全量包是 `payload.bin` 的 A/B 包。解包后，固件与 boot 链在 bootloader
   阶段刷入，逻辑分区在 fastbootd 阶段刷入（自动扩容 super），最后清 userdata。
   详见 [docs/03-manual-ota.md](docs/03-manual-ota.md)。
3. **Root**：用 KernelSU（或 ReSukiSU）的 `ksud boot-patch` 给原厂 `init_boot.img`
   打补丁并刷入，重启后 `su` 常驻。详见 [docs/04-root.md](docs/04-root.md)。
4. **去臃肿**：运营商 DM（`com.vivo.devicereg`、`com.mobiletools.systemhelper`）与
   遥测/商业预装用 `pm disable-user` 处理，并固化成 KSU 模块开机重放。
   详见 [docs/05-debloat.md](docs/05-debloat.md)。

## 仓库结构

```
docs/      01 前置检查 · 02 解锁 · 03 手动 OTA · 04 Root · 05 去臃肿 · 06 排错 · 99 研究笔记
scripts/   check_device / unlock_devinfo / flash_ota_stage1|stage2 / ksu_install / debloat_module
patches/   提交给上游 Ghostlock 的修复补丁（tagB 门控、verify 超时）
evidence/  偏移、哈希、反汇编要点（不含任何分区 dump）
tools/     外部工具清单（不打包二进制）
```

## 致谢

- [DemonKingSwarn/vivo-iqoo-9t-bootloader-unlock](https://github.com/DemonKingSwarn/vivo-iqoo-9t-bootloader-unlock)：devinfo 路线的公开参考。
- GhostLock / Ghostlock-vr：内核提权与 tagB 根因定位。
- [Eynnzerr/TelemetryCleaner](https://github.com/Eynnzerr/TelemetryCleaner)、[Greatday2233/regblock](https://github.com/Greatday2233/regblock)：运营商组件行为分析的公开证据。
- KernelSU / ReSukiSU / Vector、payload-dumper-go 等工具的作者。

## 许可证

[GNU Affero General Public License v3.0](LICENSE)。派生作品（包括通过网络提供服务的修改版）必须以同一许可证开源。
