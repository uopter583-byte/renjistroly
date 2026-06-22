import Foundation
import RenJistrolyModels

public actor RecoveryDecider {
    private var history: [RecoveryRecord] = []
    private let maxHistory = 200

    public init() {}

    // MARK: - Record

    public func record(
        toolName: String,
        appName: String?,
        failure: String,
        strategy: String,
        success: Bool
    ) {
        let record = RecoveryRecord(
            toolName: toolName,
            appName: appName,
            failurePattern: Self.classifyFailure(failure),
            strategy: strategy,
            success: success,
            timestamp: Date()
        )
        history.append(record)
        if history.count > maxHistory { history.removeFirst(history.count - maxHistory) }
    }

    public func scores(for toolName: String, appName: String?, failure: String) -> [String: Double] {
        let pattern = Self.classifyFailure(failure)
        let relevant = history.filter { record in
            record.toolName == toolName && record.failurePattern == pattern
        }
        guard !relevant.isEmpty else {
            return defaultScores(for: toolName, failure: failure)
        }

        var strategyScores: [String: (success: Int, total: Int)] = [:]
        for record in relevant {
            var entry = strategyScores[record.strategy] ?? (0, 0)
            entry.total += 1
            if record.success { entry.success += 1 }
            strategyScores[record.strategy] = entry
        }

        var scores: [String: Double] = [:]
        for (strategy, stats) in strategyScores where stats.total > 0 {
            let baseRate = Double(stats.success) / Double(stats.total)
            let recency = relevant.filter { $0.strategy == strategy }.prefix(5).filter(\.success).count
            let recencyBoost = Double(recency) / 5.0 * 0.3
            scores[strategy] = min(1.0, baseRate + recencyBoost)
        }

        // Fill gaps with default heuristics
        for (key, value) in defaultScores(for: toolName, failure: failure) where scores[key] == nil {
            scores[key] = value * 0.5
        }

        return scores
    }

    public func snapshot(toolName: String, appName: String?) -> RecoveryProfileSnapshot {
        let scope = appName.map { "\($0)/\(toolName)" } ?? toolName
        var strategies: [RecoveryStrategyMetric] = []
        for strategy in uniqueStrategies(for: toolName) {
            let relevant = history.filter { $0.toolName == toolName && $0.strategy == strategy }
            let total = relevant.count
            let success = relevant.filter(\.success).count
            let rate = total > 0 ? Double(success) / Double(total) : 0
            strategies.append(RecoveryStrategyMetric(strategy: strategy, successRate: rate))
        }
        return RecoveryProfileSnapshot(scope: scope, appName: appName, toolName: toolName, strategies: strategies)
    }

    // MARK: - Failure Classification

    public static func classifyFailure(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("找不到") || lower.contains("not found") || lower.contains("不存在") { return "element_not_found" }
        if lower.contains("快照已过期") || lower.contains("stale") || lower.contains("expired") { return "snapshot_stale" }
        if lower.contains("权限") || lower.contains("permission") || lower.contains("denied") { return "permission_denied" }
        if lower.contains("超时") || lower.contains("timeout") || lower.contains("timed out") { return "timeout" }
        if lower.contains("无法") || lower.contains("失败") || lower.contains("failed") || lower.contains("error") { return "action_failed" }
        if lower.contains("未响应") || lower.contains("not responding") || lower.contains("unresponsive") { return "app_unresponsive" }
        return "unknown"
    }

    private func uniqueStrategies(for toolName: String) -> [String] {
        Array(Set(history.filter { $0.toolName == toolName }.map(\.strategy))).sorted()
    }

    private func defaultScores(for toolName: String, failure: String) -> [String: Double] {
        let pattern = Self.classifyFailure(failure)
        switch (toolName, pattern) {
        case ("click", "element_not_found"):
            return ["remapByStableID": 0.9, "reobserveAndRetry": 0.8, "coordinateClickFallback": 0.7, "activateTargetApp": 0.4]
        case ("click", "snapshot_stale"):
            return ["reobserveAndRetry": 0.95, "remapByStableID": 0.85, "coordinateClickFallback": 0.5]
        case ("click", _):
            return ["reobserveAndRetry": 0.7, "remapByStableID": 0.6, "coordinateClickFallback": 0.5]
        case ("scroll", _):
            return ["reobserveAndRetry": 0.8, "activateTargetApp": 0.6]
        case ("drag", _):
            return ["reobserveAndRetry": 0.8, "coordinateClickFallback": 0.5, "activateTargetApp": 0.6]
        case ("type_text", _), ("set_value", _):
            return ["reobserveAndRetry": 0.8, "remapByStableID": 0.7, "activateTargetApp": 0.5]
        case (_, "permission_denied"):
            return ["reobserveAndRetry": 0.3, "activateTargetApp": 0.2]
        case (_, "timeout"):
            return ["reobserveAndRetry": 0.9, "activateTargetApp": 0.4]
        default:
            return ["reobserveAndRetry": 0.7, "remapByStableID": 0.5, "activateTargetApp": 0.4, "coordinateClickFallback": 0.3]
        }
    }
}

public struct RecoveryRecord: Codable, Sendable {
    public let toolName: String
    public let appName: String?
    public let failurePattern: String
    public let strategy: String
    public let success: Bool
    public let timestamp: Date

    public init(toolName: String, appName: String?, failurePattern: String, strategy: String, success: Bool, timestamp: Date = Date()) {
        self.toolName = toolName
        self.appName = appName
        self.failurePattern = failurePattern
        self.strategy = strategy
        self.success = success
        self.timestamp = timestamp
    }
}
