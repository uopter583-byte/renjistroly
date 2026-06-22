# Source Intake Plan

Generated during workspace cleanup on 2026-06-22.

## Summary

Untracked Swift files that should be reviewed and committed in batches:

- `Sources/RenJistrolyCapability`: 46 files
- `Sources/RenJistrolySystemBridge`: 24 files
- `Sources/RenJistrolyModels`: 8 files
- `Sources/RenJistrolyIntelligence`: 8 files
- `Sources/RenJistrolyUI`: 7 files
- `Sources/RenJistrolyConversation`: 2 files
- `Tests`: 3 files

These files are in SwiftPM target directories and the current full test run
compiled them successfully. Treat them as active code unless a later focused
review proves otherwise.

## Batch 1: UI And Interaction Tests

Files:

- `Tests/Mocks/MockScrollBridge.swift`
- `Tests/UITests/ButtonInteractionTests.swift`
- `Tests/UITests/ScrollToolTests.swift`
- `Sources/RenJistrolyUI/Components/VoiceButton.swift`
- `Sources/RenJistrolyUI/Components/DesignSystem/ConversationSidebar.swift`
- `Sources/RenJistrolyUI/Components/DesignSystem/DesignSystem.swift`
- `Sources/RenJistrolyUI/Components/DesignSystem/ModernInputBar.swift`
- `Sources/RenJistrolyUI/Components/DesignSystem/ModernMessageBubble.swift`
- `Sources/RenJistrolyUI/DesignSystem/Theme.swift`
- `Sources/RenJistrolyUI/DesignSystem/Typography.swift`

Why first:

- Closest to the reported microphone button and UI interaction failures.
- Small enough to review in one pass.

Suggested verification:

```bash
swift test --filter 'RenJistrolyUITests|ScrollToolTests|ButtonInteractionTests'
```

## Batch 2: Voice And Local ASR Runtime

Files:

- `Sources/RenJistrolySystemBridge/MelSpectrogramProcessor.swift`
- `Sources/RenJistrolySystemBridge/NemotronASRProvider.swift`
- `Sources/RenJistrolySystemBridge/RNNTGreedyDecoder.swift`
- `Sources/RenJistrolySystemBridge/COrtInputHelpers.swift`
- `Sources/RenJistrolySystemBridge/Resources/NemotronASR/**`
- `Scripts/export_nemotron_onnx.py`
- `.gitattributes`
- `docs/nemotron-asr-resources.md`

Why second:

- Directly affects offline speech recognition.
- Includes large model resources, so it needs a storage decision before any
  normal commit flow.

Suggested verification:

```bash
swift test --filter 'Voice|Audio|ContextCaptureBenchmarks'
git check-attr filter -- Sources/RenJistrolySystemBridge/Resources/NemotronASR/conformer.onnx
Scripts/verify_lfs_assets.sh
```

## Batch 3: Computer-Use Backends And App Drivers

Files:

- `Sources/RenJistrolyModels/ComputerUseBackend.swift`
- `Sources/RenJistrolyModels/SetOfMarkOverlay.swift`
- `Sources/RenJistrolySystemBridge/AXComputerUseBackend.swift`
- `Sources/RenJistrolySystemBridge/AnthropicCUBackend.swift`
- `Sources/RenJistrolySystemBridge/CDPChromeDriver.swift`
- `Sources/RenJistrolySystemBridge/ChromeDevToolsSession.swift`
- `Sources/RenJistrolySystemBridge/ChromeDriver.swift`
- `Sources/RenJistrolySystemBridge/ChromeUseBridge.swift`
- `Sources/RenJistrolySystemBridge/DOMComputerUseBackend.swift`
- `Sources/RenJistrolySystemBridge/DOMVerification.swift`
- `Sources/RenJistrolySystemBridge/FinderDriver.swift`
- `Sources/RenJistrolySystemBridge/SafariDriver.swift`
- `Sources/RenJistrolySystemBridge/SystemDriver.swift`
- `Sources/RenJistrolySystemBridge/SystemSettingsDriver.swift`
- `Sources/RenJistrolySystemBridge/VisionCUAFallback.swift`
- `Sources/RenJistrolySystemBridge/WeChatDriver.swift`
- `Sources/RenJistrolyCapability/ComputerUseCoordinator.swift`

