# 能力矩阵：场景 376-575

RenJistroly Agent 场景能力覆盖总览。按角色分组，涵盖 200 个编号场景 (376-575)。

---

## 角色分组统计

| # | 角色 | 场景范围 | 场景数 | 已实现 | 实现率 | 主要实现文件 |
|---|------|---------|-------|--------|-------|-------------|
| 1 | 工程师 (Engineer) | 376-385 | 10 | 10 | 100% | EngineerScenarioTools.swift |
| 2 | 设计师 (Designer) | 386-395 | 10 | 10 | 100% | DesignerTools.swift |
| 3 | 产品经理 (PM) | 396-405 | 10 | 10 | 100% | ProductManagerTools.swift |
| 4 | 客服 (Customer Service) | 406-415 | 10 | 10 | 100% | BusinessScenarioTools.swift / BusinessScenarioModels.swift |
| 5 | 销售 (Sales) | 416-425 | 10 | 10 | 100% | BusinessScenarioTools.swift / BusinessScenarioModels.swift |
| 6 | 运营 (Operations) | 426-435 | 10 | 10 | 100% | BusinessScenarioTools.swift / BusinessScenarioModels.swift |
| 7 | 开发者扩展 (Dev Tools) | 436-440 | 5 | 5 | 100% | BusinessScenarioTools.swift |
| 8 | 财务守卫 (Finance Guards) | 436-445 | 10 | 10 | 100% | RoleScenarioGuards.swift / RoleScenarioSafetyService.swift |
| 9 | HR 守卫 (HR Guards) | 446-455 | 10 | 10 | 100% | RoleScenarioGuards.swift / RoleScenarioSafetyService.swift |
| 10 | 管理守卫 (Manager Guards) | 456-465 | 10 | 10 | 100% | RoleScenarioGuards.swift / RoleScenarioSafetyService.swift |
| 11 | 空白 (Gap) | 466-495 | 30 | 0 | 0% | — |
| 12 | 执行层 UX (Executive UX) | 496-505 | 10 | 10 | 100% | ExecutiveUXModels.swift |
| 13 | 信任机制 (Trust) | 506-515 | 10 | 10 | 100% | TrustMechanisms.swift |
| 14 | 操作模式 (Operation Mode) | 516-525 | 10 | 10 | 100% | ModeManager.swift |
| 15 | 操作记录/引擎 (Action Engine) | 526-535 | 10 | 10 | 100% | ActionEngine.swift |
| 16 | 系统上下文 (System Context) | 536-545 | 10 | 10 | 100% | ContextProvider.swift |
| 17 | 开发上下文 (Dev Context) | 546-555 | 10 | 10 | 100% | DevContextProvider.swift |
| 18 | 空白 (Gap) | 556-575 | 20 | 0 | 0% | — |

**汇总：200 个场景中 150 个有实现（75%），50 个空白（25%）**

---

## 详细场景列表

### 工程师 (Engineer) — 376-385

| 编号 | 场景 | 实现文件 | 实现方式 | 状态 |
|------|------|---------|---------|------|
| 376 | Xcode build log 结构化解析 | EngineerScenarioTools.swift | MCPTool: XcodeBuildAnalyzeTool | ✅ |
| 377 | 先运行测试再分析失败 | EngineerScenarioTools.swift | MCPTool: TestAnalyzeTool | ✅ |
| 378 | Git 状态感知（PR 上下文） | EngineerScenarioTools.swift | MCPTool: PrStatusTool | ✅ |
| 379 | LSP/索引驱动的调用链 | EngineerScenarioTools.swift | MCPTool: CallChainTool | ✅ |
| 380 | 变更范围控制 | EngineerScenarioTools.swift | MCPTool: ChangeScopeTool | ✅ |
| 381 | CI 状态检查（GitHub Actions） | EngineerScenarioTools.swift | MCPTool: CIStatusTool | ✅ |
| 382 | Crash 日志符号化 | EngineerScenarioTools.swift | MCPTool: CrashSymbolicateTool | ✅ |
| 383 | Lockfile 安全检查 | EngineerScenarioTools.swift | MCPTool: LockfileCheckTool | ✅ |
| 384 | 环境感知（开发/生产隔离） | EngineerScenarioTools.swift | MCPTool: EnvironmentDetectTool | ✅ |
| 385 | 性能分析集成 | EngineerScenarioTools.swift | MCPTool: ProfileTool | ✅ |

