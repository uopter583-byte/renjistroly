# Changelog

## [0.2.0] - 2026-06-19

### 新增：7 个新模块（80+ 新文件）

#### RenJistrolyEnterprise — 企业级安全模式
- 10 种操作模式：只读 / 建议 / 可执行 / 高风险确认 / 禁止鼠标 / 本地模式 / 敏感 App 防护 / 自动遮蔽 / 策略锁定 / 审计导出
- `ModeManager`：模式切换、模式栈、状态转换守卫
- `ActionEngine`：预览→确认→执行→验证→审计 五阶段操作引擎（5 级风险 + 6 种状态）
- `ContextProvider`：屏幕上下文快照（Screen / App / Window / Cursor / Dialog）
- `DevContextProvider`：开发者上下文采集

#### RenJistrolyProductIdentity — 产品定位与合规层
- "Your Mac Operating Agent" 产品定位，明确能力边界（观察 / 读写 / 自动化 / 自主）
- `PolicyLayer`：4 级策略（最低 / 标准 / 严格 / 锁定），策略规则引擎
- `ActionVerificationEngine`：操作验证与结果比对
- `ReadOnlyModeEnforcer`、`MouseGuard`、`OperatingScope` 安全守卫
- `AuditHighRiskAction`：高风险操作审计追踪
- `CancelMechanism`、`StateMachineManager`、`ScreenStabilityMonitor`、`WindowMatchValidator`
- `TestMatrixPlanner`：测试矩阵规划（精度 / 稳定性 / 安全 / 恢复 / 边缘 / 性能）

#### RenJistrolyConversation — 对话引擎扩展
- `ToolExecutionService`：工具执行编排 / 重试 / 回滚
- `PlanExecutor`：多步计划执行引擎（依赖解析 + 并行执行）
- `DeveloperLoop`：开发者交互循环（诊断→修复→验证）
- `AgentSkillRegistry`：Agent 技能注册与动态加载
- `VoiceSessionManager`：语音会话生命周期管理
- `DesktopContextCollector`：桌面上下文持续采集
- `WorkflowMemoryStore`、`WorkflowTemplateStore`：工作流持久化

#### RenJistrolyIntelligence — 智能层扩展
- `ProviderRouter`：多 Provider 智能路由
- `ContextStore`：10 维上下文存储（时间线 / App / 窗口 / 屏幕 / 文件 / 剪贴板 / 输入法 / 网络 / 系统 / 用户）
- `ComputerUsePlanner`：Computer Use 场景规划与执行
- `ModelActionPlanner`、`LocalActionParser`、`LocalQuickResponder`：本地快速响应
- `AppInstructionLibrary`：应用操作指令库
- `AssistantSessionController`：助手会话控制
- `RealtimeProviders`：实时 Provider 支持
- `AgentOrchestrator` 增强：`LMCache`（LLM 响应缓存）、`MultiAgentTaskBoard`、`TaskRouter`
- `LLMBackend` 扩展：`CodexCLIBackend`、`CommandParser`、`LocalModelManager`、`OpenAICompatibleChatProvider`、`CloudGoogle`

#### RenJistrolyModels — 模型层大幅扩展
- 安全模型：`ToolSafety`（5 级风险评估）、`RoleScenarioGuards`、`ComputerUsePolicyModels`（11 条安全规则）、`ScenarioAuditModels`（17 个场景域）、`TrustMechanisms`
- 状态模型：`ComputerUseState`、`ComputerUseModels`、`DesktopContext`、`DevMode`、`ExecutionPlan`
- 场景模型：`BusinessScenarioModels`（客服会话 / 话术策略 / 情绪分析）、`ActionModels`
- 系统模型：`NativeAccessibilityModels`、`FinderState`、`BrowserState`、`OCRTypes`、`Permissions`
- 事件模型：`AgentEvent`、`AgentEventBus`、`AgentSystems`、`InteractionTrace`
- 配置模型：`ProviderConfig`、`ProviderProtocols`、`HotkeyConfig`、`VoiceInputConfig`、`VoiceModels`
- UX 模型：`ExecutiveUXModels`（能力描述层）、`ContextModels`（App / Window / Cursor / Dialog 上下文）
- 其他：`TaskRouting`、`SkillsAndEval`、`Logging`

