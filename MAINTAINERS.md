# 维护者指南

## 项目结构

RenJistroly 是一个基于 SwiftPM 模块化架构的 macOS AI 助手，采用 Swift 6.2、SwiftUI + AppKit 混合 UI，支持 macOS 15+ Apple Silicon。

```
RenJistroly/
├── Sources/
│   ├── RenJistrolyApp/           # 入口点、AppDelegate、全局热键
│   ├── RenJistrolyUI/            # SwiftUI 视图（FloatingPanel、MainWindow 等）
│   ├── RenJistrolyConversation/  # 会话管理、上下文编译、对话引擎
│   ├── RenJistrolyIntelligence/  # LLM 后端、智能路由、Agent 编排
│   ├── RenJistrolyCapability/    # MCP 工具注册与执行
│   ├── RenJistrolySystemBridge/  # macOS 系统集成（AX、ScreenCaptureKit 等）
│   ├── RenJistrolyModels/        # 核心数据类型、协议定义
│   └── RenJistrolyMCP/           # 独立 MCP 服务器
├── Tests/
├── Resources/
├── Scripts/
├── Frameworks/
├── docs/
└── Package.swift
```

依赖方向（单向）：App → UI → Conversation → Capability/Intelligence → SystemBridge/Models

## 如何贡献

欢迎提交 Pull Request。请确保：

1. 代码通过编译（`swift build`）
2. 单元测试通过（`swift test`）
3. 遵守代码规范（参见下方 §代码规范）
4. 新增功能包含对应测试
5. PR 标题清晰描述变更

## 代码规范

- **Swift 6.2 并发模型**：默认 `@MainActor`，可变后台状态使用 actor
- **UI 状态**：使用 `@Observable` 类，通过 `@Environment` 注入
- **流式处理**：`LLMBackend` 返回 `AsyncStream<String>`
- **MCP 工具**：遵循 `MCPTool` 协议，通过 `MCPToolRegistry` 注册
- **命名**：遵循 Swift API 设计指南，使用驼峰命名
- **无冗余注释**：代码自文档化，只在需要说明"为什么"时添加注释
- **导入顺序**：按标准库 → 第三方 → 内部模块排序

## PR 流程

1. Fork 仓库并创建功能分支（`feature/xxx` 或 `fix/xxx`）
2. 在分支上开发，保持提交粒度适中
3. 运行 `swift build && swift test` 确保不破坏现有功能
4. 提交 PR 至 `main` 分支，描述变更内容与动机
5. 维护者审核后合并

## 版本策略

采用语义化版本（SemVer 2.0）：

- **主版本**：破坏性 API 变更
- **次版本**：新功能（向后兼容）
- **补丁版本**：Bug 修复

版本记录见 `CHANGELOG.md`。

## 构建与发布

```bash
# Debug 构建
swift build

# Release 构建
swift build -c release

# 运行测试
swift test

# 构建独立 MCP 服务器
swift build --target RenJistrolyMCP

# 打包并启动应用
Scripts/compile_and_run.sh
```

发布新版本时更新 `version.env` 中的版本号。