### 设计师 (Designer) — 386-395

| 编号 | 场景 | 实现文件 | 实现方式 | 状态 |
|------|------|---------|---------|------|
| 386 | Figma 专用解析器 | DesignerTools.swift | MCPTool: FigmaInspectTool | ✅ |
| 387 | 视觉对比 | DesignerTools.swift | MCPTool: VisualCompareTool | ✅ |
| 388 | 资源命名规则检查 | DesignerTools.swift | MCPTool: AssetNamingCheckTool | ✅ |
| 389 | 像素测量工具 | DesignerTools.swift | MCPTool: PixelMeasureTool | ✅ |
| 390 | 设计系统组件映射 | DesignerTools.swift | MCPTool: DesignSystemMapTool | ✅ |
| 391 | 窗口/屏幕选择验证 | DesignerTools.swift | MCPTool: WindowSelectVerifyTool | ✅ |
| 392 | 截图批注生成 | DesignerTools.swift | MCPTool: ScreenshotAnnotateTool | ✅ |
| 393 | Keynote/PPT 操作保护 | DesignerTools.swift | MCPTool: KeynoteSafeEditTool | ✅ |
| 394 | 设计 Token 映射 | DesignerTools.swift | MCPTool: DesignTokenMapTool | ✅ |
| 395 | UI 节点引用能力 | DesignerTools.swift | MCPTool: UINodeReferenceTool | ✅ |

### 产品经理 (PM) — 396-405

| 编号 | 场景 | 实现文件 | 实现方式 | 状态 |
|------|------|---------|---------|------|
| 396 | 反馈可信度标记 | ProductManagerTools.swift | MCPTool: FeedbackCredibilityTool | ✅ |
| 397 | PRD 生成模板+边界检查 | ProductManagerTools.swift | MCPTool: PRDGeneratorTool | ✅ |
| 398 | 需求拆解粒度控制 | ProductManagerTools.swift | MCPTool: RequirementDecomposeTool | ✅ |
| 399 | 进度追踪 | ProductManagerTools.swift | MCPTool: ProgressTrackTool | ✅ |
| 400 | 竞品分析模板 | ProductManagerTools.swift | MCPTool: CompetitiveAnalysisTool | ✅ |
| 401 | 会议记录决策提取 | ProductManagerTools.swift | MCPTool: MeetingNotesDecisionTool | ✅ |
| 402 | Roadmap 可信度标记 | ProductManagerTools.swift | MCPTool: RoadmapConfidenceTool | ✅ |
| 403 | 收件人确认机制 | ProductManagerTools.swift | MCPTool: EmailConfirmRecipientTool | ✅ |
| 404 | 操作确认和审计 | ProductManagerTools.swift | MCPTool: IssueConfirmOperationTool | ✅ |
| 405 | 屏幕感知兜底 | ProductManagerTools.swift | MCPTool: ScreenPerceptionFallbackTool | ✅ |

### 客服 (Customer Service) — 406-415

