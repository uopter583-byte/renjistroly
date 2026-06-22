import Foundation
import RenJistrolyModels

public actor AgentSkillRegistry {
    private var skills: [UUID: AgentSkill] = [:]

    public init() {}

    @discardableResult
    public func learn(name: String, description: String, triggerPhrases: [String], steps: [String]) -> AgentSkill {
        let skill = AgentSkill(name: name, description: description, triggerPhrases: triggerPhrases, steps: steps)
        skills[skill.id] = skill
        return skill
    }

    public func match(_ prompt: String) -> AgentSkill? {
        let normalized = prompt.lowercased()
        return skills.values
            .filter { skill in
                skill.triggerPhrases.contains { normalized.contains($0.lowercased()) }
                    || normalized.contains(skill.name.lowercased())
            }
            .sorted { lhs, rhs in
                lhs.successCount - lhs.failureCount > rhs.successCount - rhs.failureCount
            }
            .first
    }

    public func all() -> [AgentSkill] {
        skills.values.sorted { $0.createdAt > $1.createdAt }
    }
}
