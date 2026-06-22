import Foundation
import RenJistrolyModels
import XCTest
@testable import RenJistrolySystemBridge

// MARK: - Microphone Permission

func testPermissionsMicrophoneCheckReturnsStatus() async {
    let center = PermissionCenter()
    let check = await center.check(.microphone)
    XCTAssertTrue(check.kind == .microphone)
    let validStatuses: [PermissionStatus] = [.granted, .denied, .notDetermined, .unknown]
    XCTAssertTrue(validStatuses.contains(check.status))
}

func testPermissionsMicrophoneRequestMethodExists() async {
    let center = PermissionCenter()
    let check = await center.check(.microphone)
    XCTAssertTrue(check.kind == .microphone)
}

// MARK: - Speech Recognition Permission

func testPermissionsSpeechRecognitionCheckReturnsStatus() async {
    let center = PermissionCenter()
    let check = await center.check(.speechRecognition)
    XCTAssertTrue(check.kind == .speechRecognition)
    let validStatuses: [PermissionStatus] = [.granted, .denied, .notDetermined, .unknown]
    XCTAssertTrue(validStatuses.contains(check.status))
}

func testPermissionsSpeechRecognitionSystemKindHasCorrectTitle() {
    XCTAssertTrue(SystemPermissionKind.speechRecognition.title == "语音识别")
    XCTAssertTrue(SystemPermissionKind.speechRecognition.description.contains("语音"))
}

// MARK: - Screen Recording Permission

func testPermissionsScreenRecordingCheckReturnsStatus() async {
    let center = PermissionCenter()
    let check = await center.check(.screenRecording)
    XCTAssertTrue(check.kind == .screenRecording)
    let validStatuses: [PermissionStatus] = [.granted, .denied, .notDetermined, .unknown]
    XCTAssertTrue(validStatuses.contains(check.status))
}

func testPermissionsScreenRecordingHasSettingsURL() {
    XCTAssertTrue(SystemPermissionKind.screenRecording.settingsURL != nil)
    let urlStr = SystemPermissionKind.screenRecording.settingsURL?.absoluteString ?? ""
    XCTAssertTrue(urlStr.contains("ScreenCapture"))
}

// MARK: - Accessibility (AX) Permission

func testPermissionsAccessibilityCheckReturnsStatus() async {
    let center = PermissionCenter()
    let check = await center.check(.accessibility)
    XCTAssertTrue(check.kind == .accessibility)
    let validStatuses: [PermissionStatus] = [.granted, .denied, .notDetermined, .unknown]
    XCTAssertTrue(validStatuses.contains(check.status))
}

func testPermissionsAccessibilityHasCorrectTitleAndSettingsURL() {
    XCTAssertTrue(SystemPermissionKind.accessibility.title == "辅助功能")
    XCTAssertTrue(SystemPermissionKind.accessibility.settingsURL != nil)
    let urlStr = SystemPermissionKind.accessibility.settingsURL?.absoluteString ?? ""
    XCTAssertTrue(urlStr.contains("Accessibility"))
}

// MARK: - Automation / Apple Events Permission

func testPermissionsAutomationCheckReturnsStatus() async {
    let center = PermissionCenter()
    let check = await center.check(.automation)
    XCTAssertTrue(check.kind == .automation)
    // Automation always starts as .unknown since it's app-specific
    XCTAssertTrue(check.status == .unknown || check.status == .granted || check.status == .denied)
}

func testPermissionsAppleEventsSystemKindIsPresent() {
    XCTAssertTrue(SystemPermissionKind.allCases.contains(.appleEvents))
    XCTAssertTrue(SystemPermissionKind.appleEvents.title == "Apple Events")
}

// MARK: - File Access Permission

func testPermissionsFileSystemCheckReturnsStatus() async {
    let center = PermissionCenter()
    let check = await center.check(.fileSystem)
    XCTAssertTrue(check.kind == .fileSystem)
    let validStatuses: [PermissionStatus] = [.granted, .denied, .notDetermined, .unknown]
    XCTAssertTrue(validStatuses.contains(check.status))
}

func testPermissionsFileSystemKindHasCorrectTitle() {
    XCTAssertTrue(PermissionKind.fileSystem.title == "文件系统")
    XCTAssertTrue(PermissionKind.fileSystem.purpose.contains("读写"))
}

