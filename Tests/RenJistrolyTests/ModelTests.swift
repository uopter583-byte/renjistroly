import XCTest
@testable import RenJistrolyModels

// =============================================================================
// ExecutiveUXModels Tests (items 496-505)
// =============================================================================

final class CapabilityDescriptionLayerTests: XCTestCase {
    func testCapabilityDescriptionLayer_defaultMappings() {
        let layer = CapabilityDescriptionLayer()
        XCTAssertFalse(layer.mappedCapabilities.isEmpty)
        XCTAssertNotNil(layer.describe("mcp"))
        XCTAssertNotNil(layer.describe("shell"))
        XCTAssertNil(layer.describe("nonexistent"))
    }

    func testCapabilityDescriptionLayer_describe() {
        let layer = CapabilityDescriptionLayer()
        guard let desc = layer.describe("mcp") else { return XCTFail("expected mcp mapping") }
        XCTAssertEqual(desc.internalName, "mcp")
        XCTAssertEqual(desc.friendlyName, "智能工具集")
        XCTAssertFalse(desc.friendlyExplanation.isEmpty)
    }

    func testCapabilityDescriptionLayer_friendlySummary_containsAll() {
        let layer = CapabilityDescriptionLayer()
        let summary = layer.friendlySummary()
        XCTAssertTrue(summary.contains("智能工具集"))
        XCTAssertTrue(summary.contains("屏幕观察"))
        XCTAssertTrue(summary.contains("命令行执行"))
    }

    func testCapabilityDescriptionLayer_customMapping() {
        let custom = CapabilityDescriptionLayer(mappedCapabilities: [
            "test": .init(internalName: "test", friendlyName: "测试", friendlyExplanation: "测试能力")
        ])
        XCTAssertEqual(custom.mappedCapabilities.count, 1)
        XCTAssertNotNil(custom.describe("test"))
    }

    func testCapabilityDescriptionLayer_equality() {
        let a = CapabilityDescriptionLayer()
        let b = CapabilityDescriptionLayer()
        XCTAssertEqual(a, b)
    }

    func testCapabilityDescriptionLayer_codable() throws {
        let layer = CapabilityDescriptionLayer()
        let data = try JSONEncoder().encode(layer)
        let decoded = try JSONDecoder().decode(CapabilityDescriptionLayer.self, from: data)
        XCTAssertEqual(layer, decoded)
    }
}

final class StuckDetectorTests: XCTestCase {
    func testStuckDetector_initialState() {
        let detector = StuckDetector()
        XCTAssertFalse(detector.isStuck)
        XCTAssertNil(detector.stuckReason)
        XCTAssertFalse(detector.needsUserIntervention)
        XCTAssertEqual(detector.retryCount, 0)
    }

    func testStuckDetector_recordActionResets() {
        var detector = StuckDetector()
        detector.isStuck = true
        detector.stuckReason = "test"
        detector.retryCount = 2
        detector.recordAction()
        XCTAssertFalse(detector.isStuck)
        XCTAssertNil(detector.stuckReason)
        XCTAssertEqual(detector.currentStuckDuration, 0)
    }

    func testStuckDetector_check_triggersAfterThreshold() {
        var detector = StuckDetector(thresholdSeconds: 0, maxRetries: 3)
        detector.lastActionTime = Date().addingTimeInterval(-60)
        detector.check()
        XCTAssertTrue(detector.isStuck)
        XCTAssertEqual(detector.retryCount, 1)
    }

    func testStuckDetector_check_maxRetriesExhausted() {
        var detector = StuckDetector(thresholdSeconds: 0, maxRetries: 2)
        detector.lastActionTime = Date().addingTimeInterval(-60)
        detector.check()
        XCTAssertTrue(detector.isStuck)
        XCTAssertEqual(detector.retryCount, 1)
        XCTAssertFalse(detector.stuckReason?.contains("可能需要您的帮助") ?? false)

        detector.check()
        XCTAssertEqual(detector.retryCount, 2)

        detector.check()
        XCTAssertEqual(detector.retryCount, 3)
        XCTAssertTrue(detector.stuckReason?.contains("可能需要您的帮助") ?? false)
        XCTAssertTrue(detector.needsUserIntervention)
    }

    func testStuckDetector_reset() {
        var detector = StuckDetector()
        detector.isStuck = true
        detector.retryCount = 5
        detector.stuckReason = "test"
        detector.reset()
        XCTAssertFalse(detector.isStuck)
        XCTAssertEqual(detector.retryCount, 0)
        XCTAssertNil(detector.stuckReason)
    }

    func testStuckDetector_userPrompt_nilWhenNotStuck() {
        let detector = StuckDetector()
        XCTAssertNil(detector.userPrompt)
    }

    func testStuckDetector_userPrompt_nilWhenAutoResolved() {
        var detector = StuckDetector(thresholdSeconds: 0, maxRetries: 3)
        detector.lastActionTime = Date().addingTimeInterval(-60)
        detector.check()
        XCTAssertTrue(detector.stuckAutoResolved)
        XCTAssertNil(detector.userPrompt)
    }

    func testStuckDetector_customThreshold() {
        let detector = StuckDetector(thresholdSeconds: 30, maxRetries: 5)
        XCTAssertEqual(detector.thresholdSeconds, 30)
        XCTAssertEqual(detector.maxRetries, 5)
    }
}

