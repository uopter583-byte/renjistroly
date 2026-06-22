import Foundation

/// 浮动面板 / 主窗口的状态展示模型。
/// 将底层状态（VoiceInputState、PlanStatus、ToolRiskLevel）映射为 UI 展示值。
/// 纯值类型，不依赖 SwiftUI，可直接单元测试。
public enum PanelStatusModel {

    /// UI 展示状态的分类枚举。
    public enum Status: String, Sendable, Equatable, CaseIterable {
        case idle
        case listening
        case lockedListening
        case transcribing
        case speaking
        case voiceFailed
        case processing
        case planExecuting
        case planPendingApproval
        case planDrafting
        case planCompleted
        case planFailed
        case planCancelled
        case planApproved
        case buildSucceeded
        case buildFailed
    }

    /// 根据各项状态计算当前的 UI 展示状态。
    /// - Parameters:
    ///   - voiceState: 当前语音状态
    ///   - isProcessing: ConversationEngine 是否正在处理
    ///   - activePlan: 当前活跃的执行计划（可选）
    ///   - lastBuildResult: 最近一次构建结果（可选，仅主窗口使用）
    /// - Returns: 对应的 UI 展示状态
    public static func status(
        voiceState: VoiceInputState,
        isProcessing: Bool,
        activePlan: ExecutionPlan?,
        lastBuildResult: BuildResult? = nil
    ) -> Status {
        // 1. 语音活跃时优先展示语音状态（voiceFailed 除外，它不改变底部状态文本）
        if isVoiceActive(voiceState) && voiceState != .failed {
            switch voiceState {
            case .listening:      return .listening
            case .lockedListening: return .lockedListening
            case .transcribing:   return .transcribing
            case .speaking:       return .speaking
            default: break
            }
        }

        // 2. 处理中
        if isProcessing {
            if activePlan?.status == .executing {
                return .planExecuting
            }
            return .processing
        }

        // 3. 有执行计划
        if let plan = activePlan {
            switch plan.status {
            case .pendingApproval: return .planPendingApproval
            case .executing:       return .planExecuting
            case .completed:       return .planCompleted
            case .failed:          return .planFailed
            case .drafting:        return .planDrafting
            case .cancelled:       return .planCancelled
            case .approved:        return .planApproved
            }
        }

        // 4. 主窗口特有的构建结果
        if let build = lastBuildResult {
            return build.success ? .buildSucceeded : .buildFailed
        }

        return .idle
    }

    /// 语音是否处于活跃状态（用于控制语音相关 UI 元素的显示）。
    public static func isVoiceActive(_ state: VoiceInputState) -> Bool {
        state == .failed || state.isCapturingAudio || state == .speaking
    }

    /// 状态对应的中文标签。
    public static func label(_ status: Status) -> String {
        switch status {
        case .idle:              return "就绪"
        case .listening:         return "正在听..."
        case .lockedListening:   return "持续监听..."
        case .transcribing:      return "转写中..."
        case .speaking:          return "朗读中..."
        case .voiceFailed:       return ""
        case .processing:        return "处理中..."
        case .planExecuting:     return "执行计划..."
        case .planPendingApproval: return "等待批准"
        case .planDrafting:      return "生成计划..."
        case .planCompleted:     return "计划完成"
        case .planFailed:        return "计划失败"
        case .planCancelled:     return ""
        case .planApproved:      return ""
        case .buildSucceeded:    return ""
        case .buildFailed:       return ""
        }
    }

    /// 状态对应的指示色标识（由视图层映射到具体 Color）。
    public enum StatusColor: String, Sendable, Equatable {
        case green
        case blue
        case orange
        case red
    }

    /// 状态对应的指示色。
    public static func statusColor(_ status: Status) -> StatusColor {
        switch status {
        case .idle:              return .green
        case .listening:         return .blue
        case .lockedListening:   return .blue
        case .transcribing:      return .orange
        case .speaking:          return .green
        case .voiceFailed:       return .red
        case .processing:        return .blue
        case .planExecuting:     return .blue
        case .planPendingApproval: return .blue
        case .planDrafting:      return .blue
        case .planCompleted:     return .green
        case .planFailed:        return .red
        case .planCancelled:     return .blue
        case .planApproved:      return .blue
        case .buildSucceeded:    return .green
        case .buildFailed:       return .red
        }
    }

    /// 风险等级对应的 SF Symbol 图标名称。
    public static func riskIconName(_ level: ToolRiskLevel) -> String {
        switch level {
        case .low:    return "checkmark.shield"
        case .medium: return "shield"
        case .high:   return "exclamationmark.shield"
        }
    }

    /// 风险等级对应的色标识。
    public static func riskColor(_ level: ToolRiskLevel) -> StatusColor {
        switch level {
        case .low:    return .green
        case .medium: return .orange
        case .high:   return .red
        }
    }
}
