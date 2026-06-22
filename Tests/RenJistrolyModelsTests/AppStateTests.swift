import Foundation
import XCTest
import RenJistrolyModels

// MARK: - PermissionGrant

func testPermissionGrantAllGrantedTrue() {
    var grant = AppState.PermissionGrant()
    grant.accessibility = true
    grant.microphone = true
    grant.speechRecognition = true
    grant.screenRecording = true
    grant.appleEvents = true
    XCTAssertTrue(grant.allGranted)
}

func testPermissionGrantAllGrantedFalseWhenMissing() {
    var grant = AppState.PermissionGrant()
    grant.accessibility = true
    grant.microphone = true
    grant.speechRecognition = true
    grant.screenRecording = true
    grant.appleEvents = false
    XCTAssertFalse(grant.allGranted)
}

func testPermissionGrantAllGrantedDefaultFalse() {
    let grant = AppState.PermissionGrant()
    XCTAssertFalse(grant.allGranted)
}

func testPermissionGrantAllGrantedPartial() {
    var grant = AppState.PermissionGrant()
    grant.accessibility = true
    grant.microphone = true
    XCTAssertFalse(grant.allGranted)
}

// MARK: - AppState defaults

@MainActor
func testAppStateDefaultValues() {
    let state = AppState()
    XCTAssertTrue(state.mode == .compact)
    XCTAssertTrue(state.voiceState == .idle)
    XCTAssertTrue(state.isHotkeyEnabled == true)
    XCTAssertTrue(state.isVoiceOutputEnabled == false)
    XCTAssertTrue(state.isContinuousVoiceModeEnabled == false)
    XCTAssertTrue(state.voiceInputMode == .accessibilityVoiceInput)
    XCTAssertTrue(state.activeConversationID == nil)
    XCTAssertTrue(state.activeProvider == .claudeCodeCLI)
    XCTAssertTrue(state.preferredCloudProvider == .anthropic)
    XCTAssertTrue(state.isOnline == true)
    XCTAssertTrue(state.isStreaming == false)
    XCTAssertTrue(state.devMode == .disabled)
    XCTAssertTrue(state.ocrEngine == .both)
}

@MainActor
func testAppStateCompleteOnboarding() {
    let state = AppState()
    XCTAssertFalse(state.hasCompletedOnboarding)
    state.completeOnboarding()
    XCTAssertTrue(state.hasCompletedOnboarding)
    UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
}
