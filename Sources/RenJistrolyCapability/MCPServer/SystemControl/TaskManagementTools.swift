import Foundation
import RenJistrolyModels

// MARK: - Data Models

public struct TaskItem: Sendable, Codable {
    public let id: String
    public var subject: String
    public var description: String
    public var status: TaskStatus
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, subject: String, description: String, status: TaskStatus, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.subject = subject
        self.description = description
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum TaskStatus: String, Sendable, Codable {
    case pending
    case inProgress = "inProgress"
    case completed
    case deleted
}

// MARK: - Task Store

public actor TaskStore {
    public static let shared = TaskStore()

    private var tasks: [String: TaskItem] = [:]
    private let storageURL: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        storageURL = home.appendingPathComponent(".renjistroly_tasks.json")
        if let data = try? Data(contentsOf: storageURL),
           let loaded = try? JSONDecoder().decode([String: TaskItem].self, from: data) {
            tasks = loaded
        }
    }

    // MARK: - CRUD

    public func create(subject: String, description: String) -> TaskItem {
        let id = UUID().uuidString
        let now = Date()
        let task = TaskItem(
            id: id,
            subject: subject,
            description: description,
            status: .pending,
            createdAt: now,
            updatedAt: now
        )
        tasks[id] = task
        save()
        return task
    }

    public func list(status filter: TaskStatus? = nil) -> [TaskItem] {
        let all = Array(tasks.values)
        if let filter {
            return all.filter { $0.status == filter }.sorted { $0.createdAt > $1.createdAt }
        }
        return all.sorted { $0.createdAt > $1.createdAt }
    }

    public func update(id: String, status: TaskStatus) -> TaskItem? {
        guard var task = tasks[id] else { return nil }
        task.status = status
        task.updatedAt = Date()
        tasks[id] = task
        save()
        return task
    }

    public func delete(id: String) -> Bool {
        guard tasks[id] != nil else { return false }
        tasks.removeValue(forKey: id)
        save()
        return true
    }

    // MARK: - Persistence

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(tasks)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Silent — persistence failure should never break tool execution
        }
    }

}

// MARK: - Task Create Tool

public struct TaskCreateTool: MCPTool {
    public let definition = ToolDefinition(
        name: "task_create",
        description: "创建任务",
        parameters: [
            .init(name: "subject", type: .string, description: "任务标题"),
            .init(name: "description", type: .string, description: "任务描述"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let subject = arguments["subject"], !subject.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: subject", isError: true)
        }
        let description = arguments["description"] ?? ""
        let task = await TaskStore.shared.create(subject: subject, description: description)
        let formatter = ISO8601DateFormatter()
        return ToolCallResult(
            id: UUID().uuidString,
            output: """
            任务已创建:
              ID: \(task.id)
              标题: \(task.subject)
              状态: \(task.status.rawValue)
              创建时间: \(formatter.string(from: task.createdAt))
            """
        )
    }
}

// MARK: - Task List Tool

public struct TaskListTool: MCPTool {
    public let definition = ToolDefinition(
        name: "task_list",
        description: "列出任务，可按状态过滤",
        parameters: [
            .init(name: "status", type: .string, description: "过滤状态: pending/inProgress/completed，为空则列出所有", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let filter: TaskStatus? = {
            guard let raw = arguments["status"], !raw.isEmpty else { return nil }
            return TaskStatus(rawValue: raw)
        }()
        let tasks = await TaskStore.shared.list(status: filter)
        if tasks.isEmpty {
            return ToolCallResult(id: UUID().uuidString, output: "暂无任务")
        }
        let formatter = ISO8601DateFormatter()
        var lines = ["共 \(tasks.count) 个任务：\n"]
        for (i, task) in tasks.enumerated() {
            lines.append("\(i + 1). [\(task.status.rawValue)] \(task.subject)")
            if !task.description.isEmpty {
                lines.append("   描述: \(task.description)")
            }
            lines.append("   ID: \(task.id)")
            lines.append("   更新: \(formatter.string(from: task.updatedAt))")
        }
        return ToolCallResult(id: UUID().uuidString, output: lines.joined(separator: "\n"))
    }
}

// MARK: - Task Update Tool

public struct TaskUpdateTool: MCPTool {
    public let definition = ToolDefinition(
        name: "task_update",
        description: "更新任务状态",
        parameters: [
            .init(name: "task_id", type: .string, description: "任务 ID"),
            .init(name: "status", type: .string, description: "新状态: pending/inProgress/completed"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let id = arguments["task_id"], !id.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: task_id", isError: true)
        }
        guard let statusRaw = arguments["status"], let status = TaskStatus(rawValue: statusRaw) else {
            return ToolCallResult(id: UUID().uuidString, output: "无效的状态值: \(arguments["status"] ?? "")，有效值: pending/inProgress/completed", isError: true)
        }
        guard let task = await TaskStore.shared.update(id: id, status: status) else {
            return ToolCallResult(id: UUID().uuidString, output: "未找到任务: \(id)", isError: true)
        }
        let formatter = ISO8601DateFormatter()
        return ToolCallResult(
            id: UUID().uuidString,
            output: """
            任务已更新:
              ID: \(task.id)
              标题: \(task.subject)
              新状态: \(task.status.rawValue)
              更新时间: \(formatter.string(from: task.updatedAt))
            """
        )
    }
}

// MARK: - Task Delete Tool

public struct TaskDeleteTool: MCPTool {
    public let definition = ToolDefinition(
        name: "task_delete",
        description: "删除任务",
        parameters: [
            .init(name: "task_id", type: .string, description: "任务 ID"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let id = arguments["task_id"], !id.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: task_id", isError: true)
        }
        let deleted = await TaskStore.shared.delete(id: id)
        guard deleted else {
            return ToolCallResult(id: UUID().uuidString, output: "未找到任务: \(id)", isError: true)
        }
        return ToolCallResult(id: UUID().uuidString, output: "任务已删除: \(id)")
    }
}
