# VersionBridgeRH 0.2.0（选项②：中文设置面板）

**源码工程，不是已编译的 DEB。** 该版本未在真实 iPhone / RootHide 上编译或运行测试。旧版的单 App 硬编码配置已改为「设置 → 版本伪装 → App 列表 → 每个 App 独立设置」。

## 环境
- iPhone 14 Pro Max，iOS 16.5，RootHide on Dopamine 3 v3.0.4：目标适配环境（未实测）。
- 需要 RootHide Theos、iOS SDK、PreferenceLoader 和运行时的 tweak 注入支持。

## 功能
- 通过 `LSApplicationWorkspace` 枚举已安装的第三方 App，显示 App 名称；**私有 API，可能在某些系统 / 注入环境中不可用**。
- 对每个 App 独立保存开关、伪装系统版本、App 版本及 Build。
- 默认**所有 App 关闭**，避免全局干扰。修改设置后彻底退出目标 App 并重启。
- 覆盖 `UIDevice.systemVersion`、`NSProcessInfo` 的常见版本读取和主 `NSBundle` 版本字段。

## 编译与安装

```bash
# 使用 RootHide 的 Theos，且本机装有 iOS SDK
cd VersionBridgeRH-Settings
make clean package
# packages/ 下为生成的 DEB（此 ZIP 中无现成 DEB）
```

通过 RootHide 支持的包管理器安装。需要 PreferenceLoader。安装后在 iOS 设置中查找「版本伪装」；若入口没有出现，检查 PreferenceLoader 是否正常安装与设置 app 的插件注入状态。

## 重要限制
- App 列表依赖私有 `LSApplicationWorkspace`，有时可能因权限、隐藏注入或运行时更改而为空。
- RootHide 可能阻止某些 App 注入，**必须允许目标 App 的插件注入**，否则配置不会生效。
- 沙盒 / CFPreferences 域的跨进程同步在 RootHide 不同配置下可能受限，若设置能写入但 App 不生效，需要在真实设备调试。
- `UIKit` 的过滤范围较广，但实际只针对用户明确启用的第三方 App 装载 hook。
- 无法修复因缺少 iOS 17/18 API、二进制不兼容导致的闪退；不保证解决所有弹窗。
- **不要用于绕过年龄验证、账号保护、安全限制、反作弊或者其他保护机制。**
- 使用前备份重要数据；建议先挑一个测试 App 验证。

## 工程文件
- `Tweak.x`：App 侧条件拦截。
- `VersionBridgeRH.plist`：UIKit 进程级注入过滤。
- `prefs/VBRootController.m`：中文已安装 App 列表。
- `prefs/VBAppController.m`：每个 App 的版本伪装设置。
- `prefs/VBShared.h`：共享 CFPreferences 域。
- `layout/Library/PreferenceLoader/Preferences/VersionBridgeRH.plist`：设置入口。
