import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - NotesPlannerTool

public struct NotesPlannerTool: MCPTool {
    public let definition = ToolDefinition(
        name: "notes_planner",
        description: "Apple Notes 规划工具，支持创建、读取、列出和搜索笔记",
        parameters: [
            .init(name: "action", type: .string, description: "操作: create(创建)/read(读取)/list(列出)/search(搜索)"),
            .init(name: "title", type: .string, description: "笔记标题 (create/read/search 时需要)", required: false),
            .init(name: "body", type: .string, description: "笔记内容 (create 时为可选)", required: false),
            .init(name: "folder", type: .string, description: "笔记文件夹名称 (create 时为可选)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action", isError: true)
        }
        let bridge = AppleScriptBridge()

        switch action {
        case "create":
            guard let title = arguments["title"], !title.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: title", isError: true)
            }
            let body = arguments["body"] ?? ""
            let escTitle = appleScriptEscape(title)
            let escBody = appleScriptEscape(body)

            if let folder = arguments["folder"], !folder.isEmpty {
                let escFolder = appleScriptEscape(folder)
                let script = """
                tell application "Notes"
                    if exists folder "\(escFolder)" then
                        make new note at folder "\(escFolder)" with properties {name:"\(escTitle)", body:"\(escBody)"}
                    else
                        make new note with properties {name:"\(escTitle)", body:"\(escBody)"}
                    end if
                end tell
                """
                _ = try await bridge.run(script)
            } else {
                let script = """
                tell application "Notes"
                    make new note with properties {name:"\(escTitle)", body:"\(escBody)"}
                end tell
                """
                _ = try await bridge.run(script)
            }
            Task { await AgentEventBus.shared.publish(.desktop(.officeAction(action: "notes_created"))) }
            return ToolCallResult(id: UUID().uuidString, output: "笔记已创建: \(title)")

        case "read":
            guard let title = arguments["title"], !title.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: title", isError: true)
            }
            let escTitle = appleScriptEscape(title)
            let script = """
            tell application "Notes"
                set noteList to notes whose name is "\(escTitle)"
                if (count of noteList) > 0 then
                    return body of first item of noteList
                else
                    return "未找到笔记"
                end if
            end tell
            """
            let result = try await bridge.run(script)
            Task { await AgentEventBus.shared.publish(.desktop(.officeAction(action: "notes_read"))) }
            return ToolCallResult(id: UUID().uuidString, output: result.stringValue ?? "笔记内容为空")

        case "list":
            let script = """
            tell application "Notes"
                set output to ""
                repeat with f in folders
                    set output to output & "📁 " & name of f & "\n"
                    repeat with n in notes of f
                        set output to output & "  📝 " & name of n & "\n"
                    end repeat
                end repeat
                return output
            end tell
            """
            let result = try await bridge.run(script)
            let output = result.stringValue ?? ""
            Task { await AgentEventBus.shared.publish(.desktop(.officeAction(action: "notes_list"))) }
            return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "没有笔记" : output)

        case "search":
            guard let query = arguments["title"], !query.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少搜索关键词（使用 title 参数）", isError: true)
            }
            let escQuery = appleScriptEscape(query)
            let script = """
            tell application "Notes"
                set matchingNotes to notes whose name contains "\(escQuery)"
                set output to ""
                repeat with n in matchingNotes
                    set output to output & name of n & "\n"
                end repeat
                return output
            end tell
            """
            let result = try await bridge.run(script)
            let output = result.stringValue ?? ""
            Task { await AgentEventBus.shared.publish(.desktop(.officeAction(action: "notes_search"))) }
            return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "未找到匹配的笔记" : output)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "不支持的操作: \(action)，支持 create/read/list/search", isError: true)
        }
    }
}

// MARK: - MailPlannerTool

public struct MailPlannerTool: MCPTool {
    public let definition = ToolDefinition(
        name: "mail_planner",
        description: "Apple Mail 规划工具，支持编写草稿和列出邮件（不会自动发送，仅创建草稿）",
        parameters: [
            .init(name: "action", type: .string, description: "操作: compose(编写草稿)/draft(编写草稿)/list(列出收件箱邮件)"),
            .init(name: "to", type: .string, description: "收件人邮箱 (compose/draft 时需要)", required: false),
            .init(name: "subject", type: .string, description: "邮件主题 (compose/draft 时需要)", required: false),
            .init(name: "body", type: .string, description: "邮件正文 (compose/draft 时需要)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action", isError: true)
        }
        let bridge = AppleScriptBridge()

        switch action {
        case "compose", "draft":
            guard let to = arguments["to"], !to.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: to", isError: true)
            }
            guard let subject = arguments["subject"], !subject.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: subject", isError: true)
            }
            guard let body = arguments["body"] else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: body", isError: true)
            }
            let escTo = appleScriptEscape(to)
            let escSubject = appleScriptEscape(subject)
            let escBody = appleScriptEscape(body)
            let script = """
            tell application "Mail"
                set newMessage to make new outgoing message with properties {subject:"\(escSubject)", content:"\(escBody)", visible:true}
                tell newMessage
                    make new to recipient at end of to recipients with properties {address:"\(escTo)"}
                end tell
                save newMessage
            end tell
            """
            _ = try await bridge.run(script)
            Task { await AgentEventBus.shared.publish(.desktop(.officeAction(action: "mail_draft_created"))) }
            return ToolCallResult(id: UUID().uuidString, output: "邮件草稿已创建: \(subject) → \(to)")

        case "list":
            let script = """
            tell application "Mail"
                set msgList to messages of inbox
                set output to ""
                repeat with m in msgList
                    set output to output & subject of m & " — " & sender of m & "\n"
                end repeat
                return output
            end tell
            """
            let result = try await bridge.run(script)
            let output = result.stringValue ?? ""
            Task { await AgentEventBus.shared.publish(.desktop(.officeAction(action: "mail_list"))) }
            return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "收件箱为空" : output)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "不支持的操作: \(action)，支持 compose/draft/list", isError: true)
        }
    }
}

