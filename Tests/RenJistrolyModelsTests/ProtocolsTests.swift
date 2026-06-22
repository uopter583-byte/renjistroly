import Foundation
import XCTest
import RenJistrolyModels

// MARK: - ParameterType

func testParameterTypeRawValues() {
    XCTAssertTrue(ToolDefinition.Parameter.ParameterType.string.rawValue == "string")
    XCTAssertTrue(ToolDefinition.Parameter.ParameterType.number.rawValue == "number")
    XCTAssertTrue(ToolDefinition.Parameter.ParameterType.boolean.rawValue == "boolean")
    XCTAssertTrue(ToolDefinition.Parameter.ParameterType.object.rawValue == "object")
    XCTAssertTrue(ToolDefinition.Parameter.ParameterType.array.rawValue == "array")
}

// MARK: - Parameter

func testParameterInitWithDefaults() {
    let param = ToolDefinition.Parameter(name: "arg1", type: .string, description: "参数1")
    XCTAssertTrue(param.name == "arg1")
    XCTAssertTrue(param.type == .string)
    XCTAssertTrue(param.description == "参数1")
    XCTAssertTrue(param.required == true)
}

func testParameterInitOptional() {
    let param = ToolDefinition.Parameter(name: "arg2", type: .boolean, description: "是否启用", required: false)
    XCTAssertTrue(param.required == false)
}

// MARK: - ToolDefinition

func testToolDefinitionMultipleParameters() {
    let tool = ToolDefinition(
        name: "multi_arg_tool",
        description: "多参数工具",
        parameters: [
            ToolDefinition.Parameter(name: "a", type: .string, description: "A"),
            ToolDefinition.Parameter(name: "b", type: .number, description: "B", required: false),
        ]
    )
    XCTAssertTrue(tool.name == "multi_arg_tool")
    XCTAssertTrue(tool.parameters.count == 2)
    XCTAssertTrue(tool.parameters[0].name == "a")
    XCTAssertTrue(!tool.parameters[1].required)
}

func testToolDefinitionEmptyParameters() {
    let tool = ToolDefinition(name: "no_arg_tool", description: "无参数", parameters: [])
    XCTAssertTrue(tool.parameters.isEmpty)
}