| 编号 | 场景 | 实现文件 | 实现方式 | 状态 |
|------|------|---------|---------|------|
| 406 | 会话上下文管理 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: SessionContextTool | ✅ |
| 407 | 话术策略层 | BusinessScenarioTools.swift | MCPTool: ScriptStrategyTool | ✅ |
| 408 | 高风险操作确认（"发送"确认） | BusinessScenarioTools.swift | MCPTool: HighRiskOpConfirmTool | ✅ |
| 409 | 权限感知 | BusinessScenarioTools.swift | MCPTool: PermissionAwarenessTool | ✅ |
| 410 | 情绪分析（含强度） | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: SentimentAnalysisTool | ✅ |
| 411 | 上下文隔离 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: ContextIsolationTool | ✅ |
| 412 | 语气保留翻译 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: TonePreservingTranslationTool | ✅ |
| 413 | CRM 操作审计 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: CRMAuditTool | ✅ |
| 414 | 风险分级拦截 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: RiskAssessmentTool | ✅ |
| 415 | OCR 置信度校验 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: OCRConfidenceTool | ✅ |

### 销售 (Sales) — 416-425

| 编号 | 场景 | 实现文件 | 实现方式 | 状态 |
|------|------|---------|---------|------|
| 416 | CRM 字段语义映射 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: CRMFieldMapTool | ✅ |
| 417 | 销售阶段感知 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: SalesStageTool | ✅ |
| 418 | 金额修改确认 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: AmountChangeConfirmTool | ✅ |
| 419 | 网页 DOM 解析 | BusinessScenarioTools.swift | MCPTool: WebDOMInspectTool | ✅ |
| 420 | 时区冲突检测 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: TimezoneConflictTool | ✅ |
| 421 | 报价模板匹配 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: QuoteTemplateTool | ✅ |
| 422 | 合同审批流程 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: ContractApprovalTool | ✅ |
| 423 | 说话人分离 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: SpeakerDiarizationTool | ✅ |
| 424 | 可靠提醒机制 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: ReminderTool | ✅ |
| 425 | 多窗口上下文融合 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: MultiWindowFusionTool | ✅ |

### 运营 (Operations) — 426-435

| 编号 | 场景 | 实现文件 | 实现方式 | 状态 |
|------|------|---------|---------|------|
| 426 | 生产开关保护 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: ProductionSwitchTool | ✅ |
| 427 | 数据导出脱敏 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: DataExportMaskTool | ✅ |
| 428 | Dry-run 预览模式 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: DryRunPreviewTool | ✅ |
| 429 | 图表 OCR+语义解析 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: ChartOCRTool | ✅ |
| 430 | 推送确认流程 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: PushNotifyConfirmTool | ✅ |
| 431 | CSV 格式校验 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: CSVValidateTool | ✅ |
| 432 | CMS 版本管理 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: CMSVersionTool | ✅ |
| 433 | 站点确认 | BusinessScenarioTools.swift | MCPTool: SiteConfirmationTool | ✅ |
| 434 | 窗口匹配验证 | BusinessScenarioTools.swift | MCPTool: WindowMatchTool | ✅ |
| 435 | 基线对比 | BusinessScenarioTools.swift / BusinessScenarioModels.swift | MCPTool: BaselineCompareTool | ✅ |

### 开发者扩展 (Dev Tools) — 436-440

| 编号 | 场景 | 实现文件 | 实现方式 | 状态 |
|------|------|---------|---------|------|
| 436 | 代码评审管理 | BusinessScenarioTools.swift | MCPTool: CodeReviewTool | ✅ |
| 437 | Git 工作流模拟 | BusinessScenarioTools.swift | MCPTool: GitWorkflowTool | ✅ |
| 438 | 终端会话管理 | BusinessScenarioTools.swift | MCPTool: TerminalSessionTool | ✅ |
| 439 | 浏览器文档查阅 | BusinessScenarioTools.swift | MCPTool: BrowserDocTool | ✅ |
| 440 | 项目诊断 | BusinessScenarioTools.swift | MCPTool: ProjectDiagnoseTool | ✅ |

### 财务守卫 (Finance Guards) — 436-445

守卫数据模型定义于 `RoleScenarioGuards.swift`，守卫服务由 `RoleScenarioSafetyService.swift` 提供。

