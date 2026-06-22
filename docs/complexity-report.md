# 代码复杂度分析报告

- 分析时间: 2026-06-19
- 源文件总数: 232
- 总代码行数: 61616
- 总函数数: 2350

## 高复杂度文件

| 文件 | 行数 | 函数数 | 最大嵌套 | 最高圈复杂度 | 平均圈复杂度 | 建议 |
|------|------|--------|---------|-------------|-------------|------|
| ConversationEngine.swift | 2417 | 81 | 6 | 57 | 5.6 | 最高圈复杂度 57，需重点重构；文件过长 (2417行)，建议拆分为多个文件；嵌套过深 (深度 6)，建议提前返回；函数过多 (81个)，考虑按职责拆分 |
| AssistantSessionController.swift | 2016 | 96 | 7 | 22 | 4.1 | 最高圈复杂度 22，需重点重构；文件过长 (2016行)，建议拆分为多个文件；嵌套过深 (深度 7)，建议提前返回；函数过多 (96个)，考虑按职责拆分 |
| AppDrivers.swift | 1766 | 117 | 5 | 15 | 2.5 | 圈复杂度 15，建议拆分；文件过长 (1766行)，建议拆分为多个文件；函数过多 (117个)，考虑按职责拆分 |
| BusinessScenarioTools.swift | 3367 | 71 | 4 | 22 | 9.5 | 最高圈复杂度 22，需重点重构；文件过长 (3367行)，建议拆分为多个文件；函数过多 (71个)，考虑按职责拆分；函数普遍复杂 (均 9.5) |
| ComputerUseRuntime.swift | 1194 | 29 | 5 | 59 | 9.0 | 最高圈复杂度 59，需重点重构；文件过长 (1194行)，建议拆分为多个文件；函数过多 (29个)，考虑按职责拆分；函数普遍复杂 (均 9.0) |
| EngineerScenarioTools.swift | 1960 | 63 | 6 | 25 | 8.1 | 最高圈复杂度 25，需重点重构；文件过长 (1960行)，建议拆分为多个文件；嵌套过深 (深度 6)，建议提前返回；函数过多 (63个)，考虑按职责拆分；函数普遍复杂 (均 8.1) |
| CommandParser.swift | 1268 | 50 | 4 | 32 | 5.4 | 最高圈复杂度 32，需重点重构；文件过长 (1268行)，建议拆分为多个文件；函数过多 (50个)，考虑按职责拆分 |
| AccessibilityContextProvider.swift | 1259 | 72 | 5 | 13 | 4.2 | 圈复杂度 13，建议拆分；文件过长 (1259行)，建议拆分为多个文件；函数过多 (72个)，考虑按职责拆分 |
| ProductManagerTools.swift | 1142 | 21 | 7 | 32 | 15.4 | 最高圈复杂度 32，需重点重构；文件过长 (1142行)，建议拆分为多个文件；嵌套过深 (深度 7)，建议提前返回；函数过多 (21个)，考虑按职责拆分；函数普遍复杂 (均 15.4) |
| AgentOrchestrator.swift | 534 | 12 | 7 | 41 | 5.8 | 最高圈复杂度 41，需重点重构；文件过长 (534行)，建议拆分为多个文件；嵌套过深 (深度 7)，建议提前返回 |
| AccessibilityBridge.swift | 971 | 51 | 5 | 17 | 4.6 | 最高圈复杂度 17，需重点重构；文件过长 (971行)，建议拆分为多个文件；函数过多 (51个)，考虑按职责拆分 |
| DeveloperToolbox.swift | 1012 | 40 | 5 | 18 | 6.8 | 最高圈复杂度 18，需重点重构；文件过长 (1012行)，建议拆分为多个文件；函数过多 (40个)，考虑按职责拆分 |
| DesignerTools.swift | 1033 | 21 | 6 | 25 | 14.3 | 最高圈复杂度 25，需重点重构；文件过长 (1033行)，建议拆分为多个文件；嵌套过深 (深度 6)，建议提前返回；函数过多 (21个)，考虑按职责拆分；函数普遍复杂 (均 14.3) |
| ToolSafetyGateway.swift | 513 | 14 | 4 | 35 | 10.9 | 最高圈复杂度 35，需重点重构；文件过长 (513行)，建议拆分为多个文件；函数普遍复杂 (均 10.9) |
| BusinessScenarioModels.swift | 1119 | 39 | 4 | 15 | 2.2 | 圈复杂度 15，建议拆分；文件过长 (1119行)，建议拆分为多个文件；函数过多 (39个)，考虑按职责拆分 |
| CodeTools.swift | 559 | 22 | 5 | 24 | 6.3 | 最高圈复杂度 24，需重点重构；文件过长 (559行)，建议拆分为多个文件；函数过多 (22个)，考虑按职责拆分 |
| AppInstructionLibrary.swift | 81 | 2 | 2 | 43 | 43.0 | 最高圈复杂度 43，需重点重构；函数普遍复杂 (均 43.0) |
| WorkflowMemoryStore.swift | 473 | 25 | 5 | 22 | 3.8 | 最高圈复杂度 22，需重点重构；文件偏长 (473行)；函数过多 (25个)，考虑按职责拆分 |
| main.swift | 329 | 5 | 3 | 36 | 8.6 | 最高圈复杂度 36，需重点重构；文件偏长 (329行)；函数普遍复杂 (均 8.6) |
| RealtimeProviders.swift | 491 | 29 | 5 | 19 | 3.3 | 最高圈复杂度 19，需重点重构；文件偏长 (491行)；函数过多 (29个)，考虑按职责拆分 |
| SmartRouter.swift | 516 | 18 | 4 | 25 | 6.2 | 最高圈复杂度 25，需重点重构；文件过长 (516行)，建议拆分为多个文件 |
| FoundationServices.swift | 427 | 31 | 4 | 19 | 4.1 | 最高圈复杂度 19，需重点重构；文件偏长 (427行)；函数过多 (31个)，考虑按职责拆分 |
| RoleScenarioGuards.swift | 960 | 47 | 2 | 7 | 1.4 | 文件过长 (960行)，建议拆分为多个文件；函数过多 (47个)，考虑按职责拆分 |
| CloudOpenAI.swift | 376 | 7 | 10 | 20 | 7.3 | 最高圈复杂度 20，需重点重构；文件偏长 (376行)；嵌套过深 (深度 10)，建议提前返回 |
| ClaudeCodeBridge.swift | 466 | 14 | 6 | 21 | 6.8 | 最高圈复杂度 21，需重点重构；文件偏长 (466行)；嵌套过深 (深度 6)，建议提前返回 |
| CloudOpenAICompatible.swift | 335 | 6 | 10 | 20 | 7.2 | 最高圈复杂度 20，需重点重构；文件偏长 (335行)；嵌套过深 (深度 10)，建议提前返回 |
| AppDriverTools.swift | 677 | 47 | 3 | 6 | 3.0 | 文件过长 (677行)，建议拆分为多个文件；函数过多 (47个)，考虑按职责拆分 |
| FocusGuard.swift | 264 | 15 | 3 | 26 | 5.2 | 最高圈复杂度 26，需重点重构 |
| DeveloperLoop.swift | 368 | 13 | 5 | 22 | 4.8 | 最高圈复杂度 22，需重点重构；文件偏长 (368行) |
| ComputerUsePlanner.swift | 527 | 19 | 4 | 18 | 7.1 | 最高圈复杂度 18，需重点重构；文件过长 (527行)，建议拆分为多个文件 |
| DeveloperAgentTaskStore.swift | 619 | 36 | 3 | 10 | 3.4 | 文件过长 (619行)，建议拆分为多个文件；函数过多 (36个)，考虑按职责拆分 |
| PermissionCenter.swift | 453 | 12 | 4 | 21 | 7.5 | 最高圈复杂度 21，需重点重构；文件偏长 (453行) |
| ActionSafety.swift | 182 | 6 | 3 | 28 | 7.3 | 最高圈复杂度 28，需重点重构 |
| AgentConsoleView.swift | 709 | 9 | 6 | 16 | 5.1 | 最高圈复杂度 16，需重点重构；文件过长 (709行)，建议拆分为多个文件；嵌套过深 (深度 6)，建议提前返回 |
| ChatwootBridge.swift | 344 | 25 | 5 | 11 | 2.2 | 圈复杂度 11，建议拆分；文件偏长 (344行)；函数过多 (25个)，考虑按职责拆分 |
| AgentSystems.swift | 766 | 23 | 3 | 10 | 1.4 | 文件过长 (766行)，建议拆分为多个文件；函数过多 (23个)，考虑按职责拆分 |
| SystemTools.swift | 474 | 22 | 4 | 11 | 5.4 | 圈复杂度 11，建议拆分；文件偏长 (474行)；函数过多 (22个)，考虑按职责拆分 |
| TrustMechanisms.swift | 1031 | 28 | 3 | 3 | 1.1 | 文件过长 (1031行)，建议拆分为多个文件；函数过多 (28个)，考虑按职责拆分 |
| CloudAnthropic.swift | 324 | 8 | 7 | 14 | 4.6 | 圈复杂度 14，建议拆分；文件偏长 (324行)；嵌套过深 (深度 7)，建议提前返回 |
| ContextProvider.swift | 376 | 29 | 3 | 7 | 3.4 | 文件偏长 (376行)；函数过多 (29个)，考虑按职责拆分 |
| PlanExecutor.swift | 234 | 4 | 6 | 16 | 5.8 | 最高圈复杂度 16，需重点重构；嵌套过深 (深度 6)，建议提前返回 |
| ShellExecutor.swift | 204 | 8 | 4 | 17 | 4.2 | 最高圈复杂度 17，需重点重构 |
| DeveloperTools.swift | 430 | 15 | 4 | 11 | 5.8 | 圈复杂度 11，建议拆分；文件偏长 (430行) |
| ExecutiveUXModels.swift | 766 | 18 | 2 | 9 | 1.5 | 文件过长 (766行)，建议拆分为多个文件 |
| ScenarioTools.swift | 162 | 8 | 4 | 17 | 5.8 | 最高圈复杂度 17，需重点重构 |
| RecoveryDecider.swift | 136 | 8 | 2 | 20 | 6.1 | 最高圈复杂度 20，需重点重构 |
| SkillRegistry.swift | 230 | 14 | 4 | 13 | 3.5 | 圈复杂度 13，建议拆分 |
| DesktopContext.swift | 138 | 4 | 3 | 20 | 5.8 | 最高圈复杂度 20，需重点重构 |
| ModelActionPlanner.swift | 140 | 6 | 2 | 20 | 5.7 | 最高圈复杂度 20，需重点重构 |
| LMCache.swift | 266 | 22 | 3 | 9 | 1.8 | 函数过多 (22个)，考虑按职责拆分 |
| AppDelegate.swift | 348 | 22 | 3 | 8 | 2.6 | 文件偏长 (348行)；函数过多 (22个)，考虑按职责拆分 |
| CloudGoogle.swift | 336 | 9 | 6 | 10 | 5.1 | 文件偏长 (336行)；嵌套过深 (深度 6)，建议提前返回 |
| TaskRouter.swift | 356 | 14 | 4 | 10 | 5.0 | 文件偏长 (356行) |
| ClaudeCodeCLI.swift | 253 | 9 | 5 | 12 | 5.0 | 圈复杂度 12，建议拆分 |
| DevContextProvider.swift | 372 | 25 | 2 | 7 | 3.6 | 文件偏长 (372行)；函数过多 (25个)，考虑按职责拆分 |
| RoleScenarioSafetyService.swift | 176 | 17 | 3 | 11 | 1.6 | 圈复杂度 11，建议拆分 |
| MCPBridge.swift | 261 | 11 | 5 | 10 | 4.2 | 可接受 |
| ChangedFilesTool.swift | 124 | 4 | 4 | 16 | 9.5 | 最高圈复杂度 16，需重点重构；函数普遍复杂 (均 9.5) |
| LocalModelManager.swift | 185 | 6 | 6 | 11 | 4.3 | 圈复杂度 11，建议拆分；嵌套过深 (深度 6)，建议提前返回 |
| OpenAICompatibleChatProvider.swift | 231 | 7 | 6 | 10 | 3.9 | 嵌套过深 (深度 6)，建议提前返回 |
| CodexCLIBackend.swift | 239 | 7 | 5 | 11 | 5.6 | 圈复杂度 11，建议拆分 |
| LSPTool.swift | 256 | 14 | 3 | 10 | 4.4 | 可接受 |
| DBPostProcessor.swift | 154 | 5 | 6 | 11 | 5.0 | 圈复杂度 11，建议拆分；嵌套过深 (深度 6)，建议提前返回 |
| WindowMatchValidator.swift | 75 | 3 | 4 | 15 | 5.7 | 圈复杂度 15，建议拆分 |
| ControlTools.swift | 348 | 20 | 3 | 5 | 3.0 | 文件偏长 (348行) |
| CodebaseMemoryBridge.swift | 292 | 15 | 4 | 6 | 2.7 | 可接受 |
| VoiceSessionManager.swift | 188 | 9 | 5 | 8 | 3.6 | 可接受 |
| TerminalTaskStore.swift | 226 | 16 | 3 | 7 | 2.1 | 可接受 |
| CommandAllowlist.swift | 267 | 11 | 3 | 9 | 2.7 | 可接受 |
| AppIntegrationTools.swift | 357 | 12 | 2 | 9 | 2.4 | 文件偏长 (357行) |
| ToolExecutionService.swift | 157 | 9 | 3 | 11 | 2.6 | 圈复杂度 11，建议拆分 |
| MacOSSpeechRecognizer.swift | 154 | 5 | 5 | 10 | 3.6 | 可接受 |
| ContextCompiler.swift | 196 | 9 | 4 | 9 | 3.0 | 可接受 |
| MainWindowView.swift | 708 | 7 | 3 | 6 | 3.9 | 文件过长 (708行)，建议拆分为多个文件 |
| ScreenContextProvider.swift | 185 | 8 | 4 | 9 | 4.9 | 可接受 |
| LocalActionParser.swift | 233 | 10 | 3 | 9 | 4.2 | 可接受 |
| main.swift | 141 | 6 | 4 | 10 | 4.7 | 可接受 |
| HealthMonitor.swift | 189 | 13 | 4 | 6 | 2.2 | 可接受 |
| ScreenStreamProvider.swift | 231 | 12 | 4 | 6 | 2.7 | 可接受 |
| FloatingPanelView.swift | 617 | 7 | 3 | 6 | 3.9 | 文件过长 (617行)，建议拆分为多个文件 |
| OCRService.swift | 164 | 8 | 5 | 7 | 3.8 | 可接受 |
| FoundationCenterView.swift | 586 | 6 | 2 | 8 | 5.2 | 文件过长 (586行)，建议拆分为多个文件 |
| ScreenCaptureBridge.swift | 158 | 8 | 4 | 8 | 2.9 | 可接受 |
| AXNotificationObserver.swift | 182 | 8 | 3 | 9 | 3.2 | 可接受 |
| SkillScanner.swift | 262 | 10 | 3 | 7 | 2.0 | 可接受 |
| PPOCRv6Service.swift | 199 | 5 | 4 | 8 | 4.2 | 可接受 |
| LocalMLX.swift | 135 | 3 | 4 | 9 | 4.7 | 可接受 |
| TaskRouting.swift | 276 | 11 | 3 | 5 | 1.4 | 可接受 |
| CredentialSanitizer.swift | 226 | 13 | 2 | 6 | 2.5 | 可接受 |
| CTCDecoder.swift | 73 | 4 | 4 | 9 | 4.2 | 可接受 |
| ModeManager.swift | 220 | 14 | 3 | 4 | 1.6 | 可接受 |
| NativeSpeechTranscriber.swift | 149 | 5 | 3 | 9 | 4.4 | 可接受 |
| MCPClient.swift | 291 | 12 | 3 | 4 | 1.7 | 可接受 |
| CommandScopeLimiter.swift | 167 | 14 | 3 | 4 | 1.8 | 可接受 |
| HotkeyManager.swift | 108 | 4 | 6 | 5 | 3.5 | 嵌套过深 (深度 6)，建议提前返回 |
| PlanCard.swift | 149 | 5 | 4 | 7 | 5.0 | 可接受 |
| SettingsView.swift | 673 | 7 | 3 | 2 | 1.1 | 文件过长 (673行)，建议拆分为多个文件 |
| RAGEngine.swift | 173 | 11 | 3 | 5 | 2.9 | 可接受 |
| AppleSpeechProvider.swift | 91 | 3 | 4 | 8 | 5.0 | 可接受 |
| ActionEngine.swift | 244 | 15 | 2 | 3 | 1.6 | 可接受 |
| PlanGenerator.swift | 112 | 5 | 2 | 9 | 4.0 | 可接受 |
| ProviderRouter.swift | 74 | 5 | 2 | 9 | 2.6 | 可接受 |
| Protocols.swift | 68 | 11 | 2 | 6 | 1.9 | 可接受 |
| ClaudeAgentTool.swift | 117 | 4 | 4 | 6 | 2.8 | 可接受 |
| SessionManager.swift | 165 | 13 | 2 | 4 | 2.2 | 可接受 |
| SkyLightEventPost.swift | 197 | 9 | 3 | 4 | 2.4 | 可接受 |
| QuickOpenTool.swift | 140 | 8 | 3 | 5 | 3.1 | 可接受 |
| ElementRegistry.swift | 88 | 5 | 3 | 7 | 2.6 | 可接受 |
| VoiceHotkeyManager.swift | 75 | 5 | 2 | 8 | 3.6 | 可接受 |
| DesktopContextCollector.swift | 108 | 12 | 2 | 4 | 1.3 | 可接受 |
| ScreenDiffVerifier.swift | 102 | 7 | 3 | 5 | 2.1 | 可接受 |
| ComputerUseObserver.swift | 101 | 3 | 3 | 7 | 3.0 | 可接受 |
| ModeControlPanel.swift | 195 | 5 | 5 | 2 | 1.2 | 可接受 |
| RedlineDiffComparator.swift | 37 | 1 | 4 | 7 | 7.0 | 可接受 |
| PermissionsView.swift | 172 | 4 | 2 | 7 | 5.2 | 可接受 |
| ActionAuditView.swift | 262 | 8 | 4 | 1 | 1.0 | 可接受 |
| LocalQuickResponder.swift | 48 | 4 | 2 | 8 | 4.5 | 可接受 |
| ToolSafety.swift | 197 | 7 | 2 | 5 | 1.6 | 可接受 |
| SubmitTextInput.swift | 143 | 7 | 3 | 4 | 2.0 | 可接受 |
| EntityMatcher.swift | 39 | 1 | 3 | 8 | 8.0 | 可接受 |
| ComputerUseState.swift | 236 | 10 | 2 | 3 | 1.3 | 可接受 |
| MCPToolRegistry.swift | 83 | 7 | 2 | 6 | 2.4 | 可接受 |
| TraceConsolePanel.swift | 158 | 7 | 4 | 2 | 1.3 | 可接受 |
| AXSettling.swift | 105 | 7 | 3 | 4 | 2.1 | 可接受 |
| ProviderConfig.swift | 103 | 2 | 2 | 8 | 4.5 | 可接受 |
| HelperService.swift | 99 | 5 | 3 | 5 | 2.6 | 可接受 |
| NetworkDiagnostic.swift | 88 | 2 | 2 | 8 | 4.5 | 可接受 |
| OCRTool.swift | 78 | 2 | 2 | 8 | 8.0 | 可接受 |
| StreamingMarkdownText.swift | 110 | 3 | 2 | 7 | 3.7 | 可接受 |
| AgentEventBus.swift | 87 | 9 | 2 | 4 | 1.3 | 可接受 |
| OrtImageHelper.swift | 122 | 3 | 3 | 5 | 3.7 | 可接受 |
| AudioCapture.swift | 68 | 4 | 3 | 5 | 3.5 | 可接受 |
| PolicyLayer.swift | 67 | 4 | 3 | 5 | 2.0 | 可接受 |
| LocalSecretScanner.swift | 46 | 1 | 4 | 5 | 5.0 | 可接受 |
| CertificateManager.swift | 40 | 2 | 3 | 6 | 4.5 | 可接受 |
| LogSanitizer.swift | 140 | 7 | 2 | 4 | 1.4 | 可接受 |
| ProviderProtocols.swift | 86 | 17 | 1 | 1 | 1.0 | 可接受 |
| EnvironmentDistinguisher.swift | 35 | 3 | 2 | 7 | 5.0 | 可接受 |
| ContextAcquisitionManager.swift | 74 | 4 | 2 | 6 | 2.2 | 可接受 |
| ContextDashboard.swift | 268 | 4 | 4 | 1 | 1.0 | 可接受 |
| ReadOnlyModeEnforcer.swift | 55 | 2 | 2 | 7 | 4.0 | 可接受 |
| MultiAgentTaskBoard.swift | 54 | 6 | 2 | 5 | 2.3 | 可接受 |
| WorkflowTemplateStore.swift | 97 | 11 | 2 | 2 | 1.5 | 可接受 |
| RegulationTimelinessMarker.swift | 41 | 2 | 2 | 7 | 4.5 | 可接受 |
| AppleScriptBridge.swift | 111 | 8 | 2 | 3 | 1.8 | 可接受 |
| UpdateManager.swift | 151 | 6 | 3 | 2 | 2.0 | 可接受 |
| CursorNeutralInput.swift | 61 | 3 | 3 | 4 | 2.0 | 可接受 |
| MouseGuard.swift | 53 | 4 | 2 | 5 | 2.8 | 可接受 |
| FocusWithoutRaise.swift | 53 | 1 | 3 | 5 | 5.0 | 可接受 |
| OnboardingView.swift | 239 | 5 | 3 | 1 | 1.0 | 可接受 |
| FloatingPanelWindow.swift | 88 | 4 | 3 | 3 | 1.8 | 可接受 |
| CompactAssistantView.swift | 205 | 3 | 3 | 2 | 1.3 | 可接受 |
| CancelMechanism.swift | 68 | 4 | 2 | 4 | 1.8 | 可接受 |
| BuildErrorAnalyzer.swift | 109 | 3 | 2 | 4 | 2.3 | 可接受 |
| InputStrategy.swift | 101 | 3 | 2 | 4 | 3.0 | 可接受 |
| OCREngineResolver.swift | 26 | 2 | 2 | 5 | 3.0 | 可接受 |
| AppState.swift | 105 | 3 | 1 | 5 | 2.3 | 可接受 |
| CursorController.swift | 93 | 6 | 2 | 2 | 1.3 | 可接受 |
| FoundationModels.swift | 291 | 7 | 1 | 1 | 1.0 | 可接受 |
| PermissionPolicy.swift | 40 | 2 | 3 | 3 | 2.0 | 可接受 |
| EvidenceReferencer.swift | 36 | 2 | 3 | 3 | 2.5 | 可接受 |
| ComputerUseModels.swift | 280 | 7 | 1 | 1 | 1.0 | 可接受 |
| ContextStore.swift | 74 | 9 | 1 | 2 | 1.2 | 可接受 |
| OpenAIAPIKeyStore.swift | 67 | 2 | 2 | 4 | 3.5 | 可接受 |
| ScreenStabilityMonitor.swift | 59 | 4 | 2 | 3 | 1.5 | 可接受 |
| AssistantRootView.swift | 394 | 2 | 1 | 2 | 1.5 | 文件偏长 (394行) |
| MacOSTextToSpeech.swift | 78 | 3 | 2 | 3 | 2.0 | 可接受 |
| SystemInfoReader.swift | 54 | 3 | 2 | 3 | 1.7 | 可接受 |
| MDMConfirmer.swift | 51 | 2 | 1 | 5 | 3.0 | 可接受 |
| ReadOnlyEvidenceMode.swift | 38 | 3 | 2 | 3 | 2.0 | 可接受 |
| ContextModels.swift | 135 | 8 | 1 | 1 | 1.0 | 可接受 |
| StateMachineManager.swift | 76 | 4 | 2 | 2 | 1.2 | 可接受 |
| SystemTextToSpeech.swift | 68 | 4 | 2 | 2 | 1.5 | 可接受 |
| SystemSettingSnapshot.swift | 64 | 2 | 2 | 3 | 3.0 | 可接受 |
| FileOperationSafety.swift | 42 | 4 | 2 | 2 | 1.8 | 可接受 |
| SystemDictationBridge.swift | 42 | 4 | 2 | 2 | 1.2 | 可接受 |
| AgentSkillRegistry.swift | 33 | 4 | 2 | 2 | 1.2 | 可接受 |
| AuditHighRiskAction.swift | 72 | 6 | 1 | 2 | 1.2 | 可接受 |
| RecipientConfirmer.swift | 26 | 1 | 2 | 3 | 3.0 | 可接受 |
| TestMatrixPlanner.swift | 120 | 4 | 1 | 2 | 1.2 | 可接受 |
| NativeAccessibilityModels.swift | 161 | 2 | 2 | 1 | 1.0 | 可接受 |
| DevMode.swift | 151 | 5 | 1 | 1 | 1.0 | 可接受 |
| InteractionTrace.swift | 101 | 4 | 1 | 2 | 1.2 | 可接受 |
| AuditExporter.swift | 37 | 2 | 2 | 2 | 1.5 | 可接受 |
| LocalOnlyPolicy.swift | 33 | 3 | 1 | 3 | 1.7 | 可接受 |
| ContractClauseMatcher.swift | 27 | 2 | 2 | 2 | 1.5 | 可接受 |
| RemoteAssistConsent.swift | 53 | 4 | 1 | 2 | 1.2 | 可接受 |
| AgentEvent.swift | 299 | 1 | 1 | 1 | 1.0 | 可接受 |
| MenuBarView.swift | 149 | 1 | 2 | 1 | 1.0 | 可接受 |
| SensitiveConfigReadOnly.swift | 36 | 4 | 1 | 2 | 1.5 | 可接受 |
| VoiceWaveformView.swift | 77 | 3 | 1 | 2 | 2.0 | 可接受 |
| MainTabView.swift | 111 | 1 | 2 | 1 | 1.0 | 可接受 |
| OperatingScope.swift | 57 | 3 | 1 | 2 | 1.3 | 可接受 |
| Localization.swift | 544 | 0 | 0 | 0 | 0 | 文件过长 (544行)，建议拆分为多个文件 |
| ScenarioAuditModels.swift | 122 | 3 | 1 | 1 | 1.0 | 可接受 |
| HighRiskOperationConfirmer.swift | 47 | 2 | 1 | 2 | 2.0 | 可接受 |
| Permissions.swift | 146 | 2 | 1 | 1 | 1.0 | 可接受 |
| SkillsAndEval.swift | 94 | 3 | 1 | 1 | 1.0 | 可接受 |
| Conversation.swift | 90 | 3 | 1 | 1 | 1.0 | 可接受 |
| SafetyAuditStore.swift | 28 | 4 | 1 | 1 | 1.0 | 可接受 |
| SettingsPanel.swift | 174 | 1 | 1 | 1 | 1.0 | 可接受 |
| ActionCard.swift | 173 | 1 | 1 | 1 | 1.0 | 可接受 |
| FinderState.swift | 71 | 3 | 1 | 1 | 1.0 | 可接受 |
| BrowserState.swift | 66 | 3 | 1 | 1 | 1.0 | 可接受 |
| Message.swift | 59 | 3 | 1 | 1 | 1.0 | 可接受 |
| ComputerUseEvalSuite.swift | 108 | 2 | 1 | 1 | 1.0 | 可接受 |
| ActionModels.swift | 93 | 2 | 1 | 1 | 1.0 | 可接受 |
| AutoRollback.swift | 41 | 1 | 1 | 2 | 2.0 | 可接受 |
| SemanticChangeDetector.swift | 41 | 1 | 1 | 2 | 2.0 | 可接受 |
| ExecutionPlan.swift | 88 | 2 | 1 | 1 | 1.0 | 可接受 |
| LogProcessingIsolator.swift | 35 | 3 | 1 | 1 | 1.0 | 可接受 |
| AuditRow.swift | 130 | 1 | 1 | 1 | 1.0 | 可接受 |
| LLMProvider.swift | 126 | 1 | 1 | 1 | 1.0 | 可接受 |
| ActionVerificationEngine.swift | 66 | 2 | 1 | 1 | 1.0 | 可接受 |
| VoiceModels.swift | 65 | 2 | 1 | 1 | 1.0 | 可接受 |
| DisclaimerTemplate.swift | 41 | 2 | 1 | 1 | 1.0 | 可接受 |
| RiskLevelIndicator.swift | 72 | 1 | 1 | 1 | 1.0 | 可接受 |
| ComputerUsePolicyModels.swift | 48 | 1 | 1 | 1 | 1.0 | 可接受 |
| RenJistrolyApp.swift | 46 | 1 | 1 | 1 | 1.0 | 可接受 |
| ProjectContext.swift | 46 | 1 | 1 | 1 | 1.0 | 可接受 |
| MenuBarExtraView.swift | 44 | 1 | 1 | 1 | 1.0 | 可接受 |
| OCRTypes.swift | 36 | 1 | 1 | 1 | 1.0 | 可接受 |
| RiskScorer.swift | 30 | 1 | 1 | 1 | 1.0 | 可接受 |
| HelperEntry.swift | 13 | 1 | 1 | 1 | 1.0 | 可接受 |
| MessageBubble.swift | 119 | 0 | 0 | 0 | 0 | 可接受 |
| ModeBadge.swift | 96 | 0 | 0 | 0 | 0 | 可接受 |
| ProductIdentity.swift | 52 | 0 | 0 | 0 | 0 | 可接受 |
| HotkeyConfig.swift | 45 | 0 | 0 | 0 | 0 | 可接受 |
| XPCProtocol.swift | 23 | 0 | 0 | 0 | 0 | 可接受 |
| VoiceInputConfig.swift | 16 | 0 | 0 | 0 | 0 | 可接受 |
| Logging.swift | 14 | 0 | 0 | 0 | 0 | 可接受 |
| XPCConstants.swift | 8 | 0 | 0 | 0 | 0 | 可接受 |

