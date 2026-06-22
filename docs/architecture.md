# 架构总览

## 项目定位

RenJistroly 是一个 macOS 原生 AI 操作代理，直接操控屏幕、窗口、应用、文件和终端。非通用助理，专为 Mac 端自动化设计。

## 模块依赖（单向）

```
RenJistrolyApp ──→ RenJistrolyUI ──→ RenJistrolyConversation ──→ RenJistrolyCapability
                                              │                           │
                                              ↓                           ↓
                                    RenJistrolyIntelligence       RenJistrolySystemBridge
                                              │                           │
                                              ↓                           │
                                        RenJistrolyModels         (无内部依赖)
```

## 模块职责

- **RenJistrolyModels** — 核心数据类型（Message、Conversation、LLMProvider、ProjectContext）和协议定义（LLMBackend、STTProvider、TTSProvider）。零依赖。
- **RenJistrolySystemBridge** — macOS 系统集成层：AccessibilityBridge（AX API）、AppleScriptBridge、ShellExecutor（沙箱）、ScreenCaptureBridge（ScreenCaptureKit）。依赖 COrt（onnxruntime 封装）、Models、XPC 协议。
- **RenJistrolyIntelligence** — LLM 后端（LocalMLX、CloudAnthropic、CloudOpenAI）、SmartRouter（复杂度路由）、AgentOrchestrator（多步代理循环）、RAGEngine（关键词检索）。
- **RenJistrolyCapability** — MCP 协议实现：MCPToolRegistry 注册 94+ 内置工具，MCPClient 连接外部服务器。
- **RenJistrolyEnterprise** — 企业安全模式系统（10 种模式），依赖 Models。
- **RenJistrolyProductIdentity** — 产品定位与能力分级（观察/读写/自动化/自主），依赖 Models。
- **RenJistrolyConversation** — 会话引擎：SessionManager（持久化）、ContextCompiler（上下文检测）、ConversationEngine（编排 LLM + MCP + RAG 的完整对话回合）。
- **RenJistrolyUI** — SwiftUI 视图层：FloatingPanelWindow、MessageBubble、StreamingMarkdownText、MenuBarView。
- **RenJistrolyMCP** — 独立 stdio MCP 服务器进程，供 Claude Code 集成。

## 数据流

用户输入 → ConversationEngine → SmartRouter 选择 LLM → LLM 流式返回 → MCP 工具调用 → SystemBridge 执行 → 结果回填 → UI 流式展示。

## 并发模型

UI 绑定 @MainActor；可变后台状态用 actor（ShellExecutor、SmartRouter、RAGEngine）；LLM 响应通过 AsyncStream 流式传输。
