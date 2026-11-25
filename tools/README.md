# 外部工具清单

本项目不打包第三方二进制，请从各自的官方发布页获取。

| 工具 | 用途 | 获取方式 |
|---|---|---|
| platform-tools（adb/fastboot） | 设备通信 | <https://developer.android.com/tools/releases/platform-tools> |
| payload-dumper-go | 从官方全量包中解出分区镜像 | <https://github.com/ssut/payload-dumper-go> |
| 7-Zip | 提取 `payload.bin` | <https://www.7-zip.org/> |
| KernelSU / ReSukiSU | Root（`ksud boot-patch`、模块安装） | 各自 GitHub Releases |
| Vector | Xposed 框架（Android 16 可用） | <https://github.com/JingMatrix/Vector> |
| NeoZygisk | Zygisk 注入 | <https://github.com/JingMatrix/NeoZygisk> |
| mountify | metamodule（overlayfs 挂载） | <https://github.com/backslashxx/mountify> |
| GhostLock | 解锁前的临时提权（可选） | 上游仓库（见 README 致谢） |

## 版本提示

- `ksud` 一般从管理器 APK 的 `lib/arm64-v8a/libksud.so` 提取，命令名仍是 `ksud`。
- KernelSU 4.x / ReSukiSU：安装/更换 metamodule 后必须重启，之后才能继续安装普通模块。
- Vector 需要 Zygisk（本项目用 NeoZygisk）配合。

## 不要提交到仓库

第三方 APK、ZIP、二进制都应通过链接获取，避免许可证与供应链问题。
