import Foundation

public enum TraceEventKind: String, Sendable, Codable, CaseIterable {
    case inputStarted = "input_started"
    case speechPartial = "speech_partial"
    case speechFinal = "speech_final"
    case contextObserved = "context_observed"
    case routeSelected = "route_selected"
    case modelFirstToken = "model_first_token"
    case toolStarted = "tool_started"
    case verifyDone = "verify_done"
    case ttsStarted = "tts_started"
    case turnComplete = "turn_complete"
    case turnFailed = "turn_failed"

    public var label: String {
        switch self {
        case .inputStarted: "输入开始"
        case .speechPartial: "语音部分"
        case .speechFinal: "语音结束"
        case .contextObserved: "上下文采集"
        case .routeSelected: "路由选择"
        case .modelFirstToken: "首个 Token"
        case .toolStarted: "工具执行"
        case .verifyDone: "验证完成"
        case .ttsStarted: "朗读开始"
        case .turnComplete: "回合完成"
        case .turnFailed: "回合失败"
        }
    }
}

public struct TraceEvent: Sendable, Identifiable, Codable {
    public let id: UUID
    public let kind: TraceEventKind
    public let timestamp: Date
    public let detail: String

    public init(kind: TraceEventKind, detail: String = "", timestamp: Date = Date()) {
        self.id = UUID()
        self.kind = kind
        self.timestamp = timestamp
        self.detail = detail
    }
}

public struct InteractionTrace: Sendable, Identifiable, Codable {
    public let id: UUID
    public let turnID: UUID
    public var events: [TraceEvent]
    public let startedAt: Date

    public init(turnID: UUID = UUID()) {
        self.id = UUID()
        self.turnID = turnID
        self.events = []
        self.startedAt = Date()
    }

    public var completedAt: Date? {
        events.last { $0.kind == .turnComplete || $0.kind == .turnFailed }?.timestamp
    }

    public var totalDuration: TimeInterval? {
        guard let end = completedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }

    public mutating func append(_ kind: TraceEventKind, detail: String = "") {
        events.append(TraceEvent(kind: kind, detail: detail))
    }

    public func duration(from: TraceEventKind, to: TraceEventKind) -> TimeInterval? {
        guard let start = events.first(where: { $0.kind == from }),
              let end = events.first(where: { $0.kind == to }) else { return nil }
        return max(0, end.timestamp.timeIntervalSince(start.timestamp))
    }
}

public struct TraceLatencySummary: Sendable, Codable {
    public let asrMs: Int?
    public let observeMs: Int?
    public let routingMs: Int?
    public let firstTokenMs: Int?
    public let toolMs: Int?
    public let ttsMs: Int?
    public let totalMs: Int?
    public let eventCount: Int

    public init(from trace: InteractionTrace) {
        asrMs = trace.duration(from: .inputStarted, to: .speechFinal).map { Int($0 * 1000) }
        observeMs = trace.duration(from: .speechFinal, to: .contextObserved).map { Int($0 * 1000) }
        routingMs = trace.duration(from: .contextObserved, to: .routeSelected).map { Int($0 * 1000) }
        firstTokenMs = trace.duration(from: .routeSelected, to: .modelFirstToken).map { Int($0 * 1000) }
        toolMs = trace.duration(from: .toolStarted, to: .verifyDone).map { Int($0 * 1000) }
        ttsMs = trace.duration(from: .verifyDone, to: .ttsStarted).map { Int($0 * 1000) }
        totalMs = trace.totalDuration.map { Int($0 * 1000) }
        eventCount = trace.events.count
    }
}