#### RenJistrolySystemBridge — 系统桥接层大幅扩展（70+ 新文件）
- 安全合规：`CredentialSanitizer`、`LocalSecretScanner`、`ReadOnlyEvidenceMode`、`EvidenceReferencer`、`FileOperationSafety`、`ActionSafety`、`RecipientConfirmer`、`HighRiskOperationConfirmer`、`MDMConfirmer`、`ContractClauseMatcher`、`DisclaimerTemplate`、`RegulationTimelinessMarker`、`RemoteAssistConsent`、`CertificateManager`
- 权限管理：`PermissionCenter`、`PermissionPolicy`、`SensitiveConfigReadOnly`、`LocalOnlyPolicy`、`CommandAllowlist`、`CommandScopeLimiter`
- 审计日志：`AuditExporter`、`LogSanitizer`、`LogProcessingIsolator`
- 屏幕与 OCR：`PPOCRv6Service`、`OCREngineResolver`、`OCRService`、`OrtImageHelper`、`CTCDecoder`、`DBPostProcessor`、`ScreenContextProvider`、`ScreenStreamProvider`、`ScreenDiffVerifier`、`SemanticChangeDetector`
- 无障碍增强：`AccessibilityContextProvider`、`AXNotificationObserver`、`AXSettling`、`ElementRegistry`、`EntityMatcher`、`EnvironmentDistinguisher`
- 鼠标/输入：`CursorController`、`InputStrategy`、`FocusGuard`、`FocusWithoutRaise`、`SkyLightEventPost`、`AutoRollback`
- 应用集成：`AppDrivers`、`ChatwootBridge`、`ClaudeCodeBridge`、`CodebaseMemoryBridge`、`SystemDictationBridge`
- 系统监控：`HealthMonitor`、`ComputerUseObserver`、`NetworkDiagnostic`、`SystemInfoReader`、`UpdateManager`、`VoiceHotkeyManager`、`SystemSettingSnapshot`、`SystemTextToSpeech`
- 开发者工具：`DeveloperAgentTaskStore`、`TerminalTaskStore`、`RedlineDiffComparator`
- 基础服务：`FoundationServices`、`RiskScorer`、`RecoveryDecider`、`OpenAIAPIKeyStore`

#### RenJistrolyCapability — MCP 工具集大幅扩展
- 新工具（20+）：`BusinessScenarioTools`、`DesignerTools`、`ProductManagerTools`、`ScenarioTools`、`AppDriverTools`、`OCRTool`、`CursorNeutralInput`、`ComputerUseRuntime`、`LSPTool`、`QuickOpenTool`、`EngineerScenarioTools`、`DeveloperToolbox`、`ChangedFilesTool`
- 技能系统：`SkillRegistry`、`SkillScanner`（Skill 协议 + 注册 + 扫描 + 匹配）
- 安全网关：`ToolSafetyGateway`（动态风险评估 + 策略决策）、`SafetyAuditStore`（审计持久化）
- `RoleScenarioSafetyService`：基于用户角色的场景安全策略
- `ComputerUseEvalSuite`：Computer Use 评估套件（覆盖率 / 稳定性 / 安全）

#### 测试基础设施
- 新增 120+ 测试文件全面覆盖：
  - **单元测试**：`RenJistrolyModelsTests` / `RenJistrolyCapabilityTests` / `RenJistrolyIntelligenceTests` / `RenJistrolyConversationTests` / `RenJistrolySystemBridgeTests` / `RenJistrolyTests`
  - **回归测试**：`RegressionTests/`（CoreCapabilityRegression、CrossModuleRegression、UpgradeMigration、TestMatrix）
  - **性能基准**：`PerformanceTests/`（ActionEngine / ContextCapture / ModeManager / Memory Benchmarks）
  - **安全测试**：`SecurityTests/`（DataExfil、SessionHijack、ToolInjection、RedTeam 计划）
  - **长时/压力测试**：`LongRunningTests/`（StateMachineStress、Longevity 计划）
  - **Mock 基础设施**：`Mocks/`（MockModeManager、MockScreenCapture）

