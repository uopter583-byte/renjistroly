import Foundation

/// SKILL.md-based skill registry (mattpocock/skills pattern).
/// Each skill is a directory with a SKILL.md file and optional plugin.json manifest.
public actor SkillRegistry {
    private var skills: [String: LoadedSkill] = [:]
    private let fileManager = FileManager.default

    public init() {}

    // MARK: - Load

    public func load(from directory: String) throws {
        let dir = URL(fileURLWithPath: directory)
        guard let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            throw SkillError.directoryNotFound(directory)
        }
        for item in contents where item.hasDirectoryPath {
            let skillFile = item.appendingPathComponent("SKILL.md")
            guard fileManager.fileExists(atPath: skillFile.path) else { continue }
            let manifestFile = item.appendingPathComponent("plugin.json")
            let manifest: SkillManifest? = (try? Data(contentsOf: manifestFile)).flatMap {
                try? JSONDecoder().decode(SkillManifest.self, from: $0)
            }
            let content = try String(contentsOf: skillFile, encoding: .utf8)
            let parsed = try parseSkillMD(content)
            let skill = LoadedSkill(
                id: item.lastPathComponent,
                path: item.path,
                manifest: manifest,
                markdown: content,
                metadata: parsed.metadata,
                body: parsed.body
            )
            skills[skill.id] = skill
        }
    }

    public func loadSingleSkill(at path: String) throws -> LoadedSkill {
        let dir = URL(fileURLWithPath: path)
        let skillFile = dir.appendingPathComponent("SKILL.md")
        guard fileManager.fileExists(atPath: skillFile.path) else {
            throw SkillError.skillFileNotFound(path)
        }
        let manifestFile = dir.appendingPathComponent("plugin.json")
        let manifest: SkillManifest? = (try? Data(contentsOf: manifestFile)).flatMap {
            try? JSONDecoder().decode(SkillManifest.self, from: $0)
        }
        let content = try String(contentsOf: skillFile, encoding: .utf8)
        let parsed = try parseSkillMD(content)
        let skill = LoadedSkill(
            id: dir.lastPathComponent,
            path: dir.path,
            manifest: manifest,
            markdown: content,
            metadata: parsed.metadata,
            body: parsed.body
        )
        skills[skill.id] = skill
        return skill
    }

    // MARK: - Query

    public func skill(id: String) -> LoadedSkill? { skills[id] }

    public func allSkills() -> [LoadedSkill] { Array(skills.values) }

    public func findSkills(matching query: String) -> [LoadedSkill] {
        let q = query.lowercased()
        return skills.values.filter { skill in
            skill.id.lowercased().contains(q) ||
            skill.metadata.title?.lowercased().contains(q) == true ||
            (skill.metadata.tags?.contains { $0.lowercased().contains(q) } == true)
        }
    }

    public func skillsByCategory(_ category: String) -> [LoadedSkill] {
        skills.values.filter { $0.metadata.category?.lowercased() == category.lowercased() }
    }

    public func skillSystemPrompt() -> String {
        skills.values.map { skill in
            var parts: [String] = []
            if let title = skill.metadata.title { parts.append("## \(title)") }
            if let desc = skill.metadata.description { parts.append(desc) }
            parts.append(skill.body)
            return parts.joined(separator: "\n")
        }.joined(separator: "\n\n---\n\n")
    }

    public func skillDirectoryIndex() -> String {
        skills.values.compactMap { skill -> String? in
            guard let title = skill.metadata.title else { return nil }
            let tags = (skill.metadata.tags ?? []).joined(separator: ", ")
            return "- **\(title)** (`\(skill.id)`)" + (tags.isEmpty ? "" : " — \(tags)")
        }.joined(separator: "\n")
    }

    // MARK: - Parse SKILL.md

    public struct ParsedSkill: Sendable {
        public let metadata: SkillMetadata
        public let body: String
    }

    public func parseSkillMD(_ content: String) throws -> ParsedSkill {
        var metadata: SkillMetadata = SkillMetadata()
        var body = content

        // Extract YAML frontmatter
        if content.hasPrefix("---") {
            let remainder = String(content.dropFirst(3))
            if let endRange = remainder.range(of: "\n---") {
                let yaml = String(remainder[..<endRange.lowerBound])
                body = String(remainder[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                metadata = try parseFrontmatter(yaml)
            }
        }

        // Fallback: extract from markdown headers
        if metadata.title == nil {
            metadata.title = extractHeader(content, pattern: "# ")
        }
        if metadata.description == nil {
            metadata.description = extractHeader(content, pattern: "> ")
        }

        return ParsedSkill(metadata: metadata, body: body)
    }

    private func parseFrontmatter(_ yaml: String) throws -> SkillMetadata {
        var metadata = SkillMetadata()
        var currentTags: [String] = []
        for line in yaml.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("name:") || trimmed.hasPrefix("title:") {
                metadata.title = extractYAMLValue(trimmed)
            } else if trimmed.hasPrefix("description:") {
                metadata.description = extractYAMLValue(trimmed)
            } else if trimmed.hasPrefix("category:") {
                metadata.category = extractYAMLValue(trimmed)
            } else if trimmed.hasPrefix("version:") {
                metadata.version = extractYAMLValue(trimmed)
            } else if trimmed.hasPrefix("author:") {
                metadata.author = extractYAMLValue(trimmed)
            } else if trimmed.hasPrefix("- ") && currentTags.isEmpty == false || trimmed.hasPrefix("tags:") {
                if trimmed.hasPrefix("tags:") {
                    let tagStr = extractYAMLValue(trimmed)
                    currentTags = tagStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
            }
        }
        if !currentTags.isEmpty { metadata.tags = currentTags }
        return metadata
    }

    private func extractYAMLValue(_ line: String) -> String {
        guard let colonIndex = line.firstIndex(of: ":") else { return "" }
        return String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces.union(.init(charactersIn: "\"'")) )
    }

    private func extractHeader(_ content: String, pattern: String) -> String? {
        for line in content.components(separatedBy: "\n") {
            if line.hasPrefix(pattern) {
                return String(line.dropFirst(pattern.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}

// MARK: - Types

public struct LoadedSkill: Sendable, Identifiable {
    public let id: String
    public let path: String
    public let manifest: SkillManifest?
    public let markdown: String
    public let metadata: SkillMetadata
    public let body: String
}

public struct SkillManifest: Codable, Sendable {
    public let name: String
    public let version: String?
    public let description: String?
    public let pluginType: String?
    public let dependencies: [String]?
    public let commands: [String]?

    enum CodingKeys: String, CodingKey {
        case name, version, description
        case pluginType = "plugin_type"
        case dependencies, commands
    }
}

public struct SkillMetadata: Codable, Sendable {
    public var title: String?
    public var description: String?
    public var category: String?
    public var version: String?
    public var author: String?
    public var tags: [String]?

    public init(title: String? = nil, description: String? = nil, category: String? = nil, version: String? = nil, author: String? = nil, tags: [String]? = nil) {
        self.title = title
        self.description = description
        self.category = category
        self.version = version
        self.author = author
        self.tags = tags
    }
}

public enum SkillError: Error, LocalizedError {
    case directoryNotFound(String)
    case skillFileNotFound(String)
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case .directoryNotFound(let dir): "目录未找到: \(dir)"
        case .skillFileNotFound(let path): "SKILL.md 未找到: \(path)"
        case .parseError(let detail): "解析错误: \(detail)"
        }
    }
}
