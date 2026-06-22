import Foundation
import RenJistrolyModels

/// Tool-based skill grouping registry.
/// Groups tools into named skills (domains) for filtered tool exposure and
/// domain-specific system prompts. Separate from the SKILL.md-based SkillRegistry.
public actor ToolSkillRegistry {
    private var skills: [String: Skill] = [:]

    public init() {
        for skill in Skill.builtinSkills() {
            skills[skill.name] = skill
        }
    }

    public func register(_ skill: Skill) {
        skills[skill.name] = skill
    }

    public func registerAll(_ skillList: [Skill]) {
        for skill in skillList {
            skills[skill.name] = skill
        }
    }

    public func skill(named name: String) -> Skill? {
        skills[name]
    }

    public var all: [Skill] {
        Array(skills.values)
    }

    /// Match skills by keyword against a prompt.
    public func match(_ prompt: String) -> [Skill] {
        let lower = prompt.lowercased()
        return skills.values.filter { skill in
            skill.triggerKeywords.contains { keyword in
                lower.contains(keyword.lowercased())
            }
        }
    }

    /// Match skills by domain.
    public func skills(for domains: Set<SkillDomain>) -> [Skill] {
        skills.values.filter { domains.contains($0.domain) }
    }

    /// Get the tool definitions for a set of skills. If general is included
    /// (or the skill list is empty), returns all tools.
    public func toolDefinitions(
        for skills: [Skill],
        from allTools: [ToolDefinition]
    ) -> [ToolDefinition] {
        guard !skills.isEmpty else { return allTools }

        let hasGeneral = skills.contains { $0.name == "general" }
        guard !hasGeneral else { return allTools }

        var names = Set<String>()
        for skill in skills {
            names.formUnion(skill.toolNames)
        }
        return allTools.filter { names.contains($0.name) }
    }

    /// Compile system prompts from matched skills.
    public func compileSystemPrompt(for skills: [Skill]) -> String {
        guard !skills.isEmpty else { return "" }
        let seen = NSOrderedSet(array: skills.map(\.name))
        var prompts: [String] = []
        for i in 0..<seen.count {
            guard let name = seen[i] as? String, let skill = self.skills[name] else { continue }
            if !skill.systemPrompt.isEmpty { prompts.append(skill.systemPrompt) }
        }
        return prompts.joined(separator: "\n\n")
    }
}
