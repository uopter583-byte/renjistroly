# RenJistroly 目录结构

> 生成时间: 2026-06-19
> 工具: ds-mapper

```
RenJistroly/
├── Sources/
│   ├── RenJistrolyApp/                    # 应用入口与主循环
│   │   ├── RenJistrolyApp.swift               # 应用入口 @main
│   │   ├── AppDelegate.swift                  # NSApp 委托与生命周期
│   │   ├── HotkeyManager.swift                # 全局快捷键管理(Option+Space)
│   │   └── SettingsView.swift                 # 设置界面
│   │
│   ├── RenJistrolyUI/                     # SwiftUI 界面层
│   │   ├── AssistantRootView.swift            # 助手根视图
│   │   ├── FoundationCenterView.swift         # 底层能力中心视图
│   │   ├── PermissionsView.swift              # 权限申请视图
│   │   ├── SettingsPanel.swift                # 设置面板
│   │   ├── ActionAuditView.swift              # 操作审计视图
│   │   ├── ContextDashboard.swift             # 上下文仪表盘
│   │   ├── MainTabView.swift                  # 主导航标签视图
│   │   ├── ModeControlPanel.swift             # 安全模式控制面板
│   │   ├── MainWindow/
│   │   │   └── MainWindowView.swift           # 沉浸式主窗口
│   │   ├── FloatingPanel/
│   │   │   ├── FloatingPanelWindow.swift      # NSPanel 非激活面板
│   │   │   ├── FloatingPanelView.swift        # 浮动面板内容视图
│   │   │   └── CompactAssistantView.swift     # 紧凑模式助手视图
│   │   ├── MenuBar/
│   │   │   ├── MenuBarExtraView.swift         # 菜单栏额外图标
│   │   │   └── MenuBarView.swift              # 菜单栏下拉菜单
│   │   └── Components/
│   │       ├── AgentConsoleView.swift         # 代理控制台日志
│   │       ├── MessageBubble.swift            # 消息气泡组件
│   │       ├── OnboardingView.swift           # 新手引导视图
│   │       ├── PlanCard.swift                 # 执行计划卡片
│   │       ├── StreamingMarkdownText.swift    # 流式 Markdown 渲染
│   │       ├── SubmitTextInput.swift          # 文字输入提交框
│   │       ├── TraceConsolePanel.swift        # 追踪控制台面板
│   │       └── VoiceWaveformView.swift        # 语音波形动画
│   │
│   ├── RenJistrolyConversation/           # 对话引擎与管理
│   │   ├── ConversationEngine.swift          # 对话核心引擎
│   │   ├── SessionManager.swift              # 会话 CRUD 持久化
│   │   ├── ContextCompiler.swift             # 项目上下文编译
│   │   ├── DesktopContextCollector.swift      # 桌面上下文收集
│   │   ├── DeveloperLoop.swift               # 开发者交互循环
│   │   ├── PlanExecutor.swift                # 计划执行器
│   │   ├── ToolExecutionService.swift        # MCP 工具执行服务
│   │   ├── AgentSkillRegistry.swift          # 代理技能注册表
│   │   ├── WorkflowMemoryStore.swift         # 工作流记忆存储
│   │   ├── WorkflowTemplateStore.swift       # 工作流模板存储
│   │   └── VoiceSessionManager.swift         # 语音会话管理
│   │
│   ├── RenJistrolyCapability/             # MCP 能力与工具层
│   │   ├── RoleScenarioSafetyService.swift   # 角色场景安全服务
│   │   ├── MCPClient/
│   │   │   └── MCPClient.swift               # 外部 MCP 服务器客户端
│   │   ├── MCPServer/
│   │   │   ├── MCPToolRegistry.swift         # MCP 工具注册中心
│   │   │   ├── ToolSafetyGateway.swift       # 工具安全门禁
│   │   │   ├── SafetyAuditStore.swift        # 安全审计日志存储
│   │   │   ├── ComputerUseEvalSuite.swift    # Computer Use 评测套件
│   │   │   ├── CodeEngine/
│   │   │   │   ├── EngineerScenarioTools.swift   # 工程师场景工具集
│   │   │   │   ├── DeveloperToolbox.swift        # 开发者工具箱
│   │   │   │   ├── DeveloperTools.swift          # 开发者工具封装
│   │   │   │   ├── CodeTools.swift               # 代码编辑工具
│   │   │   │   ├── ChangedFilesTool.swift        # 变更文件查询
│   │   │   │   ├── QuickOpenTool.swift           # 快速文件搜索
│   │   │   │   └── LSPTool.swift                 # LSP 语言服务
│   │   │   └── SystemControl/
│   │   │       ├── ScenarioTools.swift          # 场景工具基类
│   │   │       ├── BusinessScenarioTools.swift  # 商务场景工具
│   │   │       ├── DesignerTools.swift          # 设计师场景工具
│   │   │       ├── ProductManagerTools.swift    # 产品经理场景工具
│   │   │       ├── SystemTools.swift            # 系统控制工具
│   │   │       ├── ControlTools.swift           # 通用控制工具
│   │   │       ├── AppDriverTools.swift         # 应用驱动工具
│   │   │       ├── ComputerUseRuntime.swift     # Computer Use 运行时
│   │   │       ├── ClaudeAgentTool.swift        # Claude Agent 桥接
│   │   │       ├── OCRTool.swift                # OCR 文字识别工具
│   │   │       └── CursorNeutralInput.swift     # 光标中性输入
│   │   └── Skills/
│   │       ├── SkillRegistry.swift             # 技能注册管理
│   │       └── SkillScanner.swift              # 技能文件扫描
│   │
│   ├── RenJistrolyIntelligence/            # LLM 后端与智能路由
│   │   ├── ProviderRouter.swift               # 提供商路由选择
│   │   ├── ModelActionPlanner.swift           # 模型动作规划
│   │   ├── LocalActionParser.swift            # 本地动作解析
│   │   ├── LocalQuickResponder.swift          # 本地快速响应
│   │   ├── ComputerUsePlanner.swift           # Computer Use 规划
│   │   ├── ContextStore.swift                 # 应用上下文存储
│   │   ├── AppInstructionLibrary.swift        # 应用指令库
│   │   ├── AssistantSessionController.swift   # 助手会话控制
│   │   ├── RealtimeProviders.swift            # 实时能力提供商
│   │   ├── LLMBackend/
│   │   │   ├── CloudAnthropic.swift           # Anthropic Claude 后端
│   │   │   ├── CloudOpenAI.swift              # OpenAI 后端
│   │   │   ├── CloudOpenAICompatible.swift    # OpenAI 兼容后端
│   │   │   ├── CloudGoogle.swift              # Google Gemini 后端
│   │   │   ├── LocalMLX.swift                 # 本地 MLX 推理
│   │   │   ├── LocalModelManager.swift        # 本地模型管理
│   │   │   ├── ClaudeCodeCLI.swift            # Claude Code CLI
│   │   │   ├── CodexCLIBackend.swift          # Codex CLI 后端
│   │   │   ├── BuildErrorAnalyzer.swift       # 构建错误分析
│   │   │   ├── CommandParser.swift            # 命令解析器
│   │   │   └── OpenAICompatibleChatProvider.swift # 通用聊天提供商
│   │   ├── AgentOrchestrator/
│   │   │   ├── AgentOrchestrator.swift        # 多代理编排器
│   │   │   ├── SmartRouter.swift              # 智能复杂度路由
│   │   │   ├── TaskRouter.swift               # 任务分派路由
│   │   │   ├── PlanGenerator.swift            # 计划生成器
│   │   │   ├── MultiAgentTaskBoard.swift      # 多代理任务看板
│   │   │   └── LMCache.swift                  # 语言模型缓存
│   │   └── RAGEngine/
│   │       └── RAGEngine.swift                # 关键词索引检索引擎
│   │
│   ├── RenJistrolyEnterprise/              # 企业级功能层
│   │   ├── ModeManager.swift                 # 10 种安全模式管理
│   │   ├── ActionEngine.swift                # 操作执行引擎
│   │   ├── ContextProvider.swift             # 上下文提供器
│   │   └── DevContextProvider.swift          # 开发上下文提供器
│   │
│   ├── RenJistrolyProductIdentity/         # 产品定位与安全门禁
│   │   ├── ProductIdentity.swift             # 产品定位定义
│   │   ├── PolicyLayer.swift                 # 策略层框架
│   │   ├── OperatingScope.swift              # 操作范围限定
│   │   ├── ReadOnlyModeEnforcer.swift        # 只读模式强制
│   │   ├── CancelMechanism.swift             # 全局取消机制
│   │   ├── MouseGuard.swift                  # 防止抢鼠标保护
│   │   ├── WindowMatchValidator.swift        # 窗口匹配校验
│   │   ├── ScreenStabilityMonitor.swift      # 屏幕稳定监控
│   │   ├── ContextAcquisitionManager.swift   # 上下文获取管理
│   │   ├── ActionVerificationEngine.swift    # 操作验证引擎
│   │   ├── StateMachineManager.swift         # 状态机管理器
│   │   ├── AuditHighRiskAction.swift         # 高风险操作审计
│   │   └── TestMatrixPlanner.swift           # 测试矩阵规划
│   │
│   ├── RenJistrolyModels/                  # 核心数据模型(零依赖)
│   │   ├── Message.swift                     # 消息模型
│   │   ├── Conversation.swift                # 对话模型
│   │   ├── ActionModels.swift                # 操作动作模型
│   │   ├── AppState.swift                    # 应用状态模型
│   │   ├── ComputerUseModels.swift           # Computer Use 模型
│   │   ├── ComputerUseState.swift            # Computer Use 状态
│   │   ├── ComputerUsePolicyModels.swift     # Computer Use 策略
│   │   ├── DesktopContext.swift              # 桌面上下文模型
│   │   ├── ProjectContext.swift              # 项目上下文模型
│   │   ├── ContextModels.swift               # 通用上下文模型
│   │   ├── FoundationModels.swift            # 基础数据类型
│   │   ├── Protocols.swift                   # 通用协议定义
│   │   ├── ProviderProtocols.swift           # LLM 提供商协议
│   │   ├── LLMProvider.swift                 # LLM 提供商枚举
│   │   ├── ProviderConfig.swift              # 提供商配置
│   │   ├── ExecutiveUXModels.swift           # 高管友好交互模型
│   │   ├── TrustMechanisms.swift             # 跨角色信任机制
│   │   ├── RoleScenarioGuards.swift          # 角色场景守卫
│   │   ├── ScenarioAuditModels.swift         # 场景审计模型
│   │   ├── BusinessScenarioModels.swift      # 商务场景模型
│   │   ├── ToolSafety.swift                  # 工具安全模型
│   │   ├── TaskRouting.swift                 # 任务路由模型
│   │   ├── ExecutionPlan.swift               # 执行计划模型
│   │   ├── AgentEvent.swift                  # 代理事件模型
│   │   ├── AgentEventBus.swift               # 代理事件总线
│   │   ├── AgentSystems.swift                # 代理系统模型
│   │   ├── Permissions.swift                 # 权限模型
│   │   ├── DevMode.swift                     # 开发者模式模型
│   │   ├── BrowserState.swift                # 浏览器状态
│   │   ├── FinderState.swift                 # Finder 状态
│   │   ├── NativeAccessibilityModels.swift   # 原生无障碍模型
│   │   ├── OCRTypes.swift                    # OCR 类型定义
│   │   ├── InteractionTrace.swift            # 交互追踪模型
│   │   ├── VoiceModels.swift                 # 语音模型
│   │   ├── VoiceInputConfig.swift            # 语音输入配置
│   │   ├── HotkeyConfig.swift                # 快捷键配置
│   │   ├── Logging.swift                     # 日志模型
│   │   ├── SkillsAndEval.swift               # 技能与评测模型
│   │   └── ...
│   │
│   ├── RenJistrolySystemBridge/            # macOS 系统桥接层
│   │   ├── AccessibilityBridge.swift         # AX API 桥接
│   │   ├── AccessibilityContextProvider.swift # 无障碍上下文提供
│   │   ├── AppDrivers.swift                  # 应用驱动(Chrome/Safari)
│   │   ├── AppleScriptBridge.swift           # AppleScript 执行
│   │   ├── ShellExecutor.swift               # 沙箱化 Shell 执行
│   │   ├── ScreenCaptureBridge.swift         # ScreenCaptureKit 截图
│   │   ├── ScreenContextProvider.swift       # 屏幕上下文提供
│   │   ├── ScreenStreamProvider.swift        # 屏幕流式提供
│   │   ├── OCRService.swift                  # OCR 文字识别服务
│   │   ├── OCREngineResolver.swift           # OCR 引擎选择解析
│   │   ├── PPOCRv6Service.swift              # PP-OCR v6 引擎
│   │   ├── CTCDecoder.swift                  # CTC 解码器(PPOCR)
│   │   ├── OrtImageHelper.swift              # ONNX 图像预处理
│   │   ├── NativeSpeechTranscriber.swift     # 原生语音转录
│   │   ├── MacOSSpeechRecognizer.swift       # macOS 语音识别
│   │   ├── AppleSpeechProvider.swift         # Apple 语音提供商
│   │   ├── MacOSTextToSpeech.swift           # macOS 文本转语音
│   │   ├── SystemTextToSpeech.swift          # 系统 TTS 封装
│   │   ├── AudioCapture.swift                # 音频捕获
│   │   ├── SystemDictationBridge.swift       # 系统听写桥接
│   │   ├── VoiceHotkeyManager.swift          # 语音快捷键管理
│   │   ├── CursorController.swift            # 光标控制
│   │   ├── FocusWithoutRaise.swift           # 聚焦不置前
│   │   ├── FocusGuard.swift                  # 焦点守卫
│   │   ├── AXNotificationObserver.swift      # AX 通知观察
│   │   ├── AXSettling.swift                  # AX 等待稳定
│   │   ├── ElementRegistry.swift             # UI 元素注册表
│   │   ├── EntityMatcher.swift               # 实体匹配
│   │   ├── InputStrategy.swift               # 输入策略选择
│   │   ├── SkyLightEventPost.swift           # SkyLight 事件注入
│   │   ├── PermissionCenter.swift            # 权限中心管理
│   │   ├── PermissionPolicy.swift            # 权限策略
│   │   ├── CommandAllowlist.swift            # 命令白名单
│   │   ├── CommandScopeLimiter.swift         # 命令作用域限制
│   │   ├── FileOperationSafety.swift         # 文件操作安全检查
│   │   ├── LocalOnlyPolicy.swift             # 仅本地策略
│   │   ├── LocalSecretScanner.swift          # 本地密钥扫描
│   │   ├── CredentialSanitizer.swift         # 凭证脱敏器
│   │   ├── SensitiveConfigReadOnly.swift     # 敏感配置只读
│   │   ├── HealthMonitor.swift               # 系统健康监控
│   │   ├── NetworkDiagnostic.swift           # 网络诊断
│   │   ├── SystemInfoReader.swift            # 系统信息读取
│   │   ├── SystemSettingSnapshot.swift       # 系统设置快照
│   │   ├── ActionSafety.swift                # 操作安全检查
│   │   ├── RiskScorer.swift                  # 风险评分引擎
│   │   ├── HighRiskOperationConfirmer.swift  # 高风险操作确认
│   │   ├── AutoRollback.swift                # 自动回滚
│   │   ├── RecoveryDecider.swift             # 恢复决策
│   │   ├── ScreenDiffVerifier.swift          # 屏幕差异验证
│   │   ├── SemanticChangeDetector.swift      # 语义变更检测
│   │   ├── RedlineDiffComparator.swift       # 红线差异对比
│   │   ├── ComputerUseObserver.swift         # Computer Use 观察
│   │   ├── ChatwootBridge.swift              # Chatwoot 客服桥接
│   │   ├── ClaudeCodeBridge.swift            # Claude Code 桥接
│   │   ├── CodebaseMemoryBridge.swift        # 代码库记忆桥接
│   │   ├── FoundationServices.swift          # 基础服务
│   │   ├── DBPostProcessor.swift             # 数据库后处理
│   │   ├── TerminalTaskStore.swift           # 终端任务存储
│   │   ├── DeveloperAgentTaskStore.swift     # 开发者代理任务存储
│   │   ├── CertificateManager.swift          # 证书管理
│   │   ├── UpdateManager.swift               # 更新管理
│   │   ├── OpenAIAPIKeyStore.swift           # OpenAI API 密钥存储
│   │   ├── AuditExporter.swift               # 审计导出
│   │   ├── LogSanitizer.swift                # 日志脱敏
│   │   ├── LogProcessingIsolator.swift       # 日志处理隔离
│   │   ├── ReadOnlyEvidenceMode.swift        # 只读证据模式
│   │   ├── EvidenceReferencer.swift          # 证据引用
│   │   ├── DisclaimerTemplate.swift          # 免责声明模板
│   │   ├── ContractClauseMatcher.swift       # 合同条款匹配
│   │   ├── RecipientConfirmer.swift          # 收件人确认
│   │   ├── RemoteAssistConsent.swift         # 远程协助同意
│   │   ├── MDMConfirmer.swift                # MDM 策略确认
│   │   ├── RegulationTimelinessMarker.swift  # 法规时效标记
│   │   └── EnvironmentDistinguisher.swift    # 环境区分
│   │
│   ├── RenJistrolyMCP/                    # 独立 MCP 服务器入口
│   │   └── MCPBridge.swift                 # MCP JSON-RPC 服务器
│   │
│   ├── RenJistrolyBridge/                 # 桥接入口
│   │   └── main.swift                        # 桥接进程入口
│   │
│   ├── RenJistrolyGate/                   # 门禁入口
│   │   └── main.swift                        # 门禁进程入口
│   │
│   ├── RenJistrolyHelper/                 # 辅助进程
│   │   ├── HelperEntry.swift                 # 辅助进程入口
│   │   └── HelperService.swift               # 辅助服务实现
│   │
│   └── RenJistrolyXPC/                    # XPC 通信层
│       ├── XPCConstants.swift                # XPC 常量定义
│       └── XPCProtocol.swift                 # XPC 协议定义
│
├── Tests/
│   ├── RenJistrolyTests/                  # 核心集成测试
│   │   ├── ModelTests.swift                  # 模型单元测试
│   │   ├── EnterpriseModeTests.swift         # 企业模式测试
│   │   ├── EnterpriseActionTests.swift       # 企业操作测试
│   │   ├── EnterpriseContextTests.swift      # 企业上下文测试
│   │   ├── ProductIdentityTests.swift        # 产品定位测试
│   │   ├── SafetyGuardTests.swift            # 安全守卫测试
│   │   └── SystemBridgeTests.swift           # 系统桥接测试
│   │
│   ├── RenJistrolyModelsTests/            # 模型层单元测试
│   │   ├── ActionModelsTests.swift           # 操作模型测试
│   │   ├── AgentEventTests.swift             # 代理事件测试
│   │   ├── AgentEventBusTests.swift          # 事件总线测试
│   │   ├── AgentEventExtraTests.swift        # 事件额外测试
│   │   ├── AgentSystemsTests.swift           # 代理系统测试
│   │   ├── AppStateTests.swift               # 应用状态测试
│   │   ├── BrowserStateTests.swift           # 浏览器状态测试
│   │   ├── BusinessScenarioModelsTests.swift # 商务场景模型测试
│   │   ├── ComputerUseModelsTests.swift      # ComputerUse 模型测试
│   │   ├── ComputerUsePolicyTests.swift      # ComputerUse 策略测试
│   │   ├── ComputerUseStateTests.swift       # ComputerUse 状态测试
│   │   ├── ContentBlockTests.swift           # 内容块测试
│   │   ├── ContextModelsTests.swift          # 上下文模型测试
│   │   ├── DesktopContextTests.swift         # 桌面上下文测试
│   │   ├── DevModeTests.swift                # 开发模式测试
│   │   ├── ExecutionPlanTests.swift          # 执行计划测试
│   │   ├── FinderStateTests.swift            # Finder 状态测试
│   │   ├── FoundationModelsTests.swift       # 基础模型测试
│   │   ├── InteractionTraceTests.swift       # 交互追踪测试
│   │   ├── LLMProviderTests.swift            # LLM 提供商测试
│   │   ├── MessageTests.swift                # 消息模型测试
│   │   ├── NativeAccessibilityTests.swift    # 无障碍模型测试
│   │   ├── OCRTypesTests.swift               # OCR 类型测试
│   │   ├── PermissionsTests.swift            # 权限模型测试
│   │   ├── ProjectContextTests.swift         # 项目上下文测试
│   │   ├── ProtocolsTests.swift              # 协议测试
│   │   ├── ProviderConfigTests.swift         # 提供商配置测试
│   │   ├── ProviderProtocolsTests.swift      # 提供商协议测试
│   │   ├── RoleScenarioGuardsTests.swift     # 角色场景守卫测试
│   │   ├── ScenarioAuditTests.swift          # 场景审计测试
│   │   ├── SkillsAndEvalTests.swift          # 技能评测测试
│   │   ├── StabilityMetricsTests.swift       # 稳定性指标测试
│   │   ├── TaskRoutingTests.swift            # 任务路由测试
│   │   ├── ToolActionCategoryTests.swift     # 工具动作分类测试
│   │   ├── ToolSafetyTests.swift             # 工具安全测试
│   │   ├── VoiceAndHotkeyTests.swift         # 语音热键测试
│   │   ├── VoiceInputModeTests.swift         # 语音输入模式测试
│   │   ├── VoiceModelsExtraTests.swift       # 语音模型补充测试
│   │   └── WorkflowTemplateTests.swift       # 工作流模板测试
│   │
│   ├── RenJistrolyCapabilityTests/        # 能力层测试
│   │   ├── AdditionalMCPToolsAndMCPServerTests.swift # MCP 工具补充测试
│   │   ├── AppIntegrationToolsTests.swift   # 应用集成工具测试
│   │   ├── BrowserStabilityTests.swift      # 浏览器稳定性测试
│   │   ├── ComputerUseEvalSuiteTests.swift  # ComputerUse 评测测试
│   │   ├── ComputerUseRuntimeTests.swift    # ComputerUse 运行时测试
│   │   ├── DeveloperToolboxTests.swift      # 开发者工具箱测试
│   │   ├── DeveloperToolsTests.swift        # 开发者工具测试
│   │   ├── FileStabilityTests.swift         # 文件稳定性测试
│   │   ├── MCPClientSafetyTests.swift       # MCP 客户端安全测试
│   │   ├── MCPToolRegistryTests.swift       # 工具注册表测试
│   │   ├── MCPToolsDefinitionTests.swift    # 工具定义测试
│   │   ├── MCPToolsExecutionTests.swift     # 工具执行测试
│   │   ├── MouseControlStabilityTests.swift # 鼠标控制稳定性测试
│   │   ├── OCRToolTests.swift               # OCR 工具测试
│   │   ├── SafetyAuditStoreTests.swift      # 安全审计存储测试
│   │   ├── SafetyStabilityTests.swift       # 安全稳定性测试
│   │   ├── ScreenUnderstandingTests.swift   # 屏幕理解测试
│   │   ├── SkillRegistryTests.swift         # 技能注册表测试
│   │   ├── SkillScannerTests.swift          # 技能扫描测试
│   │   ├── SystemToolsDefinitionTests.swift # 系统工具定义测试
│   │   └── ToolSafetyGatewayTests.swift     # 工具安全网关测试
│   │
│   ├── RenJistrolyConversationTests/      # 对话引擎测试
│   │   ├── AgentSkillRegistryTests.swift    # 代理技能注册测试
│   │   ├── AppStabilityTests.swift          # 应用稳定性测试
│   │   ├── ContextCompilerTests.swift       # 上下文编译测试
│   │   ├── ContextStabilityTests.swift      # 上下文稳定性测试
│   │   ├── ConversationEngineTests.swift    # 对话引擎测试
│   │   ├── DiagnosticsStabilityTests.swift  # 诊断稳定性测试
│   │   ├── EnterpriseStabilityTests.swift   # 企业稳定性测试
│   │   ├── PlanExecutorTests.swift          # 计划执行器测试
│   │   ├── ResponseExperienceTests.swift    # 响应体验测试
│   │   ├── SessionManagerTests.swift        # 会话管理测试
│   │   ├── ToolExecutionServiceTests.swift  # 工具执行服务测试
│   │   ├── UIStateStabilityTests.swift      # UI 状态稳定性测试
│   │   ├── WorkflowMemoryStoreTests.swift   # 工作流内存测试
│   │   └── WorkflowTemplateStoreTests.swift # 工作流模板测试
│   │
│   ├── RenJistrolyIntelligenceTests/      # 智能层测试
│   │   ├── AgentOrchestratorTests.swift     # 代理编排器测试
│   │   ├── AppInstructionLibraryTests.swift # 应用指令库测试
│   │   ├── BuildErrorAnalyzerTests.swift    # 构建错误分析测试
│   │   ├── ClaudeCodeCLITests.swift         # Claude Code CLI 测试
│   │   ├── CloudBackendTests.swift          # 云端后端测试
│   │   ├── CloudErrorAndPromptsTests.swift  # 云端错误提示测试
│   │   ├── CommandParserTests.swift         # 命令解析测试
│   │   ├── ComputerUsePlannerTests.swift    # ComputerUse 规划测试
│   │   ├── ContextStoreTests.swift          # 上下文存储测试
│   │   ├── LMCacheTests.swift               # 语言模型缓存测试
│   │   ├── LocalActionParserTests.swift     # 本地动作解析测试
│   │   ├── LocalMLXTests.swift              # 本地 MLX 测试
│   │   ├── LocalQuickResponderTests.swift   # 本地快速响应测试
│   │   ├── ModelActionPlannerTests.swift    # 模型动作规划测试
│   │   ├── MultiAgentTaskBoardTests.swift   # 多代理任务看板测试
│   │   ├── OfflineStabilityTests.swift      # 离线稳定性测试
│   │   ├── OpenAICompatibleChatProviderTests.swift # OpenAI 兼容测试
│   │   ├── PlanGeneratorTests.swift         # 计划生成测试
│   │   ├── ProviderRouterTests.swift        # 提供商路由测试
│   │   ├── ProviderStabilityTests.swift     # 提供商稳定性测试
│   │   ├── RAGEngineTests.swift             # RAG 引擎测试
│   │   ├── RealtimeProvidersTests.swift     # 实时提供商测试
│   │   ├── SmartRouterTests.swift           # 智能路由测试
│   │   ├── TaskRouterTests.swift            # 任务路由测试
│   │   └── VoiceInputStabilityTests.swift   # 语音输入稳定性测试
│   │
│   ├── RenJistrolySystemBridgeTests/      # 系统桥接层测试
│   │   ├── ActionPolicyTests.swift          # 操作策略测试
│   │   ├── AppControlStabilityTests.swift   # 应用控制稳定性测试
│   │   ├── AppDriversTests.swift            # 应用驱动测试
│   │   ├── ChatStabilityTests.swift         # 聊天稳定性测试
│   │   ├── ChatwootBridgeTests.swift        # Chatwoot 桥接测试
│   │   ├── ClaudeCodeBridgeTests.swift      # Claude Code 桥接测试
│   │   ├── CTCDecoderTests.swift            # CTC 解码器测试
│   │   ├── DBPostProcessorTests.swift       # 数据库后处理测试
│   │   ├── DeveloperAgentTaskStoreTests.swift # 代理任务存储测试
│   │   ├── DevWorkflowStabilityTests.swift  # 开发工作流稳定性测试
│   │   ├── ElementRegistryTests.swift       # 元素注册表测试
│   │   ├── FoundationServicesTests.swift    # 基础服务测试
│   │   ├── KeyboardInputStabilityTests.swift # 键盘输入稳定性测试
│   │   ├── OCRServiceTests.swift            # OCR 服务测试
│   │   ├── PermissionCenterTests.swift      # 权限中心测试
│   │   ├── PermissionsStabilityTests.swift  # 权限稳定性测试
│   │   ├── ScreenDiffVerifierTests.swift    # 屏幕差异验证测试
│   │   ├── ShellExecutorTests.swift         # Shell 执行测试
│   │   ├── SystemBridgeEnumsTests.swift     # 系统桥接枚举测试
│   │   ├── TerminalStabilityTests.swift     # 终端稳定性测试
│   │   └── TerminalTaskStoreTests.swift     # 终端任务存储测试
│   │
│   ├── SecurityTests/                     # 安全红队测试
│   │   ├── RedTeamPlan.swift                # 红队测试计划
│   │   ├── DataExfilTests.swift             # 数据泄露渗透测试
│   │   ├── SessionHijackTests.swift         # 会话劫持测试
│   │   └── ToolInjectionTests.swift         # 工具注入攻击测试
│   │
│   ├── PerformanceTests/                  # 性能基准测试
│   │   ├── PerformanceTestBase.swift        # 性能测试基类
│   │   ├── BenchReport.swift                # 基准报告生成
│   │   ├── ActionEngineBenchmarks.swift     # 操作引擎性能基准
│   │   ├── ContextCaptureBenchmarks.swift   # 上下文捕获性能
│   │   ├── MemoryBenchmarks.swift           # 内存使用基准
│   │   └── ModeManagerBenchmarks.swift      # 模式管理器性能
│   │
│   ├── LongRunningTests/                  # 长时间运行测试
│   │   ├── LongevityPlan.swift              # 生命周期耐力测试
│   │   └── StateMachineStressTests.swift    # 状态机压力测试
│   │
│   └── RegressionTests/                   # 回归测试
│       ├── CiTestPlan.swift                 # CI 测试计划编排
│       ├── CoreCapabilityRegressionTests.swift # 核心能力回归
│       ├── CrossModuleRegressionTests.swift # 跨模块回归测试
│       ├── RegressionTestSuite.swift        # 回归测试套件
│       ├── TestMatrix.swift                 # 测试矩阵定义
│       └── UpgradeMigrationTests.swift      # 升级迁移测试
│
├── Package.swift                          # SwiftPM 包定义
├── Resources/                             # 资源文件(entitlements等)
├── Scripts/                               # 构建与辅助脚本
└── CLAUDE.md                              # Claude Code 工作指引
```

