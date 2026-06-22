import XCTest
@testable import RenJistrolySystemBridge

// MARK: - Diff computation tests

func testIdenticalText() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let text = "Line1\nLine2\nLine3"
    let result = await verifier.diff(before: text, after: text)
    XCTAssertTrue(result.addedLines.isEmpty)
    XCTAssertTrue(result.removedLines.isEmpty)
    XCTAssertTrue(result.changedLines.isEmpty)
    XCTAssertTrue(result.similarity == 1.0)
}

func testAddedLines() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let before = "Line1\nLine2"
    let after = "Line1\nLine2\nLine3\nLine4"
    let result = await verifier.diff(before: before, after: after)
    XCTAssertTrue(result.addedLines.count == 2)
    XCTAssertTrue(result.addedLines.contains("Line3"))
    XCTAssertTrue(result.addedLines.contains("Line4"))
    XCTAssertTrue(result.removedLines.isEmpty)
    XCTAssertTrue(result.similarity < 1.0)
}

func testRemovedLines() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let before = "Line1\nLine2\nLine3"
    let after = "Line1"
    let result = await verifier.diff(before: before, after: after)
    XCTAssertTrue(result.removedLines.count == 2)
    XCTAssertTrue(result.removedLines.contains("Line2"))
    XCTAssertTrue(result.removedLines.contains("Line3"))
    XCTAssertTrue(result.addedLines.isEmpty)
}

func testChangedLinesFuzzyMatch() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let before = "Save File As Document\nCancel"
    let after = "Save File As Project\nCancel"
    let result = await verifier.diff(before: before, after: after)
    XCTAssertFalse(result.changedLines.isEmpty)
}

func testExpectedKeywordsDetected() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let before = "Home Screen"
    let after = "Settings Screen"
    let result = await verifier.diff(before: before, after: after, expectedKeywords: ["Settings"])
    XCTAssertTrue(result.hasExpectedChange)
}

func testExpectedKeywordsNotFound() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let before = "Home Screen"
    let after = "Settings Screen"
    let result = await verifier.diff(before: before, after: after, expectedKeywords: ["DarkMode"])
    XCTAssertFalse(result.hasExpectedChange)
}

func testEmptyExpectedKeywordsReturnsTrue() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let result = await verifier.diff(before: "A", after: "B", expectedKeywords: [])
    XCTAssertTrue(result.hasExpectedChange)
}

func testEmptyTexts() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let result = await verifier.diff(before: "", after: "")
    XCTAssertTrue(result.addedLines.isEmpty)
    XCTAssertTrue(result.removedLines.isEmpty)
    XCTAssertTrue(result.similarity == 1.0)
}

func testBeforeEmptyAfterHasText() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let result = await verifier.diff(before: "", after: "New Content")
    XCTAssertTrue(result.addedLines.count == 1)
    XCTAssertTrue(result.similarity == 0.0)
}

func testSimilarityPartialOverlap() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let before = "A\nB\nC\nD"
    let after = "C\nD\nE\nF"
    let result = await verifier.diff(before: before, after: after)
    XCTAssertTrue(result.similarity > 0.3)
    XCTAssertTrue(result.similarity < 0.7)
}

func testSummaryFormatting() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let result = await verifier.diff(before: "Old", after: "New")
    XCTAssertTrue(result.summary.contains("相似度"))
    XCTAssertTrue(result.summary.contains("%"))
}

func testCaseInsensitiveKeywordMatch() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let result = await verifier.diff(
        before: "before",
        after: "UPPERCASE TEXT",
        expectedKeywords: ["uppercase"]
    )
    XCTAssertTrue(result.hasExpectedChange)
}

func testMultiLineKeywordMatch() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let after = """
    Menu Bar
    File Edit View
    Project Navigator
    """
    let result = await verifier.diff(
        before: "Empty",
        after: after,
        expectedKeywords: ["Project Navigator"]
    )
    XCTAssertTrue(result.hasExpectedChange)
}

// MARK: - ScreenDiffResult summary edge cases

func testSummaryNoChanges() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let result = await verifier.diff(before: "Same", after: "Same")
    XCTAssertTrue(result.summary.contains("无变化"))
}

func testSummaryAllTypes() async {
    let verifier = ScreenDiffVerifier(screen: ScreenContextProvider())
    let before = "Removed Line\nCommon Line"
    let after = "Common Line\nAdded Line"
    let result = await verifier.diff(before: before, after: after)
    XCTAssertTrue(result.summary.contains("+"))
    XCTAssertTrue(result.summary.contains("-"))
}