final class ScreenConfirmationPromptTests: XCTestCase {
    func testScreenConfirmationPrompt_defaultScope() {
        let prompt = ScreenConfirmationPrompt()
        XCTAssertEqual(prompt.scope, .afterDestructiveAction)
        XCTAssertTrue(prompt.isConfirmed)
        XCTAssertNil(prompt.pendingPrompt)
    }

    func testScreenConfirmationPrompt_setExpectation() {
        var prompt = ScreenConfirmationPrompt()
        prompt.setExpectation("Settings window")
        XCTAssertEqual(prompt.lastExpectedState, "Settings window")
        XCTAssertFalse(prompt.isConfirmed)
    }

    func testScreenConfirmationPrompt_verify_matching() {
        var prompt = ScreenConfirmationPrompt()
        prompt.setExpectation("Settings window")
        let result = prompt.verify(with: "Settings window visible")
        XCTAssertTrue(result)
        XCTAssertTrue(prompt.isConfirmed)
    }

    func testScreenConfirmationPrompt_verify_notMatching() {
        var prompt = ScreenConfirmationPrompt()
        prompt.setExpectation("Settings window")
        let result = prompt.verify(with: "Terminal window")
        XCTAssertFalse(result)
        XCTAssertFalse(prompt.isConfirmed)
        XCTAssertNotNil(prompt.pendingPrompt)
    }

    func testScreenConfirmationPrompt_confirm() {
        var prompt = ScreenConfirmationPrompt()
        prompt.setExpectation("test")
        let _ = prompt.verify(with: "different")
        prompt.confirm()
        XCTAssertTrue(prompt.isConfirmed)
        XCTAssertNil(prompt.pendingPrompt)
    }

    func testScreenConfirmationPrompt_needsConfirmation_never() {
        var prompt = ScreenConfirmationPrompt(scope: .never)
        prompt.setExpectation("test")
        XCTAssertFalse(prompt.needsConfirmation)
    }
}

final class CursorControlIndicatorTests: XCTestCase {
    func testCursorControlIndicator_initialState() {
        let indicator = CursorControlIndicator()
        XCTAssertFalse(indicator.isActive)
        XCTAssertEqual(indicator.cursorOwner, .user)
    }

    func testCursorControlIndicator_beginEndAssistControl() {
        var indicator = CursorControlIndicator()
        indicator.beginAssistControl()
        XCTAssertTrue(indicator.isActive)
        XCTAssertEqual(indicator.cursorOwner, .assistant)
        indicator.endAssistControl()
        XCTAssertFalse(indicator.isActive)
        XCTAssertEqual(indicator.cursorOwner, .user)
    }

    func testCursorControlIndicator_recordClick() {
        var indicator = CursorControlIndicator()
        indicator.recordClick(at: CGPoint(x: 100, y: 200), description: "clicked button")
        XCTAssertEqual(indicator.lastClickPosition, CGPoint(x: 100, y: 200))
        XCTAssertEqual(indicator.lastClickDescription, "clicked button")
    }

    func testCursorControlIndicator_statusMessage() {
        var indicator = CursorControlIndicator()
        XCTAssertEqual(indicator.statusMessage, "鼠标控制权：您")
        indicator.beginAssistControl()
        XCTAssertTrue(indicator.statusMessage.contains("助手"))
        indicator.endAssistControl()
        XCTAssertEqual(indicator.statusMessage, "鼠标控制权：您")
    }

    func testCursorControlIndicator_customStyle() {
        let indicator = CursorControlIndicator(style: .crosshair, color: "#FF0000", label: "测试")
        XCTAssertEqual(indicator.style, .crosshair)
        XCTAssertEqual(indicator.color, "#FF0000")
        XCTAssertEqual(indicator.label, "测试")
    }
}

final class WindowMatchConfirmTests: XCTestCase {
    func testWindowMatchConfirm_initial() {
        let confirm = WindowMatchConfirm()
        XCTAssertNil(confirm.pendingMatch)
        XCTAssertTrue(confirm.matchHistory.isEmpty)
    }

    func testWindowMatchConfirm_setExpectation() {
        var confirm = WindowMatchConfirm()
        confirm.setExpectation(app: "Safari", title: "Preferences")
        XCTAssertNotNil(confirm.pendingMatch)
        XCTAssertEqual(confirm.pendingMatch?.expectedApp, "Safari")
        XCTAssertEqual(confirm.pendingMatch?.expectedTitle, "Preferences")
    }

    func testWindowMatchConfirm_verify_matching() {
        var confirm = WindowMatchConfirm()
        confirm.setExpectation(app: "Safari", title: "Preferences")
        let result = confirm.verify(actualApp: "Safari", actualTitle: "Preferences")
        XCTAssertTrue(result)
    }

    func testWindowMatchConfirm_verify_notMatching() {
        var confirm = WindowMatchConfirm()
        confirm.setExpectation(app: "Safari", title: "Preferences")
        let result = confirm.verify(actualApp: "Chrome", actualTitle: "Gmail")
        XCTAssertFalse(result)
        XCTAssertTrue(confirm.needsConfirmation) // mismatch means needs confirmation
    }

    func testWindowMatchConfirm_noPendingMatch() {
        var confirm = WindowMatchConfirm()
        let result = confirm.verify(actualApp: "Safari", actualTitle: "Preferences")
        XCTAssertFalse(result)
    }

    func testWindowMatchConfirm_prompt() {
        var confirm = WindowMatchConfirm()
        confirm.setExpectation(app: "Safari", title: "Downloads")
        XCTAssertNotNil(confirm.prompt)
        confirm.confirmMatch()
        XCTAssertNil(confirm.prompt)
    }