## 圈复杂度 > 10 的函数

| 函数名 | 文件 | 行号 | 行数 | 圈复杂度 | 嵌套深度 | 分支数 | 循环数 | 建议 |
|--------|------|------|------|---------|---------|--------|--------|------|
| `evaluateVerification` | ComputerUseRuntime.swift:302 | 219 | 59 | 5 | 41 | 1 | 圈复杂度 59，必须拆分；函数过长 (219行) |
| `sendMessage` | ConversationEngine.swift:212 | 292 | 57 | 5 | 49 | 2 | 圈复杂度 57，必须拆分；函数过长 (292行) |
| `init` | AppInstructionLibrary.swift:4 | 76 | 43 | 2 | 24 | 1 | 圈复杂度 43，必须拆分 |
| `instructions` | AppInstructionLibrary.swift:6 | 74 | 43 | 2 | 24 | 1 | 圈复杂度 43，必须拆分 |
| `execute` | AgentOrchestrator.swift:28 | 303 | 41 | 7 | 26 | 7 | 圈复杂度 41，必须拆分；嵌套过深，提前返回；函数过长 (303行) |
| `handle` | main.swift:30 | 161 | 36 | 3 | 35 | 0 | 圈复杂度 36，必须拆分；函数过长 (161行) |
| `explainRisk` | ToolSafetyGateway.swift:338 | 86 | 35 | 3 | 30 | 0 | 圈复杂度 35，必须拆分 |
| `init` | ProductManagerTools.swift:320 | 122 | 32 | 7 | 18 | 4 | 圈复杂度 32，必须拆分；嵌套过深，提前返回；函数过长 (122行) |
| `execute` | ProductManagerTools.swift:322 | 120 | 32 | 7 | 18 | 4 | 圈复杂度 32，必须拆分；嵌套过深，提前返回；函数过长 (120行) |
| `parse` | CommandParser.swift:10 | 38 | 32 | 1 | 31 | 0 | 圈复杂度 32，必须拆分 |
| `init` | ProductManagerTools.swift:1017 | 124 | 29 | 7 | 21 | 5 | 圈复杂度 29，必须拆分；嵌套过深，提前返回；函数过长 (124行) |
| `execute` | ProductManagerTools.swift:1019 | 122 | 29 | 7 | 21 | 5 | 圈复杂度 29，必须拆分；嵌套过深，提前返回；函数过长 (122行) |
| `execute` | ActionSafety.swift:55 | 109 | 28 | 3 | 26 | 0 | 圈复杂度 28，必须拆分；函数过长 (109行) |
| `summarize` | ToolSafetyGateway.swift:204 | 61 | 27 | 3 | 26 | 0 | 圈复杂度 27，必须拆分 |
| `categorize` | ToolSafetyGateway.swift:266 | 71 | 26 | 3 | 25 | 0 | 圈复杂度 26，必须拆分 |
| `init` | FocusGuard.swift:20 | 151 | 26 | 3 | 21 | 2 | 圈复杂度 26，必须拆分；函数过长 (151行) |
| `parseCrashLog` | EngineerScenarioTools.swift:1168 | 97 | 25 | 5 | 21 | 1 | 圈复杂度 25，必须拆分 |
| `init` | DesignerTools.swift:218 | 110 | 25 | 6 | 19 | 3 | 圈复杂度 25，必须拆分；嵌套过深，提前返回；函数过长 (110行) |
| `execute` | DesignerTools.swift:220 | 108 | 25 | 6 | 19 | 3 | 圈复杂度 25，必须拆分；嵌套过深，提前返回；函数过长 (108行) |
| `assessComplexity` | SmartRouter.swift:177 | 106 | 25 | 3 | 24 | 0 | 圈复杂度 25，必须拆分；函数过长 (106行) |
| `init` | CodeTools.swift:459 | 99 | 24 | 5 | 5 | 2 | 圈复杂度 24，必须拆分 |
| `execute` | CodeTools.swift:461 | 97 | 24 | 5 | 5 | 2 | 圈复杂度 24，必须拆分 |
| `sampleProcess` | EngineerScenarioTools.swift:1757 | 106 | 23 | 5 | 16 | 2 | 圈复杂度 23，必须拆分；函数过长 (106行) |
| `init` | DesignerTools.swift:18 | 89 | 23 | 4 | 11 | 1 | 圈复杂度 23，必须拆分 |
| `execute` | DesignerTools.swift:20 | 87 | 23 | 4 | 11 | 1 | 圈复杂度 23，必须拆分 |
| `init` | BusinessScenarioTools.swift:839 | 71 | 22 | 4 | 15 | 0 | 圈复杂度 22，必须拆分 |
| `execute` | BusinessScenarioTools.swift:841 | 69 | 22 | 4 | 15 | 0 | 圈复杂度 22，必须拆分 |
| `actionDisplayName` | ComputerUseRuntime.swift:228 | 25 | 22 | 2 | 21 | 0 | 圈复杂度 22，必须拆分 |
| `runClaudeCode` | DeveloperLoop.swift:182 | 67 | 22 | 5 | 15 | 1 | 圈复杂度 22，必须拆分 |
| `recall` | WorkflowMemoryStore.swift:106 | 78 | 22 | 4 | 14 | 2 | 圈复杂度 22，必须拆分 |
| `contextPrompt` | AssistantSessionController.swift:1741 | 91 | 22 | 5 | 16 | 2 | 圈复杂度 22，必须拆分 |
| `init` | EngineerScenarioTools.swift:920 | 94 | 21 | 6 | 14 | 2 | 圈复杂度 21，必须拆分；嵌套过深，提前返回 |
| `execute` | EngineerScenarioTools.swift:922 | 92 | 21 | 6 | 14 | 2 | 圈复杂度 21，必须拆分；嵌套过深，提前返回 |
| `init` | BusinessScenarioTools.swift:2845 | 129 | 21 | 3 | 20 | 0 | 圈复杂度 21，必须拆分；函数过长 (129行) |
| `execute` | BusinessScenarioTools.swift:2847 | 127 | 21 | 3 | 20 | 0 | 圈复杂度 21，必须拆分；函数过长 (127行) |
| `init` | ProductManagerTools.swift:750 | 121 | 21 | 4 | 14 | 6 | 圈复杂度 21，必须拆分；函数过长 (121行) |
| `execute` | ProductManagerTools.swift:752 | 119 | 21 | 4 | 14 | 6 | 圈复杂度 21，必须拆分；函数过长 (119行) |
| `isMutatingShellCommand` | ToolSafetyGateway.swift:447 | 40 | 21 | 2 | 9 | 0 | 圈复杂度 21，必须拆分 |
| `screenContextPrompt` | ConversationEngine.swift:1815 | 50 | 21 | 3 | 8 | 1 | 圈复杂度 21，必须拆分 |
| `collectStructuredResult` | ClaudeCodeBridge.swift:358 | 62 | 21 | 5 | 14 | 1 | 圈复杂度 21，必须拆分 |
| `check` | PermissionCenter.swift:223 | 75 | 21 | 3 | 19 | 0 | 圈复杂度 21，必须拆分 |
| `verifyFinderToolResult` | ConversationEngine.swift:1302 | 97 | 20 | 3 | 10 | 0 | 圈复杂度 20，必须拆分 |
| `chatStream` | CloudOpenAI.swift:42 | 91 | 20 | 10 | 15 | 3 | 圈复杂度 20，必须拆分；嵌套过深，提前返回 |
| `chatStream` | CloudOpenAICompatible.swift:46 | 91 | 20 | 10 | 15 | 3 | 圈复杂度 20，必须拆分；嵌套过深，提前返回 |
| `actionKind` | ModelActionPlanner.swift:95 | 23 | 20 | 2 | 19 | 0 | 圈复杂度 20，必须拆分 |
| `promptSummary` | DesktopContext.swift:45 | 70 | 20 | 3 | 18 | 1 | 圈复杂度 20，必须拆分 |
| `classifyFailure` | RecoveryDecider.swift:79 | 10 | 20 | 1 | 6 | 0 | 圈复杂度 20，必须拆分 |
| `cancel` | ComputerUseRuntime.swift:23 | 186 | 19 | 4 | 12 | 1 | 圈复杂度 19，必须拆分；函数过长 (186行) |
| `run` | ComputerUseRuntime.swift:25 | 184 | 19 | 4 | 12 | 1 | 圈复杂度 19，必须拆分；函数过长 (184行) |
| `init` | ProductManagerTools.swift:563 | 89 | 19 | 4 | 11 | 4 | 圈复杂度 19，必须拆分 |
| `execute` | ProductManagerTools.swift:565 | 87 | 19 | 4 | 11 | 4 | 圈复杂度 19，必须拆分 |
| `sendDeveloperAgentTask` | ConversationEngine.swift:507 | 108 | 19 | 4 | 17 | 1 | 圈复杂度 19，必须拆分；函数过长 (108行) |
| `formatDeveloperTaskFinalText` | ConversationEngine.swift:668 | 55 | 19 | 3 | 18 | 0 | 圈复杂度 19，必须拆分 |
| `classifyFailure` | ConversationEngine.swift:2058 | 11 | 19 | 1 | 7 | 0 | 圈复杂度 19，必须拆分 |
| `handleMessage` | RealtimeProviders.swift:241 | 55 | 19 | 3 | 18 | 0 | 圈复杂度 19，必须拆分 |
| `parseJSONLine` | ClaudeCodeBridge.swift:196 | 55 | 19 | 6 | 17 | 1 | 圈复杂度 19，必须拆分；嵌套过深，提前返回 |
| `init` | FoundationServices.swift:251 | 73 | 19 | 4 | 16 | 0 | 圈复杂度 19，必须拆分 |
| `snapshots` | FoundationServices.swift:253 | 71 | 19 | 4 | 16 | 0 | 圈复杂度 19，必须拆分 |
| `init` | DeveloperToolbox.swift:321 | 105 | 18 | 4 | 14 | 2 | 圈复杂度 18，必须拆分；函数过长 (105行) |
| `execute` | DeveloperToolbox.swift:323 | 103 | 18 | 4 | 14 | 2 | 圈复杂度 18，必须拆分；函数过长 (103行) |
| `detectEnvironment` | EngineerScenarioTools.swift:1641 | 33 | 18 | 2 | 9 | 0 | 圈复杂度 18，必须拆分 |
| `findSuggestion` | BusinessScenarioTools.swift:3344 | 22 | 18 | 2 | 6 | 1 | 圈复杂度 18，必须拆分 |
| `extractAppName` | ConversationEngine.swift:2177 | 82 | 18 | 5 | 13 | 3 | 圈复杂度 18，必须拆分 |
| `startListening` | AssistantSessionController.swift:516 | 75 | 18 | 6 | 15 | 1 | 圈复杂度 18，必须拆分；嵌套过深，提前返回 |
| `handleUserText` | AssistantSessionController.swift:930 | 144 | 18 | 5 | 12 | 0 | 圈复杂度 18，必须拆分；函数过长 (144行) |
| `isCurrentWeChatConversation` | ComputerUsePlanner.swift:302 | 23 | 18 | 3 | 3 | 0 | 圈复杂度 18，必须拆分 |
| `init` | EngineerScenarioTools.swift:22 | 67 | 17 | 3 | 10 | 3 | 圈复杂度 17，必须拆分 |
| `execute` | EngineerScenarioTools.swift:24 | 65 | 17 | 3 | 10 | 3 | 圈复杂度 17，必须拆分 |
| `init` | EngineerScenarioTools.swift:1086 | 81 | 17 | 5 | 12 | 2 | 圈复杂度 17，必须拆分 |
| `execute` | EngineerScenarioTools.swift:1088 | 79 | 17 | 5 | 12 | 2 | 圈复杂度 17，必须拆分 |
| `init` | ScenarioTools.swift:76 | 68 | 17 | 4 | 12 | 2 | 圈复杂度 17，必须拆分 |
| `execute` | ScenarioTools.swift:78 | 66 | 17 | 4 | 12 | 2 | 圈复杂度 17，必须拆分 |
| `resizeWindow` | AccessibilityBridge.swift:419 | 49 | 17 | 4 | 15 | 1 | 圈复杂度 17，必须拆分 |
| `hasUnsafePatterns` | ShellExecutor.swift:129 | 15 | 17 | 2 | 7 | 0 | 圈复杂度 17，必须拆分 |
| `init` | ChangedFilesTool.swift:15 | 78 | 16 | 4 | 11 | 1 | 圈复杂度 16，必须拆分 |
| `execute` | ChangedFilesTool.swift:17 | 76 | 16 | 4 | 11 | 1 | 圈复杂度 16，必须拆分 |
| `analyzeFailure` | EngineerScenarioTools.swift:219 | 22 | 16 | 2 | 6 | 0 | 圈复杂度 16，必须拆分 |
| `init` | EngineerScenarioTools.swift:327 | 86 | 16 | 4 | 11 | 3 | 圈复杂度 16，必须拆分 |
| `execute` | EngineerScenarioTools.swift:329 | 84 | 16 | 4 | 11 | 3 | 圈复杂度 16，必须拆分 |
| `init` | DesignerTools.swift:847 | 92 | 16 | 5 | 8 | 2 | 圈复杂度 16，必须拆分 |
| `execute` | DesignerTools.swift:849 | 90 | 16 | 5 | 8 | 2 | 圈复杂度 16，必须拆分 |
| `init` | ProductManagerTools.swift:888 | 115 | 16 | 5 | 14 | 1 | 圈复杂度 16，必须拆分；函数过长 (115行) |
| `execute` | ProductManagerTools.swift:890 | 113 | 16 | 5 | 14 | 1 | 圈复杂度 16，必须拆分；函数过长 (113行) |
| `verifyTerminalRun` | ConversationEngine.swift:1218 | 83 | 16 | 2 | 5 | 0 | 圈复杂度 16，必须拆分 |
| `executePlan` | PlanExecutor.swift:57 | 176 | 16 | 6 | 10 | 2 | 圈复杂度 16，必须拆分；嵌套过深，提前返回；函数过长 (176行) |
| `verify` | AssistantSessionController.swift:1542 | 32 | 16 | 3 | 9 | 0 | 圈复杂度 16，必须拆分 |
| `findElement` | AccessibilityBridge.swift:750 | 39 | 16 | 4 | 8 | 1 | 圈复杂度 16，必须拆分 |
| `developerTaskDetail` | AgentConsoleView.swift:501 | 101 | 16 | 6 | 13 | 0 | 圈复杂度 16，必须拆分；嵌套过深，提前返回；函数过长 (101行) |
| `findCallers` | EngineerScenarioTools.swift:618 | 43 | 15 | 3 | 6 | 1 | 建议拆分为 2 个函数 |
| `analyzeCrash` | EngineerScenarioTools.swift:1266 | 46 | 15 | 3 | 9 | 0 | 建议拆分为 2 个函数 |
| `init` | BusinessScenarioTools.swift:131 | 71 | 15 | 4 | 10 | 3 | 建议拆分为 2 个函数 |
| `execute` | BusinessScenarioTools.swift:133 | 69 | 15 | 4 | 10 | 3 | 建议拆分为 2 个函数 |
| `recover` | ComputerUseRuntime.swift:926 | 127 | 15 | 5 | 13 | 1 | 建议拆分为 2 个函数；函数过长 (127行) |
| `init` | DesignerTools.swift:542 | 86 | 15 | 5 | 10 | 1 | 建议拆分为 2 个函数 |
| `execute` | DesignerTools.swift:544 | 84 | 15 | 5 | 10 | 1 | 建议拆分为 2 个函数 |
| `handleDeterministicDesktopTask` | ConversationEngine.swift:841 | 53 | 15 | 2 | 5 | 1 | 建议拆分为 2 个函数 |
| `routeDecisions` | SmartRouter.swift:284 | 68 | 15 | 3 | 12 | 1 | 建议拆分为 2 个函数 |
| `init` | ComputerUsePlanner.swift:7 | 183 | 15 | 3 | 12 | 0 | 建议拆分为 2 个函数；函数过长 (183行) |
| `plan` | ComputerUsePlanner.swift:9 | 181 | 15 | 3 | 12 | 0 | 建议拆分为 2 个函数；函数过长 (181行) |
| `apply` | BusinessScenarioModels.swift:819 | 38 | 15 | 4 | 14 | 0 | 建议拆分为 2 个函数 |
| `validate` | WindowMatchValidator.swift:40 | 34 | 15 | 4 | 9 | 3 | 建议拆分为 2 个函数 |
| `typeText` | AccessibilityBridge.swift:209 | 45 | 15 | 5 | 11 | 1 | 建议拆分为 2 个函数 |
| `injectDevtoolsObserver` | AppDrivers.swift:985 | 83 | 15 | 5 | 5 | 0 | 建议拆分为 2 个函数 |
| `checkSystemPermission` | PermissionCenter.swift:99 | 50 | 15 | 3 | 14 | 0 | 建议拆分为 2 个函数 |
| `init` | CodeTools.swift:356 | 63 | 14 | 3 | 10 | 3 | 建议拆分为 2 个函数 |
| `execute` | CodeTools.swift:358 | 61 | 14 | 3 | 10 | 3 | 建议拆分为 2 个函数 |
| `init` | BusinessScenarioTools.swift:456 | 66 | 14 | 4 | 13 | 0 | 建议拆分为 2 个函数 |
| `execute` | BusinessScenarioTools.swift:458 | 64 | 14 | 4 | 13 | 0 | 建议拆分为 2 个函数 |
| `init` | BusinessScenarioTools.swift:1766 | 83 | 14 | 4 | 13 | 0 | 建议拆分为 2 个函数 |
| `execute` | BusinessScenarioTools.swift:1768 | 81 | 14 | 4 | 13 | 0 | 建议拆分为 2 个函数 |
| `init` | BusinessScenarioTools.swift:2312 | 95 | 14 | 3 | 13 | 0 | 建议拆分为 2 个函数 |
| `execute` | BusinessScenarioTools.swift:2314 | 93 | 14 | 3 | 13 | 0 | 建议拆分为 2 个函数 |
| `init` | DesignerTools.swift:724 | 108 | 14 | 3 | 11 | 0 | 建议拆分为 2 个函数；函数过长 (108行) |
| `execute` | DesignerTools.swift:726 | 106 | 14 | 3 | 11 | 0 | 建议拆分为 2 个函数；函数过长 (106行) |
| `init` | DesignerTools.swift:954 | 71 | 14 | 5 | 8 | 2 | 建议拆分为 2 个函数 |
| `execute` | DesignerTools.swift:956 | 69 | 14 | 5 | 8 | 2 | 建议拆分为 2 个函数 |
| `executeLoop` | DeveloperLoop.swift:51 | 128 | 14 | 3 | 11 | 2 | 建议拆分为 2 个函数；函数过长 (128行) |
| `intent` | ComputerUsePlanner.swift:390 | 16 | 14 | 2 | 12 | 1 | 建议拆分为 2 个函数 |
| `chatStream` | CloudAnthropic.swift:42 | 66 | 14 | 7 | 10 | 1 | 建议拆分为 2 个函数；嵌套过深，提前返回 |
| `parseFileOps` | CommandParser.swift:336 | 55 | 14 | 4 | 13 | 0 | 建议拆分为 2 个函数 |
| `runStructured` | ClaudeCodeBridge.swift:108 | 87 | 14 | 6 | 10 | 2 | 建议拆分为 2 个函数；嵌套过深，提前返回 |
| `openSettings` | PermissionCenter.swift:344 | 27 | 14 | 2 | 12 | 1 | 建议拆分为 2 个函数 |
| `init` | DeveloperToolbox.swift:443 | 59 | 13 | 3 | 6 | 1 | 建议拆分为 2 个函数 |
| `execute` | DeveloperToolbox.swift:445 | 57 | 13 | 3 | 6 | 1 | 建议拆分为 2 个函数 |
| `compareResolved` | EngineerScenarioTools.swift:1422 | 50 | 13 | 4 | 7 | 3 | 建议拆分为 2 个函数 |
| `init` | BusinessScenarioTools.swift:1358 | 93 | 13 | 3 | 12 | 0 | 建议拆分为 2 个函数 |
| `execute` | BusinessScenarioTools.swift:1360 | 91 | 13 | 3 | 12 | 0 | 建议拆分为 2 个函数 |
| `effectiveVerificationGoal` | ComputerUseRuntime.swift:695 | 32 | 13 | 3 | 10 | 1 | 建议拆分为 2 个函数 |
| `init` | DesignerTools.swift:344 | 89 | 13 | 6 | 9 | 1 | 建议拆分为 2 个函数；嵌套过深，提前返回 |
| `execute` | DesignerTools.swift:346 | 87 | 13 | 6 | 9 | 1 | 建议拆分为 2 个函数；嵌套过深，提前返回 |
| `blockedResult` | ToolSafetyGateway.swift:136 | 67 | 13 | 4 | 9 | 2 | 建议拆分为 2 个函数 |
| `parseFrontmatter` | SkillRegistry.swift:132 | 25 | 13 | 4 | 8 | 1 | 建议拆分为 2 个函数 |
| `quickAction` | ConversationEngine.swift:1639 | 59 | 13 | 2 | 12 | 0 | 建议拆分为 2 个函数 |
| `extractPatterns` | WorkflowMemoryStore.swift:185 | 66 | 13 | 4 | 4 | 7 | 建议拆分为 2 个函数 |
| `publishTraceToEventBus` | AssistantSessionController.swift:221 | 27 | 13 | 2 | 12 | 0 | 建议拆分为 2 个函数 |
| `handleBuiltInCommand` | AssistantSessionController.swift:1675 | 20 | 13 | 2 | 3 | 0 | 建议拆分为 2 个函数 |
| `click` | AccessibilityContextProvider.swift:234 | 58 | 13 | 5 | 9 | 3 | 建议拆分为 2 个函数 |
| `activateRunningApplication` | AccessibilityContextProvider.swift:535 | 43 | 13 | 3 | 8 | 1 | 建议拆分为 2 个函数 |
| `defaultFix` | FoundationServices.swift:123 | 14 | 13 | 2 | 11 | 1 | 建议拆分为 2 个函数 |
| `extractRootCauses` | AgentConsoleView.swift:656 | 39 | 13 | 3 | 6 | 1 | 建议拆分为 2 个函数 |
| `init` | DeveloperToolbox.swift:184 | 53 | 12 | 3 | 11 | 0 | 建议拆分为 2 个函数 |
| `execute` | DeveloperToolbox.swift:186 | 51 | 12 | 3 | 11 | 0 | 建议拆分为 2 个函数 |
| `deduplicateSymbolResults` | DeveloperToolbox.swift:570 | 32 | 12 | 5 | 8 | 1 | 建议拆分为 2 个函数 |
| `init` | EngineerScenarioTools.swift:465 | 59 | 12 | 4 | 7 | 2 | 建议拆分为 2 个函数 |
| `execute` | EngineerScenarioTools.swift:467 | 57 | 12 | 4 | 7 | 2 | 建议拆分为 2 个函数 |
| `init` | BusinessScenarioTools.swift:1270 | 59 | 12 | 4 | 11 | 0 | 建议拆分为 2 个函数 |
| `execute` | BusinessScenarioTools.swift:1272 | 57 | 12 | 4 | 11 | 0 | 建议拆分为 2 个函数 |
| `init` | BusinessScenarioTools.swift:2694 | 92 | 12 | 3 | 11 | 0 | 建议拆分为 2 个函数 |
| `execute` | BusinessScenarioTools.swift:2696 | 90 | 12 | 3 | 11 | 0 | 建议拆分为 2 个函数 |
| `init` | BusinessScenarioTools.swift:3118 | 74 | 12 | 3 | 10 | 0 | 建议拆分为 2 个函数 |
| `execute` | BusinessScenarioTools.swift:3120 | 72 | 12 | 3 | 10 | 0 | 建议拆分为 2 个函数 |
| `verifyClickElementAction` | ComputerUseRuntime.swift:652 | 42 | 12 | 3 | 8 | 0 | 建议拆分为 2 个函数 |
| `init` | ProductManagerTools.swift:110 | 88 | 12 | 3 | 6 | 2 | 建议拆分为 2 个函数 |
| `execute` | ProductManagerTools.swift:112 | 86 | 12 | 3 | 6 | 2 | 建议拆分为 2 个函数 |
| `phaseLabel` | ConversationEngine.swift:616 | 14 | 12 | 2 | 11 | 0 | 建议拆分为 2 个函数 |
| `handleDeterministicToolTask` | ConversationEngine.swift:895 | 70 | 12 | 3 | 10 | 0 | 建议拆分为 2 个函数 |
| `loadProviderSettings` | AssistantSessionController.swift:1914 | 39 | 12 | 3 | 9 | 2 | 建议拆分为 2 个函数 |
| `parseLine` | ClaudeCodeCLI.swift:189 | 37 | 12 | 5 | 9 | 2 | 建议拆分为 2 个函数 |
| `clickChromiumStyle` | AccessibilityContextProvider.swift:304 | 104 | 12 | 3 | 8 | 3 | 建议拆分为 2 个函数；函数过长 (104行) |
| `requestSystemPermission` | PermissionCenter.swift:150 | 56 | 12 | 4 | 11 | 0 | 建议拆分为 2 个函数 |
| `request` | PermissionCenter.swift:299 | 43 | 12 | 4 | 11 | 0 | 建议拆分为 2 个函数 |
| `parseSwiftTestOutput` | DeveloperTools.swift:195 | 40 | 11 | 4 | 5 | 1 | 建议拆分为 2 个函数 |
| `parseTestOutput` | EngineerScenarioTools.swift:242 | 51 | 11 | 4 | 5 | 1 | 建议拆分为 2 个函数 |
| `init` | BusinessScenarioTools.swift:1564 | 86 | 11 | 3 | 10 | 0 | 建议拆分为 2 个函数 |
| `execute` | BusinessScenarioTools.swift:1566 | 84 | 11 | 3 | 10 | 0 | 建议拆分为 2 个函数 |
| `init` | DesignerTools.swift:122 | 81 | 11 | 5 | 6 | 2 | 建议拆分为 2 个函数 |
| `execute` | DesignerTools.swift:124 | 79 | 11 | 5 | 6 | 2 | 建议拆分为 2 个函数 |
| `init` | DesignerTools.swift:643 | 66 | 11 | 3 | 6 | 2 | 建议拆分为 2 个函数 |
| `execute` | DesignerTools.swift:645 | 64 | 11 | 3 | 6 | 2 | 建议拆分为 2 个函数 |
| `init` | SystemTools.swift:47 | 33 | 11 | 4 | 6 | 0 | 建议拆分为 2 个函数 |
| `execute` | SystemTools.swift:49 | 31 | 11 | 4 | 6 | 0 | 建议拆分为 2 个函数 |
| `runAllGuards` | RoleScenarioSafetyService.swift:128 | 47 | 11 | 3 | 9 | 1 | 建议拆分为 2 个函数 |
| `readScreenContent` | ConversationEngine.swift:1768 | 46 | 11 | 4 | 8 | 2 | 建议拆分为 2 个函数 |
| `transition` | DeveloperLoop.swift:250 | 24 | 11 | 2 | 10 | 0 | 建议拆分为 2 个函数 |
| `extractExpectedKeywords` | ToolExecutionService.swift:132 | 24 | 11 | 2 | 10 | 0 | 建议拆分为 2 个函数 |
| `probeGate` | AssistantSessionController.swift:341 | 44 | 11 | 4 | 8 | 2 | 建议拆分为 2 个函数 |
| `isValidSpeechContent` | AssistantSessionController.swift:897 | 21 | 11 | 3 | 7 | 1 | 建议拆分为 2 个函数 |
| `performComputerUseSteps` | AssistantSessionController.swift:1437 | 104 | 11 | 4 | 8 | 1 | 建议拆分为 2 个函数；函数过长 (104行) |
| `consumeRealtimeEvents` | AssistantSessionController.swift:1992 | 23 | 11 | 3 | 9 | 1 | 建议拆分为 2 个函数 |
| `runStructured` | ClaudeCodeCLI.swift:90 | 98 | 11 | 5 | 8 | 1 | 建议拆分为 2 个函数 |
| `runStructured` | CodexCLIBackend.swift:87 | 96 | 11 | 5 | 8 | 1 | 建议拆分为 2 个函数 |
| `parseGitAdvanced` | CommandParser.swift:736 | 13 | 11 | 1 | 10 | 0 | 建议拆分为 2 个函数 |
| `discoverModels` | LocalModelManager.swift:101 | 29 | 11 | 6 | 6 | 4 | 建议拆分为 2 个函数；嵌套过深，提前返回 |
| `startListening` | RealtimeProviders.swift:376 | 27 | 11 | 5 | 8 | 1 | 建议拆分为 2 个函数 |
| `assess` | BusinessScenarioModels.swift:251 | 26 | 11 | 2 | 10 | 0 | 建议拆分为 2 个函数 |
| `scroll` | AccessibilityBridge.swift:471 | 35 | 11 | 4 | 6 | 4 | 建议拆分为 2 个函数 |
| `evaluate` | ActionSafety.swift:18 | 28 | 11 | 3 | 10 | 0 | 建议拆分为 2 个函数 |
| `receive` | ChatwootBridge.swift:211 | 24 | 11 | 5 | 10 | 0 | 建议拆分为 2 个函数 |
| `run` | ClaudeCodeBridge.swift:30 | 75 | 11 | 4 | 9 | 0 | 建议拆分为 2 个函数 |
| `findConnectedComponents` | DBPostProcessor.swift:90 | 46 | 11 | 6 | 3 | 4 | 建议拆分为 2 个函数；嵌套过深，提前返回 |
| `defaultScores` | RecoveryDecider.swift:94 | 23 | 11 | 2 | 9 | 1 | 建议拆分为 2 个函数 |

