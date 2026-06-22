import Foundation
import XCTest
@testable import RenJistrolySystemBridge

// MARK: - SystemPermissionKind

func testSystemPermissionKindAllCases() {
    XCTAssertTrue(SystemPermissionKind.allCases.count == 5)
}

func testSystemPermissionKindTitles() {
    XCTAssertTrue(SystemPermissionKind.accessibility.title == "辅助功能")
    XCTAssertTrue(SystemPermissionKind.microphone.title == "麦克风")
    XCTAssertTrue(SystemPermissionKind.speechRecognition.title == "语音识别")
    XCTAssertTrue(SystemPermissionKind.screenRecording.title == "屏幕录制")
    XCTAssertTrue(SystemPermissionKind.appleEvents.title == "Apple Events")
}

func testSystemPermissionKindDescriptionsNonEmpty() {
    for kind in SystemPermissionKind.allCases {
        XCTAssertFalse(kind.description.isEmpty)
    }
}

func testSystemPermissionKindSettingsURLs() {
    for kind in SystemPermissionKind.allCases {
        XCTAssertTrue(kind.settingsURL != nil)
    }
}

// MARK: - SystemPermissionStatus

func testSystemPermissionStatusIsGranted() {
    XCTAssertTrue(SystemPermissionStatus.granted.isGranted)
    XCTAssertFalse(SystemPermissionStatus.denied.isGranted)
    XCTAssertFalse(SystemPermissionStatus.notDetermined.isGranted)
    XCTAssertFalse(SystemPermissionStatus.unknown.isGranted)
}

func testSystemPermissionStatusDisplayNames() {
    XCTAssertTrue(SystemPermissionStatus.granted.displayName == "已授权")
    XCTAssertTrue(SystemPermissionStatus.denied.displayName == "未授权")
    XCTAssertTrue(SystemPermissionStatus.notDetermined.displayName == "未请求")
    XCTAssertTrue(SystemPermissionStatus.unknown.displayName == "需验证")
}

// MARK: - SystemPermissionCheck

func testSystemPermissionCheckInit() {
    let check = SystemPermissionCheck(kind: .accessibility, status: .granted, detail: "已启用")
    XCTAssertTrue(check.kind == .accessibility)
    XCTAssertTrue(check.status == .granted)
    XCTAssertTrue(check.detail == "已启用")
    XCTAssertTrue(check.id == .accessibility)
}

// MARK: - AccessibilityError

func testAccessibilityErrorNoPermission() {
    XCTAssertTrue(AccessibilityError.noPermission.errorDescription?.contains("辅助功能权限") == true)
}

func testAccessibilityErrorActionFailed() {
    XCTAssertTrue(AccessibilityError.actionFailed("click").errorDescription?.contains("click") == true)
}

func testAccessibilityErrorElementNotFound() {
    XCTAssertTrue(AccessibilityError.elementNotFound.errorDescription?.contains("UI 元素") == true)
}

// MARK: - KeyStoreError

func testKeyStoreErrorSaveFailed() {
    let err = KeyStoreError.saveFailed(-25300)
    let desc = String(describing: err)
    XCTAssertTrue(desc.contains("saveFailed") || desc.contains("-25300"))
}

// MARK: - NativeSpeechTranscriberError

func testNativeSpeechTranscriberErrorNotAvailable() {
    XCTAssertTrue(NativeSpeechTranscriberError.notAvailable.errorDescription?.contains("不可用") == true)
}

func testNativeSpeechTranscriberErrorNotAuthorized() {
    XCTAssertTrue(NativeSpeechTranscriberError.notAuthorized.errorDescription?.contains("权限") == true)
}

// MARK: - STTError

func testSTTErrorAllCases() {
    let cases: [STTError] = [.noPermission, .notAvailable, .recognitionFailed]
    XCTAssertTrue(cases.count == 3)
}

// MARK: - HelperStatus

func testHelperStatusAllCases() {
    let cases: [UpdateManager.HelperStatus] = [
        .unknown, .notInstalled, .installed, .installing, .connected, .error("fail")
    ]
    XCTAssertTrue(cases.count == 6)
}

// MARK: - AppDriverCapability

func testAppDriverCapabilityAllCases() {
    let all = AppDriverCapability.allCases
    XCTAssertTrue(all.count == 7)
    XCTAssertTrue(all.contains(.open))
    XCTAssertTrue(all.contains(.runCommand))
    XCTAssertTrue(all.contains(.requiresConfirmationBeforeSend))
}