    func testWindowMatch_windowMatchIsMatch() {
        let match = WindowMatchConfirm.WindowMatch(
            expectedTitle: "Downloads", expectedApp: "Safari",
            actualTitle: "Downloads", actualApp: "Safari"
        )
        XCTAssertTrue(match.isMatch)
        XCTAssertTrue(match.matchDescription.contains("✓"))
    }
}

final class InteractionModeStateTests: XCTestCase {
    func testInteractionMode_default() {
        let state = InteractionModeState()
        XCTAssertEqual(state.currentMode, .assistant)
        XCTAssertTrue(state.modeHistory.isEmpty)
    }

    func testInteractionMode_switchTo() {
        var state = InteractionModeState()
        state.switchTo(.debug, reason: "troubleshooting")
        XCTAssertEqual(state.currentMode, .debug)
        XCTAssertEqual(state.modeHistory.count, 1)
        XCTAssertEqual(state.modeHistory.first?.reason, "troubleshooting")
    }

    func testInteractionMode_properties() {
        XCTAssertTrue(InteractionMode.assistant.autoApproveLowRisk)
        XCTAssertFalse(InteractionMode.debug.autoApproveLowRisk)
        XCTAssertTrue(InteractionMode.debug.showTechnicalDetail)
        XCTAssertTrue(InteractionMode.debug.showToolCalls)
    }
}

final class OperationDescriptionTests: XCTestCase {
    func testOperationDescription_empty() {
        let desc = OperationDescription()
        XCTAssertTrue(desc.operationChain.isEmpty)
        XCTAssertNil(desc.currentSummary)
        XCTAssertEqual(desc.fullProgressDescription, "暂无操作")
    }

    func testOperationDescription_startAndComplete() {
        var desc = OperationDescription()
        let step = OperationDescription.OperationStep(
            action: "click", targetDescription: "OK button", purpose: "confirm"
        )
        desc.startOperation(step)
        XCTAssertEqual(desc.operationChain.count, 1)
        XCTAssertEqual(desc.operationChain[0].status, .executing)
        XCTAssertNotNil(desc.currentSummary)

        desc.completeCurrent()
        XCTAssertEqual(desc.operationChain[0].status, .completed)
    }

    func testOperationDescription_failCurrent() {
        var desc = OperationDescription()
        let step = OperationDescription.OperationStep(
            action: "open", targetDescription: "Finder", purpose: "browse files"
        )
        desc.startOperation(step)
        desc.failCurrent()
        XCTAssertEqual(desc.operationChain[0].status, .failed)
    }

    func testOperationDescription_userFriendlyDescription() {
        let step = OperationDescription.OperationStep(
            action: "click", targetDescription: "Submit", purpose: "submit form"
        )
        XCTAssertEqual(step.userFriendlyDescription, "点击「Submit」")
    }

    func testOperationDescription_userFriendlyDescription_unknownAction() {
        let step = OperationDescription.OperationStep(
            action: "customOp", targetDescription: "target", purpose: "test"
        )
        XCTAssertEqual(step.userFriendlyDescription, "customOp「target」")
    }

    func testOperationDescription_fullProgressDescription() {
        var desc = OperationDescription()
        let s1 = OperationDescription.OperationStep(action: "copy", targetDescription: "file", purpose: "backup")
        desc.startOperation(s1)
        desc.completeCurrent()
        let s2 = OperationDescription.OperationStep(action: "paste", targetDescription: "folder", purpose: "restore")
        desc.startOperation(s2)
        XCTAssertTrue(desc.fullProgressDescription.contains("1/2"))
        XCTAssertTrue(desc.fullProgressDescription.contains("粘贴"))
    }
}

final class ConfirmationReasonTests: XCTestCase {
    func testConfirmationReason_default() {
        let reason = ConfirmationReason(category: .destructiveAction, specificReason: "Deleting files")
        XCTAssertEqual(reason.category, .destructiveAction)
        XCTAssertFalse(reason.isUnderstood)
    }

    func testConfirmationReason_promptMessage() {
        let reason = ConfirmationReason(
            category: .financial, specificReason: "购买 Pro 版",
            riskDescription: "花费 $99", actionSummary: "购买操作"
        )
        let prompt = reason.promptMessage
        XCTAssertTrue(prompt.contains("需要您确认"))
        XCTAssertTrue(prompt.contains("购买 Pro 版"))
        XCTAssertTrue(prompt.contains("$99"))
    }

    func testConfirmationReason_allCategories() {
        for category in ConfirmationReason.ReasonCategory.allCases {
            let reason = ConfirmationReason(category: category, specificReason: "test")
            XCTAssertFalse(reason.promptMessage.isEmpty)
            XCTAssertFalse(category.title.isEmpty)
            XCTAssertFalse(category.friendlyExplanation.isEmpty)
        }
    }
}

