import AppKit
import Foundation
import RenJistrolyModels

public enum AppDriverCapability: String, Sendable, Hashable, CaseIterable {
    case open
    case search
    case read
    case write
    case runCommand
    case manageWindows
    case requiresConfirmationBeforeSend
}

public protocol AppDriver: Sendable {
    var id: String { get }
    var displayName: String { get }
    var capabilities: Set<AppDriverCapability> { get }
}

public struct FileInfo: Sendable, Hashable {
    public let path: String
    public let name: String
    public let size: Int64
    public let modifiedAt: Date?

    public init(path: String, name: String, size: Int64, modifiedAt: Date?) {
        self.path = path
        self.name = name
        self.size = size
        self.modifiedAt = modifiedAt
    }
}

// Shared by SafariDriver and ChromeDriver
public struct ConsoleLogEntry: Codable, Sendable {
    public let level: String
    public let message: String
    public let ts: Double
}

public struct NetworkRequestEntry: Codable, Sendable {
    public let method: String
    public let url: String
    public let statusCode: Int
    public let duration: Int?
    public let ts: Double
    public let error: String?

    public init(method: String, url: String, statusCode: Int, duration: Int?, ts: Double, error: String? = nil) {
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.duration = duration
        self.ts = ts
        self.error = error
    }
}

// Registry for all drivers
public struct AppDriverRegistry: Sendable {
    public let drivers: [any AppDriver]

    public init(drivers: [any AppDriver] = [
        FinderDriver(),
        SafariDriver(),
        ChromeDriver(),
        TerminalDriver(),
        XcodeDriver(),
        SystemSettingsDriver(),
        WeChatDriver(),
        SystemDriver(),
    ]) {
        self.drivers = drivers
    }

    public func driver(id: String) -> (any AppDriver)? {
        drivers.first { $0.id == id }
    }
}

// MARK: - Shared Helpers

func normalizedHost(from rawURL: String?) -> String? {
    guard let rawURL,
          let url = URL(string: rawURL),
          let host = url.host?.replacingOccurrences(of: "www.", with: ""),
          !host.isEmpty else {
        return nil
    }
    return host
}

func extractedSearchQuery(from rawURL: String?) -> String? {
    guard let rawURL,
          let components = URLComponents(string: rawURL),
          let item = components.queryItems?.first(where: { ["q", "query", "text", "p"].contains($0.name.lowercased()) }),
          let value = item.value?.removingPercentEncoding ?? item.value,
          !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
    }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension String {
    var nonEmptyValue: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
