# RenJistroly 项目文件清单

> 生成日期: 2026-06-19
> 统计基于: `.swift` 源文件 + 文档 + 配置

---

## 概览

| 类别 | 文件数 | 代码行数 |
|------|-------|---------|
| Sources (.swift) | 232 | 61,566 |
| Tests (.swift) | 159 | 36,441 |
| 文档 | 30 | — |
| 脚本 | 13 | — |
| **合计 (Swift)** | **391** | **98,007** |

---

## 一、Sources — 源代码 (232 文件, 61,566 行)

### RenJistrolyModels (38 文件, 8,543 行)
核心数据模型与类型定义。

- `ActionModels.swift`
- `AgentEvent.swift`
- `AgentEventBus.swift`
- `AgentSystems.swift`
- `AppState.swift`
- `BrowserState.swift`
- `BusinessScenarioModels.swift`
- `ComputerUseModels.swift`
- `ComputerUsePolicyModels.swift`
- `ComputerUseState.swift`
- `ContextModels.swift`
- `Conversation.swift`
- `DesktopContext.swift`
- `DevMode.swift`
- `ExecutionPlan.swift`
- `ExecutiveUXModels.swift`
- `FinderState.swift`
- `FoundationModels.swift`
- `HotkeyConfig.swift`
- `InteractionTrace.swift`
- `LLMProvider.swift`
- `Logging.swift`
- `Message.swift`
- `NativeAccessibilityModels.swift`
- `OCRTypes.swift`
- `Permissions.swift`
- `ProjectContext.swift`
- `Protocols.swift`
- `ProviderConfig.swift`
- `ProviderProtocols.swift`
- `RoleScenarioGuards.swift`
- `ScenarioAuditModels.swift`
- `SkillsAndEval.swift`
- `TaskRouting.swift`
- `ToolSafety.swift`
- `TrustMechanisms.swift`
- `VoiceInputConfig.swift`
- `VoiceModels.swift`

### RenJistrolySystemBridge (74 文件, 13,168 行)
系统桥接层 — 最大模块，涵盖无障碍、语音、OCR、权限、屏幕捕获、安全等。

- `AccessibilityBridge.swift`
- `AccessibilityContextProvider.swift`
- `ActionSafety.swift`
- `AppDrivers.swift`
- `AppleScriptBridge.swift`
- `AppleSpeechProvider.swift`
- `AudioCapture.swift`
- `AuditExporter.swift`
- `AutoRollback.swift`
- `AXNotificationObserver.swift`
- `AXSettling.swift`
- `CertificateManager.swift`
- `ChatwootBridge.swift`
- `ClaudeCodeBridge.swift`
- `CodebaseMemoryBridge.swift`
- `CommandAllowlist.swift`
- `CommandScopeLimiter.swift`
- `ComputerUseObserver.swift`
- `ContractClauseMatcher.swift`
- `CredentialSanitizer.swift`
- `CTCDecoder.swift`
- `CursorController.swift`
- `DBPostProcessor.swift`
- `DeveloperAgentTaskStore.swift`
- `DisclaimerTemplate.swift`
- `ElementRegistry.swift`
- `EntityMatcher.swift`
- `EnvironmentDistinguisher.swift`
- `EvidenceReferencer.swift`
- `FileOperationSafety.swift`
- `FocusGuard.swift`
- `FocusWithoutRaise.swift`
- `FoundationServices.swift`
- `HealthMonitor.swift`
- `HighRiskOperationConfirmer.swift`
- `InputStrategy.swift`
- `LocalOnlyPolicy.swift`
- `LocalSecretScanner.swift`
- `LogProcessingIsolator.swift`
- `LogSanitizer.swift`
- `MacOSSpeechRecognizer.swift`
- `MacOSTextToSpeech.swift`
- `MDMConfirmer.swift`
- `NativeSpeechTranscriber.swift`
- `NetworkDiagnostic.swift`
- `OCREngineResolver.swift`
- `OCRService.swift`
- `OpenAIAPIKeyStore.swift`
- `OrtImageHelper.swift`
- `PermissionCenter.swift`
- `PermissionPolicy.swift`
- `PPOCRv6Service.swift`
- `ReadOnlyEvidenceMode.swift`
- `RecipientConfirmer.swift`
- `RecoveryDecider.swift`
- `RedlineDiffComparator.swift`
- `RegulationTimelinessMarker.swift`
- `RemoteAssistConsent.swift`
- `RiskScorer.swift`
- `ScreenCaptureBridge.swift`
- `ScreenContextProvider.swift`
- `ScreenDiffVerifier.swift`
- `ScreenStreamProvider.swift`
- `SemanticChangeDetector.swift`
- `SensitiveConfigReadOnly.swift`
- `ShellExecutor.swift`
- `SkyLightEventPost.swift`
- `SystemDictationBridge.swift`
- `SystemInfoReader.swift`
- `SystemSettingSnapshot.swift`
- `SystemTextToSpeech.swift`
- `TerminalTaskStore.swift`
- `UpdateManager.swift`
- `VoiceHotkeyManager.swift`

