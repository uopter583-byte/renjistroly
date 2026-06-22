import SwiftUI
import RenJistrolyModels

public struct AgentConsoleView: View {
    private let route: RoutedTask?
    private let boardItems: [MultiAgentBoardItem]
    private let developerTasks: [DeveloperAgentTask]
    private let auditRecords: [SafetyAuditRecord]
    private let memories: [TaskMemory]
    private let skills: [AgentSkill]
    private let recoveryProfile: RecoveryProfileSnapshot
    private let computerUseTrace: ComputerUseTraceSnapshot?
    private let recentAgentTimeline: [AgentTimelineEvent]
    private let onRetryDeveloperTask: ((UUID) -> Void)?
    private let onApproveDeveloperTask: ((UUID) -> Void)?
    private let onStopDeveloperTask: ((UUID) -> Void)?
    private let onRetryComputerUseStep: ((String) -> Void)?
    private let onApproveComputerUseStep: ((String) -> Void)?
    private let onSendCommand: ((String) -> Void)?
    private let onRetryAllFailed: (() -> Void)?
    private let onStopAll: (() -> Void)?
    private let onTriggerRecovery: ((String) -> Void)?
    @State private var selectedDeveloperTaskID: UUID?
    @State private var commandText: String = ""

    public init(
        route: RoutedTask? = nil,
        boardItems: [MultiAgentBoardItem] = [],
        developerTasks: [DeveloperAgentTask] = [],
        auditRecords: [SafetyAuditRecord] = [],
        memories: [TaskMemory] = [],
        skills: [AgentSkill] = [],
        recoveryProfile: RecoveryProfileSnapshot = RecoveryProfileSnapshot(scope: "global"),
        computerUseTrace: ComputerUseTraceSnapshot? = nil,
        recentAgentTimeline: [AgentTimelineEvent] = [],
        onRetryDeveloperTask: ((UUID) -> Void)? = nil,
        onApproveDeveloperTask: ((UUID) -> Void)? = nil,
        onStopDeveloperTask: ((UUID) -> Void)? = nil,
        onRetryComputerUseStep: ((String) -> Void)? = nil,
        onApproveComputerUseStep: ((String) -> Void)? = nil,
        onSendCommand: ((String) -> Void)? = nil,
        onRetryAllFailed: (() -> Void)? = nil,
        onStopAll: (() -> Void)? = nil,
        onTriggerRecovery: ((String) -> Void)? = nil
    ) {
        self.route = route
        self.boardItems = boardItems
        self.developerTasks = developerTasks
        self.auditRecords = auditRecords
        self.memories = memories
        self.skills = skills
        self.recoveryProfile = recoveryProfile
        self.computerUseTrace = computerUseTrace
        self.recentAgentTimeline = recentAgentTimeline
        self.onRetryDeveloperTask = onRetryDeveloperTask
        self.onApproveDeveloperTask = onApproveDeveloperTask
        self.onStopDeveloperTask = onStopDeveloperTask
        self.onRetryComputerUseStep = onRetryComputerUseStep
        self.onApproveComputerUseStep = onApproveComputerUseStep
        self.onSendCommand = onSendCommand
        self.onRetryAllFailed = onRetryAllFailed
        self.onStopAll = onStopAll
        self.onTriggerRecovery = onTriggerRecovery
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            commandBar
            quickActionsBar
            routeSection
            boardSection
            developerSection
            timelineSection
            safetySection
            recoverySection
            computerUseSection
            memorySection
            skillsSection
        }
        .padding(16)
    }

    private var commandBar: some View {
        HStack(spacing: 8) {
            TextField("输入命令...", text: $commandText)
                .font(.system(size: 12, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    let cmd = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cmd.isEmpty else { return }
                    onSendCommand?(cmd)
                    commandText = ""
                }
            if !commandText.isEmpty {
                Button("发送") {
                    let cmd = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cmd.isEmpty else { return }
                    onSendCommand?(cmd)
                    commandText = ""
                }
                .font(.system(size: 11))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    private var quickActionsBar: some View {
        let runningCount = developerTasks.filter { $0.status == .running }.count
        let failedCount = developerTasks.filter { $0.status == .failed }.count
        let waitingCount = developerTasks.filter { $0.status == .waitingForConfirmation }.count

        return Group {
            if runningCount > 0 || failedCount > 0 || waitingCount > 0 {
                HStack(spacing: 6) {
                    Text("快捷操作")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    if runningCount > 0, onStopAll != nil {
                        Button("停止全部(\(runningCount))") { onStopAll?() }
                            .font(.system(size: 10))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red)
                    }
                    if failedCount > 0, onRetryAllFailed != nil {
                        Button("重试全部失败(\(failedCount))") { onRetryAllFailed?() }
                            .font(.system(size: 10))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.orange)
                    }
                    if waitingCount > 0 {
                        Button("批准全部(\(waitingCount))") {
                            developerTasks.filter { $0.status == .waitingForConfirmation }.forEach { onApproveDeveloperTask?($0.id) }
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.blue)
                    }
                }
            }
        }
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Task Router", systemImage: "arrow.triangle.branch")
                .font(.system(size: 13, weight: .semibold))
            if let route {
                Text("\(route.primaryRoute.kind.rawValue) · \(Int(route.primaryRoute.confidence * 100))%")
                    .font(.system(size: 12, weight: .medium))
                Text(route.primaryRoute.reason)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                Text("等待任务输入")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var boardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Multi-Agent Board", systemImage: "rectangle.3.group")
                .font(.system(size: 13, weight: .semibold))
            ForEach(boardItems.prefix(6)) { item in
                HStack {
                    Text(item.role.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 58, alignment: .leading)
                    Text(item.objective)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Spacer()
                    statusPill(item.status)
                }
            }
        }
    }

    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Developer Agent", systemImage: "terminal")
                .font(.system(size: 13, weight: .semibold))
            if developerTasks.isEmpty {
                Text("暂无 Claude Code 任务")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                ForEach(developerTasks.prefix(5)) { task in
                    Button {
                        selectedDeveloperTaskID = task.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.prompt)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                if let cwd = task.cwd, !cwd.isEmpty {
                                    Text(cwd)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            statusPill(task.status)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(task.id == selectedTask?.id ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                if let selectedTask {
                    developerTaskDetail(selectedTask)
                }
            }
        }
    }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Safety Audit", systemImage: "checkmark.shield")
                .font(.system(size: 13, weight: .semibold))
            if auditRecords.isEmpty {
                Text("暂无安全记录")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                ForEach(auditRecords.prefix(5)) { record in
                    Text("\(record.decision.rawValue): \(record.assessment.summary)")
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Agent Timeline", systemImage: "timeline.selection")
                .font(.system(size: 13, weight: .semibold))
            if recentAgentTimeline.isEmpty {
                Text("暂无统一事件")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                ForEach(recentAgentTimeline.prefix(6)) { event in
                    HStack(alignment: .top, spacing: 8) {
                        miniTag(event.source)
                        Text(event.kind)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 68, alignment: .leading)
                        Text(event.summary)
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Workflow Memory", systemImage: "brain")
                .font(.system(size: 13, weight: .semibold))
            if memories.isEmpty {
                Text("暂无工作流记忆")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                ForEach(memories.prefix(5)) { memory in
                    Text(memory.task)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
            }
        }
    }

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Recovery Profile", systemImage: "waveform.path.ecg")
                .font(.system(size: 13, weight: .semibold))
            if recoveryProfile.strategies.isEmpty {
                Text("暂无恢复策略画像")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 8) {
                    miniTag(recoveryProfile.scope)
                    if let appName = recoveryProfile.appName, !appName.isEmpty {
                        miniTag(appName)
                    }
                    if let toolName = recoveryProfile.toolName, !toolName.isEmpty {
                        miniTag(toolName)
                    }
                }

                ForEach(recoveryProfile.strategies.prefix(4)) { metric in
                    HStack(spacing: 8) {
                        Text(metric.strategy)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(metric.successRate * 100))%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Skills", systemImage: "sparkles")
                .font(.system(size: 13, weight: .semibold))
            if skills.isEmpty {
                Text("暂无技能")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                ForEach(skills.prefix(5)) { skill in
                    Text(skill.name)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
            }
        }
    }

    private var computerUseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Computer Use Trace", systemImage: "cursorarrow.motionlines")
                .font(.system(size: 13, weight: .semibold))
            if let computerUseTrace {
                HStack(spacing: 8) {
                    miniTag(computerUseTrace.routeLabel)
                    miniTag(computerUseTrace.phase)
                    miniTag(computerUseTrace.run.succeeded ? "verified" : "needs-recovery")
                }
                Text(computerUseTrace.taskText)
                    .font(.system(size: 11))
                    .lineLimit(2)

                if let browserPageState = computerUseTrace.browserPageState {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            miniTag(browserPageState.browserName)
                            if let host = browserPageState.host, !host.isEmpty {
                                miniTag(host)
                            }
                        }
                        if let tabTitle = browserPageState.tabTitle, !tabTitle.isEmpty {
                            detailLine(title: "页面", value: tabTitle)
                        }
                        if let searchQuery = browserPageState.searchQuery, !searchQuery.isEmpty {
                            detailLine(title: "搜索词", value: searchQuery)
                        }
                        if let url = browserPageState.url, !url.isEmpty {
                            detailLine(title: "URL", value: url)
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                if !computerUseTrace.events.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(computerUseTrace.events.suffix(4)) { event in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(event.stepIndex + 1)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 12, alignment: .leading)
                                Text("\(event.phase) · \(event.toolName)")
                                    .font(.system(size: 10, design: .monospaced))
                                Spacer()
                            }
                            Text(event.summary)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                ForEach(Array(computerUseTrace.run.steps.prefix(6)), id: \.action.toolCall.id) { step in
                    let idx = computerUseTrace.run.steps.firstIndex(of: step) ?? 0
                    cuStepCard(step: step, index: idx)
                }
            } else {
                Text("暂无 Computer Use trace")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func cuStepCard(step: ComputerUseStepResult, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let backend = step.backendUsed {
                    backendTag(backend)
                }
                Text("\(index + 1). \(step.action.toolCall.name)")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text(step.verified ? "已验证" : "未验证")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(step.verified ? .green : .orange)
            }
            // Permission error display
            if let permError = step.permissionError, !permError.isEmpty {
                cuPermissionErrorView(permError)
            }
            if !step.verified {
                HStack(spacing: 8) {
                    if onRetryComputerUseStep != nil {
                        Button("重试") {
                            onRetryComputerUseStep?(step.action.toolCall.id)
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    if onApproveComputerUseStep != nil {
                        Button("强制通过") {
                            onApproveComputerUseStep?(step.action.toolCall.id)
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    if onTriggerRecovery != nil {
                        Button("恢复") {
                            onTriggerRecovery?(step.action.toolCall.id)
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.orange)
                    }
                }
            }
            if let recoveryStrategy = step.recoveryStrategy, !recoveryStrategy.isEmpty {
                detailLine(title: "策略", value: recoveryStrategy)
            }
            if let stateDelta = step.stateDelta {
                detailLine(title: "变化", value: stateDelta.summary)
            }
            if !step.verificationEvidence.isEmpty {
                detailLine(title: "证明", value: step.verificationEvidence.joined(separator: "；"))
            }
            if let recoverySummary = step.recoverySummary, !recoverySummary.isEmpty {
                detailLine(title: "恢复", value: recoverySummary)
            }
            if let recoveryFrom = step.recoveryFromBackend {
                detailLine(title: "切换", value: "从 \(recoveryFrom) 切换到当前后端")
            }
        }
        .padding(8)
        .background(step.permissionError != nil ? Color.red.opacity(0.03) : Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func cuPermissionErrorView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                Text("权限不足")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.red)
            }
            Text(text)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func statusPill(_ status: AgentTaskStatus) -> some View {
        Text(status.rawValue)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(statusColor(status).opacity(0.15)))
            .foregroundColor(statusColor(status))
    }

    private func backendTag(_ text: String) -> some View {
        let color: Color = {
            if text.hasPrefix("AX") { return .blue }
            if text.hasPrefix("DOM") { return .green }
            if text.hasPrefix("Vision") { return .purple }
            return .secondary
        }()
        return Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundColor(color)
    }

    private func miniTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
            .foregroundColor(.secondary)
    }

    private func statusColor(_ status: AgentTaskStatus) -> Color {
        switch status {
        case .queued: return .secondary
        case .running: return .blue
        case .waitingForConfirmation: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        case .paused: return .yellow
        }
    }

    private var selectedTask: DeveloperAgentTask? {
        guard let selectedDeveloperTaskID else { return nil }
        return developerTasks.first(where: { $0.id == selectedDeveloperTaskID })
    }

    private func developerTaskDetail(_ task: DeveloperAgentTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("任务详情")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                if task.status == .running {
                    Button("停止") {
                        onStopDeveloperTask?(task.id)
                    }
                    .font(.system(size: 11))
                } else if task.status == .waitingForConfirmation {
                    Button("批准并继续") {
                        onApproveDeveloperTask?(task.id)
                    }
                    .font(.system(size: 11))
                } else if task.status == .failed || task.status == .cancelled || task.status == .completed {
                    Button("重试") {
                        onRetryDeveloperTask?(task.id)
                    }
                    .font(.system(size: 11))
                }
            }

            HStack(spacing: 10) {
                Text("重试 \(task.retryCount)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                if let exitCode = task.exitCode {
                    Text("退出码 \(exitCode)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                if let finishedAt = task.finishedAt {
                    Text(finishedAt, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            if !task.changedFiles.isEmpty {
                detailTagSection(title: "变更文件", items: task.changedFiles)
            }

            if !task.commandsRun.isEmpty {
                detailTagSection(title: "执行命令", items: task.commandsRun)
            }

            if let pendingApprovalSummary = task.pendingApprovalSummary, !pendingApprovalSummary.isEmpty {
                detailLine(title: "待批准", value: pendingApprovalSummary)
            }

            if let resultSummary = task.resultSummary, !resultSummary.isEmpty {
                detailLine(title: "结果", value: resultSummary)
            }

            if let buildSummary = task.buildSummary, !buildSummary.isEmpty {
                detailLine(title: "构建", value: buildSummary)
            }

            if let testSummary = task.testSummary, !testSummary.isEmpty {
                detailLine(title: "测试", value: testSummary)
            }

            if task.status == .failed {
                rootCauseSection(task)
            }

            if !task.events.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近事件")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    ForEach(task.events.suffix(5)) { event in
                        HStack(alignment: .top, spacing: 8) {
                            Text(event.kind)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 52, alignment: .leading)
                            Text(event.summary)
                                .font(.system(size: 10))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(2)
                        }
                    }
                }
            }

            ScrollView {
                Text(task.output.isEmpty ? "任务还没有输出。" : task.output)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 80, maxHeight: 180)
            .padding(8)
            .background(Color.black.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.top, 4)
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 10))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rootCauseSection(_ task: DeveloperAgentTask) -> some View {
        let causes = extractRootCauses(from: task)
        guard !causes.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Label("根因分析", systemImage: "magnifyingglass.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red)
                    Spacer()
                    if onTriggerRecovery != nil {
                        Button("触发恢复") {
                            onTriggerRecovery?(task.id.uuidString)
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.orange)
                    }
                }
                ForEach(causes.prefix(5), id: \.self) { cause in
                    HStack(alignment: .top, spacing: 6) {
                        Text(cause.icon)
                            .font(.system(size: 10))
                        Text(cause.description)
                            .font(.system(size: 10))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                    }
                }
            }
            .padding(8)
            .background(Color.red.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        )
    }

    private struct RootCause: Hashable {
        let icon: String
        let description: String
    }

    private func extractRootCauses(from task: DeveloperAgentTask) -> [RootCause] {
        var causes: [RootCause] = []
        let output = task.output

        if let buildSummary = task.buildSummary, buildSummary.contains("失败") {
            let errorLines = output.components(separatedBy: "\n").filter {
                $0.contains("error:") || $0.contains("错误:") || $0.contains("❌")
            }
            if let first = errorLines.first {
                causes.append(RootCause(icon: "🔨", description: "构建失败: \(first.prefix(120))"))
            } else {
                causes.append(RootCause(icon: "🔨", description: "构建失败: \(buildSummary)"))
            }
        }

        if let testSummary = task.testSummary, testSummary.contains("失败") {
            let failLines = output.components(separatedBy: "\n").filter {
                $0.contains("XCTAssert") || $0.contains("test") && $0.contains("failed")
            }
            if let first = failLines.first {
                causes.append(RootCause(icon: "🧪", description: "测试失败: \(first.prefix(120))"))
            } else {
                causes.append(RootCause(icon: "🧪", description: "测试失败: \(testSummary)"))
            }
        }

        if let exitCode = task.exitCode, exitCode != 0, task.buildSummary == nil, task.testSummary == nil {
            causes.append(RootCause(icon: "💻", description: "进程退出码: \(exitCode)"))
        }

        if task.status == .failed && causes.isEmpty {
            let lastLines = output.components(separatedBy: "\n").suffix(3).filter { !$0.isEmpty }
            for line in lastLines {
                causes.append(RootCause(icon: "⚠️", description: String(line.prefix(150))))
            }
        }

        return causes
    }

    private func detailTagSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            ForEach(items.prefix(6), id: \.self) { item in
                Text(item)
                    .font(.system(size: 10, design: .monospaced))
                    .lineLimit(1)
            }
        }
    }
}
