import Foundation

public actor AgentEventBus {
    public static let shared = AgentEventBus()
    private var continuations: [UUID: AsyncStream<AgentEvent>.Continuation] = [:]
    private var timelineContinuations: [UUID: AsyncStream<AgentTimelineEntry>.Continuation] = [:]
    private var eventBuffer: [AgentTimelineEntry] = []
    private let maxBufferSize: Int

    public init(maxBufferSize: Int = 500) {
        self.maxBufferSize = maxBufferSize
    }

    public func publish(_ event: AgentEvent) {
        let entry = AgentTimelineEntry(event: event)
        eventBuffer.append(entry)
        if eventBuffer.count > maxBufferSize {
            eventBuffer.removeFirst(eventBuffer.count - maxBufferSize)
        }
        for (_, continuation) in continuations {
            continuation.yield(event)
        }
        for (_, continuation) in timelineContinuations {
            continuation.yield(entry)
        }
    }

    public func subscribe() -> (stream: AsyncStream<AgentEvent>, id: UUID) {
        let id = UUID()
        let (stream, continuation) = AsyncStream<AgentEvent>.makeStream(bufferingPolicy: .bufferingNewest(200))
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.unsubscribe(id) }
        }
        return (stream, id)
    }

    public func subscribeTimeline() -> (stream: AsyncStream<AgentTimelineEntry>, id: UUID) {
        let id = UUID()
        let (stream, continuation) = AsyncStream<AgentTimelineEntry>.makeStream(bufferingPolicy: .bufferingNewest(200))
        timelineContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.unsubscribe(id) }
        }
        return (stream, id)
    }

    public func unsubscribe(_ id: UUID) {
        continuations[id]?.finish()
        continuations.removeValue(forKey: id)
        timelineContinuations[id]?.finish()
        timelineContinuations.removeValue(forKey: id)
    }

    public func recentEvents(_ count: Int = 50) -> [AgentTimelineEntry] {
        Array(eventBuffer.suffix(count))
    }

    public func events(matching category: String, limit: Int = 50) -> [AgentTimelineEntry] {
        eventBuffer.filter { $0.category == category }.suffix(limit)
    }

    public func events(matching kind: EventKind, limit: Int = 50) -> [AgentTimelineEntry] {
        eventBuffer.filter { $0.event.kind == kind }.suffix(limit)
    }

    public var subscriberCount: Int { continuations.count + timelineContinuations.count }
}

public enum EventKind: Sendable {
    case voice, desktop, browser, code, lifecycle, system
}

extension AgentEvent {
    public var kind: EventKind {
        switch self {
        case .voice: return .voice
        case .desktop: return .desktop
        case .browser: return .browser
        case .code: return .code
        case .lifecycle: return .lifecycle
        case .system: return .system
        }
    }

    public func matches(_ kind: EventKind) -> Bool {
        self.kind == kind
    }

    public var eventDescription: String { summary }
}