### MCP 工具系统（25 工具 → 94+ 工具）
- 工具数量从 25 个扩展到 94+ 个，覆盖企业级场景
- 新增跨应用工作流、多步执行计划、开发者 LSP 集成

### 工具安全升级
- 10 种安全模式（之前 3 种预设策略扩展为完整模式体系）
- 5 级风险评估：trivial / low / medium / high / critical
- 操作引擎：预览→确认→执行→验证→审计 五阶段
- 安全网关：`ToolSafetyGateway` + `SafetyAuditStore`
- 策略层：4 级策略（最低 / 标准 / 严格 / 锁定）
- 敏感数据防护：凭证清理、密钥扫描、只读证据模式

### 企业用户角色场景（12 种用户场景域）
- 启动/权限 / 语音对话 / 屏幕理解 / App 控制 / 控件操作 / 文件 Finder / 浏览器 / 微信邮件 / 多终端任务 / 开发工作流 / 办公生产力 / 娱乐媒体
- 安全隐私 / 自优化 / 财务 / HR / 管理者 场景域

### 上下文感知系统（10 维上下文）
- 时间线 / 当前 App / 窗口 / 屏幕 / 文件 / 剪贴板 / 输入法 / 网络 / 系统 / 用户
- 持续桌面上下文采集 + 上下文快照 + 语义变化检测

### 当前开发线
- 新增模块为半完成状态（标记为 Enterprise / ProductIdentity / Bridge / Gate / Helper / XPC）
- PolicyLayer、AuditHighRiskAction、TestMatrixPlanner 处于功能预研阶段
- COrt（ONNX Runtime C 桥接）为 PP-OCRv6 本地推理预留

## 0.1.0 — Initial Release

**发布时间**：2026-06-14

### 核心能力
- 语音交互：按住 Option+Space 说话，松开自动发送；支持连续语音模式
- 多模式浮窗：NSPanel HUD 浮窗 + 完整主窗口 + 菜单栏入口
- LLM 后端：Claude Code CLI（默认）、Claude API、OpenAI 兼容、本地 MLX
- 语音转写：Apple Speech / SFSpeechRecognizer 语音识别
- TTS 语音合成：AVSpeechSynthesizer

### MCP 工具系统 (25 工具)
- **系统控制 (13)**：OpenApp、SystemInfo、RunningApps、ClickElement、ActivateMenu、TypeText、ReadFocusedText、PressKey、Scroll、WindowList、FocusWindow、Drag、UITree
- **代码工具 (6)**：GitStatus、GitLog、ReadFile、ListFiles、WriteFile、ShellCommand
- **开发者工具 (3)**：SwiftBuild、SwiftTest、ProjectInfo
- **场景工具 (3)**：PolishReplace（润色替换）、ExplainSelected（解释）、ReadScreen（读屏）
- **智能工具 (4)**：ClaudeAgent（多步代理）、PlanGenerator（执行计划）、BuildErrorAnalyzer（构建分析）

### 工具安全
- 三级风险评估：Low / Medium / High
- 三种策略预设：Default（低自动）、Permissive（低中自动）、Strict（全部确认）
- 确认弹窗：高风险操作需用户批准，显示工具名/风险等级/操作摘要
- 审查日志：记录所有工具执行结果

### 执行计划
- LLM 自动拆分复杂任务为多步计划
- 逐步执行，显示进度
- 全部批准 / 逐步批准模式

### 开发者模式
- 一键构建（swift build）
- 一键测试（swift test）
- LLM 错误分析
- 构建状态实时显示

### 场景闭环
- 润色选中文字（LLM 润色 → 自动替换）
- 解释选中内容（代码/文字/翻译）
- 读取屏幕内容（前台应用/窗口/焦点/UI 树）

### 浮窗体验
- 脉冲状态灯（按状态变色）
- 实时语音波形（7 段正弦动画）
- 语音转录实时预览
- 状态文字动画过渡

### 系统要求
- macOS 15.0+
- Apple Silicon (arm64)
