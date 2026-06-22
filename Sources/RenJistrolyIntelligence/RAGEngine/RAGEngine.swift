import Foundation
import RenJistrolyModels

public actor RAGEngine {
    private var documentStore: [UUID: RAGDocument] = [:]
    private var index: [String: [UUID]] = [:] // Simple keyword index

    public init() {}

    public func indexProject(at path: String) async throws {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: path)

        while let file = enumerator?.nextObject() as? String {
            let fullPath = "\(path)/\(file)"
            guard fileManager.isReadableFile(atPath: fullPath) else { continue }
            guard isIndexableFile(fullPath) else { continue }

            guard let content = try? await Task.detached(operation: {
                try String(contentsOfFile: fullPath, encoding: .utf8)
            }).value else { continue }

            let docID = UUID()
            let document = RAGDocument(
                id: docID,
                path: fullPath,
                relativePath: file,
                content: content.prefix(5000).description,
                metadata: [
                    "extension": URL(fileURLWithPath: fullPath).pathExtension,
                    "size": String(content.count),
                ]
            )

            documentStore[docID] = document
            indexKeywords(document: document)
        }
    }

    public func search(_ query: String, topK: Int = 5) async -> [RAGSearchResult] {
        let keywords = tokenize(query)
        var scores: [UUID: Double] = [:]

        for keyword in keywords {
            guard let hits = index[keyword] else { continue }
            let idf = log(Double(documentStore.count) / Double(hits.count) + 0.5)
            for docID in hits {
                scores[docID, default: 0] += 1.0 * idf
            }
        }

        let topDocs = scores
            .sorted { $0.value > $1.value }
            .prefix(topK)
            .compactMap { pair -> RAGSearchResult? in
                guard let doc = documentStore[pair.key] else { return nil }
                let snippet = findRelevantSnippet(in: doc.content, keywords: keywords)
                return RAGSearchResult(
                    documentID: doc.id,
                    path: doc.relativePath,
                    score: pair.value,
                    snippet: snippet
                )
            }

        return topDocs
    }

    public func buildContext(_ query: String, topK: Int = 3) async -> String {
        let results = await search(query, topK: topK)
        guard !results.isEmpty else { return "" }

        var context = "## 相关代码文件\n\n"
        for result in results {
            context += "### \(result.path)\n"
            context += "```\n\(result.snippet)\n```\n\n"
        }
        return context
    }

    public func clear() {
        documentStore.removeAll()
        index.removeAll()
    }

    // MARK: - Private

    private func indexKeywords(document: RAGDocument) {
        let keywords = tokenize(document.content)
        for keyword in Set(keywords) {
            index[keyword, default: []].append(document.id)
        }
    }

    func tokenize(_ text: String) -> [String] {
        guard let pattern = try? NSRegularExpression(pattern: "[^a-z0-9\u{4e00}-\u{9fff}_]") else { return [] }
        let cleaned = pattern.stringByReplacingMatches(
            in: text.lowercased(),
            range: NSRange(text.startIndex..., in: text),
            withTemplate: " "
        )
        return cleaned
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 1 }
    }

    func findRelevantSnippet(in content: String, keywords: [String], snippetLines: Int = 5) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var bestStart = 0
        var bestScore = 0

        for i in 0..<lines.count {
            let lineText = lines[i].lowercased()
            var score = 0
            for kw in keywords {
                if lineText.contains(kw) { score += 1 }
            }
            if score > bestScore {
                bestScore = score
                bestStart = i
            }
        }

        let start = max(0, bestStart - snippetLines / 2)
        let end = min(lines.count, start + snippetLines)
        return lines[start..<end].joined(separator: "\n")
    }

    func isIndexableFile(_ path: String) -> Bool {
        let indexableExtensions: Set<String> = [
            "swift", "m", "h", "c", "cpp", "hpp",
            "py", "js", "ts", "jsx", "tsx",
            "rs", "go", "java", "kt", "scala",
            "rb", "php", "json", "yaml", "yml",
            "toml", "md", "txt", "csv",
            "html", "css", "scss",
            "sh", "bash", "zsh",
            "sql", "graphql", "gql",
        ]
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        let maxSize = 1024 * 1024 // 1MB
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
            if let size = attrs[.size] as? Int, size > maxSize { return false }
        }
        return indexableExtensions.contains(ext)
    }
}

struct RAGDocument: Sendable, Hashable {
    let id: UUID
    let path: String
    let relativePath: String
    let content: String
    let metadata: [String: String]

    init(id: UUID, path: String, relativePath: String, content: String, metadata: [String: String]) {
        self.id = id
        self.path = path
        self.relativePath = relativePath
        self.content = content
        self.metadata = metadata
    }
}

public struct RAGSearchResult: Sendable, Hashable {
    public let documentID: UUID
    public let path: String
    public let score: Double
    public let snippet: String

    public init(documentID: UUID, path: String, score: Double, snippet: String) {
        self.documentID = documentID
        self.path = path
        self.score = score
        self.snippet = snippet
    }
}
