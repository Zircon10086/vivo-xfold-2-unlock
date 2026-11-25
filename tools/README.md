# 外部工具

本项目不打包第三方二进制。

| 工具 | 用途 | 获取方式 |
|---|---|---|
| platform-tools（adb/fastboot） | 设备通信与 bootloader 验证 | <https://developer.android.com/tools/releases/platform-tools> |
| GhostLock（可选） | 解锁前获取临时 root（本项目未附带源码） | 上游仓库（见 README 致谢） |

## 说明

- 解锁只需要一个能写 `devinfo` 的 root shell；任何稳定的临时提权方式都可以替代 GhostLock。
- 本项目不提供、也不要求任何 ROM、分区镜像或签名工具。
- 下载第三方工具后请自行核对发布页提供的哈希。
