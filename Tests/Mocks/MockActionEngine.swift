import Foundation
@testable import RenJistrolyModels

// MARK: - MockActionEngine

/// 模拟动作执行引擎。
/// 记录每次动作的执行请求、结果，支持预设执行结果。
final class MockActionEngine {
    /// 执行记录
    private(set) var executionHistory: [ActionRecord] = []

    /// 预设结果映射（用于控制特定 action kind 的返回结果）
    var presetResults: [MacActionKind: ActionResult] = [:]

    /// 全局默认结果
    var defaultResult: ActionResult

    /// 模拟执行延迟
    var simulateDelay: TimeInterval = 0

    /// 允许执行的动作 types（为空表示全部允许）
    var allowedActions: Set<MacActionKind> = []

    /// 拒绝时使用的错误信息
    var denyMessage: String = "Action not allowed in current mode"

    init(defaultResult: ActionResult? = nil) {
        let fallback = ActionResult(actionID: UUID(), success: true, message: "Mock 执行成功")
        self.defaultResult = defaultResult ?? fallback
    }

    /// 执行一个 MacAction，返回预设或默认结果
    func execute(_ action: MacAction) async -> ActionResult {
        if simulateDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(simulateDelay * 1_000_000_000))
        }

        guard allowedActions.isEmpty || allowedActions.contains(action.kind) else {
            return record(action, result: ActionResult(actionID: action.id, success: false, message: denyMessage))
        }

        if let preset = presetResults[action.kind] {
            return record(action, result: preset)
        }

        return record(action, result: defaultResult)
    }

    /// 执行并验证执行后状态（模拟 verify 流程）
    func executeAndVerify(_ action: MacAction, expectedState: String) async -> (ActionResult, Bool) {
        let result = await execute(action)
        let verified = result.success && verifyState(expectedState)
        return (result, verified)
    }

    /// 获取特定 kind 的执行记录
    func records(for kind: MacActionKind) -> [ActionRecord] {
        executionHistory.filter { $0.action.kind == kind }
    }

    /// 最近 N 条记录
    func recentRecords(_ count: Int = 5) -> [ActionRecord] {
        Array(executionHistory.suffix(count))
    }

    /// 总执行次数
    var totalExecutions: Int { executionHistory.count }

    /// 成功次数
    var successCount: Int { executionHistory.filter { $0.result.success }.count }

    /// 失败次数
    var failureCount: Int { executionHistory.filter { !$0.result.success }.count }

    /// 清空历史
    func reset() {
        executionHistory.removeAll()
    }

    /// 预设一个 kind 的结果
    func stub(_ kind: MacActionKind, result: ActionResult) {
        presetResults[kind] = result
    }

    // MARK: - Private

    private func record(_ action: MacAction, result: ActionResult) -> ActionResult {
        executionHistory.append(ActionRecord(action: action, result: result))
        return result
    }

    private func verifyState(_ state: String) -> Bool {
        !state.isEmpty
    }
}

// MARK: - MockActionRecorder

/// 纯记录器，不执行实际动作，只记录动作请求。
actor MockActionRecorder {
    private(set) var recordedActions: [MacAction] = []
    private(set) var shouldSucceed: Bool = true

    init(shouldSucceed: Bool = true) {
        self.shouldSucceed = shouldSucceed
    }

    func record(_ action: MacAction) {
        recordedActions.append(action)
    }

    func execute(_ action: MacAction) -> ActionResult {
        recordedActions.append(action)
        return ActionResult(actionID: action.id, success: shouldSucceed, message: shouldSucceed ? "ok" : "模拟失败")
    }

    var count: Int { recordedActions.count }

    func reset() {
        recordedActions.removeAll()
    }

    nonisolated var safeActions: [MacAction] {
        get async { await recordedActions }
    }
}

// MARK: - Supporting Types

struct ActionRecord: Equatable {
    let action: MacAction
    let result: ActionResult
    let timestamp: Date

    init(action: MacAction, result: ActionResult) {
        self.action = action
        self.result = result
        self.timestamp = Date()
    }
}

// MARK: - 预设场景工厂

enum MockActionScenario {
    /// 创建一个简单的点击动作
    static func click(at point: CGPoint, risk: ActionRiskLevel = .readOnly) -> MacAction {
        MacAction(
            kind: .clickAt,
            payload: ["x": "\(Int(point.x))", "y": "\(Int(point.y))"],
            riskLevel: risk,
            humanPreview: "点击 (\(Int(point.x)), \(Int(point.y)))"
        )
    }

    /// 创建一个输入文字的动作
    static func typeText(_ text: String, risk: ActionRiskLevel = .reversibleInput) -> MacAction {
        MacAction(
            kind: .insertText,
            payload: ["text": text],
            riskLevel: risk,
            humanPreview: "输入文字"
        )
    }

    /// 创建一个读取上下文动作
    static func readContext() -> MacAction {
        MacAction(
            kind: .readContext,
            riskLevel: .readOnly,
            humanPreview: "读取当前上下文"
        )
    }

    /// 创建一个打开应用动作
    static func openApp(_ name: String, risk: ActionRiskLevel = .persistentOrExternal) -> MacAction {
        MacAction(
            kind: .openApplication,
            payload: ["app": name],
            riskLevel: risk,
            humanPreview: "打开应用 \(name)"
        )
    }

    /// 创建一个关闭窗口动作
    static func closeWindow(risk: ActionRiskLevel = .destructiveOrSensitive) -> MacAction {
        MacAction(
            kind: .closeWindow,
            riskLevel: risk,
            humanPreview: "关闭当前窗口"
        )
    }

    /// 一组常见操作序列
    static func typicalSession() -> [MacAction] {
        [
            readContext(),
            click(at: CGPoint(x: 100, y: 200)),
            typeText("Hello"),
            openApp("Safari"),
        ]
    }
}
