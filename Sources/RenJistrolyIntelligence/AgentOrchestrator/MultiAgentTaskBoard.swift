import Foundation
import RenJistrolyModels

public actor MultiAgentTaskBoard {
    private var items: [UUID: MultiAgentBoardItem] = [:]

    public init() {}

    public func seedDefaultBoard(for objective: String) -> [MultiAgentBoardItem] {
        let templates: [(AgentRole, String)] = [
            (.planner, "拆解任务并选择执行域"),
            (.code, "处理代码库修改和 Claude Code 开发任务"),
            (.test, "运行测试并整理失败信息"),
            (.review, "审查 diff、风险和遗漏"),
            (.desktop, "用 macOS Computer Use 验证本地界面"),
            (.summary, "汇总结果、产物和下一步"),
        ]
        let newItems = templates.map { role, description in
            MultiAgentBoardItem(role: role, objective: "\(description): \(objective)")
        }
        for item in newItems {
            items[item.id] = item
        }
        return newItems
    }

    public func add(role: AgentRole, objective: String) -> MultiAgentBoardItem {
        let item = MultiAgentBoardItem(role: role, objective: objective)
        items[item.id] = item
        return item
    }

    public func update(
        _ id: UUID,
        status: AgentTaskStatus? = nil,
        latestLog: String? = nil,
        artifactPaths: [String]? = nil
    ) {
        guard var item = items[id] else { return }
        if let status { item.status = status }
        if let latestLog { item.latestLog = latestLog }
        if let artifactPaths { item.artifactPaths = artifactPaths }
        items[id] = item
    }

    public func all() -> [MultiAgentBoardItem] {
        items.values.sorted { $0.role.rawValue < $1.role.rawValue }
    }

    public func byStatus(_ status: AgentTaskStatus) -> [MultiAgentBoardItem] {
        all().filter { $0.status == status }
    }
}
