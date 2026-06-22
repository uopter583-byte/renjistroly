import Testing
import Foundation
@testable import RenJistrolyModels
@testable import RenJistrolyCapability

// MARK: - Scroll Tool Tests

@Test func scrollTool_injectsMock() async throws {
    let mock = MockScrollBridge()
    let tool = ScrollTool(bridge: mock)

    _ = try await tool.execute(arguments: ["lines": "15"])

    let args = await mock.recordedArgs
    #expect(args.count == 1)
    #expect(args[0].lines == 15)
    #expect(args[0].deltaY == 0)
    #expect(args[0].deltaX == 0)
}

@Test func scrollTool_linesNegative() async throws {
    let mock = MockScrollBridge()
    let tool = ScrollTool(bridge: mock)

    _ = try await tool.execute(arguments: ["lines": "-10"])

    let args = await mock.recordedArgs
    #expect(args.count == 1)
    #expect(args[0].lines == -10)
}

@Test func scrollTool_deltaYFallback() async throws {
    let mock = MockScrollBridge()
    let tool = ScrollTool(bridge: mock)

    _ = try await tool.execute(arguments: ["delta_y": "3"])

    let args = await mock.recordedArgs
    #expect(args.count == 1)
    #expect(args[0].lines == 0)
    #expect(args[0].deltaY == 3)
}

@Test func scrollTool_defaultInit() async throws {
    // Default init uses real AccessibilityBridge — should not crash or throw
    let tool = ScrollTool()
    let _ = tool.definition // verify it's fully constructed
}

@Test func scrollTool_errorPropagation() async throws {
    let mock = MockScrollBridge(shouldThrow: true)
    let tool = ScrollTool(bridge: mock)

    let result = try await tool.execute(arguments: ["lines": "5"])
    #expect(result.isError == true)
}
