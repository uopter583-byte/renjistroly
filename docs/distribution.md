# RenJistroly macOS 分发指南

## 分发方式选择

**推荐：Developer ID 分发（Mac App Store 之外）**

RenJistroly 的功能设计——系统自动化（AX API）、屏幕录制（ScreenCaptureKit）、任意 Shell 执行、SMJobBless 特权辅助工具——与 Mac App Store 的 App Sandbox 要求**从根本上不兼容**。因此推荐使用 Developer ID 分发（Gatekeeper + 公证），不走 Mac App Store。

| 特性 | Developer ID | Mac App Store |
|------|-------------|---------------|
| App Sandbox | 不需要 | **强制要求** ❌ |
| SMJobBless 辅助工具 | 支持 ✅ | 不支持 ❌ |
| Shell 执行 | 支持 ✅ | 不支持 ❌ |
| 屏幕录制 | 支持 ✅ | 受限 |
| 公证（Notarization） | 需要 ✅ | Apple 自动处理 |
| 用户安装方式 | 手动拖入 /Applications | App Store 自动安装 |

---

## 前置条件

### 1. Apple Developer 账号

需要 Apple Developer Program 会员资格（$99/年）。

### 2. 所需证书

| 用途 | 证书类型 |
|------|----------|
| Developer ID 分发 | `Developer ID Application: <你的名字>` |
| 本地开发调试 | `Apple Development: <你的名字>` |

**检查已有证书：**

```bash
# 查看所有可用于签名的身份
security find-identity -v -p basic

# 查看 Developer ID 身份
security find-identity -v -p macappstore
```

如果缺少 `Developer ID Application` 证书，通过 Xcode 生成：

1. 打开 Xcode > Settings > Accounts
2. 登录你的 Apple ID
3. 点击 "Manage Certificates"
4. 点击 "+" > "Developer ID Application"

### 3. 公证凭证设置（一次性）

```bash
# 在 App Store Connect 生成 App 专用密码
# https://appleid.apple.com/account/manage > App-Specific Passwords

# 存储公证凭据到钥匙串
xcrun notarytool store-credentials "RenJistrolyNotary" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "@keychain:AC_PASSWORD"
```

---

## 代码签名配置

### 当前权限（Entitlements）

位于 `Resources/entitlements.plist`：

| Entitlement | 值 | 说明 |
|-------------|-----|------|
| `com.apple.security.app-sandbox` | `false` | Developer ID 不需要沙箱 |
| `com.apple.security.accessibility` | `true` | 辅助功能（读取/控制 UI） |
| `com.apple.security.cs.allow-unsigned-executable-memory` | `true` | 允许 JIT 内存（onnxruntime 需要） |
| `com.apple.security.cs.disable-library-validation` | `true` | 禁用库验证（嵌入的 dylib） |
| `com.apple.security.device.microphone` | `true` | 麦克风权限 |
| `com.apple.security.automation.apple-events` | `true` | Apple Events 自动化 |
| `com.apple.security.network.client` | `true` | 网络访问（LLM API） |
| `com.apple.security.files.user-selected.read-write` | `true` | 用户选择的文件读写 |
| `com.apple.security.files.downloads.read-write` | `true` | 下载文件夹读写 |
| `com.apple.security.personal-information.*` | `true` | 日历/联系人/位置 |

### Hardened Runtime 例外

Developer ID 分发需要启用 Hardened Runtime（`--options runtime`）。当前 entitlements 中以下两项也是 Hardened Runtime 的例外：

- `com.apple.security.cs.allow-unsigned-executable-memory` — 允许 JIT 编译
- `com.apple.security.cs.disable-library-validation` — 允许加载未签名库

这两项用于 onnxruntime 推理引擎。如果 Apple 在审查中要求，可以提交解释。

### 签名顺序

`package_app.sh` 已实现正确签名顺序：

1. 先签名特权辅助工具（`Contents/Library/LaunchServices/com.renjistroly.helper`）
2. 签名 Frameworks 中所有可执行文件
3. 签名整个 .app 包（带 entitlements）

---

## 分发步骤

### 步骤 1：构建 + 签名 + 打包

```bash
cd /Users/yoming/RenJistroly

# 使用 Developer ID 签名（替换为你的证书名）
APP_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
SIGNING_MODE="devid" \
./Scripts/package_app.sh release
```

如果证书名包含空格，用引号包裹。脚本会自动：

- 构建 arm64 release 二进制
- 嵌入 onnxruntime dylib
- 复制资源包（SwiftPM resource bundles）
- 复制 Info.plist 和 entitlements
- 按正确顺序签名整个 .app 包

验证签名：

```bash
codesign -dvvv RenJistroly.app
# 应输出: Signature=adhoc → Signature=Developer ID Application
# 应包含: TeamIdentifier=YOUR_TEAM_ID

spctl -a -v RenJistroly.app
# 应输出: accepted source=Developer ID
```

### 步骤 2：公证（Notarization）

```bash
# 方法 A：使用钥匙串凭证（推荐）
./Scripts/notarize.sh

# 方法 B：使用环境变量
APPLE_ID="your@email.com" \
APPLE_TEAM_ID="YOUR_TEAM_ID" \
APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
./Scripts/notarize.sh
```

公证过程：

1. 脚本将 .app 打包为 zip
2. 上传到 Apple 公证服务（`xcrun notarytool submit --wait`）
3. Apple 扫描 -> 通过后返回 ticket
4. 钉入票据到 .app（`xcrun stapler staple`）
5. 验证钉入结果（`xcrun stapler validate`）

**常见公证问题：**

