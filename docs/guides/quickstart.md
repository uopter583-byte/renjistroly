# 快速开始

## 系统要求

- macOS 15+
- Apple Silicon (M1 及以上)
- 约 200MB 磁盘空间

## 安装

### 从源码构建

```bash
git clone https://github.com/user/RenJistroly
cd RenJistroly
swift build -c release
```

构建产物位于 `.build/arm64-apple-macosx/release/RenJistrolyApp`。

### 直接运行

```bash
swift run
# 或直接打开应用
open .build/arm64-apple-macosx/release/RenJistrolyApp
```

## 首次启动权限配置

RenJistroly 需要以下 macOS 权限才能正常运行：

### 1. 辅助功能 (Accessibility)
用于读取 UI 元素、点击按钮、输入文字等桌面操控。

> **系统设置 > 隐私与安全性 > 辅助功能 > 添加 RenJistroly.app**

### 2. 屏幕录制 (Screen Recording)
用于读取屏幕内容、OCR 文字识别。

> **系统设置 > 隐私与安全性 > 屏幕录制 > 添加 RenJistroly.app**

### 3. 麦克风 (Microphone)
用于语音输入（如果使用语音功能）。

> **系统设置 > 隐私与安全性 > 麦克风 > 添加 RenJistroly.app**

### 4. 自动化 (Apple Events)
用于控制其他应用。

> **系统设置 > 隐私与安全性 > 自动化 > 添加 RenJistroly.app**

> **提示:** 首次启动时，RenJistroly 会自动检测权限状态并引导你完成授权。

## 两种使用模式

### 紧凑模式 (Floating Panel)
按 `Option + Space` 调出半透明浮动面板，适合快速问答和日常操作。

- 话按钮发送文字
- 点击 🎤 按钮语音输入
- 支持一键「润色」「解释」「读屏」场景动作

### 展开模式 (Main Window)
从菜单栏图标选择「展开」或通过设置切换到全窗口模式。

- 左侧对话列表，右侧聊天区
- Agent 控制台（显示工具调用、审计记录、任务状态）
- Claude Code 启动器（集成开发任务）

## 基本使用流程

1. **启动 RenJistroly** — 菜单栏出现图标
2. **按 `Option + Space`** — 调出浮动面板
3. **输入或说出需求** — 例如 "帮我搜索一下这个文件夹"、"解释这段选中的代码"
4. **查看结果** — AI 会分析上下文并执行操作
5. **确认操作** — 高风险操作会弹出确认对话框

## 下一步

- 了解[核心功能](core-features.md)的完整能力
- 配置[企业安全模式](enterprise-mode.md)保护敏感环境
- 尝试[语音交互](voice-interaction.md)释放双手
- 与 [Claude Code](mcp-integration.md) 组合使用
