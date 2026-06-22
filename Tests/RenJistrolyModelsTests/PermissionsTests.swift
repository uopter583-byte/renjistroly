import Foundation
import XCTest
import RenJistrolyModels

// MARK: - PermissionKind

func testPermissionKindTitles() {
    XCTAssertTrue(PermissionKind.microphone.title == "麦克风")
    XCTAssertTrue(PermissionKind.speechRecognition.title == "语音识别")
    XCTAssertTrue(PermissionKind.screenRecording.title == "屏幕录制")
    XCTAssertTrue(PermissionKind.accessibility.title == "辅助功能")
    XCTAssertTrue(PermissionKind.automation.title == "自动化")
    XCTAssertTrue(PermissionKind.fileSystem.title == "文件系统")
    XCTAssertTrue(PermissionKind.shellExecution.title == "终端执行")
    XCTAssertTrue(PermissionKind.network.title == "网络访问")
    XCTAssertTrue(PermissionKind.apiCredentials.title == "模型密钥")
    XCTAssertTrue(PermissionKind.stableIdentity.title == "签名身份")
}

func testPermissionKindPurposesNotEmpty() {
    for kind in PermissionKind.allCases {
        XCTAssertFalse(kind.purpose.isEmpty)
    }
}

func testPermissionKindAllCasesCount() {
    XCTAssertTrue(PermissionKind.allCases.count == 10)
}

// MARK: - PermissionStatus

func testPermissionStatusGrantedCheck() {
    XCTAssertTrue(PermissionStatus.granted.isGranted)
    XCTAssertFalse(PermissionStatus.denied.isGranted)
    XCTAssertFalse(PermissionStatus.notDetermined.isGranted)
    XCTAssertFalse(PermissionStatus.unknown.isGranted)
}

func testPermissionStatusLabels() {
    XCTAssertTrue(PermissionStatus.granted.label == "已授权")
    XCTAssertTrue(PermissionStatus.denied.label == "未授权")
    XCTAssertTrue(PermissionStatus.notDetermined.label == "未请求")
    XCTAssertTrue(PermissionStatus.unknown.label == "需验证")
}

// MARK: - PermissionSnapshot

func testPermissionSnapshotID() {
    let snap = PermissionSnapshot(kind: .microphone, status: .granted)
    XCTAssertTrue(snap.id == .microphone)
    XCTAssertTrue(snap.status == .granted)
}

// MARK: - FullAccessCapabilityKind

func testFullAccessCapabilityKindTitles() {
    XCTAssertTrue(FullAccessCapabilityKind.voiceInput.title == "语音输入")
    XCTAssertTrue(FullAccessCapabilityKind.voiceOutput.title == "语音输出")
    XCTAssertTrue(FullAccessCapabilityKind.screenUnderstanding.title == "屏幕理解")
    XCTAssertTrue(FullAccessCapabilityKind.appControl.title == "App 控制")
    XCTAssertTrue(FullAccessCapabilityKind.automation.title == "自动化控制")
    XCTAssertTrue(FullAccessCapabilityKind.fileSystem.title == "文件系统")
    XCTAssertTrue(FullAccessCapabilityKind.shellExecution.title == "终端执行")
    XCTAssertTrue(FullAccessCapabilityKind.network.title == "网络")
    XCTAssertTrue(FullAccessCapabilityKind.modelCredentials.title == "模型密钥")
    XCTAssertTrue(FullAccessCapabilityKind.stableIdentity.title == "稳定身份")
    XCTAssertTrue(FullAccessCapabilityKind.safetyPolicy.title == "安全策略")
}

func testFullAccessCapabilityKindCodexNotEmpty() {
    for kind in FullAccessCapabilityKind.allCases {
        XCTAssertFalse(kind.codexEquivalent.isEmpty)
    }
}

func testFullAccessCapabilityKindAllCasesCount() {
    XCTAssertTrue(FullAccessCapabilityKind.allCases.count == 11)
}

// MARK: - FullAccessCapabilitySnapshot

func testFullAccessCapabilitySnapshotID() {
    let snap = FullAccessCapabilitySnapshot(
        kind: .voiceInput,
        status: .ok,
        detail: "正常",
        requiredPermissions: [.microphone]
    )
    XCTAssertTrue(snap.id == .voiceInput)
    XCTAssertTrue(snap.requiredPermissions.count == 1)
    XCTAssertTrue(snap.requiredPermissions[0] == .microphone)
}

func testFullAccessCapabilitySnapshotEmptyPermissions() {
    let snap = FullAccessCapabilitySnapshot(kind: .safetyPolicy, status: .ok, detail: "正常")
    XCTAssertTrue(snap.requiredPermissions.isEmpty)
}
