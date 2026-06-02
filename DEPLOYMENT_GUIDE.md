# 维生素分析仪 iOS 真机调试总结

## 项目信息
- **项目名称**: 维生素分析仪 (Vitamin Analyzer)
- **项目路径**: `/Volumes/S10/analysis-c/`（移动硬盘）
- **Flutter SDK**: `/Users/jianyu/development/flutter`（本机）
- **构建日期**: 2026-06-01
- **iOS 版本**: 14.0+
- **App 大小**: 28.0MB (Release)

---

## 环境准备

### 1. Flutter SDK
- 位置: `/Users/jianyu/development/flutter`
- 版本: Flutter 3.32.0
- 环境变量: `PATH` 包含 `/Users/jianyu/development/flutter/bin`

### 2. Ruby & CocoaPods
- Ruby 3.4.4 (通过 Homebrew 安装)
- CocoaPods 1.16.2 (安装在 `~/.gem/ruby/3.4.0/`)
- PATH: `/Users/jianyu/.gem/ruby/3.4.0/bin:/opt/homebrew/opt/ruby/bin:$PATH`

### 3. CocoaPods Specs 仓库
- 位置: `~/.cocoapods/repos/master/`
- 来源: 手动 `git clone` 自 `https://github.com/CocoaPods/Specs.git`
- 原因: 网络 SSL 证书拦截，无法通过 `pod install` 自动下载

### 4. 网络代理
- 工具: Shadowrocket
- HTTP 代理: `127.0.0.1:1082`
- 环境变量: `http_proxy` 和 `https_proxy`

---

## 项目迁移到移动硬盘

### 原因
本机硬盘空间不足（只剩 245MB），Xcode 编译需要 10G+ 临时空间

### 步骤
```bash
# 1. 复制项目到移动硬盘 (S10, ExFAT SSD)
cp -R /Users/jianyu/Workspace/analysis-c /Volumes/S10/analysis-c

# 2. 重新获取依赖
cd /Volumes/S10/analysis-c
flutter pub get

# 3. iOS 依赖安装
cd ios
export PATH="/Users/jianyu/.gem/ruby/3.4.0/bin:/opt/homebrew/opt/ruby/bin:$PATH"
export http_proxy=http://127.0.0.1:1082
export https_proxy=http://127.0.0.1:1082
pod install --no-repo-update
```

