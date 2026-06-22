# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
swift build                    # Debug build
swift build -c release         # Release build
swift test                     # Run all tests
swift test --filter "TestName" # Run a single test
swift build --target RenJistrolyMCP             # Build standalone MCP server
swift build --target RenJistrolyBridge          # Build bridge CLI
swift build --target RenJistrolyGate            # Build gate relay
swift build --target RenJistrolyHelper          # Build privileged helper
swift build --target RenJistrolyEnterprise      # Build enterprise security module
swift build --target RenJistrolyProductIdentity # Build product identity module
swift build --target RenJistrolyUIPreview       # Build UI preview components
Scripts/compile_and_run.sh     # Package and launch the app
```

## MCP Server

`RenJistrolyMCP` is a standalone stdio-based MCP server that exposes all 94+ real tools (AX UI control, ScreenCaptureKit, AppleScript, file/git/code operations) to Claude Code. Uses `MCPToolRegistry` directly — no subprocess proxying.

### Claude Code configuration

Add to `.claude/settings.json`:
```json
{
  "mcpServers": {
    "renjistroly": {
      "command": "/path/to/.build/debug/RenJistrolyMCP"
    }
  }
}
```

The binary location after `swift build --target RenJistrolyMCP`:
- Debug: `.build/arm64-apple-macosx/debug/RenJistrolyMCP`
- Release: `.build/arm64-apple-macosx/release/RenJistrolyMCP`

**Permissions**: The MCP server process needs its own Accessibility and Screen Recording permission grants. First tool call to each capability will trigger the macOS permission prompt.

## Architecture

RenJistroly is a macOS-native AI assistant built with Swift 6.2, using SwiftUI + AppKit hybrid UI and SwiftPM modular architecture. Target: macOS 15+ on Apple Silicon.

### Dependency direction (单向)

```
RenJistrolyApp ──→ RenJistrolyUI ──→ RenJistrolyConversation ──→ RenJistrolyCapability
                                              │                           │
                                              ↓                           ↓
                                    RenJistrolyIntelligence       RenJistrolySystemBridge
                                              │                      ↗        │
                                              ↓                COrt          ↓
                                        RenJistrolyModels           RenJistrolyXPC

                              RenJistrolyEnterprise ──→ RenJistrolyModels
                            RenJistrolyProductIdentity ──→ RenJistrolyModels
                               RenJistrolyUIPreview ──→ RenJistrolyEnterprise

Standalone Executables:
  RenJistrolyMCP ──→ RenJistrolyCapability │ RenJistrolySystemBridge │ RenJistrolyModels
  RenJistrolyBridge ──→ RenJistrolyModels │ RenJistrolySystemBridge
  RenJistrolyGate ──→ (standalone gate relay)
  RenJistrolyHelper ──→ RenJistrolyXPC
