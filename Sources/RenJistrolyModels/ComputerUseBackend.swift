import Foundation

/// Abstract backend for Computer Use — each backend knows how to observe and act in its environment.
public enum ComputerUseBackendKind: String, Sendable, Codable {
    case accessibility  /// macOS AX API (native apps)
    case dom            /// Browser DOM via JavaScript injection
    case vision         /// Screenshot → vision model → coordinates
    case anthropicCU    /// Anthropic Computer Use API (vision + reasoning)
}

public protocol ComputerUseBackend: Sendable {
    var kind: ComputerUseBackendKind { get }
    var displayName: String { get }

    /// Observe current state, returning targets the backend can interact with.
    func observe(existingObservation: ComputerUseObservation) async -> ComputerUseObservation

    /// Check whether this backend can handle a given action.
    func canHandle(action: MacAction) -> Bool

    /// Execute a MacAction and return the result.
    func execute(action: MacAction) async -> BackendActionResult
}

/// Bridge target — a concrete element reference that a backend can interact with.
public struct ComputerUseBackendTarget: Sendable, Codable {
    public var backendKind: ComputerUseBackendKind
    public var refID: String      /// e.g. AX ref "e12", DOM selector "#submit-btn", or SOM marker
    public var label: String
    public var bounds: CGRect?

    public init(backendKind: ComputerUseBackendKind, refID: String, label: String, bounds: CGRect? = nil) {
        self.backendKind = backendKind
        self.refID = refID
        self.label = label
        self.bounds = bounds
    }
}

/// Result of a backend action execution.
public struct BackendActionResult: Sendable, Codable, Equatable {
    public var success: Bool
    public var message: String
    public var beforeSnapshot: String?
    public var afterSnapshot: String?

    public init(success: Bool, message: String, beforeSnapshot: String? = nil, afterSnapshot: String? = nil) {
        self.success = success
        self.message = message
        self.beforeSnapshot = beforeSnapshot
        self.afterSnapshot = afterSnapshot
    }
}