final class FriendlyErrorMessageTests: XCTestCase {
    func testFriendlyErrorMessage_permissionError() {
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "accessibility permission denied"])
        let msg = FriendlyErrorMessage.from(error: error)
        XCTAssertEqual(msg.errorCategory, .permissionDenied)
        XCTAssertTrue(msg.isActionable)
    }

    func testFriendlyErrorMessage_timeoutError() {
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "request timed out"])
        let msg = FriendlyErrorMessage.from(error: error)
        XCTAssertEqual(msg.errorCategory, .timeout)
    }

    func testFriendlyErrorMessage_networkError() {
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "network connection failed"])
        let msg = FriendlyErrorMessage.from(error: error)
        XCTAssertEqual(msg.errorCategory, .networkError)
    }

    func testFriendlyErrorMessage_notFoundError() {
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "element not found"])
        let msg = FriendlyErrorMessage.from(error: error)
        XCTAssertEqual(msg.errorCategory, .elementNotFound)
    }

    func testFriendlyErrorMessage_unknownError() {
        let error = NSError(domain: "test", code: 999, userInfo: [NSLocalizedDescriptionKey: "something weird happened"])
        let msg = FriendlyErrorMessage.from(error: error)
        XCTAssertEqual(msg.errorCategory, .unknown)
        XCTAssertFalse(msg.isActionable)
    }

    func testFriendlyErrorMessage_formatted() {
        let msg = FriendlyErrorMessage(
            technicalError: "err",
            friendlyMessage: "操作失败",
            suggestion: "请重试"
        )
        let formatted = msg.formatted()
        XCTAssertTrue(formatted.contains("操作失败"))
        XCTAssertTrue(formatted.contains("请重试"))
    }
}

final class GlobalStopMechanismTests: XCTestCase {
    func testGlobalStopMechanism_initial() {
        let stop = GlobalStopMechanism()
        XCTAssertTrue(stop.isRunning)
        XCTAssertFalse(stop.isStopped)
        XCTAssertTrue(stop.canResume)
    }

    func testGlobalStopMechanism_requestStop_soft() {
        var stop = GlobalStopMechanism()
        stop.requestStop(level: .soft)
        XCTAssertEqual(stop.state, .stopRequested)
        XCTAssertTrue(stop.isStopped)
        XCTAssertEqual(stop.stopMessage, "操作将在当前步骤完成后停止")
    }

    func testGlobalStopMechanism_requestStop_hard() {
        var stop = GlobalStopMechanism()
        stop.requestStop(level: .hard)
        stop.confirmStopped()
        XCTAssertEqual(stop.state, .stopped)
        XCTAssertTrue(stop.canResume)
        XCTAssertEqual(stop.stopMessage, "操作已停止")
    }

    func testGlobalStopMechanism_requestStop_panic() {
        var stop = GlobalStopMechanism()
        stop.requestStop(level: .panic, reason: "panic!")
        stop.confirmStopped()
        XCTAssertFalse(stop.canResume)
        XCTAssertEqual(stop.stopMessage, "已紧急停止，正在回滚")
    }

    func testGlobalStopMechanism_resume() {
        var stop = GlobalStopMechanism()
        stop.requestStop(level: .hard)
        stop.confirmStopped()
        stop.resume()
        XCTAssertTrue(stop.isRunning)
        XCTAssertNil(stop.stopReason)
    }

    func testGlobalStopMechanism_stopMessage_nilWhenRunning() {
        let stop = GlobalStopMechanism()
        XCTAssertNil(stop.stopMessage)
    }
}

// =============================================================================
// TrustMechanisms Tests (items 506-515)
// =============================================================================

final class ClickPreviewTests: XCTestCase {
    func testClickPreview_default() {
        let preview = ClickPreview()
        XCTAssertTrue(preview.previewEnabled)
        XCTAssertTrue(preview.requireConfirmation)
        XCTAssertNil(preview.pendingClick)
    }

    func testClickPreview_setAndConfirm() {
        var preview = ClickPreview()
        let target = ClickPreview.ClickTarget(
            targetDescription: "Save button", targetApp: "Notes",
            elementRole: "AXButton", elementLabel: "Save", actionDescription: "click Save"
        )
        preview.setPendingClick(target)
        XCTAssertNotNil(preview.pendingClick)
        XCTAssertTrue(preview.needsConfirmation)

        preview.confirm()
        XCTAssertTrue(preview.pendingClick?.isConfirmed ?? false)
        XCTAssertFalse(preview.needsConfirmation)
    }

    func testClickPreview_reject() {
        var preview = ClickPreview()
        let target = ClickPreview.ClickTarget(targetDescription: "Delete", actionDescription: "delete")
        preview.setPendingClick(target)
        preview.reject()
        XCTAssertNil(preview.pendingClick)
    }

    func testClickPreview_promptMessage() {
        var preview = ClickPreview()
        let target = ClickPreview.ClickTarget(
            targetDescription: "OK", targetApp: "Finder",
            elementLabel: "OK", actionDescription: "click"
        )
        preview.setPendingClick(target)
        XCTAssertNotNil(preview.promptMessage)

        preview.confirm()
        XCTAssertNil(preview.promptMessage)
    }

    func testClickPreview_needsConfirmation_disabled() {
        var preview = ClickPreview(previewEnabled: false, requireConfirmation: false)
        let target = ClickPreview.ClickTarget(targetDescription: "test", actionDescription: "test")
        preview.setPendingClick(target)
        XCTAssertFalse(preview.needsConfirmation)
    }

    func testClickPreview_previewSummary() {
        let target = ClickPreview.ClickTarget(
            targetDescription: "OK", targetApp: "Safari",
            elementLabel: "OK button", screenPosition: "center",
            actionDescription: "click OK"
        )
        let summary = target.previewSummary
        XCTAssertTrue(summary.contains("Safari"))
        XCTAssertTrue(summary.contains("OK button"))
    }
}

final class SendPreviewTests: XCTestCase {
    func testSendPreview_default() {
        let preview = SendPreview()
        XCTAssertNil(preview.pendingSend)
        XCTAssertTrue(preview.requireConfirmation)
    }