## 重构优先级

### 1. 最高：圈复杂度 > 15 的函数

共 88 个函数：
- `evaluateVerification` — ComputerUseRuntime.swift:302 — 圈复杂度 59 — 219 行
- `sendMessage` — ConversationEngine.swift:212 — 圈复杂度 57 — 292 行
- `init` — AppInstructionLibrary.swift:4 — 圈复杂度 43 — 76 行
- `instructions` — AppInstructionLibrary.swift:6 — 圈复杂度 43 — 74 行
- `execute` — AgentOrchestrator.swift:28 — 圈复杂度 41 — 303 行
- `handle` — main.swift:30 — 圈复杂度 36 — 161 行
- `explainRisk` — ToolSafetyGateway.swift:338 — 圈复杂度 35 — 86 行
- `init` — ProductManagerTools.swift:320 — 圈复杂度 32 — 122 行
- `execute` — ProductManagerTools.swift:322 — 圈复杂度 32 — 120 行
- `parse` — CommandParser.swift:10 — 圈复杂度 32 — 38 行
- `init` — ProductManagerTools.swift:1017 — 圈复杂度 29 — 124 行
- `execute` — ProductManagerTools.swift:1019 — 圈复杂度 29 — 122 行
- `execute` — ActionSafety.swift:55 — 圈复杂度 28 — 109 行
- `summarize` — ToolSafetyGateway.swift:204 — 圈复杂度 27 — 61 行
- `categorize` — ToolSafetyGateway.swift:266 — 圈复杂度 26 — 71 行
- `init` — FocusGuard.swift:20 — 圈复杂度 26 — 151 行
- `parseCrashLog` — EngineerScenarioTools.swift:1168 — 圈复杂度 25 — 97 行
- `init` — DesignerTools.swift:218 — 圈复杂度 25 — 110 行
- `execute` — DesignerTools.swift:220 — 圈复杂度 25 — 108 行
- `assessComplexity` — SmartRouter.swift:177 — 圈复杂度 25 — 106 行
- `init` — CodeTools.swift:459 — 圈复杂度 24 — 99 行
- `execute` — CodeTools.swift:461 — 圈复杂度 24 — 97 行
- `sampleProcess` — EngineerScenarioTools.swift:1757 — 圈复杂度 23 — 106 行
- `init` — DesignerTools.swift:18 — 圈复杂度 23 — 89 行
- `execute` — DesignerTools.swift:20 — 圈复杂度 23 — 87 行
- `init` — BusinessScenarioTools.swift:839 — 圈复杂度 22 — 71 行
- `execute` — BusinessScenarioTools.swift:841 — 圈复杂度 22 — 69 行
- `actionDisplayName` — ComputerUseRuntime.swift:228 — 圈复杂度 22 — 25 行
- `runClaudeCode` — DeveloperLoop.swift:182 — 圈复杂度 22 — 67 行
- `recall` — WorkflowMemoryStore.swift:106 — 圈复杂度 22 — 78 行
- `contextPrompt` — AssistantSessionController.swift:1741 — 圈复杂度 22 — 91 行
- `init` — EngineerScenarioTools.swift:920 — 圈复杂度 21 — 94 行
- `execute` — EngineerScenarioTools.swift:922 — 圈复杂度 21 — 92 行
- `init` — BusinessScenarioTools.swift:2845 — 圈复杂度 21 — 129 行
- `execute` — BusinessScenarioTools.swift:2847 — 圈复杂度 21 — 127 行
- `init` — ProductManagerTools.swift:750 — 圈复杂度 21 — 121 行
- `execute` — ProductManagerTools.swift:752 — 圈复杂度 21 — 119 行
- `isMutatingShellCommand` — ToolSafetyGateway.swift:447 — 圈复杂度 21 — 40 行
- `screenContextPrompt` — ConversationEngine.swift:1815 — 圈复杂度 21 — 50 行
- `collectStructuredResult` — ClaudeCodeBridge.swift:358 — 圈复杂度 21 — 62 行
- `check` — PermissionCenter.swift:223 — 圈复杂度 21 — 75 行
- `verifyFinderToolResult` — ConversationEngine.swift:1302 — 圈复杂度 20 — 97 行
- `chatStream` — CloudOpenAI.swift:42 — 圈复杂度 20 — 91 行
- `chatStream` — CloudOpenAICompatible.swift:46 — 圈复杂度 20 — 91 行
- `actionKind` — ModelActionPlanner.swift:95 — 圈复杂度 20 — 23 行
- `promptSummary` — DesktopContext.swift:45 — 圈复杂度 20 — 70 行
- `classifyFailure` — RecoveryDecider.swift:79 — 圈复杂度 20 — 10 行
- `cancel` — ComputerUseRuntime.swift:23 — 圈复杂度 19 — 186 行
- `run` — ComputerUseRuntime.swift:25 — 圈复杂度 19 — 184 行
- `init` — ProductManagerTools.swift:563 — 圈复杂度 19 — 89 行
- `execute` — ProductManagerTools.swift:565 — 圈复杂度 19 — 87 行
- `sendDeveloperAgentTask` — ConversationEngine.swift:507 — 圈复杂度 19 — 108 行
- `formatDeveloperTaskFinalText` — ConversationEngine.swift:668 — 圈复杂度 19 — 55 行
- `classifyFailure` — ConversationEngine.swift:2058 — 圈复杂度 19 — 11 行
- `handleMessage` — RealtimeProviders.swift:241 — 圈复杂度 19 — 55 行
- `parseJSONLine` — ClaudeCodeBridge.swift:196 — 圈复杂度 19 — 55 行
- `init` — FoundationServices.swift:251 — 圈复杂度 19 — 73 行
- `snapshots` — FoundationServices.swift:253 — 圈复杂度 19 — 71 行
- `init` — DeveloperToolbox.swift:321 — 圈复杂度 18 — 105 行
- `execute` — DeveloperToolbox.swift:323 — 圈复杂度 18 — 103 行
- `detectEnvironment` — EngineerScenarioTools.swift:1641 — 圈复杂度 18 — 33 行
- `findSuggestion` — BusinessScenarioTools.swift:3344 — 圈复杂度 18 — 22 行
- `extractAppName` — ConversationEngine.swift:2177 — 圈复杂度 18 — 82 行
- `startListening` — AssistantSessionController.swift:516 — 圈复杂度 18 — 75 行
- `handleUserText` — AssistantSessionController.swift:930 — 圈复杂度 18 — 144 行
- `isCurrentWeChatConversation` — ComputerUsePlanner.swift:302 — 圈复杂度 18 — 23 行
- `init` — EngineerScenarioTools.swift:22 — 圈复杂度 17 — 67 行
- `execute` — EngineerScenarioTools.swift:24 — 圈复杂度 17 — 65 行
- `init` — EngineerScenarioTools.swift:1086 — 圈复杂度 17 — 81 行
- `execute` — EngineerScenarioTools.swift:1088 — 圈复杂度 17 — 79 行
- `init` — ScenarioTools.swift:76 — 圈复杂度 17 — 68 行
- `execute` — ScenarioTools.swift:78 — 圈复杂度 17 — 66 行
- `resizeWindow` — AccessibilityBridge.swift:419 — 圈复杂度 17 — 49 行
- `hasUnsafePatterns` — ShellExecutor.swift:129 — 圈复杂度 17 — 15 行
- `init` — ChangedFilesTool.swift:15 — 圈复杂度 16 — 78 行
- `execute` — ChangedFilesTool.swift:17 — 圈复杂度 16 — 76 行
- `analyzeFailure` — EngineerScenarioTools.swift:219 — 圈复杂度 16 — 22 行
- `init` — EngineerScenarioTools.swift:327 — 圈复杂度 16 — 86 行
- `execute` — EngineerScenarioTools.swift:329 — 圈复杂度 16 — 84 行
- `init` — DesignerTools.swift:847 — 圈复杂度 16 — 92 行
- `execute` — DesignerTools.swift:849 — 圈复杂度 16 — 90 行
- `init` — ProductManagerTools.swift:888 — 圈复杂度 16 — 115 行
- `execute` — ProductManagerTools.swift:890 — 圈复杂度 16 — 113 行
- `verifyTerminalRun` — ConversationEngine.swift:1218 — 圈复杂度 16 — 83 行
- `executePlan` — PlanExecutor.swift:57 — 圈复杂度 16 — 176 行
- `verify` — AssistantSessionController.swift:1542 — 圈复杂度 16 — 32 行
- `findElement` — AccessibilityBridge.swift:750 — 圈复杂度 16 — 39 行
- `developerTaskDetail` — AgentConsoleView.swift:501 — 圈复杂度 16 — 101 行