```

### Module roles

- **RenJistrolyModels** — Core data types (`Message`, `Conversation`, `LLMProvider`, `ProjectContext`), protocol definitions (`LLMBackend`, `STTProvider`, `TTSProvider`, `MCPTool`). No dependencies.
- **RenJistrolySystemBridge** — macOS system integration: `AccessibilityBridge` (AX API), `AccessibilityContextProvider`, `AppleScriptBridge`, `ShellExecutor` (sandboxed, command allowlist, credential sanitizer), `ScreenCaptureBridge` (ScreenCaptureKit, OCR), `AppDrivers`, `PermissionCenter` (macOS permission management), `FocusGuard`, `CursorController`, `HealthMonitor`, `ClaudeCodeBridge`, `ChatwootBridge`, `CodebaseMemoryBridge`, `LogSanitizer`, `CommandScopeLimiter`, `LocalOnlyPolicy`, `AuditExporter`. Dependencies: COrt + Models + XPC.
- **RenJistrolyIntelligence** — LLM backends (`LocalMLX`, `CloudAnthropic`, `CloudOpenAI`), `SmartRouter` (complexity-based routing), `AgentOrchestrator` (multi-step agent loop), `RAGEngine` (keyword-index code retrieval). Depends on Models.
- **RenJistrolyCapability** — MCP protocol: `MCPToolRegistry` + built-in tools (system control, code tools, file tools), `MCPClient` for external server connections. Depends on Models + SystemBridge.
- **RenJistrolyConversation** — `SessionManager` (persistence, CRUD), `ContextCompiler` (project context detection), `ConversationEngine` (orchestrates LLM + MCP + RAG + ProductIdentity quality gate for a complete chat turn). Depends on Models + Intelligence + Capability + ProductIdentity.
- **RenJistrolyUI** — SwiftUI enterprise views: `FloatingPanelWindow` (NSPanel subclass), `FloatingPanelView` (compact mode), `MainWindowView` (immersive mode with sidebar), `MenuBarView`, `AssistantRootView`, `MainTabView`, `ModeControlPanel` (enterprise security mode UI), `ContextDashboard`, `ActionAuditView`, `SettingsPanel`, `PermissionsView`. Depends on all lower layers.
- **RenJistrolyApp** — Entry point, `AppDelegate` (floating panel lifecycle + permissions), `HotkeyManager` (Carbon global hotkey), `SettingsView`. Executable target.
- **RenJistrolyMCP** — Standalone stdio MCP server (`@main` struct implementing 2024-11-05 JSON-RPC protocol). Links `RenJistrolyCapability` + `RenJistrolySystemBridge` to expose all tools directly. Executable target for Claude Code integration.
- **RenJistrolyEnterprise** — 企业安全模式系统：`ModeManager`（10 种可叠加操作模式：只读/建议/执行/高风险/无鼠标/本地/敏感 App 防护/自动遮蔽/策略锁定/审计导出）、`ActionEngine`（动作风险等级评估与审批流）、`ContextProvider` / `DevContextProvider`（系统/应用/屏幕上下文快照）。Depends on Models.
- **RenJistrolyProductIdentity** — 产品定位与安全门禁：`ProductIdentity`（Mac Operating Agent 品牌定位与能力边界）、`ActionVerificationEngine`、`PolicyLayer`、`ReadOnlyModeEnforcer`、`MouseGuard`、`ScreenStabilityMonitor`、`WindowMatchValidator`、`StateMachineManager`、`TestMatrixPlanner`。Depends on Models.
- **RenJistrolyUIPreview** — SwiftUI 企业界面原型组件：`ActionCard`、`AuditRow`、`ModeBadge`、`RiskLevelIndicator`。用于 SwiftUI 预览驱动的组件开发。Depends on Enterprise.
- **RenJistrolyResources** — 本地化资源：`Localization.swift`（中文/英文字符串表）。无内部依赖。
- **RenJistrolyBridge** — 桥接 CLI 可执行文件，用于 Claude Code 集成（click/type/observe/open-app 等原子操作）。Depends on Models + SystemBridge.
- **RenJistrolyGate** — 独立语音门禁可执行文件，用于 App 与 Claude Code 会话之间的语音中继。无内部依赖。
- **RenJistrolyHelper** — SMJobBless 特权辅助工具，以 root 权限执行受限系统操作。Depends on XPC.
- **RenJistrolyXPC** — XPC 共享协议定义（`RenJistrolyXPCProtocol`）。无内部依赖。被 SystemBridge 和 Helper 使用。
- **COrt** — C 语言封装层，链接 Homebrew onnxruntime 库。无内部依赖。

### Key patterns

- **Swift 6.2 approachable concurrency**: Main actor by default. Types annotated `@MainActor` when UI-bound; actors for mutable background state (`SwiftExecutor`, `SmartRouter`, `RAGEngine`).
- **UI state**: `@Observable` classes (`AppState`, `SessionManager`, `ConversationEngine`) injected via `@Environment`.
- **Streaming**: `LLMBackend` protocol returns `AsyncStream<String>`. `ConversationEngine.beginStreamingResponse()` creates a placeholder message, tokens accumulate via `appendStreamToken()`.
- **Tools**: `MCPTool` protocol — each tool has a `ToolDefinition` and async `execute()` method. Registration via `MCPToolRegistry`.
- **Floating panel**: Non-activating `NSPanel` with `.hudWindow` material, summoned by `Option+Space` (Carbon `RegisterEventHotKey`).
- **RAG**: Simple keyword-index with TF-IDF scoring. No vector embedding dependency.

### Permissions required

Accessibility (AX API), Screen Recording (ScreenCaptureKit), Microphone (voice), Apple Events (automation). Entitlements in `Resources/entitlements.plist`.

## Tests

```
Tests/
├── RenJistrolyModelsTests/         # 模型层单元测试
├── RenJistrolySystemBridgeTests/   # 系统桥接单元测试
├── RenJistrolyIntelligenceTests/   # 智能层单元测试
├── RenJistrolyCapabilityTests/     # 能力层单元测试
├── RenJistrolyConversationTests/   # 会话引擎单元测试
├── RenJistrolyTests/               # 跨模块综合集成测试
├── SecurityTests/                  # 安全红队测试（数据外泄/会话劫持/工具注入）
├── PerformanceTests/               # 性能基准测试（动作引擎/上下文捕获/内存/模式管理）
├── RegressionTests/                # 回归测试套件（跨模块/升级迁移/CI 测试计划/测试矩阵）
├── LongRunningTests/               # 长时运行与稳定性测试
├── UITests/                        # UI 自动化测试（点击精度/屏幕读取/窗口管理）
├── HumanInteractionTests/          # 人机交互测试（模式切换/信任流程/错误恢复）
├── IntegrationTests/               # 集成测试基类
├── Mocks/                          # Mock 基础设施 (MockActionEngine/MockModeManager/MockScreenCapture)
└── RenJistrolyTestPlans/           # CI 测试计划与测试矩阵
```

```bash
# Run specific test suites
swift test --target RenJistrolyModelsTests
swift test --target RenJistrolySystemBridgeTests
swift test --target RenJistrolyIntelligenceTests
swift test --target RenJistrolyCapabilityTests
swift test --target RenJistrolyConversationTests

# Specialized test suites
swift test --target SecurityTests        # Security red team tests
swift test --target PerformanceTests     # Performance benchmarks
swift test --target RegressionTests      # Regression test suite
swift test --target LongRunningTests     # Long-running stability tests
swift test --target RenJistrolyTests     # Comprehensive cross-module tests

# UI and human interaction tests (requires display + Accessibility permission)
swift test --target UITests              # UI automation tests
```
