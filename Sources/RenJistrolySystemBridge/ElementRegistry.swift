import AppKit
import RenJistrolyModels

// @unchecked Sendable: AXUIElement is only used within the ElementRegistry actor
// and passed to callers that must use it on the main thread (AppKit requirement).
extension AXUIElement: @unchecked @retroactive Sendable {}

public actor ElementRegistry {
    public static let shared = ElementRegistry()

    private var elements: [String: AXUIElement] = [:]
    private var metadata: [String: ComputerUseElement] = [:]
    private var capturedAt: Date?
    private var appBundleID: String?
    private var appName: String?
    private let ttl: TimeInterval

    public init(ttl: TimeInterval = 30) {
        self.ttl = ttl
    }

    public func replace(
        elements newElements: [(ComputerUseElement, AXUIElement)],
        appBundleID: String?,
        appName: String?
    ) {
        var resolvedElements: [String: AXUIElement] = [:]
        var resolvedMetadata: [String: ComputerUseElement] = [:]
        for (metadata, element) in newElements {
            resolvedElements[metadata.elementIndex] = element
            resolvedMetadata[metadata.elementIndex] = metadata
            resolvedElements[metadata.stableID] = element
            resolvedMetadata[metadata.stableID] = metadata
        }
        elements = resolvedElements
        metadata = resolvedMetadata
        capturedAt = Date()
        self.appBundleID = appBundleID
        self.appName = appName
    }

    public func element(for index: String, expectedApp: String? = nil) throws -> AXUIElement {
        guard let capturedAt, Date().timeIntervalSince(capturedAt) <= ttl else {
            throw ElementRegistryError.snapshotExpired
        }
        if let expectedApp, !expectedApp.isEmpty {
            let matchesBundle = appBundleID?.localizedCaseInsensitiveContains(expectedApp) == true
            let matchesName = appName?.localizedCaseInsensitiveContains(expectedApp) == true
            guard matchesBundle || matchesName else {
                throw ElementRegistryError.appMismatch(expected: expectedApp, actual: appName ?? appBundleID ?? "unknown")
            }
        }
        guard let element = elements[index] else {
            throw ElementRegistryError.elementNotFound(index)
        }
        return element
    }

    public func metadata(for index: String) -> ComputerUseElement? {
        metadata[index]
    }

    public func clear() {
        elements.removeAll()
        metadata.removeAll()
        capturedAt = nil
        appBundleID = nil
        appName = nil
    }
}

public enum ElementRegistryError: LocalizedError, Sendable {
    case snapshotExpired
    case elementNotFound(String)
    case appMismatch(expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case .snapshotExpired:
            return "UI 快照已过期，请先重新 observe/get_app_state"
        case .elementNotFound(let index):
            return "找不到 UI 元素: \(index)"
        case .appMismatch(let expected, let actual):
            return "UI 快照属于 \(actual)，不是请求的 \(expected)"
        }
    }
}
