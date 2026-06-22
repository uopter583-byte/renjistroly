import Foundation

public actor ContextStore {
    private let fileURL: URL
    private let maxRecentExchanges = 3
    private var cachedEntries: [ContextEntry]?

    public struct ContextEntry: Codable, Sendable {
        public let role: String
        public let content: String
        public let time: Date

        public init(role: String, content: String, time: Date = Date()) {
            self.role = role
            self.content = content
            self.time = time
        }
    }

    public init(fileName: String = "conversation_context.json") {
        let dir = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("RenJistroly")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent(fileName)
    }

    public func append(_ entry: ContextEntry) {
        var entries = load()
        entries.append(entry)
        save(entries)
    }

    public func appendExchange(user: String, assistant: String) {
        var entries = load()
        entries.append(ContextEntry(role: "user", content: user))
        entries.append(ContextEntry(role: "assistant", content: assistant))
        save(entries)
    }

    /// Only the last few exchanges for sending in each request — saves tokens.
    public func recentContext() -> [ContextEntry] {
        let entries = load()
        let maxEntries = maxRecentExchanges * 2
        return Array(entries.suffix(maxEntries))
    }

    /// Full history for display/search purposes.
    public func allEntries() -> [ContextEntry] {
        load()
    }

    public func clear() {
        cachedEntries = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    public var entryCount: Int { load().count }

    public var exchangeCount: Int { load().count / 2 }

    // MARK: - Private

    private func load() -> [ContextEntry] {
        if let cached = cachedEntries { return cached }
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([ContextEntry].self, from: data)
        else { return [] }
        cachedEntries = entries
        return entries
    }

    private func save(_ entries: [ContextEntry]) {
        cachedEntries = entries
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