### RenJistrolyCapability (27 文件, 15,155 行)
MCP 服务器工具、代码引擎、系统控制、安全网关。

- `MCPClient/MCPClient.swift`
- `MCPServer/ToolSafetyGateway.swift`
- `MCPServer/MCPToolRegistry.swift`
- `MCPServer/SafetyAuditStore.swift`
- `MCPServer/ComputerUseEvalSuite.swift`
- `MCPServer/AppIntegration/AppIntegrationTools.swift`
- `MCPServer/CodeEngine/ChangedFilesTool.swift`
- `MCPServer/CodeEngine/CodeTools.swift`
- `MCPServer/CodeEngine/DeveloperToolbox.swift`
- `MCPServer/CodeEngine/DeveloperTools.swift`
- `MCPServer/CodeEngine/EngineerScenarioTools.swift`
- `MCPServer/CodeEngine/LSPTool.swift`
- `MCPServer/CodeEngine/QuickOpenTool.swift`
- `MCPServer/SystemControl/AppDriverTools.swift`
- `MCPServer/SystemControl/BusinessScenarioTools.swift`
- `MCPServer/SystemControl/ClaudeAgentTool.swift`
- `MCPServer/SystemControl/ComputerUseRuntime.swift`
- `MCPServer/SystemControl/ControlTools.swift`
- `MCPServer/SystemControl/CursorNeutralInput.swift`
- `MCPServer/SystemControl/DesignerTools.swift`
- `MCPServer/SystemControl/OCRTool.swift`
- `MCPServer/SystemControl/ProductManagerTools.swift`
- `MCPServer/SystemControl/ScenarioTools.swift`
- `MCPServer/SystemControl/SystemTools.swift`
- `RoleScenarioSafetyService.swift`
- `Skills/SkillRegistry.swift`
- `Skills/SkillScanner.swift`

### RenJistrolyIntelligence (27 文件, 9,459 行)
LLM 后端、智能路由、RAG、Agent 编排。

- `AgentOrchestrator/AgentOrchestrator.swift`
- `AgentOrchestrator/LMCache.swift`
- `AgentOrchestrator/MultiAgentTaskBoard.swift`
- `AgentOrchestrator/PlanGenerator.swift`
- `AgentOrchestrator/SmartRouter.swift`
- `AgentOrchestrator/TaskRouter.swift`
- `AppInstructionLibrary.swift`
- `AssistantSessionController.swift`
- `ComputerUsePlanner.swift`
- `ContextStore.swift`
- `LLMBackend/BuildErrorAnalyzer.swift`
- `LLMBackend/ClaudeCodeCLI.swift`
- `LLMBackend/CloudAnthropic.swift`
- `LLMBackend/CloudGoogle.swift`
- `LLMBackend/CloudOpenAI.swift`
- `LLMBackend/CloudOpenAICompatible.swift`
- `LLMBackend/CodexCLIBackend.swift`
- `LLMBackend/CommandParser.swift`
- `LLMBackend/LocalMLX.swift`
- `LLMBackend/LocalModelManager.swift`
- `LLMBackend/OpenAICompatibleChatProvider.swift`
- `LocalActionParser.swift`
- `LocalQuickResponder.swift`
- `ModelActionPlanner.swift`
- `ProviderRouter.swift`
- `RAGEngine/RAGEngine.swift`
- `RealtimeProviders.swift`