| 编号 | 场景 | 实现方式 | 状态 |
|------|------|---------|------|
| 436 | OCR 数字校验和纠错 | OCRDigitValidator | ✅ |
| 437 | 金额验证 | AmountValidator | ✅ |
| 438 | 敏感数据保护 | SensitiveDataProtector | ✅ |
| 439 | 付款审批流 | PaymentApprovalFlow | ✅ |
| 440 | Excel 公式感知 | ExcelFormulaAwareness | ✅ |
| 441 | Excel 格式保护 | ExcelFormatProtector | ✅ |
| 442 | 税务信息隔离 | TaxInfoIsolator | ✅ |
| 443 | 敏感剪贴板管理 | SensitiveClipboardManager | ✅ |
| 444 | 对账误差阈值 | ReconciliationErrorThreshold | ✅ |
| 445 | 表单提交确认 | FormSubmitConfirmation | ✅ |

> 注：436-440 同时存在开发者扩展工具和财务守卫数据模型——两套实现共享编号但职责不同。

### HR 守卫 (HR Guards) — 446-455

| 编号 | 场景 | 实现方式 | 状态 |
|------|------|---------|------|
| 446 | 简历数据脱敏 | ResumeDataMasker | ✅ |
| 447 | offer 薪资验证 | OfferSalaryValidator | ✅ |
| 448 | 候选人确认 | CandidateConfirmer | ✅ |
| 449 | HR 权限边界 | HRPermissionBoundary | ✅ |
| 450 | 合规语气检查 | ComplianceToneChecker | ✅ |
| 451 | 离职流程风控 | ResignationRiskController | ✅ |
| 452 | 隐私边界 | PrivacyBoundaryGuard | ✅ |
| 453 | 合同审查流程 | ContractReviewFlow | ✅ |
| 454 | 批量发送确认 | BatchSendConfirmer | ✅ |
| 455 | 字段验证 | FieldValidator | ✅ |

### 管理守卫 (Manager Guards) — 456-465

| 编号 | 场景 | 实现方式 | 状态 |
|------|------|---------|------|
| 456 | 进度真实性 | ProgressAuthenticityChecker | ✅ |
| 457 | 图表趋势解读 | ChartTrendInterpreter | ✅ |
| 458 | 周报引用溯源 | WeeklyReportCitationTracer | ✅ |
| 459 | 会议冲突检测 | MeetingConflictDetector | ✅ |
| 460 | 收件人确认 | RecipientConfirmer | ✅ |
| 461 | 风险历史 | RiskHistoryTracker | ✅ |
| 462 | 决策记录 | DecisionRecorder | ✅ |
| 463 | 审批权限 | ApprovalPermissionModel | ✅ |
| 464 | 预算数据保护 | BudgetDataProtector | ✅ |
| 465 | 措辞合规 | WordingComplianceChecker | ✅ |

### 空白 (GAP) — 466-495（30 个场景未定义）

场景 466-495 在代码库中无任何 MARK 定义、数据模型或工具实现。这是编号体系中的预留段。

### 执行层 UX (Executive UX) — 496-505

数据模型定义于 `ExecutiveUXModels.swift`。使用纯数据模型，无独立 MCPTool 实现，由 ConversationEngine 等上层调用。

| 编号 | 场景 | 实现方式 | 状态 |
|------|------|---------|------|
| 496 | 能力描述层 | CapabilityDescriptionLayer | ✅ |
| 497 | 卡住检测 | StuckDetector | ✅ |
| 498 | 屏幕状态确认 | ScreenConfirmationPrompt | ✅ |
| 499 | 鼠标控制可视化指示 | CursorControlIndicator | ✅ |
| 500 | 窗口匹配确认 | WindowMatchConfirm | ✅ |
| 501 | 交互模式切换 | InteractionMode | ✅ |
| 502 | 实时操作描述 | OperationDescription | ✅ |
| 503 | 确认理由说明 | ConfirmationReason | ✅ |
| 504 | 友好错误消息 | FriendlyErrorMessage | ✅ |
| 505 | 全局停止机制 | GlobalStopMechanism | ✅ |