    func testSendPreview_setAndConfirm() {
        var preview = SendPreview()
        let send = SendPreview.PendingSend(
            channelDescription: "Email", recipients: ["test@example.com"],
            subject: "Hello", bodyPreview: "This is a test message"
        )
        preview.setPendingSend(send)
        XCTAssertTrue(preview.needsConfirmation)
        preview.confirm()
        XCTAssertFalse(preview.needsConfirmation)
    }

    func testSendPreview_reject() {
        var preview = SendPreview()
        let send = SendPreview.PendingSend(
            channelDescription: "Slack", recipients: ["team"], bodyPreview: "update"
        )
        preview.setPendingSend(send)
        preview.reject()
        XCTAssertNil(preview.pendingSend)
    }

    func testSendPreview_summary() {
        let send = SendPreview.PendingSend(
            channelDescription: "WeChat", recipients: ["Alice", "Bob"],
            subject: "Meeting", bodyPreview: "Reminder for tomorrow's meeting",
            attachments: ["doc.pdf"]
        )
        let summary = send.summary
        XCTAssertTrue(summary.contains("WeChat"))
        XCTAssertTrue(summary.contains("Alice"))
        XCTAssertTrue(summary.contains("Bob"))
        XCTAssertTrue(summary.contains("doc.pdf"))
    }
}

final class DeleteTrashProtectionTests: XCTestCase {
    func testDeleteTrashProtection_default() {
        let protection = DeleteTrashProtection()
        XCTAssertTrue(protection.forceTrashOnly)
        XCTAssertTrue(protection.requireConfirmation)
    }

    func testDeleteTrashProtection_confirmMovesToTrash() {
        var protection = DeleteTrashProtection()
        let request = DeleteTrashProtection.DeleteRequest(
            filePaths: ["/tmp/test.txt"], totalSizeBytes: 1024
        )
        protection.setPendingDelete(request)
        protection.confirm()
        XCTAssertTrue(protection.pendingDelete?.isMovedToTrash ?? false)
        XCTAssertTrue(protection.canExecute)
    }

    func testDeleteTrashProtection_reject() {
        var protection = DeleteTrashProtection()
        let request = DeleteTrashProtection.DeleteRequest(filePaths: ["/tmp/test.txt"])
        protection.setPendingDelete(request)
        protection.reject()
        XCTAssertNil(protection.pendingDelete)
    }

    func testDeleteTrashProtection_canExecute_notConfirmed() {
        var protection = DeleteTrashProtection()
        let request = DeleteTrashProtection.DeleteRequest(filePaths: ["/tmp/test.txt"])
        protection.setPendingDelete(request)
        XCTAssertFalse(protection.canExecute)
    }

    func testDeleteTrashProtection_sizeFormatted() {
        let request = DeleteTrashProtection.DeleteRequest(
            filePaths: ["/big.file"], totalSizeBytes: 1_000_000_000
        )
        XCTAssertFalse(request.sizeFormatted.isEmpty)
    }

    func testDeleteTrashProtection_protectionLevelCritical() {
        let request = DeleteTrashProtection.DeleteRequest(
            filePaths: ["/etc/config"], protectionLevel: .critical
        )
        XCTAssertTrue(request.summary.contains("⚠️"))
    }

    func testDeleteTrashProtection_promptMessage() {
        var protection = DeleteTrashProtection()
        let request = DeleteTrashProtection.DeleteRequest(filePaths: ["/tmp/test.txt"])
        protection.setPendingDelete(request)
        let prompt = protection.promptMessage
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt?.contains("废纸篓") ?? false)
    }
}

final class DataMaskingEngineTests: XCTestCase {
    func testDataMaskingEngine_disabled() {
        var engine = DataMaskingEngine(isEnabled: false)
        let input = "my email is user@example.com"
        let result = engine.mask(input)
        XCTAssertEqual(result, input)
    }

    func testDataMaskingEngine_maskEmail() {
        var engine = DataMaskingEngine()
        let result = engine.mask("contact me at john.doe@company.com")
        XCTAssertFalse(result.contains("john.doe@company.com"))
        XCTAssertTrue(result.contains("@company.com"))
    }

    func testDataMaskingEngine_maskPhone() {
        var engine = DataMaskingEngine()
        let result = engine.mask("call 13800138000 for details")
        XCTAssertTrue(result.contains("138****8000"))
    }

    func testDataMaskingEngine_maskApiKey() {
        var engine = DataMaskingEngine()
        let result = engine.mask("api_key = sk-abc123secret456")
        XCTAssertTrue(result.contains("sk-"))
        XCTAssertTrue(result.contains("****"))
    }

    func testDataMaskingEngine_maskIPAddress() {
        var engine = DataMaskingEngine(enabledCategories: [.ipAddress])
        let result = engine.mask("server: 192.168.1.100")
        XCTAssertTrue(result.contains("192.168"))
        XCTAssertTrue(result.contains("***"))
    }

    func testDataMaskingEngine_maskSensitiveKeys() {
        var engine = DataMaskingEngine()
        let dict = ["password": "mySecret123", "name": "John", "apiKey": "abc123"]
        let result = engine.maskSensitiveKeys(in: dict)
        XCTAssertEqual(result["password"]?.count, 8)
        XCTAssertEqual(result["name"], "John")
        XCTAssertEqual(result["apiKey"]?.count, 6) // "abc123".count = 6, min(6, 8) = 6
    }

    func testDataMaskingEngine_lastMaskedCount() {
        var engine = DataMaskingEngine()
        _ = engine.mask("email: test@test.com, phone: 13800138000")
        XCTAssertTrue(engine.lastMaskedCount > 0)
    }