### RenJistrolyUI (22 文件, 5,655 行)
SwiftUI 界面 — 主窗口、浮动面板、菜单栏、组件。

- `ActionAuditView.swift`
- `AssistantRootView.swift`
- `ContextDashboard.swift`
- `FoundationCenterView.swift`
- `MainTabView.swift`
- `ModeControlPanel.swift`
- `PermissionsView.swift`
- `SettingsPanel.swift`
- `Components/AgentConsoleView.swift`
- `Components/MessageBubble.swift`
- `Components/OnboardingView.swift`
- `Components/PlanCard.swift`
- `Components/StreamingMarkdownText.swift`
- `Components/SubmitTextInput.swift`
- `Components/TraceConsolePanel.swift`
- `Components/VoiceWaveformView.swift`
- `FloatingPanel/CompactAssistantView.swift`
- `FloatingPanel/FloatingPanelView.swift`
- `FloatingPanel/FloatingPanelWindow.swift`
- `MainWindow/MainWindowView.swift`
- `MenuBar/MenuBarExtraView.swift`
- `MenuBar/MenuBarView.swift`

### RenJistrolyProductIdentity (13 文件, 881 行)
产品身份、安全策略、读模式强制、状态机。

- `ActionVerificationEngine.swift`
- `AuditHighRiskAction.swift`
- `CancelMechanism.swift`
- `ContextAcquisitionManager.swift`
- `MouseGuard.swift`
- `OperatingScope.swift`
- `PolicyLayer.swift`
- `ProductIdentity.swift`
- `ReadOnlyModeEnforcer.swift`
- `ScreenStabilityMonitor.swift`
- `StateMachineManager.swift`
- `TestMatrixPlanner.swift`
- `WindowMatchValidator.swift`

### RenJistrolyEnterprise (4 文件, 1,232 行)
企业模式、上下文提供方。

- `ActionEngine.swift`
- `ContextProvider.swift`
- `DevContextProvider.swift`
- `ModeManager.swift`

### RenJistrolyApp (4 文件, 1,171 行)
App 入口、热键管理、设置。

- `AppDelegate.swift`
- `HotkeyManager.swift`
- `RenJistrolyApp.swift`
- `SettingsView.swift`

### RenJistrolyHelper (2 文件, 110 行)
Helper (SMAppService / XPC 服务)。

- `HelperEntry.swift`
- `HelperService.swift`

### RenJistrolyXPC (2 文件, 29 行)
XPC 常量与协议定义。

- `XPCConstants.swift`
- `XPCProtocol.swift`

### RenJistrolyBridge (1 文件, 328 行)
桥接入口点。

- `main.swift`

### RenJistrolyGate (1 文件, 140 行)
Gate 入口点。

- `main.swift`

### RenJistrolyMCP (1 文件, 260 行)
MCP 桥接。

- `MCPBridge.swift`

---

## 二、Tests — 测试 (159 文件, 36,441 行)