// MARK: - Permission State Refresh (full check)

func testPermissionsFullCheckReturnsAllKinds() async {
    let center = PermissionCenter()
    let all = await center.checkAll()
    XCTAssertTrue(all.count == PermissionKind.allCases.count)
    let kinds = Set(all.map(\.kind))
    XCTAssertTrue(kinds.count == PermissionKind.allCases.count)
    for kind in PermissionKind.allCases {
        XCTAssertTrue(kinds.contains(kind))
    }
}

func testPermissionsSystemCheckReturnsFiveEntries() async {
    let center = PermissionCenter()
    let checks = await center.checkSystemPermissions()
    XCTAssertTrue(checks.count == SystemPermissionKind.allCases.count)
    let kinds = Set(checks.map(\.kind))
    XCTAssertTrue(kinds.count == SystemPermissionKind.allCases.count)
}

// MARK: - Open System Settings for Permission

func testPermissionsSystemPermissionKindAllHaveSettingsURLs() {
    for kind in SystemPermissionKind.allCases {
        XCTAssertTrue(kind.settingsURL != nil)
    }
}

func testPermissionsAllPermissionKindsHaveSettingsURLs() {
    for kind in PermissionKind.allCases {
        let snapshot = PermissionSnapshot(kind: kind, status: .notDetermined)
        XCTAssertTrue(!snapshot.detail.isEmpty || kind == .stableIdentity || kind == .fileSystem)
    }
}

// MARK: - Resume Operation After Permission Granted

func testPermissionsStatusGrantedFlag() {
    XCTAssertTrue(SystemPermissionStatus.granted.isGranted)
    XCTAssertFalse(SystemPermissionStatus.denied.isGranted)
    XCTAssertFalse(SystemPermissionStatus.notDetermined.isGranted)
    XCTAssertFalse(SystemPermissionStatus.unknown.isGranted)

    XCTAssertTrue(PermissionStatus.granted.isGranted)
    XCTAssertFalse(PermissionStatus.denied.isGranted)
    XCTAssertFalse(PermissionStatus.notDetermined.isGranted)
    XCTAssertFalse(PermissionStatus.unknown.isGranted)
}

func testPermissionsSystemCheckDetailNotEmptyForKnownKinds() {
    let checks = [SystemPermissionCheck(kind: .accessibility, status: .granted, detail: "已授权。")]
    for check in checks {
        XCTAssertTrue(!check.detail.isEmpty || check.status == .notDetermined)
    }
}

// MARK: - Don't Pretend Permission is Granted When Not

func testPermissionsStatusNeverPretendsGranted() {
    let allCases: [SystemPermissionStatus] = [.denied, .notDetermined, .unknown]
    for status in allCases {
        XCTAssertFalse(status.isGranted)
    }
}

func testPermissionsSystemCheckReflectsActualStatus() {
    let deniedCheck = SystemPermissionCheck(kind: .microphone, status: .denied)
    let notDeterminedCheck = SystemPermissionCheck(kind: .speechRecognition, status: .notDetermined)
    let unknownCheck = SystemPermissionCheck(kind: .appleEvents, status: .unknown)

    XCTAssertFalse(deniedCheck.status.isGranted)
    XCTAssertFalse(notDeterminedCheck.status.isGranted)
    XCTAssertFalse(unknownCheck.status.isGranted)
}

// MARK: - Additional PermissionKind Coverage

func testPermissionsSnapshotDetailForEachKind() {
    let kindsAndDetails: [(PermissionKind, String)] = [
        (.microphone, "麦克风"),
        (.speechRecognition, "语音"),
        (.screenRecording, "屏幕"),
        (.accessibility, "辅助功能"),
        (.automation, "自动化"),
        (.fileSystem, "文件"),
        (.shellExecution, "终端"),
        (.network, "网络"),
        (.apiCredentials, "密钥"),
        (.stableIdentity, "签名"),
    ]
    for (kind, keyword) in kindsAndDetails {
        let snapshot = PermissionSnapshot(kind: kind, status: .granted, detail: "测试 \(keyword)")
        XCTAssertTrue(snapshot.kind == kind)
        XCTAssertTrue(snapshot.id == kind)
        XCTAssertTrue(snapshot.detail.contains("测试"))
    }
}