### 2. 高：文件超过 300 行

共 51 个文件：
- `RenJistrolyCapability/MCPServer/SystemControl/BusinessScenarioTools.swift` — 3367 行，71 个函数
- `RenJistrolyConversation/ConversationEngine.swift` — 2417 行，81 个函数
- `RenJistrolyIntelligence/AssistantSessionController.swift` — 2016 行，96 个函数
- `RenJistrolyCapability/MCPServer/CodeEngine/EngineerScenarioTools.swift` — 1960 行，63 个函数
- `RenJistrolySystemBridge/AppDrivers.swift` — 1766 行，117 个函数
- `RenJistrolyIntelligence/LLMBackend/CommandParser.swift` — 1268 行，50 个函数
- `RenJistrolySystemBridge/AccessibilityContextProvider.swift` — 1259 行，72 个函数
- `RenJistrolyCapability/MCPServer/SystemControl/ComputerUseRuntime.swift` — 1194 行，29 个函数
- `RenJistrolyCapability/MCPServer/SystemControl/ProductManagerTools.swift` — 1142 行，21 个函数
- `RenJistrolyModels/BusinessScenarioModels.swift` — 1119 行，39 个函数
- `RenJistrolyCapability/MCPServer/SystemControl/DesignerTools.swift` — 1033 行，21 个函数
- `RenJistrolyModels/TrustMechanisms.swift` — 1031 行，28 个函数
- `RenJistrolyCapability/MCPServer/CodeEngine/DeveloperToolbox.swift` — 1012 行，40 个函数
- `RenJistrolySystemBridge/AccessibilityBridge.swift` — 971 行，51 个函数
- `RenJistrolyModels/RoleScenarioGuards.swift` — 960 行，47 个函数
- `RenJistrolyModels/AgentSystems.swift` — 766 行，23 个函数
- `RenJistrolyModels/ExecutiveUXModels.swift` — 766 行，18 个函数
- `RenJistrolyUI/Components/AgentConsoleView.swift` — 709 行，9 个函数
- `RenJistrolyUI/MainWindow/MainWindowView.swift` — 708 行，7 个函数
- `RenJistrolyCapability/MCPServer/SystemControl/AppDriverTools.swift` — 677 行，47 个函数
- `RenJistrolyApp/SettingsView.swift` — 673 行，7 个函数
- `RenJistrolySystemBridge/DeveloperAgentTaskStore.swift` — 619 行，36 个函数
- `RenJistrolyUI/FloatingPanel/FloatingPanelView.swift` — 617 行，7 个函数
- `RenJistrolyUI/FoundationCenterView.swift` — 586 行，6 个函数
- `RenJistrolyCapability/MCPServer/CodeEngine/CodeTools.swift` — 559 行，22 个函数
- `RenJistrolyIntelligence/AgentOrchestrator/AgentOrchestrator.swift` — 534 行，12 个函数
- `RenJistrolyIntelligence/ComputerUsePlanner.swift` — 527 行，19 个函数
- `RenJistrolyIntelligence/AgentOrchestrator/SmartRouter.swift` — 516 行，18 个函数
- `RenJistrolyCapability/MCPServer/ToolSafetyGateway.swift` — 513 行，14 个函数
- `RenJistrolyIntelligence/RealtimeProviders.swift` — 491 行，29 个函数
- `RenJistrolyCapability/MCPServer/SystemControl/SystemTools.swift` — 474 行，22 个函数
- `RenJistrolyConversation/WorkflowMemoryStore.swift` — 473 行，25 个函数
- `RenJistrolySystemBridge/ClaudeCodeBridge.swift` — 466 行，14 个函数
- `RenJistrolySystemBridge/PermissionCenter.swift` — 453 行，12 个函数
- `RenJistrolyCapability/MCPServer/CodeEngine/DeveloperTools.swift` — 430 行，15 个函数
- `RenJistrolySystemBridge/FoundationServices.swift` — 427 行，31 个函数
- `RenJistrolyUI/AssistantRootView.swift` — 394 行，2 个函数
- `RenJistrolyEnterprise/ContextProvider.swift` — 376 行，29 个函数
- `RenJistrolyIntelligence/LLMBackend/CloudOpenAI.swift` — 376 行，7 个函数
- `RenJistrolyEnterprise/DevContextProvider.swift` — 372 行，25 个函数
- `RenJistrolyConversation/DeveloperLoop.swift` — 368 行，13 个函数
- `RenJistrolyCapability/MCPServer/AppIntegration/AppIntegrationTools.swift` — 357 行，12 个函数
- `RenJistrolyIntelligence/AgentOrchestrator/TaskRouter.swift` — 356 行，14 个函数
- `RenJistrolyApp/AppDelegate.swift` — 348 行，22 个函数
- `RenJistrolyCapability/MCPServer/SystemControl/ControlTools.swift` — 348 行，20 个函数
- `RenJistrolySystemBridge/ChatwootBridge.swift` — 344 行，25 个函数
- `RenJistrolyIntelligence/LLMBackend/CloudGoogle.swift` — 336 行，9 个函数
- `RenJistrolyIntelligence/LLMBackend/CloudOpenAICompatible.swift` — 335 行，6 个函数
- `RenJistrolyBridge/main.swift` — 329 行，5 个函数
- `RenJistrolyIntelligence/LLMBackend/CloudAnthropic.swift` — 324 行，8 个函数