| 测试组 | 文件数 | 内容 |
|--------|-------|------|
| RenJistrolyModelsTests | 39 | 模型层单元测试（Action, Agent, State, Protocol, Voice 等） |
| RenJistrolyIntelligenceTests | 25 | LLM 后端、路由、RAG、编排器测试 |
| RenJistrolyCapabilityTests | 21 | MCP 工具、安全网关、Skill 扫描测试 |
| RenJistrolySystemBridgeTests | 21 | OCR、Shell、权限、ElementRegistry 等桥接测试 |
| RenJistrolyConversationTests | 14 | 会话引擎、PlanExecutor、TemplateStore 测试 |
| RenJistrolyTests | 7 | 端到端/集成测试（Enterprise, Safety, Bridge） |
| PerformanceTests | 6 | ActionEngine、Context、Memory、ModeManager 基准 |
| RegressionTests | 6 | 核心能力回归、跨模块回归、升级迁移 |
| UITests | 4 | 点击精度、屏幕阅读、窗口管理 |
| SecurityTests | 4 | 数据泄露、会话劫持、工具注入、红队计划 |
| HumanInteractionTests | 3 | 错误恢复、模式切换、信任流 |
| Mocks | 3 | MockActionEngine, MockModeManager, MockScreenCapture |
| LongRunningTests | 2 | 持久化计划、状态机压力 |
| RenJistrolyTestPlans | 3 | CI 测试计划、测试矩阵、升级迁移 |
| IntegrationTests | 1 | 集成测试基类 |

---

## 三、Docs — 文档 (30 文件)

### 架构与设计
- `architecture.md` — 系统架构
- `PRODUCT_ARCHITECTURE.md` — 产品架构
- `directory-structure.md` — 目录结构
- `enterprise-modes.md` — 企业模式
- `distribution.md` — 分发与打包
- `user-roles.md` — 用户角色
- `sounds.md` — 音效设计

### 工程与管理
- `engineering-assessment.md` — 工程评估
- `project-status.md` — 项目状态
- `dependency-audit.md` — 依赖审计
- `complexity-report.md` — 复杂度报告
- `coverage-targets.md` — 覆盖率目标
- `code-review.md` — 代码审查记录
- `bug-inventory.md` — Bug 清单
- `test-dashboard.md` — 测试仪表盘
- `toolchain-check.md` — 工具链检查
- `security.md` — 安全文档
- `REFERENCE_AGENT_STRATEGY.md` — Agent 策略参考

### 迭代记录 (ROUND_*)
- `ROUND_01_ENGINEERING_BASELINE.md`
- `ROUND_02_PRODUCT_ARCHITECTURE.md`
- `ROUND_03_PERMISSION_CENTER.md`
- `ROUND_04_VOICE_INPUT_STABILITY.md`
- `ROUND_05_TEXT_TO_SPEECH.md`
- `ROUND_06_DESKTOP_CONTEXT.md`
- `ROUND_07_TOOL_SAFETY.md`
- `ROUND_08_EXECUTION_PLAN.md`
- `ROUND_09_DEVELOPER_MODE.md`
- `ROUND_10_FLOATING_PANEL_UPGRADE.md`
- `ROUND_11_ENDPOINT_SCENARIOS.md`
- `ROUND_12_PACKAGING_AND_RELEASE.md`

---

## 四、Scripts — 脚本 (13 文件)

| 脚本 | 用途 |
|------|------|
| `build.sh` | 编译构建 |
| `compile_and_run.sh` | 编译并运行 |
| `create_dmg.sh` | 打包 DMG |
| `notarize.sh` | 公证 |
| `package_app.sh` | 应用打包 |
| `launch.sh` | 启动 |
| `setup.sh` | 环境初始化 |
| `test.sh` | 运行测试 |
| `run-all-tests.sh` | 全量测试 |
| `coverage.sh` | 覆盖率报告 |
| `lint.sh` | 代码风格检查 |
| `stability_check.sh` | 稳定性检查 |
| `convert_ppocr.py` | PPOCR 模型转换 (Python) |

---

## 五、配置与基础设施