    func testDataMaskingEngine_noMatch() {
        var engine = DataMaskingEngine(enabledCategories: [.email])
        let result = engine.mask("this is a plain text without sensitive info")
        XCTAssertEqual(result, "this is a plain text without sensitive info")
    }

    func testDataMaskingEngine_codable() throws {
        let engine = DataMaskingEngine()
        let data = try JSONEncoder().encode(engine)
        let decoded = try JSONDecoder().decode(DataMaskingEngine.self, from: data)
        XCTAssertEqual(engine.isEnabled, decoded.isEnabled)
        XCTAssertEqual(engine.enabledCategories, decoded.enabledCategories)
    }
}

final class OperationVerifierTests: XCTestCase {
    func testOperationVerifier_empty() {
        let verifier = OperationVerifier()
        XCTAssertTrue(verifier.records.isEmpty)
        XCTAssertTrue(verifier.allPassed)
        XCTAssertEqual(verifier.passRate, 1.0)
    }

    func testOperationVerifier_addRecord() {
        var verifier = OperationVerifier()
        let record = OperationVerifier.VerificationRecord(
            operationDescription: "click save", method: .screenshotCompare,
            expectedResult: "button visible", passed: true
        )
        verifier.addRecord(record)
        XCTAssertEqual(verifier.records.count, 1)
        XCTAssertTrue(verifier.allPassed)
    }

    func testOperationVerifier_passRate() {
        var verifier = OperationVerifier()
        verifier.addRecord(.init(operationDescription: "a", method: .elementExist, expectedResult: "exists", passed: true))
        verifier.addRecord(.init(operationDescription: "b", method: .elementExist, expectedResult: "exists", passed: false))
        XCTAssertEqual(verifier.passRate, 0.5)
    }

    func testOperationVerifier_evidenceSummary() {
        var verifier = OperationVerifier()
        verifier.addRecord(.init(operationDescription: "test", method: .manual, expectedResult: "ok", passed: true, screenshotAfterPath: "/tmp/shot.png"))
        let summary = verifier.evidenceSummary
        XCTAssertTrue(summary.contains("1/1"))
        XCTAssertTrue(summary.contains("1 张"))
    }

    func testOperationVerifier_lastRecord() {
        var verifier = OperationVerifier()
        let r1 = OperationVerifier.VerificationRecord(operationDescription: "first", method: .manual, expectedResult: "ok")
        let r2 = OperationVerifier.VerificationRecord(operationDescription: "second", method: .manual, expectedResult: "ok")
        verifier.addRecord(r1)
        verifier.addRecord(r2)
        XCTAssertEqual(verifier.lastRecord?.operationDescription, "second")
    }
}

final class HeartbeatRecoveryTests: XCTestCase {
    func testHeartbeatRecovery_initial() {
        let hb = HeartbeatRecovery()
        XCTAssertTrue(hb.isHealthy)
        XCTAssertFalse(hb.needsAttention)
        XCTAssertEqual(hb.currentStatus, .healthy)
    }

    func testHeartbeatRecovery_beat() {
        var hb = HeartbeatRecovery()
        hb.currentStatus = .critical
        hb.beat()
        XCTAssertTrue(hb.isHealthy)
        XCTAssertEqual(hb.heartbeatHistory.count, 1)
    }

    func testHeartbeatRecovery_check_warning() {
        var hb = HeartbeatRecovery(heartbeatInterval: 1, warningThreshold: 1, criticalThreshold: 100)
        hb.lastHeartbeat = Date().addingTimeInterval(-3)
        let status = hb.check()
        XCTAssertEqual(status, .warning)
    }

    func testHeartbeatRecovery_check_critical() {
        var hb = HeartbeatRecovery(heartbeatInterval: 1, warningThreshold: 2, criticalThreshold: 3)
        hb.lastHeartbeat = Date().addingTimeInterval(-10)
        let status = hb.check()
        XCTAssertEqual(status, .lost)
        XCTAssertTrue(hb.isHealthy) // auto recovery resets
    }

    func testHeartbeatRecovery_statusSummary() {
        let hb = HeartbeatRecovery()
        let summary = hb.statusSummary
        XCTAssertTrue(summary.contains("运行正常"))
    }

    func testHeartbeatRecovery_reset() {
        var hb = HeartbeatRecovery()
        hb.currentStatus = .lost
        hb.reset()
        XCTAssertTrue(hb.isHealthy)
    }

    func testHeartbeatRecovery_historyLimit() {
        var hb = HeartbeatRecovery()
        for _ in 0..<150 { hb.beat() }
        XCTAssertLessThanOrEqual(hb.heartbeatHistory.count, 100)
    }
}

