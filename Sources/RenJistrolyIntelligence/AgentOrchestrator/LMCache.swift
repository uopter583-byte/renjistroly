import Foundation
import RenJistrolyModels

/// Tiered KV cache for LLM inference (LMCache pattern):
/// Tier 1 (hot, GPU): in-memory LRU cache of recent responses
/// Tier 2 (warm, RAM): in-memory cache with larger capacity
/// Tier 3 (cold, SSD): on-disk cache of embeddings and responses
/// Tier 4 (miss, cloud): API call
public actor LMCache {
    private let tier1: MemoryTier
    private let tier2: MemoryTier
    private let tier3: DiskTier

    public struct Config: Sendable {
        public var tier1MaxEntries: Int
        public var tier2MaxEntries: Int
        public var tier3MaxSizeMB: Int
        public var ttlSeconds: TimeInterval

        public init(tier1MaxEntries: Int = 50, tier2MaxEntries: Int = 500, tier3MaxSizeMB: Int = 100, ttlSeconds: TimeInterval = 3600) {
            self.tier1MaxEntries = tier1MaxEntries
            self.tier2MaxEntries = tier2MaxEntries
            self.tier3MaxSizeMB = tier3MaxSizeMB
            self.ttlSeconds = ttlSeconds
        }

        public static let `default` = Config()
    }

    public init(config: Config = .default) {
        self.tier1 = MemoryTier(maxEntries: config.tier1MaxEntries, ttlSeconds: config.ttlSeconds)
        self.tier2 = MemoryTier(maxEntries: config.tier2MaxEntries, ttlSeconds: config.ttlSeconds * 3)
        self.tier3 = DiskTier(maxSizeMB: config.tier3MaxSizeMB, ttlSeconds: config.ttlSeconds * 24)
    }

    // MARK: - Get / Set

    public func get(key: String) async -> CachedResponse? {
        if let entry = await tier1.get(key) {
            await tier1.touch(key) // Promote to front of LRU
            return entry
        }
        if let entry = await tier2.get(key) {
            // Promote: tier2 -> tier1
            await tier1.set(key, value: entry)
            await tier2.remove(key)
            return entry
        }
        if let entry = await tier3.get(key) {
            await tier1.set(key, value: entry)
            return entry
        }
        return nil
    }

    public func set(key: String, value: CachedResponse) async {
        await tier1.set(key, value: value)
        await tier2.set(key, value: value)
        await tier3.set(key, value: value)
    }

    public func warmTier1(key: String, value: CachedResponse) async {
        await tier1.set(key, value: value)
    }

    public func invalidate(key: String) async {
        await tier1.remove(key)
        await tier2.remove(key)
        await tier3.remove(key)
    }

    public func prune() async {
        await tier1.prune()
        await tier2.prune()
        await tier3.prune()
    }

    // MARK: - Stats

    public var tierStats: String {
        get async {
            """
            Tier1 (GPU): \(await tier1.count) entries
            Tier2 (RAM): \(await tier2.count) entries
            Tier3 (SSD): \(await tier3.approximateSizeMB) MB
            """
        }
    }

    public func cacheKey(messages: [Message], config: LLMConfiguration) -> String {
        let content = messages.map { "\($0.role):\($0.textContent.prefix(200))" }.joined(separator: "|")
        return "\(config.provider.rawValue):\(config.model):\(content.hashValue)"
    }
}

// MARK: - Tier implementations

private actor MemoryTier {
    private var entries: [String: CacheEntry] = [:]
    private var lru: [String] = []
    private let maxEntries: Int
    private let ttlSeconds: TimeInterval

    init(maxEntries: Int, ttlSeconds: TimeInterval) {
        self.maxEntries = maxEntries
        self.ttlSeconds = ttlSeconds
    }

    func get(_ key: String) -> CachedResponse? {
        guard let entry = entries[key] else { return nil }
        if Date().timeIntervalSince(entry.createdAt) > ttlSeconds {
            entries.removeValue(forKey: key)
            lru.removeAll { $0 == key }
            return nil
        }
        return entry.response
    }

    func set(_ key: String, value: CachedResponse) {
        entries[key] = CacheEntry(response: value, createdAt: Date())
        lru.removeAll { $0 == key }
        lru.append(key)
        evictIfNeeded()
    }

    func touch(_ key: String) {
        lru.removeAll { $0 == key }
        lru.append(key)
    }

    func remove(_ key: String) {
        entries.removeValue(forKey: key)
        lru.removeAll { $0 == key }
    }

    func prune() {
        let now = Date()
        entries = entries.filter { now.timeIntervalSince($0.value.createdAt) <= ttlSeconds }
        lru = lru.filter { entries[$0] != nil }
    }

    var count: Int { entries.count }

    private func evictIfNeeded() {
        while lru.count > maxEntries, let oldest = lru.first {
            entries.removeValue(forKey: oldest)
            lru.removeFirst()
        }
    }
}