### 根级配置
| 文件 | 说明 |
|------|------|
| `Package.swift` | SwiftPM 包清单 |
| `.swiftformat` | Swift 格式化规则 |
| `.editorconfig` | 跨编辑器文件格式配置 |
| `.gitignore` | Git 忽略规则 |
| `.mcp.json` | MCP 服务器配置 |
| `version.env` | 版本号定义 |
| `CLAUDE.md` | Claude Code 项目指令 |
| `CHANGELOG.md` | 变更日志 |
| `CONTRIBUTING.md` | 贡献指南 |
| `MAINTAINERS.md` | 维护者说明 |
| `README.md` | 项目简介 |
| `README-CICD.md` | CI/CD 说明 |

### GitHub
| 文件 | 说明 |
|------|------|
| `.github/workflows/ci.yml` | CI 流水线 |
| `.github/workflows/release.yml` | 发布流水线 |
| `.github/dependabot.yml` | 依赖自动更新 |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR 模板 |
| `.github/ISSUE_TEMPLATE/bug_report.md` | Bug 报告模板 |
| `.github/ISSUE_TEMPLATE/feature_request.md` | 功能请求模板 |

### .claude
| 文件/目录 | 说明 |
|----------|------|
| `.claude/skills/` | Claude Code skills |
| `.claude/mcp.json` | MCP 配置 |
| `.claude/settings.local.json` | 本地设置 |

---

## 六、Resources — 资源

| 文件 | 说明 |
|------|------|
| `Resources/AppIcon.svg` | 应用图标 (SVG) |
| `Resources/AppIcon.iconset/Contents.json` | 图标集描述 |
| `Resources/Assets.xcassets/Contents.json` | 资源目录描述 |
| `Resources/entitlements.plist` | Entitlements |
| `Resources/Info.plist` | 应用 Info |
| `Resources/sounds/.gitkeep` | 音效占位 |

## 七、Frameworks — 外部依赖

| 文件 | 说明 |
|------|------|
| `Frameworks/libonnxruntime.1.26.0.dylib` | ONNX Runtime |
| `Frameworks/libonnxruntime.1.dylib` | ONNX Runtime (symlink) |

## 八、HelperConfig — Helper 配置

| 文件 | 说明 |
|------|------|
| `HelperConfig/com.renjistroly.helper.plist` | SMAppService plist |
| `HelperConfig/Info.plist` | Helper Info |

## 九、其他目录

| 目录 | 说明 |
|------|------|
| `_archived/` | 归档旧代码（mac-voice-assistant, renjistroly） |
| `_vendored/` | 第三方依赖（aisuite, chatwoot） |
| `build/` | 构建产物 |
| `stability_logs/` | 稳定性测试日志 |

---

## 附录: 模块占比

| 模块 | Swift 文件数 | 代码行数 | 行数占比 |
|------|------------|---------|---------|
| RenJistrolySystemBridge | 74 | 13,168 | 21.4% |
| RenJistrolyCapability | 27 | 15,155 | 24.6% |
| RenJistrolyIntelligence | 27 | 9,459 | 15.4% |
| RenJistrolyModels | 38 | 8,543 | 13.9% |
| RenJistrolyUI | 22 | 5,655 | 9.2% |
| RenJistrolyConversation | 11 | 4,425 | 7.2% |
| RenJistrolyEnterprise | 4 | 1,232 | 2.0% |
| RenJistrolyApp | 4 | 1,171 | 1.9% |
| RenJistrolyProductIdentity | 13 | 881 | 1.4% |
| RenJistrolyBridge | 1 | 328 | 0.5% |
| RenJistrolyMCP | 1 | 260 | 0.4% |
| RenJistrolyGate | 1 | 140 | 0.2% |
| RenJistrolyHelper | 2 | 110 | 0.2% |
| RenJistrolyXPC | 2 | 29 | 0.0% |
| **合计** | **232** | **61,566** | **100%** |

---

*Generated by `docs/project-inventory.md` via inventory automation.*