final class ContextSummaryTests: XCTestCase {
    func testContextSummary_empty() {
        let summary = ContextSummary()
        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.formatted(), "当前无上下文信息")
    }

    func testContextSummary_addItem() {
        var summary = ContextSummary()
        summary.addItem(category: "app", content: "Safari is frontmost")
        XCTAssertFalse(summary.isEmpty)
        XCTAssertEqual(summary.items.count, 1)
    }

    func testContextSummary_formatted() {
        var summary = ContextSummary()
        summary.addItem(category: "app", content: "Finder")
        summary.addItem(category: "file", content: "document.pdf")
        let formatted = summary.formatted()
        XCTAssertTrue(formatted.contains("Finder"))
        XCTAssertTrue(formatted.contains("document.pdf"))
    }

    func testContextSummary_compactSummary() {
        var summary = ContextSummary()
        summary.addItem(category: "a", content: "Step 1")
        summary.addItem(category: "b", content: "Step 2")
        XCTAssertEqual(summary.compactSummary(), "Step 1 → Step 2")
    }

    func testContextSummary_maxItems() {
        var summary = ContextSummary(maxItems: 3)
        for i in 0..<10 { summary.addItem(category: "t", content: "item \(i)") }
        XCTAssertEqual(summary.items.count, 3)
    }

    func testContextSummary_clear() {
        var summary = ContextSummary()
        summary.addItem(category: "a", content: "test")
        summary.clear()
        XCTAssertTrue(summary.isEmpty)
    }

    func testContextSummary_summaryByCategory() {
        var summary = ContextSummary()
        summary.addItem(category: "app", content: "Safari")
        summary.addItem(category: "app", content: "Terminal")
        summary.addItem(category: "file", content: "test.txt")
        let grouped = summary.summaryByCategory()
        XCTAssertEqual(grouped["app"]?.count, 2)
        XCTAssertEqual(grouped["file"]?.count, 1)
    }
}

final class DecisionPointConfirmationTests: XCTestCase {
    func testDecisionPointConfirmation_initial() {
        let dp = DecisionPointConfirmation()
        XCTAssertNil(dp.pendingDecision)
        XCTAssertFalse(dp.needsDecision)
    }

    func testDecisionPointConfirmation_presentAndSelect() {
        var dp = DecisionPointConfirmation()
        let decision = DecisionPointConfirmation.DecisionPoint(
            title: "Choose method",
            description: "How to proceed?",
            options: [
                .init(label: "Option A", description: "Do A"),
                .init(label: "Option B", description: "Do B"),
            ]
        )
        dp.presentDecision(decision)
        XCTAssertTrue(dp.needsDecision)
        XCTAssertNotNil(dp.prompt)

        dp.selectOption("Option A")
        XCTAssertFalse(dp.needsDecision)
        XCTAssertNil(dp.pendingDecision)
        XCTAssertEqual(dp.decisionHistory.count, 1)
    }

    func testDecisionPointConfirmation_reject() {
        var dp = DecisionPointConfirmation()
        let decision = DecisionPointConfirmation.DecisionPoint(
            title: "Test", description: "desc",
            options: [.init(label: "Yes", description: "Do it")]
        )
        dp.presentDecision(decision)
        dp.reject()
        XCTAssertNil(dp.pendingDecision)
    }

    func testDecisionPoint_pendingPrompt() {
        let decision = DecisionPointConfirmation.DecisionPoint(
            title: "Confirm", description: "Please confirm",
            options: [
                .init(label: "Proceed", description: "Continue", isRecommended: true),
                .init(label: "Cancel", description: "Abort"),
            ],
            context: "High risk operation"
        )
        let prompt = decision.pendingPrompt
        XCTAssertTrue(prompt.contains("Confirm"))
        XCTAssertTrue(prompt.contains("Proceed"))
        XCTAssertTrue(prompt.contains("Cancel"))
        XCTAssertTrue(prompt.contains("High risk operation"))
    }

    func testDecisionPointConfirmation_codable() throws {
        let option = DecisionPointConfirmation.DecisionOption(label: "A", description: "desc")
        let data = try JSONEncoder().encode(option)
        let decoded = try JSONDecoder().decode(DecisionPointConfirmation.DecisionOption.self, from: data)
        XCTAssertEqual(option, decoded)
    }
}

final class ModelOperationQueueTests: XCTestCase {
    typealias Q = RenJistrolyModels.OperationQueue

    func testOperationQueue_empty() {
        let queue = Q()
        XCTAssertTrue(queue.operations.isEmpty)
        XCTAssertTrue(queue.conflicts.isEmpty)
        XCTAssertTrue(queue.canAcceptMore)
        XCTAssertNil(queue.nextOperation)
        XCTAssertEqual(queue.activeCount, 0)
    }

    func testOperationQueue_enqueue() {
        var queue = Q()
        let op = Q.QueuedOperation(name: "click save", operationType: "click")
        queue.enqueue(op)
        XCTAssertEqual(queue.operations.count, 1)
    }

    func testOperationQueue_complete() {
        var queue = Q()
        let op = Q.QueuedOperation(name: "test", operationType: "click")
        queue.enqueue(op)
        queue.complete(op.id)
        XCTAssertEqual(queue.operations.first?.status, .completed)
    }

    func testOperationQueue_cancel() {
        var queue = Q()
        let op = Q.QueuedOperation(name: "test", operationType: "click")
        queue.enqueue(op)
        queue.cancel(op.id)
        XCTAssertEqual(queue.operations.first?.status, .cancelled)
    }

    func testOperationQueue_fail() {
        var queue = Q()
        let op = Q.QueuedOperation(name: "test", operationType: "click")
        queue.enqueue(op)
        queue.fail(op.id, error: "error")
        XCTAssertEqual(queue.operations.first?.status, .failed)
    }

    func testOperationQueue_conflictDetection() {
        var queue = Q()
        let op1 = Q.QueuedOperation(name: "click A", targetApp: "Safari", targetWindow: "Window1", operationType: "click")
        let op2 = Q.QueuedOperation(name: "click A again", targetApp: "Safari", targetWindow: "Window1", operationType: "click")
        queue.enqueue(op1)
        queue.enqueue(op2)
        XCTAssertTrue(queue.conflicts.count > 0 || queue.operations.contains { $0.status == .blocked })
    }