### 信任机制 (Trust) — 506-515

数据模型定义于 `TrustMechanisms.swift`。

| 编号 | 场景 | 实现方式 | 状态 |
|------|------|---------|------|
| 506 | 点击预览+确认 | ClickPreview | ✅ |
| 507 | 发送预览+确认 | SendPreview | ✅ |
| 508 | 删除回收站保护 | DeleteTrashProtection | ✅ |
| 509 | 数据脱敏引擎 | DataMaskingEngine | ✅ |
| 510 | 操作验证+截图证据 | OperationVerifier | ✅ |
| 511 | 心跳检测+自动恢复 | HeartbeatRecovery | ✅ |
| 512 | 上下文摘要显示 | ContextSummary | ✅ |
| 513 | 决策点用户确认 | DecisionPointConfirmation | ✅ |
| 514 | 操作队列+冲突检测 | OperationQueue | ✅ |
| 515 | 操作日志+回放 | OperationLogReplay | ✅ |

### 操作模式 (Operation Mode) — 516-525

实现在 `ModeManager.swift`。

| 编号 | 场景 | 实现方式 | 状态 |
|------|------|---------|------|
| 516-525 | 操作模式管理（10 个子场景） | OperationMode / ModeManager | ✅ |

子场景包括：readOnly, suggest, executable, highRisk, noMouse, localOnly, sensitiveAppBlock, autoMask, policyLock, auditExport。

### 操作记录/引擎 (Action Engine) — 526-535

实现在 `ActionEngine.swift`。

| 编号 | 场景 | 实现方式 | 状态 |
|------|------|---------|------|
| 526-535 | 操作记录+审计引擎 | ActionRecord / ActionEngine | ✅ |

### 系统上下文 (System Context) — 536-545

实现在 `ContextProvider.swift`。

| 编号 | 场景 | 实现方式 | 状态 |
|------|------|---------|------|
| 536-545 | 系统上下文快照+管理 | ContextManager / SystemContext | ✅ |

子快照包括：ScreenContextSnapshot, AppContextSnapshot, WindowContextSnapshot, FocusContextSnapshot, SelectionContextSnapshot, ClipboardRiskSnapshot, TaskContextSnapshot, ModelContextSnapshot, PermissionContextSnapshot, SecurityModeContextSnapshot, HealthStatusSnapshot。

### 开发上下文 (Dev Context) — 546-555

实现在 `DevContextProvider.swift`。

| 编号 | 场景 | 实现方式 | 状态 |
|------|------|---------|------|
| 546-555 | 开发上下文快照+管理 | DevContextManager / DevContext | ✅ |

子快照包括：RepoContextSnapshot, BranchContextSnapshot, DiffContextSnapshot, TestStateSnapshot, BuildStateSnapshot, CIStateSnapshot, IssueContextSnapshot, PRContextSnapshot, FileContextSnapshot, SymbolContextSnapshot。

### 空白 (GAP) — 556-575（20 个场景未定义）

场景 556-575 在代码库中无任何实现或定义。

---

## 实现级别说明

| 实现级别 | 定义 | 覆盖场景数 |
|---------|------|-----------|
| MCPTool | 完整实现：有 MCPTool 协议实现，可在运行时通过 MCP 调用 | 55（376-440） |
| 守卫数据模型 | 纯数据模型 + RoleSafetyService 调用接口，无独立 MCPTool | 30（436-465） |
| 运行时模型 | 数据模型 + 运行时 Manager/Protocol，由系统内部使用 | 60（496-555） |
| 空白 | 未定义 | 50（466-495, 556-575） |
| **总计** | | **200** |
