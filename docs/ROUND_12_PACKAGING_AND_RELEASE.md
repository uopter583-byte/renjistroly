# 第 12 轮：打包与发布准备

**完成时间**：2026-06-14

## 完成了什么

完成从源码到可分发 DMG 的完整打包发布链路，以及首次启动引导体验。

### 新增文件
- `Scripts/notarize.sh` — Apple 公证脚本，支持 keychain profile 或环境变量两种认证方式
  - 使用 `xcrun notarytool submit --wait` 提交公证
  - 自动 `xcrun stapler staple` 钉入票据
  - 钉入后验证 `xcrun stapler validate`
- `Scripts/create_dmg.sh` — DMG 安装包制作脚本
  - 创建临时 staging 目录，放入 .app + /Applications 快捷方式
  - 使用 `hdiutil` 创建 UDZO 压缩磁盘镜像（zlib level 9）
  - 1.4MB 压缩体积
- `Sources/RenJistrolyUI/Components/OnboardingView.swift` — 首次启动引导界面
  - 4 步引导：欢迎介绍 → 权限检查 → 快捷键说明 → 快速上手
  - TabView page style 翻页
  - 步骤进度点 + 继续/开始按钮
  - KeyboardKey 组件渲染快捷键视觉效果
- `CHANGELOG.md` — 版本更新记录（0.1.0 初始版本完整功能列表）
- `.gitignore` — 忽略构建产物（.build/、*.app、*.dmg、DS_Store）

### 修改文件
- **AppState** — 新增 `hasCompletedOnboarding` 属性（UserDefaults 持久化）+ `completeOnboarding()` 方法
- **RenJistrolyApp** — `.sheet` 条件展示 OnboardingView（首次启动时）
- **package_app.sh** — 默认值修正为 RenJistroly / com.renjistroly.app，优先 source version.env

### 打包发布流程

```bash
# 1. 构建 + 签名
./Scripts/package_app.sh release

# 2. 公证（需要 Apple Developer 账号）
APPLE_ID=you@me.com APPLE_TEAM_ID=XXXXX APPLE_APP_PASSWORD=xxxx ./Scripts/notarize.sh

# 3. 制作 DMG
./Scripts/create_dmg.sh

# 或一键完成（开发环境）
./Scripts/compile_and_run.sh --test
```

### 首次启动流程
1. 打开 App → 弹出 OnboardingView sheet
2. 用户浏览 4 步引导：欢迎、权限、快捷键、上手示例
3. 点击"开始使用" → UserDefaults 记录完成 → 进入主界面
4. 后续启动不再显示（除非清除 UserDefaults）

## 代码状态
- 构建: `swift build` ✅
- 测试: 40 tests, 0 failures ✅
- 打包: `bash Scripts/package_app.sh` ✅
- DMG: `bash Scripts/create_dmg.sh` ✅ (1.4MB)

## 项目总览

经过 12 轮迭代，RenJistroly 从零构建为：
- **7 个 SwiftPM 模块**，层次清晰单向依赖
- **26 个 MCP 工具**，覆盖系统控制/代码工具/场景工具
- **三级安全评估**，确认弹窗 + 审查日志
- **多步执行计划**，LLM 自动编排
- **语音交互**，Option+Space 全局热键 + 浮窗控制台
- **完整打包链路**，源码 → build → sign → notarize → DMG