// MARK: - CalendarPlannerTool

public struct CalendarPlannerTool: MCPTool {
    public let definition = ToolDefinition(
        name: "calendar_planner",
        description: "Apple Calendar 规划工具，支持创建、列出和查看即将到来的日程",
        parameters: [
            .init(name: "action", type: .string, description: "操作: create(创建)/list(列出所有日程)/upcoming(即将到来)"),
            .init(name: "title", type: .string, description: "日程标题 (create 时需要)", required: false),
            .init(name: "start_date", type: .string, description: "开始时间 ISO8601 (如 2026-06-20T10:00:00Z，create 时需要)", required: false),
            .init(name: "end_date", type: .string, description: "结束时间 ISO8601 (如 2026-06-20T11:00:00Z，create 时需要)", required: false),
            .init(name: "calendar_name", type: .string, description: "日历名称 (create 时为可选)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action", isError: true)
        }
        let bridge = AppleScriptBridge()

        switch action {
        case "create":
            guard let title = arguments["title"], !title.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: title", isError: true)
            }
            guard let startStr = arguments["start_date"], !startStr.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: start_date", isError: true)
            }
            guard let endStr = arguments["end_date"], !endStr.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: end_date", isError: true)
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let startDate = formatter.date(from: startStr) ?? {
                formatter.formatOptions = [.withInternetDateTime]
                return formatter.date(from: startStr)
            }() else {
                return ToolCallResult(id: UUID().uuidString, output: "无效的 start_date 格式，请使用 ISO8601", isError: true)
            }
            guard let endDate = formatter.date(from: endStr) ?? {
                formatter.formatOptions = [.withInternetDateTime]
                return formatter.date(from: endStr)
            }() else {
                return ToolCallResult(id: UUID().uuidString, output: "无效的 end_date 格式，请使用 ISO8601", isError: true)
            }

            let sc = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startDate)
            let ec = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: endDate)
            let months = ["January", "February", "March", "April", "May", "June",
                          "July", "August", "September", "October", "November", "December"]
            let sm = months[(sc.month ?? 1) - 1]
            let em = months[(ec.month ?? 1) - 1]
            let escTitle = appleScriptEscape(title)

            let dateScript: String = """
            set startDate to current date
            set year of startDate to \(sc.year ?? 2026)
            set month of startDate to \(sm)
            set day of startDate to \(sc.day ?? 1)
            set hours of startDate to \(sc.hour ?? 0)
            set minutes of startDate to \(sc.minute ?? 0)
            set seconds of startDate to \(sc.second ?? 0)

            set endDate to current date
            set year of endDate to \(ec.year ?? 2026)
            set month of endDate to \(em)
            set day of endDate to \(ec.day ?? 1)
            set hours of endDate to \(ec.hour ?? 0)
            set minutes of endDate to \(ec.minute ?? 0)
            set seconds of endDate to \(ec.second ?? 0)
            """

            if let calName = arguments["calendar_name"], !calName.isEmpty {
                let escCal = appleScriptEscape(calName)
                let script = """
                tell application "Calendar"
                    tell calendar "\(escCal)"
                        \(dateScript)
                        make new event at end with properties {summary:"\(escTitle)", start date:startDate, end date:endDate}
                    end tell
                end tell
                """
                _ = try await bridge.run(script)
            } else {
                let script = """
                tell application "Calendar"
                    set calList to calendars
                    if (count of calList) > 0 then
                        set targetCal to first item of calList
                        tell targetCal
                            \(dateScript)
                            make new event at end with properties {summary:"\(escTitle)", start date:startDate, end date:endDate}
                        end tell
                    end if
                end tell
                """
                _ = try await bridge.run(script)
            }
            Task { await AgentEventBus.shared.publish(.desktop(.officeAction(action: "calendar_created"))) }
            return ToolCallResult(id: UUID().uuidString, output: "日程已创建: \(title)")

        case "list":
            let script = """
            tell application "Calendar"
                set output to ""
                repeat with c in calendars
                    set output to output & "[" & title of c & "]\n"
                    repeat with e in events of c
                        set output to output & "  " & summary of e & " (" & (start date of e as string) & ")\n"
                    end repeat
                end repeat
                return output
            end tell
            """
            let result = try await bridge.run(script)
            let output = result.stringValue ?? ""
            Task { await AgentEventBus.shared.publish(.desktop(.officeAction(action: "calendar_list"))) }
            return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "没有日程" : output)

        case "upcoming":
            let script = """
            tell application "Calendar"
                set output to ""
                set now to current date
                repeat with c in calendars
                    repeat with e in events of c
                        if start date of e ≥ now then
                            set output to output & summary of e & " (" & (start date of e as string) & ")\n"
                        end if
                    end repeat
                end repeat
                return output
            end tell
            """
            let result = try await bridge.run(script)
            let output = result.stringValue ?? ""
            Task { await AgentEventBus.shared.publish(.desktop(.officeAction(action: "calendar_upcoming"))) }
            return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "没有即将到来的日程" : output)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "不支持的操作: \(action)，支持 create/list/upcoming", isError: true)
        }
    }
}

// MARK: - Helper

private func appleScriptEscape(_ str: String) -> String {
    str.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
}