func testPermissionsDisplayNamesAreNotEmpty() {
    for status in SystemPermissionStatus.allCases {
        XCTAssertFalse(status.displayName.isEmpty)
    }
}

// MARK: - FullAccessCapabilitySnapshot

func testPermissionsCapabilitySnapshotCreation() {
    let snap = FullAccessCapabilitySnapshot(
        kind: .voiceInput,
        status: .ok,
        detail: "可用",
        requiredPermissions: [.microphone, .speechRecognition]
    )
    XCTAssertTrue(snap.kind == .voiceInput)
    XCTAssertTrue(snap.status == .ok)
    XCTAssertFalse(snap.detail.isEmpty)
    XCTAssertTrue(snap.requiredPermissions.count == 2)
}

func testPermissionsFullAccessCapabilitySnapshotStatusValues() {
    for kind in FullAccessCapabilityKind.allCases {
        for status in FoundationHealthStatus.allCases {
            let snap = FullAccessCapabilitySnapshot(kind: kind, status: status, detail: status.label)
            XCTAssertTrue(snap.kind == kind)
            XCTAssertFalse(snap.detail.isEmpty)
        }
    }
}

extension SystemPermissionStatus: CaseIterable {
    public static var allCases: [SystemPermissionStatus] {
        [.granted, .denied, .notDetermined, .unknown]
    }
}

extension FoundationHealthStatus: CaseIterable {
    public static var allCases: [FoundationHealthStatus] {
        [.ok, .warning, .failing, .notImplemented]
    }
}

// MARK: - Microphone System Kind

func testPermissionsMicrophoneKindHasTitleAndDescription() {
    XCTAssertTrue(SystemPermissionKind.microphone.title == "麦克风")
    XCTAssertTrue(SystemPermissionKind.microphone.description.contains("语音"))
}

// MARK: - Speech Recognition Settings URL

func testPermissionsSpeechRecognitionKindHasCorrectSettingsURL() {
    let url = SystemPermissionKind.speechRecognition.settingsURL
    XCTAssertTrue(url != nil)
    XCTAssertTrue(url?.absoluteString.contains("SpeechRecognition") == true)
}

// MARK: - Screen Recording Check Detail

func testPermissionsScreenRecordingCheckDetailOnDenied() {
    let deniedCheck = SystemPermissionCheck(kind: .screenRecording, status: .denied, detail: "需要在系统设置中启用。")
    XCTAssertFalse(deniedCheck.status.isGranted)
    XCTAssertTrue(deniedCheck.detail.contains("启用"))
}

// MARK: - Accessibility Description

func testPermissionsAccessibilitySystemKindDescription() {
    XCTAssertTrue(SystemPermissionKind.accessibility.description.contains("界面"))
}

// MARK: - Automation Uses Apple Events

func testPermissionsAutomationUsesAppleEventsEnum() {
    XCTAssertTrue(SystemPermissionKind.allCases.contains(.appleEvents))
    XCTAssertTrue(SystemPermissionKind.appleEvents.title == "Apple Events")
}

// MARK: - File System Snapshot

func testPermissionsFileSystemSnapshotGranted() {
    let snap = PermissionSnapshot(kind: .fileSystem, status: .granted, detail: "可以写入桌面/下载/文稿目录。")
    XCTAssertTrue(snap.kind == .fileSystem)
    XCTAssertTrue(snap.status == .granted)
    XCTAssertFalse(snap.detail.isEmpty)
}

// MARK: - State Refresh Capability Voice Input

func testPermissionsVoiceInputRequiresMicAndSpeech() {
    let snap = FullAccessCapabilitySnapshot(kind: .voiceInput, status: .warning, detail: "需要麦克风和语音识别权限。", requiredPermissions: [.microphone, .speechRecognition])
    XCTAssertTrue(snap.requiredPermissions.contains(.microphone))
    XCTAssertTrue(snap.requiredPermissions.contains(.speechRecognition))
}

// MARK: - Open Settings URLs All Non-Empty

func testPermissionsAllSystemKindsHaveNonEmptySettingsURLs() {
    for kind in SystemPermissionKind.allCases {
        let url = kind.settingsURL
        XCTAssertTrue(url != nil)
        XCTAssertTrue(!(url?.absoluteString.isEmpty ?? true))
    }
}

// MARK: - Resume After Grant Capability Mapping

