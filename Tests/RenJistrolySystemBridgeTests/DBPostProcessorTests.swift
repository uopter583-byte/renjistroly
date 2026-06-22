import Foundation
import XCTest
@testable import RenJistrolySystemBridge

// MARK: - Empty / invalid input

func testEmptyHeatmap() {
    let pp = DBPostProcessor()
    let results = pp.process(heatmap: [], mapWidth: 0, mapHeight: 0, imageWidth: 100, imageHeight: 100)
    XCTAssertTrue(results.isEmpty)
}

func testZeroDimensions() {
    let pp = DBPostProcessor()
    let results = pp.process(heatmap: [0.5], mapWidth: 0, mapHeight: 1, imageWidth: 100, imageHeight: 100)
    XCTAssertTrue(results.isEmpty)
}

// MARK: - All below threshold

func testAllBelowThreshold() {
    let pp = DBPostProcessor(threshold: 0.5)
    // 2x2 heatmap, all values below threshold
    let heatmap: [Float] = [0.1, 0.1, 0.1, 0.1]
    let results = pp.process(heatmap: heatmap, mapWidth: 2, mapHeight: 2, imageWidth: 100, imageHeight: 100)
    XCTAssertTrue(results.isEmpty)
}

// MARK: - Single box detection

func testSingleBox() {
    let pp = DBPostProcessor(threshold: 0.2, boxThreshold: 0.3, minSize: 1)
    // 3x3 heatmap with a 2x2 block of high values
    let heatmap: [Float] = [
        0.8, 0.8, 0.1,
        0.8, 0.8, 0.1,
        0.1, 0.1, 0.1,
    ]
    let results = pp.process(heatmap: heatmap, mapWidth: 3, mapHeight: 3, imageWidth: 300, imageHeight: 300)
    XCTAssertTrue(results.count == 1)
    let box = results[0]
    XCTAssertTrue(box.width > 0)
    XCTAssertTrue(box.height > 0)
    XCTAssertTrue(box.confidence > 0)
}

// MARK: - Multiple boxes

func testMultipleBoxes() {
    let pp = DBPostProcessor(threshold: 0.2, boxThreshold: 0.3, minSize: 1)
    // 5x5 heatmap with 2 separated boxes
    let heatmap: [Float] = [
        0.8, 0.8, 0.1, 0.1, 0.1,
        0.8, 0.8, 0.1, 0.1, 0.1,
        0.1, 0.1, 0.1, 0.1, 0.1,
        0.1, 0.1, 0.1, 0.8, 0.8,
        0.1, 0.1, 0.1, 0.8, 0.8,
    ]
    let results = pp.process(heatmap: heatmap, mapWidth: 5, mapHeight: 5, imageWidth: 500, imageHeight: 500)
    XCTAssertTrue(results.count == 2)
}

// MARK: - Min size filter

func testMinSizeFilter() {
    let pp = DBPostProcessor(threshold: 0.2, boxThreshold: 0.1, minSize: 10)
    // Single pixel above threshold won't make a component of minSize 10
    let heatmap: [Float] = [
        0.1, 0.1, 0.1,
        0.1, 0.8, 0.1,
        0.1, 0.1, 0.1,
    ]
    let results = pp.process(heatmap: heatmap, mapWidth: 3, mapHeight: 3, imageWidth: 300, imageHeight: 300)
    XCTAssertTrue(results.isEmpty)
}

// MARK: - Box threshold filter

func testBoxThresholdFilter() {
    let pp = DBPostProcessor(threshold: 0.2, boxThreshold: 0.9, minSize: 1)
    // Box exists but its average score is below boxThreshold
    let heatmap: [Float] = [
        0.5, 0.5, 0.1,
        0.5, 0.5, 0.1,
        0.1, 0.1, 0.1,
    ]
    let results = pp.process(heatmap: heatmap, mapWidth: 3, mapHeight: 3, imageWidth: 300, imageHeight: 300)
    // Average of the 2x2 block is 0.5, which is < 0.9
    XCTAssertTrue(results.isEmpty)
}

// MARK: - Coordinate mapping

func testCoordinateMapping() {
    let pp = DBPostProcessor(threshold: 0.2, boxThreshold: 0.3, minSize: 1)
    // 4x4 heatmap, box in top-left, image is 800x400
    let heatmap: [Float] = [
        0.8, 0.8, 0.1, 0.1,
        0.8, 0.8, 0.1, 0.1,
        0.1, 0.1, 0.1, 0.1,
        0.1, 0.1, 0.1, 0.1,
    ]
    let results = pp.process(heatmap: heatmap, mapWidth: 4, mapHeight: 4, imageWidth: 800, imageHeight: 400)
    XCTAssertTrue(results.count == 1)
    let box = results[0]
    // Box should be in the top-left quadrant of the image
    XCTAssertTrue(box.x < 400)
    XCTAssertTrue(box.y < 200)
}

// MARK: - Default configuration

func testDefaultConfiguration() {
    let pp = DBPostProcessor()
    XCTAssertTrue(pp.threshold == 0.2)
    XCTAssertTrue(pp.boxThreshold == 0.4)
    XCTAssertTrue(pp.maxCandidates == 1000)
    XCTAssertTrue(pp.unclipRatio == 1.4)
    XCTAssertTrue(pp.minSize == 5)
}

// MARK: - DetectedTextBox

func testDetectedTextBoxFields() {
    let box = DetectedTextBox(x: 10, y: 20, width: 100, height: 50, confidence: 0.95)
    XCTAssertTrue(box.x == 10)
    XCTAssertTrue(box.y == 20)
    XCTAssertTrue(box.width == 100)
    XCTAssertTrue(box.height == 50)
    XCTAssertTrue(box.confidence == 0.95)
}
