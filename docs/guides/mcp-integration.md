# 与 Claude Code 集成

RenJistroly 提供独立的 MCP 服务器，把 94+ 个 macOS 原生工具暴露给 Claude Code，让 Claude Code 也能操控你的 Mac。

## 架构

```
Claude Code ←→ RenJistrolyMCP (stdio) ←→ macOS (AX/ScreenCaptureKit/Shell)
```

RenJistrolyMCP 是独立的可执行文件，通过 stdio JSON-RPC 协议与 Claude Code 通信。不需要运行 RenJistroly App 即可使用 MCP 工具。

## 配置方法

### 1. 构建 MCP 服务器

```bash
cd RenJistroly
swift build --target RenJistrolyMCP -c release
```

产物路径: `.build/arm64-apple-macosx/release/RenJistrolyMCP`

### 2. 注册到 Claude Code

在 Claude Code 的 `mcp.json` 配置文件中添加：

```json
{
  "mcpServers": {
    "renjistroly": {
      "command": "/absolute/path/to/.build/arm64-apple-macosx/release/RenJistrolyMCP"
    }
  }
}
```

配置位置（按优先级）：
- 项目级: `.claude/mcp.json`（仅当前项目）
- 全局: `~/.claude/mcp.json`（所有项目）

### 3. 首次使用需授权

首次调用 MCP 工具时，macOS 会弹出权限请求：
- 辅助功能权限
- 屏幕录制权限

授予后即可使用全部能力。

## MCP 工具一览

注册后，Claude Code 会自动加载以下工具分组：

| 分组 | 数量 | 功能 |
|------|------|------|
| 应用操控 | 12 | 打开应用、窗口管理、菜单操作 |
| 文件操作 | 12 | 浏览、创建、移动、复制、删除 |
| 鼠标键盘 | 11 | 点击、输入、快捷键、滚动、拖拽 |
| AX UI | 3 | 窗口列表、焦点、UI 树 |
| 代码编辑 | 8 | Git、文件读写、Shell、剪贴板 |
| 浏览器 | 7 | Safari/Chrome DOM 操作、导航 |
| 构建调试 | 14 | Swift 构建测试、Xcode、符号搜索 |
| Git 高级 | 13 | 分支、提交、推送、标签、变基 |
| 屏幕 OCR | 6 | 截图对比、屏幕上下文、文字识别 |
| 系统 | 5 | 系统信息、进程、媒体控制 |

## 与 RenJistroly App 配合使用

最佳实践是两者同时使用：

- **RenJistroly App** — 桌面操控、屏幕理解、语音交互、企业安全
- **Claude Code** — 代码编辑、重构、文件操作

App 内的 Claude Code 启动器（设置 > 开发者模式）可以直接委派开发任务给 Claude Code。

## 权限说明

MCP 服务器进程需要独立的权限授权（与 RenJistroly App 不同）：

| 权限 | 首次触发时机 |
|------|-------------|
| 辅助功能 | 第一次 click/type 操作 |
| 屏幕录制 | 第一次 ocr_screen/screen_context |

授权后权限会自动持久化。