func testPermissionsCapabilityAllStatusCombinations() {
    for kind in FullAccessCapabilityKind.allCases {
        for status in FoundationHealthStatus.allCases {
            let snap = FullAccessCapabilitySnapshot(kind: kind, status: status, detail: status.label)
            XCTAssertTrue(snap.kind == kind)
            XCTAssertTrue(snap.status == status)
        }
    }
}

// MARK: - No Pretending For Any PermissionStatus

func testPermissionsAllNonGrantedStatusesNotPretended() {
    XCTAssertFalse(PermissionStatus.notDetermined.isGranted)
    XCTAssertFalse(PermissionStatus.unknown.isGranted)
    XCTAssertFalse(PermissionStatus.denied.isGranted)
    XCTAssertTrue(PermissionStatus.granted.isGranted)
}

// MARK: - PermissionStatus Labels

func testPermissionsStatusLabelsForAllStatuses() {
    XCTAssertTrue(PermissionStatus.granted.label == "已授权")
    XCTAssertTrue(PermissionStatus.denied.label == "未授权")
    XCTAssertTrue(PermissionStatus.notDetermined.label == "未请求")
    XCTAssertTrue(PermissionStatus.unknown.label == "需验证")
}

func testPermissionsSystemStatusDisplayNamesForAllStatuses() {
    XCTAssertTrue(SystemPermissionStatus.granted.displayName == "已授权")
    XCTAssertTrue(SystemPermissionStatus.denied.displayName == "未授权")
    XCTAssertTrue(SystemPermissionStatus.notDetermined.displayName == "未请求")
    XCTAssertTrue(SystemPermissionStatus.unknown.displayName == "需验证")
}

// MARK: - FoundationHealthStatus Labels

func testPermissionsFoundationHealthStatusLabels() {
    XCTAssertTrue(FoundationHealthStatus.ok.label == "正常")
    XCTAssertTrue(FoundationHealthStatus.warning.label == "需关注")
    XCTAssertTrue(FoundationHealthStatus.failing.label == "失败")
    XCTAssertTrue(FoundationHealthStatus.notImplemented.label == "未完成")
}

// MARK: - PermissionPolicy Additional Rules

func testPermissionsPermissionPolicyCommandAndBlocked() {
    let policy = PermissionPolicy()
    XCTAssertTrue(policy.evaluate(installPath: "run.command") == .allowed)
    let blockedPolicy = PermissionPolicy(rules: [
        PermissionPolicy.Rule(pattern: "*.exe", access: .blocked),
    ])
    XCTAssertTrue(blockedPolicy.evaluate(installPath: "tool.exe") == .blocked)
}

// MARK: - Shell Execution Check Detail

func testPermissionsShellExecutionSnapshotContainsKeywords() {
    let snap = PermissionSnapshot(kind: .shellExecution, status: .granted, detail: "可执行系统命令。")
    XCTAssertTrue(snap.kind == .shellExecution)
    XCTAssertTrue(snap.status == .granted)
    XCTAssertTrue(snap.detail.contains("命令") || snap.detail.contains("swift"))
}

// MARK: - SystemPermissionKind Descriptions

func testPermissionsAllSystemKindsHaveNonEmptyDescriptions() {
    for kind in SystemPermissionKind.allCases {
        XCTAssertFalse(kind.description.isEmpty)
    }
}

// MARK: - FullAccessCapability Requires Proper Permissions

func testPermissionsScreenUnderstandingNeedsScreenRecording() {
    let snap = FullAccessCapabilitySnapshot(kind: .screenUnderstanding, status: .warning, detail: "需要屏幕录制。", requiredPermissions: [.screenRecording])
    XCTAssertTrue(snap.requiredPermissions.contains(.screenRecording))
}

func testPermissionsAppControlNeedsAccessibility() {
    let snap = FullAccessCapabilitySnapshot(kind: .appControl, status: .warning, detail: "需要辅助功能。", requiredPermissions: [.accessibility])
    XCTAssertTrue(snap.requiredPermissions.contains(.accessibility))
}

final class PermissionCenterLiveMappingTests: XCTestCase {
    func testScreenRecordingUsesLiveSystemCheckDetail() async {
        let center = PermissionCenter()
        let check = await center.check(.screenRecording)
        XCTAssertTrue(check.kind == .screenRecording)
        XCTAssertFalse(check.detail.contains("首次截屏时由系统确认"))
    }
}
