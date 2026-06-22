import Foundation
import RenJistrolyModels

// MARK: - Hook Protocol

public protocol ToolHook: Sendable {
    var name: String { get }
    var priority: Int { get } // lower = runs first
    func onBeforeExecute(tool: String, arguments: [String: String]) async
    func onAfterExecute(tool: String, arguments: [String: String], result: ToolCallResult) async
}

extension ToolHook {
    public var priority: Int { 100 }
    func onBeforeExecute(tool _: String, arguments _: [String: String]) async {}
    func onAfterExecute(tool _: String, arguments _: [String: String], result _: ToolCallResult) async {}
}

// MARK: - Hook Registry

public actor ToolHookRegistry {
    private var hooks: [String: any ToolHook] = [:]

    public init() {}

    public func register(_ hook: any ToolHook) {
        hooks[hook.name] = hook
    }

    public func registerAll(_ hookList: [any ToolHook]) {
        for hook in hookList {
            hooks[hook.name] = hook
        }
    }

    public func unregister(name: String) {
        hooks.removeValue(forKey: name)
    }

    public var allHooks: [any ToolHook] {
        hooks.values.sorted { $0.priority < $1.priority }
    }

    public func fireBeforeAll(tool: String, arguments: [String: String]) async {
        for hook in allHooks {
            await hook.onBeforeExecute(tool: tool, arguments: arguments)
        }
    }

    public func fireAfterAll(tool: String, arguments: [String: String], result: ToolCallResult) async {
        for hook in allHooks {
            await hook.onAfterExecute(tool: tool, arguments: arguments, result: result)
        }
    }
}