### 编译目录配置
将 Xcode DerivedData 链接到移动硬盘：
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
mkdir -p /Volumes/S10/Xcode/DerivedData
ln -s /Volumes/S10/Xcode/DerivedData ~/Library/Developer/Xcode/DerivedData
```

---

## 关键代码修复

### 1. 移除 `dart:html`（iOS 不支持）
**文件**: `lib/services/database_service.dart`
- 删除: `import 'dart:html' as html;`
- 修改: `_loadFromLocalStorage()` 和 `_saveToLocalStorage()` 为空实现
- 原因: `dart:html` 是 Web 专用，iOS/Android 不支持

### 2. 降级 `fl_chart` 版本
**文件**: `pubspec.yaml`
- 原版本: `fl_chart: ^1.1.0`（不兼容 Flutter 3.32）
- 新版本: `fl_chart: ^0.66.0`
- 错误: `Matrix4.translateByDouble` 和 `scaleByDouble` 方法不存在

### 3. 移除 `tooltipBgColor` 参数
**文件**: 
- `lib/widgets/vitamin_chart.dart` (第 121 行)
- `lib/widgets/mineral_chart.dart` (第 121 行)
- 原因: `fl_chart` 0.66.0 版本 API 变化，`tooltipBgColor` 参数已移除

### 4. Podfile 配置
**文件**: `ios/Podfile`
```ruby
platform :ios, '14.0'
source 'https://github.com/CocoaPods/Specs.git'
```
- 指定 iOS 14.0 平台
- 使用本地 master 仓库（避免网络 SSL 问题）

---

## Xcode 配置

### 1. 打开项目
```bash
open /Volumes/S10/analysis-c/ios/Runner.xcworkspace
```
**注意**: 必须用 `.xcworkspace`，不是 `.xcodeproj`

### 2. 配置签名
- TARGETS → Runner → Signing & Capabilities
- Team: 选择个人 Apple ID（免费开发者账号）
- Bundle Identifier: `com.aifeisucn.vitaminAnalyzer`
- Automatically manage signing: ✅

### 3. 配置 Build Configurations
- TARGETS → Runner → Info → Configurations
- Debug: `Pods-Runner.debug`
- Release: `Pods-Runner.release`
- Profile: `Pods-Runner.profile`

### 4. 构建运行
- 顶部工具栏选择 iPhone（不是 My Mac）
- Product → Clean Build Folder (Cmd+Shift+K)
- 点击 ▶️ 运行 (Cmd+R)

---

## 手机设置

### 1. 开启开发者模式
设置 → 隐私与安全性 → 开发者模式 → 开启

### 2. 信任开发者
设置 → 通用 → VPN与设备管理 → 信任 [你的 Apple ID]

### 3. 首次运行
- 连接 Mac 信任电脑
- Xcode 构建安装
- 手机上点击 App 图标

---

## 遇到的坑点

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| CocoaPods SSL 证书验证失败 | 网络中间人拦截 | 手动下载 Specs 仓库到本地 |
| `pod install` 超时 | 网络慢/被拦截 | 使用本地 master 仓库 + 代理 |
| 硬盘空间不足 | Xcode 编译需 10G+ | 项目放移动硬盘 + 清理缓存 |
| `dart:html` 编译错误 | iOS 不支持 Web API | 移除相关代码 |
| `fl_chart` 1.1.0 不兼容 | API 变化 | 降级到 0.66.0 |
| `tooltipBgColor` 参数错误 | API 移除 | 删除该参数 |
| `dyld_shared_cache_extract_dylibs` | Xcode 调试符号问题 | 忽略，不影响运行 |
| Developer Disk Image | iOS 18.7.7 太新 | 直接用手机测试，不通过 Xcode 调试 |

---

## 清理空间命令

```bash
# Xcode 缓存
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Developer/Xcode/Archives/*
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/*

# Claude 缓存 (13G)
rm -rf ~/Library/Application\ Support/Claude/logs/*
rm -rf ~/Library/Application\ Support/Claude/crash_reports/*

# 飞书缓存 (3.4G)
rm -rf ~/Library/Application\ Support/LarkShell/Cache/*

# 其他缓存
rm -rf ~/Library/Caches/datalab
rm -rf ~/.cache/uv
rm -rf ~/.cache/huggingface
```

---

## 后续可选

### 1. 注册 Apple Developer ($99/年)
- 地址: https://developer.apple.com/programs
- 支持: TestFlight 分发、App Store 上架

### 2. 蒲公英 / fir.im 免费分发
- 不需要 Apple Developer 账号
- 上传 IPA 生成下载链接
- 适合内部测试

### 3. Android 构建
- 需要 Android SDK
- 配置 `ANDROID_HOME` 环境变量

---

## 项目文件结构

```
/Volumes/S10/analysis-c/
├── lib/
│   ├── main.dart
│   ├── screens/           # 页面
│   ├── widgets/           # 组件 (vitamin_chart.dart, mineral_chart.dart)
│   ├── models/            # 数据模型
│   └── services/          # 服务 (ai_service.dart, history_service.dart)
├── ios/
│   ├── Runner.xcworkspace # Xcode 工作区
│   ├── Podfile            # CocoaPods 配置
│   └── Flutter/           # Flutter 生成的 iOS 配置
├── pubspec.yaml           # 依赖配置
└── build/
    └── ios/
        └── iphoneos/
            └── Runner.app  # 构建产物 (28MB)
```

---

## 构建命令总结

```bash
# 1. 环境准备
export PATH="/Users/jianyu/development/flutter/bin:/Users/jianyu/.gem/ruby/3.4.0/bin:/opt/homebrew/opt/ruby/bin:$PATH"
export http_proxy=http://127.0.0.1:1082
export https_proxy=http://127.0.0.1:1082

# 2. 获取依赖
cd /Volumes/S10/analysis-c
flutter pub get

# 3. iOS 依赖
cd ios
pod install --no-repo-update

# 4. 构建 Release
flutter build ios --release

# 5. 用 Xcode 安装到手机
open Runner.xcworkspace
```

---

*文档生成时间: 2026-06-01*
*作者: AI Assistant*
