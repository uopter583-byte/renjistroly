import Foundation
import XCTest
import RenJistrolyModels

// MARK: - VoiceInputMode

func testVoiceInputModeAllCases() {
    let all = VoiceInputMode.allCases
    XCTAssertTrue(all.count == 3)
    XCTAssertTrue(all.contains(.accessibilityVoiceInput))
    XCTAssertTrue(all.contains(.systemDictationShortcut))
    XCTAssertTrue(all.contains(.builtInSpeechRecognition))
}

func testVoiceInputModeRawValues() {
    XCTAssertTrue(VoiceInputMode.accessibilityVoiceInput.rawValue == "accessibilityVoiceInput")
    XCTAssertTrue(VoiceInputMode.systemDictationShortcut.rawValue == "systemDictationShortcut")
    XCTAssertTrue(VoiceInputMode.builtInSpeechRecognition.rawValue == "builtInSpeechRecognition")
}

// MARK: - AppMode

func testAppModeRawValues() {
    XCTAssertTrue(AppMode.compact.rawValue == "compact")
    XCTAssertTrue(AppMode.expanded.rawValue == "expanded")
    XCTAssertTrue(AppMode.immersive.rawValue == "immersive")
}
