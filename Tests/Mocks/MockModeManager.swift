import Foundation
@testable import RenJistrolyModels

// MARK: - MockModeManager

/// 模拟 AppMode 状态管理。
/// 记录每次模式切换请求并验证合法性。
final class MockModeManager {
    /// 当前模式
    private(set) var currentMode: AppMode = .compact

    /// 模式切换历史
    private(set) var transitionHistory: [ModeTransition] = []

    /// 允许哪些切换
    var allowedTransitions: Set<AppMode> = [.compact, .expanded, .immersive]

    /// 是否模拟动画延迟（用于异步测试）
    var simulateAnimationDelay: Bool = false
    var animationDelay: TimeInterval = 0.3

    /// 是否允许切换（可设为 false 来模拟故障）
    var canSwitch: Bool = true

    struct ModeTransition: Equatable {
        let from: AppMode
        let to: AppMode
        let timestamp: Date
        let success: Bool

        init(from: AppMode, to: AppMode, success: Bool) {
            self.from = from
            self.to = to
            self.timestamp = Date()
            self.success = success
        }
    }

    /// 尝试切换到新模式
    @discardableResult
    func switchTo(_ newMode: AppMode) -> Bool {
        guard canSwitch, allowedTransitions.contains(newMode) else {
            transitionHistory.append(ModeTransition(from: currentMode, to: newMode, success: false))
            return false
        }
        let oldMode = currentMode
        currentMode = newMode
        transitionHistory.append(ModeTransition(from: oldMode, to: newMode, success: true))
        return true
    }

    /// 当前是否在非紧凑模式
    var isExpanded: Bool { currentMode != .compact }

    /// 切换次数
    var transitionCount: Int { transitionHistory.count }

    /// 成功切换次数
    var successCount: Int { transitionHistory.filter(\.success).count }

    /// 最后一条切换记录
    var lastTransition: ModeTransition? { transitionHistory.last }

    /// 重置换挡记录
    func reset() {
        currentMode = .compact
        transitionHistory.removeAll()
        canSwitch = true
    }

    /// 验证切换序列是否合法（不允许重复切换到同一模式）
    func validateTransitionSequence() -> Bool {
        for i in 1..<transitionHistory.count {
            let prev = transitionHistory[i - 1]
            let curr = transitionHistory[i]
            if prev.to == curr.to {
                return false
            }
            if prev.to != curr.from {
                return false
            }
        }
        return true
    }
}

// MARK: - MockVoiceStateManager

final class MockVoiceStateManager {
    private(set) var currentState: VoiceInputState = .idle
    private(set) var stateChanges: [VoiceInputState] = [.idle]

    var canStartListeningResult: Bool = true
    var canFinishListeningResult: Bool = false

    @discardableResult
    func transition(to newState: VoiceInputState) -> Bool {
        guard isValidTransition(from: currentState, to: newState) else {
            return false
        }
        currentState = newState
        stateChanges.append(newState)
        return true
    }

    var changeCount: Int { stateChanges.count }
    var idleTime: Bool { currentState == .idle }
    var isCapturing: Bool { currentState.isCapturingAudio }
    var canStart: Bool { currentState.canStartListening && canStartListeningResult }
    var canFinish: Bool { currentState.canFinishListening && canFinishListeningResult }

    private func isValidTransition(from: VoiceInputState, to: VoiceInputState) -> Bool {
        switch (from, to) {
        case (.idle, .listening), (.idle, .requestingPermission):
            true
        case (.requestingPermission, .listening), (.requestingPermission, .failed):
            true
        case (.listening, .lockedListening), (.listening, .transcribing), (.listening, .failed):
            true
        case (.lockedListening, .listening), (.lockedListening, .transcribing), (.lockedListening, .failed):
            true
        case (.transcribing, .processing), (.transcribing, .failed):
            true
        case (.processing, .speaking), (.processing, .idle), (.processing, .failed):
            true
        case (.speaking, .idle), (.speaking, .listening), (.speaking, .failed):
            true
        case (.failed, .idle), (.failed, .requestingPermission):
            true
        default:
            false
        }
    }

    func reset() {
        currentState = .idle
        stateChanges = [.idle]
    }
}

// MARK: - 预设场景

enum MockModeScenario {
    enum Error: Swift.Error, Equatable {
        case unexpectedResult(String)
    }

    /// 标准三模式循环：compact → expanded → immersive → compact
    static func standardCycle(manager: MockModeManager) throws {
        guard manager.switchTo(.expanded) else { throw Error.unexpectedResult("切换到 expanded 失败") }
        guard manager.switchTo(.immersive) else { throw Error.unexpectedResult("切换到 immersive 失败") }
        guard manager.switchTo(.compact) else { throw Error.unexpectedResult("切换到 compact 失败") }
    }

    /// 阻止非法切换的测试场景
    static func rejectedTransition(manager: MockModeManager) throws {
        manager.allowedTransitions = [.compact, .expanded]
        guard manager.switchTo(.expanded) else { throw Error.unexpectedResult("切换到 expanded 失败") }
        if manager.switchTo(.immersive) { throw Error.unexpectedResult("切换到 immersive 应该被拒绝") }
    }

    /// 切换故障模拟
    static func failureScenario(manager: MockModeManager) throws {
        manager.canSwitch = false
        if manager.switchTo(.expanded) { throw Error.unexpectedResult("切换应该失败") }
        guard manager.currentMode == .compact else { throw Error.unexpectedResult("模式应为 compact") }
    }
}