    func testOperationQueue_nextOperation_highestPriority() {
        var queue = Q()
        let op1 = Q.QueuedOperation(name: "low", operationType: "click", priority: 1)
        let op2 = Q.QueuedOperation(name: "high", operationType: "click", priority: 10)
        queue.enqueue(op1)
        queue.enqueue(op2)
        XCTAssertEqual(queue.nextOperation?.name, "high")
    }

    func testOperationQueue_queueSummary() {
        var queue = Q()
        let op = Q.QueuedOperation(name: "test", operationType: "click")
        queue.enqueue(op)
        let summary = queue.queueSummary
        XCTAssertTrue(summary.contains("1待执行"))
    }

    func testOperationQueue_maxConcurrent() {
        var queue = Q(maxConcurrent: 2)
        let op1 = Q.QueuedOperation(name: "1", operationType: "type", priority: 1)
        let op2 = Q.QueuedOperation(name: "2", operationType: "type", priority: 2)
        queue.enqueue(op1)
        queue.enqueue(op2)
        XCTAssertTrue(queue.canAcceptMore)
    }

    func testOperationQueue_autoResolveDisabled() {
        var queue = Q(autoResolveConflicts: false)
        let op1 = Q.QueuedOperation(name: "A", targetApp: "Safari", targetWindow: "W", operationType: "click")
        let op2 = Q.QueuedOperation(name: "B", targetApp: "Safari", targetWindow: "W", operationType: "click")
        queue.enqueue(op1)
        queue.enqueue(op2)
        let blocked = queue.operations.filter { $0.status == .blocked }
        XCTAssertTrue(blocked.isEmpty)
        XCTAssertFalse(queue.conflicts.isEmpty)
    }

    func testOperationQueue_dependencyWakeup() {
        var queue = Q()
        let op1 = Q.QueuedOperation(name: "dep", operationType: "init")
        let op2 = Q.QueuedOperation(name: "dependent", operationType: "action", dependsOn: [op1.id])
        queue.enqueue(op1)
        queue.enqueue(op2)
        guard queue.operations.indices.contains(1) else { return XCTFail("no second operation") }
        queue.complete(op1.id)
    }
}

final class OperationLogReplayTests: XCTestCase {
    func testOperationLogReplay_empty() {
        let log = OperationLogReplay()
        XCTAssertTrue(log.entries.isEmpty)
        XCTAssertEqual(log.successRate, 1.0)
        XCTAssertEqual(log.totalDurationMs, 0)
    }

    func testOperationLogReplay_record() {
        var log = OperationLogReplay()
        log.record(action: "click", targetDescription: "save button", durationMs: 100, success: true)
        XCTAssertEqual(log.entries.count, 1)
        XCTAssertEqual(log.successRate, 1.0)
    }

    func testOperationLogReplay_recordFailure() {
        var log = OperationLogReplay()
        log.record(action: "delete", targetDescription: "file", success: false, detail: "permission denied")
        XCTAssertFalse(log.entries.first?.success ?? true)
        XCTAssertNotNil(log.entries.first?.detail)
    }

    func testOperationLogReplay_filterByAction() {
        var log = OperationLogReplay()
        log.record(action: "click", targetDescription: "btn")
        log.record(action: "type", targetDescription: "field")
        log.record(action: "click", targetDescription: "other")
        let clicks = log.filter(byAction: "click")
        XCTAssertEqual(clicks.count, 2)
    }

    func testOperationLogReplay_filterSuccessOnly() {
        var log = OperationLogReplay()
        log.record(action: "a", targetDescription: "t1", success: true)
        log.record(action: "b", targetDescription: "t2", success: false)
        let successes = log.filter(successOnly: true)
        XCTAssertEqual(successes.count, 1)
    }

    func testOperationLogReplay_recentEntries() {
        var log = OperationLogReplay()
        for i in 0..<25 { log.record(action: "a\(i)", targetDescription: "t", success: true) }
        XCTAssertEqual(log.recentEntries.count, 20)
    }

    func testOperationLogReplay_successRate() {
        var log = OperationLogReplay()
        log.record(action: "a", targetDescription: "t1", success: true)
        log.record(action: "b", targetDescription: "t2", success: true)
        log.record(action: "c", targetDescription: "t3", success: false)
        XCTAssertEqual(log.successRate, 2.0 / 3.0, accuracy: 0.01)
    }

    func testOperationLogReplay_clear() {
        var log = OperationLogReplay()
        log.record(action: "test", targetDescription: "t")
        log.clear()
        XCTAssertTrue(log.entries.isEmpty)
    }

    func testOperationLogReplay_textExport() {
        var log = OperationLogReplay(sessionLabel: "Test Session")
        log.record(action: "click", targetDescription: "btn", durationMs: 50, success: true)
        let export = log.textExport()
        XCTAssertTrue(export.contains("Test Session"))
        XCTAssertTrue(export.contains("click"))
    }

    func testOperationLogReplay_groupByAction() {
        var log = OperationLogReplay()
        log.record(action: "click", targetDescription: "a")
        log.record(action: "click", targetDescription: "b")
        log.record(action: "type", targetDescription: "c")
        let groups = log.groupByAction
        XCTAssertEqual(groups["click"]?.count, 2)
        XCTAssertEqual(groups["type"]?.count, 1)
    }

    func testOperationLogReplay_maxEntries() {
        var log = OperationLogReplay(maxEntries: 3)
        for i in 0..<10 { log.record(action: "a\(i)", targetDescription: "t") }
        XCTAssertEqual(log.entries.count, 3)
    }
}
