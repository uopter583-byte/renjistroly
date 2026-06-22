import Foundation
import XCTest
import RenJistrolyModels

// MARK: - NativeAccessibilityFeatureKind

func testNativeAccessibilityFeatureKindTitles() {
    XCTAssertTrue(NativeAccessibilityFeatureKind.voiceControl.title == "语音控制")
    XCTAssertTrue(NativeAccessibilityFeatureKind.liveCaptions.title == "实时字幕")
    XCTAssertTrue(NativeAccessibilityFeatureKind.dictation.title == "听写")
    XCTAssertTrue(NativeAccessibilityFeatureKind.hoverText.title == "悬停文本")
}

func testNativeAccessibilityFeatureKindModes() {
    XCTAssertTrue(NativeAccessibilityFeatureKind.dictation.mode == .direct)
    XCTAssertTrue(NativeAccessibilityFeatureKind.spokenContent.mode == .direct)
    XCTAssertTrue(NativeAccessibilityFeatureKind.voiceControl.mode == .assisted)
    XCTAssertTrue(NativeAccessibilityFeatureKind.liveSpeech.mode == .assisted)
    XCTAssertTrue(NativeAccessibilityFeatureKind.rtt.mode == .settingsOnly)
    XCTAssertTrue(NativeAccessibilityFeatureKind.captions.mode == .settingsOnly)
}

func testNativeAccessibilityFeatureKindURLPrefix() {
    for kind in NativeAccessibilityFeatureKind.allCases {
        XCTAssertTrue(kind.settingURLString.hasPrefix("x-apple.systempreferences:"))
    }
}

func testNativeAccessibilityFeatureKindAppUsageNotEmpty() {
    for kind in NativeAccessibilityFeatureKind.allCases {
        XCTAssertFalse(kind.appUsage.isEmpty)
    }
}

func testNativeAccessibilityFeatureKindAllCasesCount() {
    XCTAssertTrue(NativeAccessibilityFeatureKind.allCases.count == 14)
}

// MARK: - NativeAccessibilityIntegrationMode

func testNativeAccessibilityIntegrationModeTitles() {
    XCTAssertTrue(NativeAccessibilityIntegrationMode.direct.title == "已直接接入")
    XCTAssertTrue(NativeAccessibilityIntegrationMode.assisted.title == "可协同使用")
    XCTAssertTrue(NativeAccessibilityIntegrationMode.settingsOnly.title == "系统级设置")
}

// MARK: - NativeAccessibilityFeatureSnapshot

func testNativeAccessibilityFeatureSnapshotFromKind() {
    let snap = NativeAccessibilityFeatureSnapshot(kind: .voiceControl)
    XCTAssertTrue(snap.mode == .assisted)
    XCTAssertTrue(snap.id == .voiceControl)
    XCTAssertFalse(snap.detail.isEmpty)
}

// MARK: - NativeAccessibilityFeatureCatalog

func testNativeAccessibilityFeatureCatalogAll() {
    let all = NativeAccessibilityFeatureCatalog.all
    XCTAssertTrue(all.count == NativeAccessibilityFeatureKind.allCases.count)
}

func testNativeAccessibilityFeatureCatalogMatchDirect() {
    XCTAssertTrue(NativeAccessibilityFeatureCatalog.match("语音控制") == .voiceControl)
    XCTAssertTrue(NativeAccessibilityFeatureCatalog.match("听写") == .dictation)
    XCTAssertTrue(NativeAccessibilityFeatureCatalog.match("实时字幕") == .liveCaptions)
    XCTAssertTrue(NativeAccessibilityFeatureCatalog.match("悬停文本") == .hoverText)
    XCTAssertTrue(NativeAccessibilityFeatureCatalog.match("字幕") == .captions)
}

func testNativeAccessibilityFeatureCatalogMatchAlias() {
    XCTAssertTrue(NativeAccessibilityFeatureCatalog.match("鼠标控制") == .pointerControl)
    XCTAssertTrue(NativeAccessibilityFeatureCatalog.match("声音快捷指令") == .vocalShortcuts)
    XCTAssertTrue(NativeAccessibilityFeatureCatalog.match("语音输入") == .dictation)
    XCTAssertTrue(NativeAccessibilityFeatureCatalog.match("朗读内容") == .spokenContent)
}

func testNativeAccessibilityFeatureCatalogMatchUnknown() {
    XCTAssertTrue(NativeAccessibilityFeatureCatalog.match("飞行模式") == nil)
    XCTAssertTrue(NativeAccessibilityFeatureCatalog.match("蓝牙") == nil)
}
