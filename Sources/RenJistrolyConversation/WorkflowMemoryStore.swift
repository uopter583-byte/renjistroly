import Foundation
import OSLog
import RenJistrolyModels

public actor WorkflowMemoryStore {
    public struct RecoveryStrategyScore: Codable, Sendable, Hashable {
        public let attempts: Int
        public let successes: Int

        public init(attempts: Int, successes: Int) {
            self.attempts = attempts
            self.successes = successes
        }

        public var successRate: Double {
            guard attempts > 0 else { return 0 }
            return Double(successes) / Double(attempts)
        }
    }

    public struct RecoveryStrategyProfile: Codable, Sendable, Hashable {
        public let scores: [String: RecoveryStrategyScore]
        public let scope: String

        public init(scores: [String: RecoveryStrategyScore], scope: String) {
            self.scores = scores
            self.scope = scope
        }

        public var successRates: [String: Double] {
            scores.mapValues(\.successRate)
        }
    }

    private var memories: [TaskMemory] = []
    private var invertedIndex: [String: Set<UUID>] = [:]
    private var tfIndex: [UUID: [String: Double]] = [:]
    private var idfScores: [String: Double] = [:]
    private let storageURL: URL?

    public init(storageURL: URL? = WorkflowMemoryStore.defaultStorageURL()) {
        self.storageURL = storageURL
        let loaded = Self.loadMemories(from: storageURL)
        self.memories = loaded
        // Build inverted index synchronously in init
        var idx: [String: Set<UUID>] = [:]
        var tf: [UUID: [String: Double]] = [:]
        var idf: [String: Double] = [:]
        for memory in loaded {
            let allText = [memory.task] + memory.steps + [memory.learnedWorkflow].compactMap { $0 }
            var termFreq: [String: Double] = [:]
            var totalTerms = 0
            for text in allText {
                for token in Self.tokenizeStatic(text) {
                    termFreq[token, default: 0] += 1
                    totalTerms += 1
                    idx[token, default: []].insert(memory.id)
                }
            }
            guard totalTerms > 0 else { continue }
            var normalized: [String: Double] = [:]
            for (term, freq) in termFreq {
                normalized[term] = freq / Double(totalTerms)
            }
            tf[memory.id] = normalized
        }
        let docCount = Double(max(loaded.count, 1))
        for term in idx.keys {
            idf[term] = log(docCount / Double(idx[term]?.count ?? 1))
        }
        self.invertedIndex = idx
        self.tfIndex = tf
        self.idfScores = idf
    }

    @discardableResult
    public func remember(
        task: String,
        steps: [String],
        success: Bool,
        failureReason: String? = nil,
        failureCategory: FailureCategory? = nil,
        learnedWorkflow: String? = nil,
        domain: String? = nil,
        appName: String? = nil,
        projectPath: String? = nil,
        tags: [String] = []
    ) -> TaskMemory {
        let memory = TaskMemory(
            task: task,
            steps: steps,
            success: success,
            failureReason: failureReason,
            failureCategory: failureCategory,
            learnedWorkflow: learnedWorkflow,
            domain: domain,
            appName: appName,
            projectPath: projectPath,
            tags: tags
        )
        memories.append(memory)
        indexMemory(memory)
        saveMemories()
        return memory
    }

    public func recall(matching query: String, limit: Int = 5, context: MemoryContext = .init()) -> [TaskMemory] {
        guard !memories.isEmpty else { return [] }
        let queryTokens = tokenize(query)
        guard !queryTokens.isEmpty else { return [] }

        let now = Date()
        let halfLife: TimeInterval = context.relevanceHalfLife

        var scores: [(UUID, Double)] = []
        for memory in memories {
            var score = tfidfScore(queryTokens: queryTokens, memory: memory)

            // Recency decay
            let age = now.timeIntervalSince(memory.createdAt)
            if age > 0 {
                let decay = pow(0.5, age / halfLife)
                score *= decay
            }

            if memory.success { score *= 1.2 }
            if memory.learnedWorkflow != nil { score *= 1.3 }

            // Project context keyword boost
            if let projectKeywords = context.projectKeywords {
                let keywordTokens = projectKeywords.flatMap { tokenize($0) }
                let overlap = queryTokens.filter { keywordTokens.contains($0) }.count
                score *= 1.0 + Double(overlap) * 0.15
            }

            // Domain filter — use enriched domain field
            if let domain = context.domain, !domain.isEmpty {
                let domainLower = domain.lowercased()
                if memory.domain?.lowercased() == domainLower
                    || memory.task.lowercased().contains(domainLower)
                    || memory.steps.contains(where: { $0.lowercased().contains(domainLower) }) {
                    score *= 1.5
                }
            }

            // App context boost
            if let appName = memory.appName, query.lowercased().contains(appName.lowercased()) {
                score *= 1.3
            }

            // Failure pattern penalty: if we've seen this failure before, boost for awareness
            if !memory.success, let fp = memory.failurePattern {
                let similarFailures = memories.filter {
                    !$0.success && $0.failurePattern == fp
                }.count
                if similarFailures > 1 {
                    score *= 1.0 + Double(min(similarFailures, 5)) * 0.1
                }
            }

            if score > 0.02 {
                scores.append((memory.id, score))
            }
        }

        let topIDs = scores
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)

        if !topIDs.isEmpty {
            return topIDs.compactMap { id in memories.first { $0.id == id } }
        }

        let normalized = query.lowercased()
        return memories
            .filter { memory in
                memory.task.lowercased().contains(normalized)
                    || memory.steps.contains { $0.lowercased().contains(normalized) }
                    || (memory.learnedWorkflow?.lowercased().contains(normalized) == true)
            }
            .suffix(limit)
            .reversed()
    }

    public func extractPatterns(minSuccessRate: Double = 0.7) -> [MemoryPattern] {
        var patterns: [MemoryPattern] = []

        // Extract tool sequences from successful memories
        let successful = memories.filter { $0.success }
        guard successful.count >= 2 else { return [] }

        // Extract common step patterns
        var stepPatterns: [String: (count: Int, successes: Int)] = [:]
        for memory in memories {
            let toolSteps = memory.steps.filter { $0.contains("tool:") || $0.contains("strategy:") }
            for step in toolSteps {
                var entry = stepPatterns[step, default: (0, 0)]
                entry.count += 1
                if memory.success { entry.successes += 1 }
                stepPatterns[step] = entry
            }
        }

        for (step, stats) in stepPatterns {
            let rate = Double(stats.successes) / Double(max(stats.count, 1))
            if rate >= minSuccessRate, stats.count >= 2 {
                patterns.append(MemoryPattern(
                    pattern: step,
                    sourceTaskCount: stats.count,
                    successRate: rate,
                    kind: .stepPattern
                ))
            }
        }

        // Extract workflow patterns (sequences of 2+ consecutive successful steps)
        let successfulWorkflows = successful.filter { $0.steps.count >= 2 }
        if successfulWorkflows.count >= 2 {
            var sequencePairs: [String: (count: Int, successes: Int)] = [:]
            for memory in successfulWorkflows {
                for i in 0..<(memory.steps.count - 1) {
                    let pair = "\(memory.steps[i]) → \(memory.steps[i + 1])"
                    var entry = sequencePairs[pair, default: (0, 0)]
                    entry.count += 1
                    entry.successes += 1
                    sequencePairs[pair] = entry
                }
            }
            for (pair, stats) in sequencePairs where stats.count >= 2 {
                patterns.append(MemoryPattern(
                    pattern: pair,
                    sourceTaskCount: stats.count,
                    successRate: Double(stats.successes) / Double(max(stats.count, 1)),
                    kind: .workflowSequence
                ))
            }
        }

        // Extract learned workflows as patterns
        for memory in successful where memory.learnedWorkflow != nil {
            patterns.append(MemoryPattern(
                pattern: memory.learnedWorkflow ?? memory.task,
                sourceTaskCount: 1,
                successRate: 1.0,
                kind: .learnedWorkflow
            ))
        }

        return patterns.sorted { $0.successRate > $1.successRate }
    }

    public func consolidatedContext(limit: Int = 8) -> String {
        let top = memories.suffix(limit).reversed()
        return top.enumerated().map { idx, memory in
            let status = memory.success ? "[成功]" : "[失败]"
            let workflow = memory.learnedWorkflow.map { " → 流程: \($0)" } ?? ""
            let app = memory.appName.map { " @\($0)" } ?? ""
            let failure = memory.failurePattern.map { " [\($0)]" } ?? ""
            return "\(idx + 1). \(status)\(app) \(memory.task)\(workflow)\(failure)"
        }.joined(separator: "\n")
    }

    public func recentFailurePatterns(limit: Int = 5) -> [String] {
        let failures = memories.filter { !$0.success && $0.failurePattern != nil }
        let patterns = Dictionary(grouping: failures, by: \.failurePattern)
        return patterns
            .sorted { $0.value.count > $1.value.count }
            .prefix(limit)
            .map { "\($0.key ?? "未知") (×\($0.value.count))" }
    }

    public struct MemoryContext: Sendable {
        public var projectKeywords: [String]?
        public var domain: String?
        public var relevanceHalfLife: TimeInterval

        public init(
            projectKeywords: [String]? = nil,
            domain: String? = nil,
            relevanceHalfLife: TimeInterval = 86_400 * 7
        ) {
            self.projectKeywords = projectKeywords
            self.domain = domain
            self.relevanceHalfLife = relevanceHalfLife
        }
    }

    public func all() -> [TaskMemory] { memories }

    public func recoveryStrategyScores() -> [String: RecoveryStrategyScore] {
        recoveryStrategyScores(appName: nil, toolName: nil)
    }

    public func recoveryStrategyScores(appName: String?, toolName: String?) -> [String: RecoveryStrategyScore] {
        var totals: [String: (attempts: Int, successes: Int)] = [:]

        for memory in memories {
            if let appName, Self.appToken(in: memory.steps)?.caseInsensitiveCompare(appName) != .orderedSame {
                continue
            }
            if let toolName, Self.toolToken(in: memory.steps)?.caseInsensitiveCompare(toolName) != .orderedSame {
                continue
            }
            let strategies = Set(memory.steps.compactMap(Self.recoveryStrategyToken(from:)))
            for strategy in strategies {
                var current = totals[strategy, default: (0, 0)]
                current.attempts += 1
                if memory.success { current.successes += 1 }
                totals[strategy] = current
            }
        }

        return totals.mapValues { RecoveryStrategyScore(attempts: $0.attempts, successes: $0.successes) }
    }

    public func bestRecoveryStrategyProfile(appName: String?, toolName: String?) -> RecoveryStrategyProfile {
        let scopes: [(String, String?, String?)] = [
            ("app+tool", appName, toolName),
            ("app", appName, nil),
            ("tool", nil, toolName),
            ("global", nil, nil),
        ]

        for (scope, scopedApp, scopedTool) in scopes {
            let scores = recoveryStrategyScores(appName: scopedApp, toolName: scopedTool)
            if !scores.isEmpty {
                return RecoveryStrategyProfile(scores: scores, scope: scope)
            }
        }

        return RecoveryStrategyProfile(scores: [:], scope: "global")
    }

    public static func defaultStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport
            .appendingPathComponent("RenJistroly")
            .appendingPathComponent("workflow-memories.json")
    }

    // MARK: - TF-IDF Index

    private static func tokenizeStatic(_ text: String) -> [String] {
        let cleaned = text.lowercased()
            .replacingOccurrences(of: #"[^\p{Unified_Ideograph}\w]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        var tokens: [String] = []
        var i = cleaned.startIndex
        var pendingAlpha = ""
        while i < cleaned.endIndex {
            let char = cleaned[i]
            if char.isASCII && (char.isLetter || char.isNumber) {
                pendingAlpha.append(char)
            } else {
                if !pendingAlpha.isEmpty {
                    tokens.append(pendingAlpha)
                    pendingAlpha = ""
                }
                if let scalar = char.unicodeScalars.first,
                   scalar.properties.isUnifiedIdeograph {
                    if let prev = tokens.last,
                       prev.unicodeScalars.first?.properties.isUnifiedIdeograph == true {
                        tokens[tokens.count - 1] = prev + String(char)
                    } else {
                        tokens.append(String(char))
                    }
                } else if char != " " {
                    tokens.append(String(char))
                }
            }
            i = cleaned.index(after: i)
        }
        if !pendingAlpha.isEmpty { tokens.append(pendingAlpha) }
        return tokens.filter { $0.count <= 20 }
    }

    private func tokenize(_ text: String) -> [String] {
        Self.tokenizeStatic(text)
    }

    private func indexMemory(_ memory: TaskMemory) {
        let allText = [memory.searchableText]
        var termFreq: [String: Double] = [:]
        var totalTerms = 0

        for text in allText {
            let tokens = tokenize(text)
            for token in tokens {
                termFreq[token, default: 0] += 1
                totalTerms += 1
                invertedIndex[token, default: []].insert(memory.id)
            }
        }

        guard totalTerms > 0 else { return }
        for (term, freq) in termFreq {
            termFreq[term] = freq / Double(totalTerms)
        }
        tfIndex[memory.id] = termFreq

        // Update IDF
        let docCount = Double(memories.count)
        for term in termFreq.keys {
            let docFreq = Double(invertedIndex[term]?.count ?? 1)
            idfScores[term] = log(docCount / docFreq)
        }
    }

    private func tfidfScore(queryTokens: [String], memory: TaskMemory) -> Double {
        guard let tf = tfIndex[memory.id] else { return 0 }
        var score: Double = 0
        for token in queryTokens {
            let tfVal = tf[token] ?? 0
            let idfVal = idfScores[token] ?? 0
            score += tfVal * idfVal
        }
        return score
    }

    private func rebuildIndex() {
        invertedIndex.removeAll()
        tfIndex.removeAll()
        idfScores.removeAll()
        for memory in memories {
            indexMemory(memory)
        }
    }

    private func saveMemories() {
        guard let storageURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(memories)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            #if DEBUG
            Logger.memory.error("保存工作流记忆失败: \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }

    private static func loadMemories(from storageURL: URL?) -> [TaskMemory] {
        guard let storageURL,
              let data = try? Data(contentsOf: storageURL),
              let saved = try? JSONDecoder().decode([TaskMemory].self, from: data) else {
            return []
        }
        return saved
    }

    private static func recoveryStrategyToken(from step: String) -> String? {
        tokenValue(from: step, prefix: "strategy:")
    }

    private static func appToken(in steps: [String]) -> String? {
        steps.compactMap { tokenValue(from: $0, prefix: "app:") }.first
    }

    private static func toolToken(in steps: [String]) -> String? {
        steps.compactMap { tokenValue(from: $0, prefix: "tool:") }.first
    }

    private static func tokenValue(from step: String, prefix: String) -> String? {
        guard step.hasPrefix(prefix) else { return nil }
        let value = step.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }
}