## 模块统计

| 模块 | 文件数 |
|------|--------|
| RenJistrolyModels | 38 |
| RenJistrolySystemBridge | 74 |
| RenJistrolyIntelligence | 27 |
| RenJistrolyCapability | 27 |
| RenJistrolyConversation | 11 |
| RenJistrolyUI | 22 |
| RenJistrolyProductIdentity | 13 |
| RenJistrolyApp | 4 |
| RenJistrolyMCP | 1 |
| RenJistrolyBridge | 1 |
| RenJistrolyGate | 1 |
| RenJistrolyHelper | 2 |
| RenJistrolyXPC | 2 |
| **Sources 合计** | **227** |
| RenJistrolyTests | 7 |
| RenJistrolyModelsTests | 39 |
| RenJistrolyCapabilityTests | 21 |
| RenJistrolyConversationTests | 14 |
| RenJistrolyIntelligenceTests | 25 |
| RenJistrolySystemBridgeTests | 21 |
| SecurityTests | 4 |
| PerformanceTests | 6 |
| LongRunningTests | 2 |
| RegressionTests | 6 |
| **Tests 合计** | **145** |
| **总计** | **372** |

## 依赖方向

```
RenJistrolyApp ──→ RenJistrolyUI ──→ RenJistrolyConversation ──→ RenJistrolyCapability
                                              │                           │
                                              ↓                           ↓
                                    RenJistrolyIntelligence       RenJistrolySystemBridge
                                              │                           │
                                              ↓                           │
                                        RenJistrolyModels         (无内部依赖)
```

## 关键架构规则

- **RenJistrolyModels**: 零依赖模块，所有其他模块依赖它
- **RenJistrolySystemBridge**: 无内部依赖，直接操作 macOS API
- **RenJistrolyCapability**: 依赖 Models + SystemBridge，组合系统功能为 MCP 工具
- **RenJistrolyMCP**: 独立二进制，通过 `MCPToolRegistry` 暴露全部 94+ 工具
- 所有模块使用 Swift 6.2 并发模型，`@MainActor` 默认
