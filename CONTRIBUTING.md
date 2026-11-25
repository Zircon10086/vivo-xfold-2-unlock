# 贡献指南

## 可以贡献什么

1. **其他 vivo 机型的实测记录**：机型、构建号、devinfo 布局（偏移与原始值）、
   ABL 中 `ANDROID-BOOT!` 的比较点、解锁是否成功、recovery 是否有清数据入口。
2. **脚本改进**：更强的机型门禁、错误恢复、跨平台（Windows Git Bash / WSL）。
3. **文档纠错**：命令、路径、不同版本的行为差异。

## 不要提交

- 任何分区镜像（`devinfo.img`、`abl*.img` 等）；
- ROM 包、`payload.bin`；
- 带签名参数的官方下载链接；
- 设备序列号、IMEI、MAC、账号信息、完整日志；
- 第三方 APK/二进制或反编译全文（引用偏移与字符串即可）。

## 提交前检查

```bash
for f in scripts/*.sh; do bash -n "$f" || echo "FAIL $f"; done
grep -rInE '([0-9]{15})|sign=|([0-9A-Fa-f]{32,})' --exclude-dir=.git . | head
```

## PR 要求

- 说明测试机型、构建号、执行到哪一步、结果如何。
- 破坏性操作必须默认 dry-run，且提供回退路径。
- 新增机型支持时，在 README 支持范围表中加一行（未验证写「—」）。
