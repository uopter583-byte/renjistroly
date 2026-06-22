import Foundation
import XCTest
@testable import RenJistrolySystemBridge

// MARK: - Greedy decode

func testSimpleDecode() {
    let decoder = CTCDecoder(chars: ["blank", "a", "b", "c"])
    // timeSteps=3, numClasses=4. Logits: [t0: high on 'a', t1: high on 'b', t2: high on 'c']
    let logits: [Float] = [
        0.1, 0.9, 0.1, 0.1,  // t0 → class 1 (a)
        0.1, 0.1, 0.9, 0.1,  // t1 → class 2 (b)
        0.1, 0.1, 0.1, 0.9,  // t2 → class 3 (c)
    ]
    let result = decoder.greedyDecode(logits: logits, timeSteps: 3, numClasses: 4)
    XCTAssertTrue(result == "abc")
}

func testDecodeSkipsRepeatedChars() {
    let decoder = CTCDecoder(chars: ["blank", "a", "b"])
    // Same char twice in a row → collapsed
    let logits: [Float] = [
        0.1, 0.9, 0.1,  // t0 → a
        0.1, 0.9, 0.1,  // t1 → a (repeat, skipped)
        0.1, 0.1, 0.9,  // t2 → b
    ]
    let result = decoder.greedyDecode(logits: logits, timeSteps: 3, numClasses: 3)
    XCTAssertTrue(result == "ab")
}

func testDecodeSkipsBlank() {
    let decoder = CTCDecoder(chars: ["blank", "a", "b"], blankIndex: 0)
    let logits: [Float] = [
        0.9, 0.1, 0.1,  // t0 → blank
        0.1, 0.9, 0.1,  // t1 → a
        0.9, 0.1, 0.1,  // t2 → blank
        0.1, 0.1, 0.9,  // t3 → b
    ]
    let result = decoder.greedyDecode(logits: logits, timeSteps: 4, numClasses: 3)
    XCTAssertTrue(result == "ab")
}

func testDecodeBlankSeparatesRepeats() {
    let decoder = CTCDecoder(chars: ["blank", "a"])
    // a, blank, a → "aa" (blank in between allows repeat)
    let logits: [Float] = [
        0.1, 0.9,  // t0 → a
        0.9, 0.1,  // t1 → blank
        0.1, 0.9,  // t2 → a
    ]
    let result = decoder.greedyDecode(logits: logits, timeSteps: 3, numClasses: 2)
    XCTAssertTrue(result == "aa")
}

func testDecodeEmptyInput() {
    let decoder = CTCDecoder(chars: ["blank", "a"])
    let result = decoder.greedyDecode(logits: [], timeSteps: 0, numClasses: 2)
    XCTAssertTrue(result == "")
}

func testDecodeAllBlank() {
    let decoder = CTCDecoder(chars: ["blank", "a", "b"])
    let logits: [Float] = [
        0.9, 0.1, 0.1,
        0.9, 0.1, 0.1,
    ]
    let result = decoder.greedyDecode(logits: logits, timeSteps: 2, numClasses: 3)
    XCTAssertTrue(result == "")
}

func testDecodeInsufficientLogits() {
    let decoder = CTCDecoder(chars: ["blank", "a"])
    let result = decoder.greedyDecode(logits: [0.5, 0.5], timeSteps: 10, numClasses: 2)
    XCTAssertTrue(result == "")
}

// MARK: - Confidence

func testConfidence() {
    let decoder = CTCDecoder(chars: ["blank", "a", "b"])
    let logits: [Float] = [
        0.1, 0.8, 0.1,  // max 0.8
        0.1, 0.1, 0.8,  // max 0.8
    ]
    let conf = decoder.confidence(logits: logits, timeSteps: 2, numClasses: 3)
    XCTAssertTrue(conf == 0.8)
}

func testConfidenceEmptyInput() {
    let decoder = CTCDecoder(chars: ["blank"])
    let conf = decoder.confidence(logits: [], timeSteps: 0, numClasses: 1)
    XCTAssertTrue(conf == 0)
}