| 问题 | 处理 |
|------|------|
| "Unsupported executable type" | 确保所有二进制都被签名 |
| "Missing hardened runtime" | 签名时需加 `--options runtime`（`package_app.sh` 已处理） |
| 包含违反政策的 API | 检查 Frameworks/ 中的动态库 |
| 公证耗时 | 一般 2-10 分钟，`--wait` 会自动等待 |

### 步骤 3：制作 DMG 安装包

```bash
./Scripts/create_dmg.sh
```

执行后会在项目根目录生成 `RenJistroly-0.1.0.dmg`（版本号取自 `version.env`）。

DMG 包含：
- RenJistroly.app
- /Applications 快捷方式（拖拽安装）

---

## 一键发布完整命令

```bash
cd /Users/yoming/RenJistroly

# 设置环境变量
export APP_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export SIGNING_MODE="devid"
export APPLE_ID="your@email.com"
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"

# 打包
./Scripts/package_app.sh release

# 公证
./Scripts/notarize.sh

# DMG
./Scripts/create_dmg.sh
```

---

## 所需系统权限说明

最终用户首次启动时需要授予以下权限：

| 权限 | 弹窗描述 | 用途 |
|------|----------|------|
| **辅助功能 (Accessibility)** | "RenJistroly needs Accessibility access to help you control and automate your Mac." | 读取/控制 UI 元素、点击、输入文字 |
| **屏幕录制 (Screen Recording)** | "RenJistroly captures screen content to provide context-aware assistance." | OCR 识别屏幕内容 |
| **麦克风 (Microphone)** | "RenJistroly uses the microphone for voice input and push-to-talk commands." | 语音输入 |
| **Apple Events** | "RenJistroly uses Apple Events to automate applications on your behalf." | 跨应用自动化 |
| **文件访问 (Files)** | 系统文件选择对话框 | 读写用户选择的文件 |

所有这些权限描述已在 `Resources/Info.plist` 和 `package_app.sh` 的 Info.plist 模板中配置。

---

## 版本号管理

所有版本相关配置集中在 `version.env`：

```env
APP_NAME=RenJistroly
BUNDLE_ID=com.renjistroly.app
APP_VERSION=0.1.0
MARKETING_VERSION=0.1.0
BUILD_NUMBER=1
```

发布新版时：

1. 更新 `MARKETING_VERSION`（语义化版本号）
2. 递增 `BUILD_NUMBER`（构建号）
3. 更新 `CHANGELOG.md`
4. 执行打包发布流程

---

## 常见问题

### Q: "应用已损坏，无法打开。请移到废纸篓。"

**原因**：没有公证，或者公证未通过。

**解决**：

```bash
# 移除 quarantine 属性（仅开发调试用）
xattr -dr com.apple.quarantine RenJistroly.app

# 上线分发必须完成公证
./Scripts/notarize.sh
```

### Q: "无法验证开发者" 或 "macOS 无法验证此 App 是否包含恶意软件"

**原因**：没有用 Developer ID 签名，或签名不正确。

**解决**：

```bash
# 确认使用 Developer ID Application 证书签名
codesign -dvvv RenJistroly.app
# 查找 Signature= 字段

# 检查 TeamIdentifier
# 如果没有 TeamIdentifier 说明是 ad-hoc 签名
```

### Q: 公证退回，显示 "The binary uses an SDK older than the required minimum"

**原因**：构建使用的 macOS SDK 版本过低。

**解决**：确保 Xcode 版本 >= 16，且 `Package.swift` 中 `platforms: [.macOS(.v15)]` 使用最新 SDK 构建。

### Q: 公证退回 "The signature does not include a secure timestamp"

**原因**：签名时缺少 `--timestamp` 选项。

**解决**：`package_app.sh` 已在非 ad-hoc 模式下添加 `--timestamp`。确认 `APP_IDENTITY` 已正确设置。

### Q: 辅助功能权限请求未弹出

**原因**：`Resources/Info.plist` 中 `NSAccessibilityUsageDescription` 缺失。

**解决**：确认该字段存在。此外，辅助功能权限只能由用户通过 `系统设置 > 隐私与安全性 > 辅助功能` 手动授予，应用无法直接请求。

### Q: 屏幕录制权限请求未弹出

**原因**：`Resources/Info.plist` 中 `NSScreenCaptureUsageDescription` 缺失。

**解决**：确认该字段存在。与辅助功能类似，屏幕录制权限需用户在系统设置中手动授予。

### Q: onnxruntime 加载失败 "Library not loaded"

**原因**：动态库路径解析失败。

**解决**：

```bash
# 检查 onnxruntime 库在 bundle 中的位置
ls RenJistroly.app/Contents/Frameworks/libonnxruntime*

# 检查 install_name
otool -L RenJistroly.app/Contents/MacOS/RenJistroly | grep onnx

# 确认引用路径指向 @rpath/libonnxruntime.1.dylib
# 而非 /opt/homebrew/... 路径
```

### Q: "The executable does not have the hardened runtime enabled"

**原因**：Developer ID 签名必须启用 Hardened Runtime。

**解决**：`package_app.sh` 在提供 `APP_IDENTITY` 时会自动添加 `--options runtime`。确认环境变量已设置。

### Q: 每次运行都弹权限窗口

**原因**：代码签名更改后，macOS 会重新评估权限。在开发阶段使用 ad-hoc 签名切换频繁会导致此问题。

**解决**：确定开发者 ID 证书后保持签名一致性。或者在开发阶段将 Release 构建加入辅助功能/屏幕录制白名单。

---

## 参考

- [Apple 代码签名文档](https://developer.apple.com/documentation/security/code_signing)
- [Apple 公证文档](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Hardened Runtime 文档](https://developer.apple.com/documentation/security/hardened_runtime)
- [Developer ID 文档](https://developer.apple.com/developer-id/)