Why third:

- This is the core desktop automation layer.
- It should be reviewed together with permission and focus behavior.

Suggested verification:

```bash
swift test --filter 'ComputerUse|AppControl|WindowManagement|ScreenUnderstanding'
```

## Batch 4: MCP Tool Expansion

Files:

- `Sources/RenJistrolyCapability/MCPClient/ToolHook.swift`
- `Sources/RenJistrolyCapability/MCPClient/ToolHooks/VisualizerHook.swift`
- `Sources/RenJistrolyCapability/MCPClient/ToolSkillRegistry.swift`
- `Sources/RenJistrolyCapability/MCPServer/AppIntegration/*.swift`
- `Sources/RenJistrolyCapability/MCPServer/CodeEngine/*.swift`
- `Sources/RenJistrolyCapability/MCPServer/SystemControl/*.swift`
- `Sources/RenJistrolySystemBridge/VisualizerCoordinator.swift`
- `Sources/RenJistrolySystemBridge/CursorOverlayController.swift`
- `Sources/RenJistrolySystemBridge/DialogDetector.swift`
- `Sources/RenJistrolySystemBridge/ElementPurposeInference.swift`
- `Sources/RenJistrolySystemBridge/IDEAndTerminalDrivers.swift`

Why fourth:

- Largest surface area, many tools.
- Needs registry and safety-gateway checks before merging.

Suggested verification:

```bash
swift test --filter 'MCP|Tool|SkillRegistry|ToolSafetyGateway|Terminal'
```

## Batch 5: Conversation And Intelligence Session Support

Files:

- `Sources/RenJistrolyConversation/MessageHandler.swift`
- `Sources/RenJistrolyConversation/StreamManager.swift`
- `Sources/RenJistrolyIntelligence/LLMBackend/CommandParserFile.swift`
- `Sources/RenJistrolyIntelligence/LLMBackend/CommandParserGit.swift`
- `Sources/RenJistrolyIntelligence/LLMBackend/CommandParserShell.swift`
- `Sources/RenJistrolyIntelligence/LLMBackend/CommandParserSystem.swift`
- `Sources/RenJistrolyIntelligence/PromptBuilder.swift`
- `Sources/RenJistrolyIntelligence/SessionContext.swift`
- `Sources/RenJistrolyIntelligence/SessionGateConfig.swift`
- `Sources/RenJistrolyIntelligence/SessionProviderHealth.swift`

Why fifth:

- Affects routing, prompts, streaming, and session stability.

Suggested verification:

```bash
swift test --filter 'Conversation|CommandParser|Provider|Session|SmartRouter'
```

## Batch 6: Domain Models And Scenario Types

Files:

- `Sources/RenJistrolyModels/ContactCenterModels.swift`
- `Sources/RenJistrolyModels/OperationsModels.swift`
- `Sources/RenJistrolyModels/PanelStatusModel.swift`
- `Sources/RenJistrolyModels/SalesScenarioModels.swift`
- `Sources/RenJistrolyModels/ScheduleModels.swift`
- `Sources/RenJistrolyModels/Skill.swift`

Why sixth:

- Mostly shared data surface.
- Should land after the feature code that proves each model is actually used.

Suggested verification:

```bash
swift test --filter 'Models|Scenario|TaskRouting|RoleScenario'
```

## Final Gate

After each batch is reviewed:

```bash
swift test --scratch-path /private/tmp/renjistroly-intake-full
```

Do not stage the `NemotronASR` payload until Git LFS is installed and
`git lfs status` confirms the large model files are LFS pointers.