### 3. 中：嵌套深度 > 5

共 27 个函数：
- `chatStream` — CloudOpenAI.swift:42 — 深度 10，圈复杂度 20
- `chatStream` — CloudOpenAICompatible.swift:46 — 深度 10，圈复杂度 20
- `init` — ProductManagerTools.swift:320 — 深度 7，圈复杂度 32
- `execute` — ProductManagerTools.swift:322 — 深度 7，圈复杂度 32
- `init` — ProductManagerTools.swift:1017 — 深度 7，圈复杂度 29
- `execute` — ProductManagerTools.swift:1019 — 深度 7，圈复杂度 29
- `execute` — AgentOrchestrator.swift:28 — 深度 7，圈复杂度 41
- `startGateReplyLoop` — AssistantSessionController.swift:303 — 深度 7，圈复杂度 6
- `chatStream` — CloudAnthropic.swift:42 — 深度 7，圈复杂度 14
- `setupEventHandler` — HotkeyManager.swift:51 — 深度 6，圈复杂度 5
- `init` — EngineerScenarioTools.swift:920 — 深度 6，圈复杂度 21
- `execute` — EngineerScenarioTools.swift:922 — 深度 6，圈复杂度 21
- `init` — DesignerTools.swift:218 — 深度 6，圈复杂度 25
- `execute` — DesignerTools.swift:220 — 深度 6，圈复杂度 25
- `init` — DesignerTools.swift:344 — 深度 6，圈复杂度 13
- `execute` — DesignerTools.swift:346 — 深度 6，圈复杂度 13
- `toggleScreenStream` — ConversationEngine.swift:1593 — 深度 6，圈复杂度 4
- `executePlan` — PlanExecutor.swift:57 — 深度 6，圈复杂度 16
- `startDialogWatcher` — AssistantSessionController.swift:153 — 深度 6，圈复杂度 8
- `startListening` — AssistantSessionController.swift:516 — 深度 6，圈复杂度 18
- `chatStream` — CloudGoogle.swift:44 — 深度 6，圈复杂度 10
- `discoverModels` — LocalModelManager.swift:101 — 深度 6，圈复杂度 11
- `stream` — OpenAICompatibleChatProvider.swift:34 — 深度 6，圈复杂度 10
- `runStructured` — ClaudeCodeBridge.swift:108 — 深度 6，圈复杂度 14
- `parseJSONLine` — ClaudeCodeBridge.swift:196 — 深度 6，圈复杂度 19
- `findConnectedComponents` — DBPostProcessor.swift:90 — 深度 6，圈复杂度 11
- `developerTaskDetail` — AgentConsoleView.swift:501 — 深度 6，圈复杂度 16