// MARK: - XcodeWorkspaceState

func testXcodeWorkspaceStateFullInit() {
    let state = XcodeWorkspaceState(
        windowTitle: "RenJistroly.xcodeproj",
        workspacePath: "/Users/me/RenJistroly",
        activeScheme: "RenJistrolyApp"
    )
    XCTAssertTrue(state.windowTitle == "RenJistroly.xcodeproj")
    XCTAssertTrue(state.workspacePath == "/Users/me/RenJistroly")
    XCTAssertTrue(state.activeScheme == "RenJistrolyApp")
}

func testXcodeWorkspaceStateEmptyInit() {
    let state = XcodeWorkspaceState(windowTitle: nil, workspacePath: nil, activeScheme: nil)
    XCTAssertTrue(state.windowTitle == nil)
    XCTAssertTrue(state.workspacePath == nil)
    XCTAssertTrue(state.activeScheme == nil)
}

// MARK: - WeChatChatState

func testWeChatChatStateOpen() {
    let state = WeChatChatState(isOpen: true, activeChatTitle: "张三")
    XCTAssertTrue(state.isOpen)
    XCTAssertTrue(state.activeChatTitle == "张三")
}

func testWeChatChatStateClosedEnum() {
    let state = WeChatChatState(isOpen: false, activeChatTitle: nil)
    XCTAssertFalse(state.isOpen)
    XCTAssertTrue(state.activeChatTitle == nil)
}

// MARK: - SystemSettingsPane

func testSystemSettingsPaneAllCases() {
    let all = SystemSettingsPane.allCases
    XCTAssertTrue(all.count >= 8)
    XCTAssertTrue(all.contains(.wifi))
    XCTAssertTrue(all.contains(.bluetooth))
    XCTAssertTrue(all.contains(.accessibility))
}

// MARK: - AccessibilityPermissionGuide

func testAccessibilityPermissionGuideSettingsURL() {
    XCTAssertTrue(AccessibilityPermissionGuide.settingsURL != nil)
}

func testAccessibilityPermissionGuideMessage() {
    let msg = AccessibilityPermissionGuide.message
    XCTAssertTrue(msg.contains("辅助功能"))
    XCTAssertTrue(msg.contains("系统设置"))
}

// MARK: - STTError

func testSTTErrorDescriptions() {
    XCTAssertTrue(STTError.noPermission.errorDescription?.contains("权限") == true)
    XCTAssertTrue(STTError.notAvailable.errorDescription?.contains("不支持") == true)
    XCTAssertTrue(STTError.recognitionFailed.errorDescription?.contains("失败") == true)
}

// MARK: - OCRError

func testOCRErrorDescriptions() {
    XCTAssertTrue(OCRError.imageConversionFailed.errorDescription?.contains("转换失败") == true)
}

// MARK: - AppleScriptError

func testAppleScriptErrorDescriptions() {
    XCTAssertTrue(AppleScriptError.invalidScript.errorDescription?.contains("无效") == true)
    let err = AppleScriptError.executionFailed(code: 1, message: "timeout")
    XCTAssertTrue(err.errorDescription?.contains("1") == true)
    XCTAssertTrue(err.errorDescription?.contains("timeout") == true)
}

// MARK: - ShellError

func testShellErrorDescriptions() {
    XCTAssertTrue(ShellError.emptyCommand.errorDescription?.contains("为空") == true)
    XCTAssertTrue(ShellError.commandNotAllowed("rm").errorDescription?.contains("rm") == true)
    XCTAssertTrue(ShellError.timeout.errorDescription?.contains("超时") == true)
    XCTAssertTrue(ShellError.executionFailed("OOM").errorDescription?.contains("OOM") == true)
}

// MARK: - ScreenCaptureError

func testScreenCaptureErrorDescriptions() {
    XCTAssertTrue(ScreenCaptureError.noDisplayAvailable.errorDescription?.contains("显示器") == true)
    XCTAssertTrue(ScreenCaptureError.imageConversionFailed.errorDescription?.contains("转换失败") == true)
    XCTAssertTrue(ScreenCaptureError.streamError("disconnect").errorDescription?.contains("disconnect") == true)
}

// MARK: - AppleSpeechError

func testAppleSpeechErrorDescriptions() {
    XCTAssertTrue(AppleSpeechError.notAvailable.errorDescription?.contains("不支持") == true)
    XCTAssertTrue(AppleSpeechError.notAuthorized.errorDescription?.contains("权限") == true)
}
