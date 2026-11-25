# 证据目录说明

本目录只放**可公开复核的小体积证据**，不放任何分区 dump、厂商二进制或 ROM。

建议存放：

| 文件 | 内容 |
|---|---|
| `devinfo-layout.md` | devinfo 偏移表与写入前后逐字节对比（脱敏） |
| `abl-strings.txt` | 关键字符串与 RVA（从自己的 ABL 提取后摘录） |
| `kernel-config-snippet.txt` | 与 namespace/容器结论相关的 `/proc/config.gz` 片段 |
| `props-baseline.txt` | 脱敏后的 `getprop` 关键属性（去除序列号、IMEI、MAC） |

不要提交：

- `devinfo.img`、`abl_a.img`、任何 `*.img` 分区镜像；
- 完整 `payload.bin` 或 ROM 包；
- 带签名参数的下载链接；
- 含设备序列号、IMEI、Wi-Fi MAC、账号信息的日志。

提交前自查：

```bash
grep -rInE '([0-9A-Fa-f]{8,})|([0-9]{15})|sign=' evidence/ || true
```