### 4. 低：文件层面关注

函数数量较多的文件（> 15 个函数）：
- `RenJistrolySystemBridge/AppDrivers.swift` — 117 个函数，1766 行
- `RenJistrolyIntelligence/AssistantSessionController.swift` — 96 个函数，2016 行
- `RenJistrolyConversation/ConversationEngine.swift` — 81 个函数，2417 行
- `RenJistrolySystemBridge/AccessibilityContextProvider.swift` — 72 个函数，1259 行
- `RenJistrolyCapability/MCPServer/SystemControl/BusinessScenarioTools.swift` — 71 个函数，3367 行
- `RenJistrolyCapability/MCPServer/CodeEngine/EngineerScenarioTools.swift` — 63 个函数，1960 行
- `RenJistrolySystemBridge/AccessibilityBridge.swift` — 51 个函数，971 行
- `RenJistrolyIntelligence/LLMBackend/CommandParser.swift` — 50 个函数，1268 行
- `RenJistrolyCapability/MCPServer/SystemControl/AppDriverTools.swift` — 47 个函数，677 行
- `RenJistrolyModels/RoleScenarioGuards.swift` — 47 个函数，960 行
- `RenJistrolyCapability/MCPServer/CodeEngine/DeveloperToolbox.swift` — 40 个函数，1012 行
- `RenJistrolyModels/BusinessScenarioModels.swift` — 39 个函数，1119 行
- `RenJistrolySystemBridge/DeveloperAgentTaskStore.swift` — 36 个函数，619 行
- `RenJistrolySystemBridge/FoundationServices.swift` — 31 个函数，427 行
- `RenJistrolyCapability/MCPServer/SystemControl/ComputerUseRuntime.swift` — 29 个函数，1194 行
- `RenJistrolyEnterprise/ContextProvider.swift` — 29 个函数，376 行
- `RenJistrolyIntelligence/RealtimeProviders.swift` — 29 个函数，491 行
- `RenJistrolyModels/TrustMechanisms.swift` — 28 个函数，1031 行
- `RenJistrolyConversation/WorkflowMemoryStore.swift` — 25 个函数，473 行
- `RenJistrolyEnterprise/DevContextProvider.swift` — 25 个函数，372 行
- `RenJistrolySystemBridge/ChatwootBridge.swift` — 25 个函数，344 行
- `RenJistrolyModels/AgentSystems.swift` — 23 个函数，766 行
- `RenJistrolyApp/AppDelegate.swift` — 22 个函数，348 行
- `RenJistrolyCapability/MCPServer/CodeEngine/CodeTools.swift` — 22 个函数，559 行
- `RenJistrolyCapability/MCPServer/SystemControl/SystemTools.swift` — 22 个函数，474 行
- `RenJistrolyIntelligence/AgentOrchestrator/LMCache.swift` — 22 个函数，266 行
- `RenJistrolyCapability/MCPServer/SystemControl/DesignerTools.swift` — 21 个函数，1033 行
- `RenJistrolyCapability/MCPServer/SystemControl/ProductManagerTools.swift` — 21 个函数，1142 行
- `RenJistrolyCapability/MCPServer/SystemControl/ControlTools.swift` — 20 个函数，348 行
- `RenJistrolyIntelligence/ComputerUsePlanner.swift` — 19 个函数，527 行
- `RenJistrolyIntelligence/AgentOrchestrator/SmartRouter.swift` — 18 个函数，516 行
- `RenJistrolyModels/ExecutiveUXModels.swift` — 18 个函数，766 行
- `RenJistrolyCapability/RoleScenarioSafetyService.swift` — 17 个函数，176 行
- `RenJistrolyModels/ProviderProtocols.swift` — 17 个函数，86 行
- `RenJistrolySystemBridge/TerminalTaskStore.swift` — 16 个函数，226 行

## 统计摘要

- 总文件数: 232
- 总函数数: 2350
- 总代码行数: 61616
- 圈复杂度 > 10 的函数: 191
- 圈复杂度 > 15 的函数: 88
- 嵌套深度 > 5 的函数: 27
- 文件 > 300 行的文件: 51
- 平均圈复杂度: 4.1
- 最高圈复杂度: 59

---
*报告由代码分析工具自动生成*
