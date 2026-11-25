# 05 · 去臃肿与运营商遥测组件

> 目标：禁用国行 vivo 的运营商 DM 组件、遥测/分析服务与商业预装，并固化成可重复执行的模块。
> 所有操作**可逆**（`pm enable` 即恢复）。

## 背景事实（有公开证据的）

| 包 | 作用 | 证据 |
|---|---|---|
| `com.vivo.devicereg` | 移动（彩讯 `cn.richinfo.dm` SDK）+ 电信自注册；采集应用清单、使用时长、分应用流量、基站/Wi-Fi、SIM 等；上报 `a.fxltsbl.com`；本地库 `cmcc_dm.db` 有 `table_app_collect_list` | [RegBlocker](https://github.com/Greatday2233/regblock) 的 hook 清单与实测；[TelemetryCleaner](https://github.com/Eynnzerr/TelemetryCleaner) 列出该包并注明 vivo 保护名单、非 Root 不可卸载 |
| `com.mobiletools.systemhelper` | 联通 SystemHelper；读取定位、设备/SIM 标识、已安装应用、分应用流量并上传 | TelemetryCleaner 的实测报告 |
| `com.vivo.aiservice` / `com.vivo.aiengine` | AI 服务/引擎（社区称含本地内容审核词库与埋点） | 仅二手拆包来源，**未独立复核** |
| `com.vivo.abe` | AppBehaviorEngine 应用行为引擎 | 组件存在，作用未独立验证 |

> 结论边界：运营商组件「默认采集并具备上报能力」属实；「上传照片/屏幕内容」类说法**没有**公开证据。

## 处置分级

- **T1 隐私类**：`com.vivo.devicereg`、`com.mobiletools.systemhelper`、`com.vivo.aiengine`、
  `com.vivo.aiservice`、`com.vivo.abe`、`com.vivo.pushservice`
  （pushservice 关闭后依赖 vivo 推送通道的 App 通知会延迟）。
- **T2 商业预装**：浏览器、应用商店、游戏中心、云服务、杂志、视频编辑、钱包/支付、
  Jovi 助手/搜索、主题商店、动态壁纸、健康小组件等。
- **不要动**：`com.vivo.systemuiplugin`、各类 `*.overlay` 资源包、`faceunlock/faceui`、
  `healthservice`、`SeService`、`DR`（DRM）、`sps`、`daemonService`、`smspush`、`ifaa`。

## 手动执行

```bash
adb shell su -c "pm disable-user --user 0 com.vivo.devicereg"
adb shell su -c "pm list packages -d"      # 确认状态
```

被 vivo 列入保护名单的包（如 devicereg）在有 root 时可以 `disable-user`；
不要直接删除系统 APK，禁用即可，恢复更简单。

## 固化成模块

`scripts/debloat_module.sh` 读取一份 TSV（`包名<TAB>动作`），生成 KSU 模块并安装：

```bash
bash scripts/debloat_module.sh --packages packages.example.tsv --dry-run
bash scripts/debloat_module.sh --packages packages.example.tsv --install
```

模块内容：

- `service.sh`：等 `sys.boot_completed=1` 后 sleep 20 秒，逐个 `pm disable-user`；
  日志写到 `/data/local/tmp/debloat.log`。
- 可选：向 `/system/etc/hosts` 追加 `a.fxltsbl.com` / `b.fxltsbl.com` / `zzhc.vnet.cn`
  → `0.0.0.0`（/system 只读时会自动跳过）。

## 恢复

```bash
adb shell su -c "pm enable com.vivo.browser"
adb shell su -c "/data/adb/ksud module disable <module-id>"   # 停止开机重放
```

## 注意

- 更新系统（OTA）后需要确认模块仍生效；系统升级可能重新启用部分组件。
- 禁用运营商组件理论上不影响通话/数据（RegBlocker 实测双卡 IMS 正常），
  但不同地区/运营商策略不同，建议逐项验证后再长期保留。
- 去臃肿清单请按自己的使用习惯调整，不要盲目全禁。