private actor DiskTier {
    private let cacheDir: URL
    private let maxSizeBytes: Int
    private let ttlSeconds: TimeInterval

    init(maxSizeMB: Int, ttlSeconds: TimeInterval) {
        self.cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent("lmcache-disk")
        self.maxSizeBytes = maxSizeMB * 1024 * 1024
        self.ttlSeconds = ttlSeconds
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func get(_ key: String) -> CachedResponse? {
        let file = cacheDir.appendingPathComponent(sanitizedKey(key) + ".json")
        guard FileManager.default.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file),
              let entry = try? JSONDecoder().decode(DiskEntry.self, from: data)
        else { return nil }
        if Date().timeIntervalSince(entry.createdAt) > ttlSeconds {
            try? FileManager.default.removeItem(at: file)
            return nil
        }
        return entry.response
    }

    func set(_ key: String, value: CachedResponse) {
        let file = cacheDir.appendingPathComponent(sanitizedKey(key) + ".json")
        let entry = DiskEntry(response: value, createdAt: Date())
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: file, options: .atomic)
        prune()
    }

    func remove(_ key: String) {
        let file = cacheDir.appendingPathComponent(sanitizedKey(key) + ".json")
        try? FileManager.default.removeItem(at: file)
    }

    func prune() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }
        let now = Date()
        var totalSize = 0
        var expiredFiles: [URL] = []

        for file in files {
            let attrs = (try? FileManager.default.attributesOfItem(atPath: file.path)) ?? [:]
            let size = (attrs[.size] as? Int) ?? 0
            totalSize += size
            if let modDate = attrs[.modificationDate] as? Date, now.timeIntervalSince(modDate) > ttlSeconds {
                expiredFiles.append(file)
            }
        }

        for file in expiredFiles {
            try? FileManager.default.removeItem(at: file)
        }

        // Evict by size (oldest first) if over limit
        if totalSize > maxSizeBytes {
            let sorted = files.sorted { f1, f2 in
                let d1 = ((try? FileManager.default.attributesOfItem(atPath: f1.path))?[.modificationDate] as? Date) ?? Date()
                let d2 = ((try? FileManager.default.attributesOfItem(atPath: f2.path))?[.modificationDate] as? Date) ?? Date()
                return d1 < d2
            }
            for file in sorted {
                guard totalSize > maxSizeBytes / 2 else { break }
                let fileAttrs = (try? FileManager.default.attributesOfItem(atPath: file.path)) ?? [:]
                totalSize -= fileAttrs[.size] as? Int ?? 0
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    var approximateSizeMB: Int {
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        let total = files.reduce(0) { sum, file in
            let attrs = (try? FileManager.default.attributesOfItem(atPath: file.path)) ?? [:]
            let size = attrs[.size] as? Int ?? 0
            return sum + size
        }
        return total / (1024 * 1024)
    }

    private func sanitizedKey(_ key: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return key.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
    }
}

// MARK: - Types

public struct CachedResponse: Codable, Sendable {
    public let text: String
    public let provider: String
    public let model: String
    public let totalTokens: Int

    public init(text: String, provider: String, model: String, totalTokens: Int = 0) {
        self.text = text
        self.provider = provider
        self.model = model
        self.totalTokens = totalTokens
    }
}

private struct CacheEntry: Sendable {
    let response: CachedResponse
    let createdAt: Date
}

private struct DiskEntry: Codable {
    let response: CachedResponse
    let createdAt: Date
}
