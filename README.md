# PowerCuff R3 — RootHide 适配工程

基于公开仓库 [Baldaran/Powercuff-r3vamp](https://github.com/Baldaran/Powercuff-r3vamp)
（HEAD `eb770afc`，公开配置为 1.0.0）新建的独立工程，针对
iPhone 14 Pro Max / iOS 16.5 / RootHide Dopamine 2.4.9.27 调整。没有覆盖原始仓库，也没有改动用户上传的成品 DEB。

## 适配与优化点

- 包名与偏好域改为独立 `com.minis.powercuff-r3vamp-roothide`，不接管已发布的 `com.rpetrich.powercuff` / `com.baldaran.powercuff-r3vamp`，避免升级链与用户配置被无关包改写。
- 构建改为 RootHide：`THEOS_PACKAGE_SCHEME = roothide`，`ARCHS = arm64e`，`TARGET = iphone:clang:16.5:16.0`，SDK 固定 16.5。
- 默认 `PowerMode = 0`（Off，即系统默认行为）；Moderate 为可选档位，不再默认写入 3。`RequireLowPowerMode` 默认 false。
- 偏好域单一；Tweak 对缺失键按 0 处理，与面板默认一致，不再有新旧域软链桥接和备份覆盖问题。
- 注入过滤器只保留 `SpringBoard` 与 `thermalmonitord` 两个可执行文件，不按 Bundle ID 全局注入。
- 热模拟 off 路径直接向系统传 `off`；LPM 限制与档位归一（0–4）在单一队列内完成。
- 卸载脚本只做防御性设置变更通知；不在用户偏好文件里写默认值。

## 关键源码

- `Powercuff.x`：单域、默认关闭、`thermalmonitord`/`SpringBoard` 分支、off 复位与 LPM 限制。
- `PCR3RootHide.plist`：注入过滤器。
- `layout/Library/PreferenceLoader/Preferences/Powercuff/Powercuff.plist`：面板，默认 Off。
- `layout/DEBIAN/{postinst,prerm,postrm}`：无默认写入；卸载仅防御性通知。

## 构建

需要 macOS 与 Xcode 15.4、roothide/theos、iPhoneOS16.5 SDK。本机（Alpine/Linux iSH）没有 iOS SDK，
且链接出的 dylib 无法生成真正的 arm64e + PAC ABI，因此不在此处编出可安装 deb。

### 本地（macOS）

```sh
export THEOS=/path/to/roothide/theos
sh build.sh roothide
```

### GitHub Actions

`.github/workflows/build.yml` 在 macos-14 + Xcode 15.4 上检出 roothide/theos 与
iPhoneOS16.5 SDK，构建并上传 `packages-roothide`，推送到 main/master 或手动触发时发布 Release。
发布版本为 `1.0.0-<run_number>`。

## 设备验收门禁（未完成）

在目标机依次确认并留日志：

1. 面板显示为 Off，主库读取缺失键为 0，热模拟为系统默认。
2. 切到 Moderate 时 `thermalmonitord` 进入对应热模拟状态，日志无异常。
3. 切回 Off 后确认退出热模拟；开启 LPM 限制时退出 LPM 后档位归 0。
4. 升级、失败回滚、remove、purge 后 `thermalmonitord`/`SpringBoard` 行为与偏好均正确。
5. 用 `llvm-readobj`/`llvm-objdump`/`ldid` 核对产物确实是 `CPU_SUBTYPE_ARM64E` 且含指针认证序列。

以上任一未通过，不应将产物称为“完整可安装修复”。
