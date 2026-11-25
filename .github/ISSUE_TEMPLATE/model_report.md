---
name: Model report (vivo 机型实测)
about: 提交其他 vivo 机型的 devinfo/ABL 实测数据（不要提交任何镜像）
labels: model-report
---

## 机型

- 市场名：
- 型号代码（`ro.product.device`）：
- SoC：
- 原厂构建号：
- 内核版本（`uname -r`）：

## devinfo

- 分区大小：
- 前 16 字节（hex，可公开）：
- 0x0d / 0x0e 原始值：
- 写入后是否解锁成功：
- recovery 是否有「清除所有数据」：

## ABL

- 是否找到 `ANDROID-BOOT!` 的 CompareMem 调用点（地址/方式）：
- 是否有 `Device is unlocked, Skipping boot verification` 字符串：
- 其它线索：

## 其它

- 升级路径（例如 OS4 → OS5 → OS6）：
- Root 方案（KernelSU / ReSukiSU / 其他）：
- 遇到的问题：

> 提醒：请勿提交 `devinfo.img`、`abl_a.img`、ROM 包或带签名参数的下载链接。
