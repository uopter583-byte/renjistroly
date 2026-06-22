import Foundation
import XCTest
import RenJistrolyModels

// MARK: - TranscriptEvent remaining cases

func testTranscriptEventFinalEquality() {
    let a = TranscriptEvent.final("hello world")
    let b = TranscriptEvent.final("hello world")
    let c = TranscriptEvent.final("different")
    XCTAssertTrue(a == b)
    XCTAssertTrue(a != c)
}

func testTranscriptEventFailedEquality() {
    let a = TranscriptEvent.failed("timeout")
    let b = TranscriptEvent.failed("timeout")
    let c = TranscriptEvent.failed("no speech")
    XCTAssertTrue(a == b)
    XCTAssertTrue(a != c)
}

func testTranscriptEventCrossTypeInequality() {
    let partial = TranscriptEvent.partial("hello")
    let final = TranscriptEvent.final("hello")
    let failed = TranscriptEvent.failed("hello")
    XCTAssertTrue(partial != final)
    XCTAssertTrue(partial != failed)
    XCTAssertTrue(final != failed)
}

// MARK: - VoiceSubmitMode

func testVoiceSubmitModeID() {
    XCTAssertTrue(VoiceSubmitMode.manual.id == "manual")
    XCTAssertTrue(VoiceSubmitMode.automatic.id == "automatic")
}

func testVoiceSubmitModeAllCases() {
    XCTAssertTrue(VoiceSubmitMode.allCases.count == 2)
    XCTAssertTrue(VoiceSubmitMode.allCases.contains(.manual))
    XCTAssertTrue(VoiceSubmitMode.allCases.contains(.automatic))
}
