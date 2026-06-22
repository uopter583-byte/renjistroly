import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

@MainActor
@Observable
public final class ContextCompiler {
    public private(set) var currentContext: ProjectContext?
    public private(set) var isCompiling: Bool = false

    private let shellExecutor: ShellExecutor
    private let accessibilityBridge: AccessibilityBridge
    private let appleScriptBridge: AppleScriptBridge

    public init(
        shellExecutor: ShellExecutor = ShellExecutor(),
        accessibilityBridge: AccessibilityBridge = AccessibilityBridge(),
        appleScriptBridge: AppleScriptBridge = AppleScriptBridge()
    ) {
        self.shellExecutor = shellExecutor
        self.accessibilityBridge = accessibilityBridge
        self.appleScriptBridge = appleScriptBridge
    }

    public func compileContext(cwd: String? = nil) async -> ProjectContext {
        isCompiling = true
        defer { isCompiling = false }

        async let activeFile = getActiveFile()
        async let gitContext = getGitContext(cwd: cwd)
        async let projectType = detectProjectType(cwd: cwd)
        async let activeApp = getActiveApp()
        async let selectedText = getSelectedText()

        let context = await ProjectContext(
            rootPath: cwd,
            activeFile: activeFile,
            gitBranch: gitContext?.branch,
            gitRemote: gitContext?.remote,
            projectType: projectType,
            dependencies: nil,
            activeAppBundleID: activeApp,
            selectedText: selectedText,
            screenSummary: nil
        )

        currentContext = context
        return context
    }

    public func compileSystemPrompt(
        context: ProjectContext?,
        desktopContext: DesktopContext? = nil,
        workflowMemories: [TaskMemory] = []
    ) -> String {
        var prompt = "你是 RenJistroly，一个 macOS 原生智能助手。你可以直接操控用户的电脑。"

        if let cwd = context?.rootPath {
            prompt += "\n当前工作目录: \(cwd)"
        }

        if let projectType = context?.projectType {
            prompt += "\n项目类型: \(projectType.rawValue)"
        }

        if let branch = context?.gitBranch {
            prompt += "\nGit 分支: \(branch)"
        }

        if let activeFile = context?.activeFile {
            prompt += "\n当前活跃文件: \(activeFile)"
        }

        if let activeApp = context?.activeAppBundleID {
            prompt += "\n用户当前在前台应用: \(activeApp)"
        }

        if let selectedText = context?.selectedText {
            let truncated = String(selectedText.prefix(500))
            prompt += "\n用户选中的文本:\n```\n\(truncated)\n```"
        }

        if let desktopContext {
            prompt += "\n\n\(desktopContext.promptSummary())"
        }

        let workflowMemoryContext = buildWorkflowMemoryContext(memories: workflowMemories)
        if !workflowMemoryContext.isEmpty {
            prompt += "\n\n相关工作流记忆:\n\(workflowMemoryContext)"
        }

        prompt += "\n\n你有能力直接操控 macOS 系统，以下是你可用的工具："
        prompt += "\n【文字输入】type_text / read_focused_text — 在当前焦点输入框打字或读取内容"
        prompt += "\n【按键模拟】press_key — 按键盘按键或组合键（cmd/ctrl/shift/option）"
        prompt += "\n【界面控制】click_element — 点击按钮、链接等 UI 元素（通过文字匹配）"
        prompt += "\n【菜单导航】activate_menu — 执行菜单栏命令（如 '文件/新建' 'Edit/Copy'）"
        prompt += "\n【窗口管理】list_windows / focus_window — 列出窗口 / 切换窗口"
        prompt += "\n【滚动翻页】scroll — 滚动当前焦点区域"
        prompt += "\n【鼠标拖拽】drag — 从一点拖拽到另一点"
        prompt += "\n【UI 探查】get_ui_tree — 获取当前应用 UI 元素树"
        prompt += "\n【应用管理】open_app / running_apps — 打开/切换/查看应用"
        prompt += "\n【命令执行】shell_command — 在终端执行命令"
        prompt += "\n【文件操作】read_file / write_file / list_files — 读写文件"
        prompt += "\n【系统信息】system_info / git_status / git_log"
        prompt += "\n\n当用户要求做任何操作，直接调用工具执行，然后用中文简短确认结果。"
        prompt += "\n例如：'在终端运行 git status' → open_app('Terminal') → type_text('git status') → press_key(key='return')"

        return prompt
    }

    public func buildWorkflowMemoryContext(memories: [TaskMemory], limit: Int = 3) -> String {
        guard !memories.isEmpty else { return "" }

        return memories
            .suffix(limit)
            .reversed()
            .enumerated()
            .map { index, memory in
                var lines = ["\(index + 1). 任务: \(memory.task)"]
                lines.append("状态: \(memory.success ? "成功" : "失败")")
                lines.append("步骤: \(memory.steps.joined(separator: " -> "))")
                if let learnedWorkflow = memory.learnedWorkflow, !learnedWorkflow.isEmpty {
                    lines.append("沉淀流程: \(learnedWorkflow)")
                }
                if let failureReason = memory.failureReason, !failureReason.isEmpty {
                    lines.append("失败原因: \(String(failureReason.prefix(160)))")
                }
                return lines.joined(separator: "\n")
            }
            .joined(separator: "\n\n")
    }

    // MARK: - Private

    private func getActiveFile() async -> String? {
        let script = #"""
        tell application "System Events"
            tell first application process whose frontmost is true
                try
                    return title of front window
                end try
            end tell
        end tell
        return ""
        """#
        do {
            let result = try await appleScriptBridge.run(script)
            let title = result.stringValue?.trimmingCharacters(in: .whitespaces) ?? ""
            return title.isEmpty ? nil : title
        } catch {
            return nil
        }
    }

    private func getGitContext(cwd: String?) async -> GitContext? {
        let path = cwd ?? FileManager.default.currentDirectoryPath
        return try? await shellExecutor.getProjectGitContext(path)
    }

    private func detectProjectType(cwd: String?) async -> ProjectContext.ProjectType? {
        let path = cwd ?? FileManager.default.currentDirectoryPath
        let fm = FileManager.default

        let indicators: [(String, ProjectContext.ProjectType)] = [
            ("Package.swift", .swiftPM),
            (".xcodeproj", .xcode),
            ("package.json", .node),
            ("pyproject.toml", .python),
            ("Cargo.toml", .rust),
            ("go.mod", .go),
        ]

        for (file, type) in indicators {
            if fm.fileExists(atPath: "\(path)/\(file)") {
                return type
            }
            // Check for xcodeproj/xcworkspace directories
            if file.hasPrefix(".") { continue }
            if let contents = try? fm.contentsOfDirectory(atPath: path) {
                if contents.contains(where: { $0.hasSuffix(file) }) {
                    return type
                }
            }
        }
        return nil
    }

    private func getActiveApp() async -> String? {
        try? await accessibilityBridge.getFocusedAppBundleID()
    }

    private func getSelectedText() async -> String? {
        try? await accessibilityBridge.getSelectedText()
    }
}
