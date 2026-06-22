import RenJistrolyIntelligence
import RenJistrolyModels
import SwiftUI

public struct FoundationCenterView: View {
    @ObservedObject var controller: AssistantSessionController

    public init(controller: AssistantSessionController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("基础中心")
                    .font(.title2.bold())
                Spacer()
                Button {
                    Task { await controller.refreshFoundationState() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                Button {
                    controller.reportCurrentProblem()
                } label: {
                    Label("记录问题", systemImage: "exclamationmark.bubble")
                }
                Button {
                    controller.createSelfOptimizationPlan()
                } label: {
                    Label("生成升级计划", systemImage: "wand.and.stars")
                }
                Button {
                    controller.createBaseVersionBackup()
                } label: {
                    Label("创建基础版", systemImage: "archivebox")
                }
                Button {
                    controller.restoreBaseVersion()
                } label: {
                    Label("恢复基础版", systemImage: "arrow.uturn.backward")
                }
                .tint(.orange)
            }

            if !controller.foundationMessage.isEmpty {
                Text(controller.foundationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    FoundationLayerSection(layers: controller.foundationLayers)
                    ScenarioAuditSection(report: controller.scenarioAuditReport)
                    ComputerUseSection(controller: controller)
                    TerminalTaskSection(controller: controller)
                    ComputerUsePolicySection()
                    DiagnosticsSection(diagnostics: controller.recentDiagnostics)
                    FeedbackSection(feedback: controller.recentFeedback)
                    MemorySection(memories: controller.userMemories)
                    ProviderHealthSection(controller: controller)
                    UpgradePlanSection(plans: controller.upgradePlans)
                }
                .padding(.bottom, 16)
            }
        }
        .padding(16)
        .task {
            await controller.refreshFoundationState()
        }
    }
}

private struct ScenarioAuditSection: View {
    let report: ScenarioAuditReport

    var body: some View {
        GroupBox("1200 场景覆盖审计") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("覆盖率 \(report.summary.coveragePercent)%")
                        .font(.headline)
                    Spacer()
                    Text("实测 \(report.summary.verified)")
                    Text("实现 \(report.summary.implemented)")
                    Text("部分 \(report.summary.partial)")
                    Text("缺失 \(report.summary.missing)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 8)], spacing: 8) {
                    ForEach(report.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.domain.title)
                                    .font(.caption.bold())
                                Spacer()
                                Text(item.status.title)
                                    .font(.caption2.bold())
                                    .foregroundStyle(color(for: item.status))
                            }
                            Text(item.title)
                                .font(.caption)
                                .lineLimit(2)
                            Text(item.evidence)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text(item.nextFix)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(8)
                        .background(.quaternary.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(6)
        }
    }

    private func color(for status: ScenarioCoverageStatus) -> Color {
        switch status {
        case .verified: .green
        case .implemented: .blue
        case .partial: .orange
        case .missing: .red
        }
    }
}

private struct ComputerUseSection: View {
    @ObservedObject var controller: AssistantSessionController

    var body: some View {
        GroupBox("Computer Use 闭环") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button {
                        controller.observeComputerUse()
                    } label: {
                        Label("观察电脑", systemImage: "eye")
                    }
                    Spacer()
                    if let result = controller.lastComputerUseResult {
                        Text(result.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if let observation = controller.lastComputerUseObservation {
                    Text("运行中 App：\(observation.runningApps.count) 个，可见窗口：\(observation.visibleWindows.count) 个，目标：\(observation.targets.count) 个")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 6) {
                        ForEach(observation.targets.prefix(16)) { target in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(target.label)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                Text("\(target.kind.title)\(target.owner.map { " · \($0)" } ?? "")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(6)
                            .background(.quaternary.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                } else {
                    EmptyText("还没有观察快照。")
                }

                if let plan = controller.lastComputerUsePlan {
                    Divider()
                    Text("最近计划：\(plan.reason)")
                        .font(.caption.bold())
                    Text(plan.action?.humanPreview ?? plan.steps.map { $0.action.humanPreview }.joined(separator: " -> "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let result = controller.lastComputerUseResult, !result.stepResults.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(result.stepResults.enumerated()), id: \.element.id) { index, stepResult in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: stepResult.verified ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(stepResult.verified ? .green : .orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(index + 1). \(stepResult.step.action.humanPreview)")
                                            .font(.caption2.bold())
                                        Text(stepResult.note)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(6)
        }
    }
}

private struct TerminalTaskSection: View {
    @ObservedObject var controller: AssistantSessionController
    @State private var name = "dev"
    @State private var command = "swift test"
    @State private var workingDirectory = "\(NSHomeDirectory())/RenJistroly"

    var body: some View {
        GroupBox("终端任务中心") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("任务名", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)
                    TextField("工作目录", text: $workingDirectory)
                        .textFieldStyle(.roundedBorder)
                    TextField("命令", text: $command)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        controller.createTerminalTask(name: name, command: command, workingDirectory: workingDirectory)
                    } label: {
                        Label("启动", systemImage: "terminal")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button {
                        controller.refreshTerminalTasks()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }

                if controller.terminalTasks.isEmpty {
                    EmptyText("还没有终端任务。")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 8)], spacing: 8) {
                        ForEach(controller.terminalTasks.prefix(12)) { task in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(task.name)
                                        .font(.caption.bold())
                                    Spacer()
                                    Text(task.status.title)
                                        .font(.caption2.bold())
                                        .foregroundStyle(color(for: task.status))
                                }
                                Text(task.command)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .textSelection(.enabled)
                                Text(task.workingDirectory)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                if !task.lastMessage.isEmpty {
                                    Text(task.lastMessage)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 8) {
                                    if let pid = task.pid {
                                        Text("PID \(pid)")
                                    }
                                    if let exitCode = task.exitCode {
                                        Text("Exit \(exitCode)")
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                if let output = task.outputTail, !output.isEmpty {
                                    Text(output)
                                        .font(.system(.caption2, design: .monospaced))
                                        .lineLimit(6)
                                        .textSelection(.enabled)
                                }
                                HStack {
                                    Button {
                                        controller.openTerminalTaskLog(id: task.id)
                                    } label: {
                                        Label("日志", systemImage: "doc.text")
                                    }
                                    Button {
                                        controller.restartTerminalTask(id: task.id)
                                    } label: {
                                        Label("重启", systemImage: "arrow.triangle.2.circlepath")
                                    }
                                    Button {
                                        controller.stopTerminalTask(id: task.id)
                                    } label: {
                                        Label("停止", systemImage: "stop.circle")
                                    }
                                    .disabled(task.status != .running)
                                }
                                .font(.caption)
                            }
                            .padding(8)
                            .background(.quaternary.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding(6)
        }
    }

    private func color(for status: TerminalTaskStatus) -> Color {
        switch status {
        case .pending, .waiting: .orange
        case .running: .green
        case .succeeded: .blue
        case .failed: .red
        case .cancelled: .secondary
        }
    }
}

private struct ComputerUsePolicySection: View {
    var body: some View {
        GroupBox("Computer Use 确认策略") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 8)], spacing: 8) {
                ForEach(ComputerUsePolicyCatalog.rules) { rule in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(rule.title)
                                .font(.caption.bold())
                            Spacer()
                            Text(rule.mode.title)
                                .font(.caption2)
                                .foregroundStyle(color(for: rule.mode))
                        }
                        Text(rule.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(6)
                    .background(.quaternary.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(6)
        }
    }

    private func color(for mode: ComputerUseConfirmationMode) -> Color {
        switch mode {
        case .noConfirmation: .green
        case .preApprovalWorks: .orange
        case .alwaysConfirm: .red
        case .handOffRequired: .purple
        }
    }
}

private struct FoundationLayerSection: View {
    let layers: [FoundationLayerSnapshot]

    var body: some View {
        GroupBox("1～12 层基础状态") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 8)], spacing: 8) {
                ForEach(layers) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(item.layer.rawValue). \(item.layer.title)")
                                .font(.headline)
                            Spacer()
                            Text(item.status.label)
                                .font(.caption.bold())
                                .foregroundStyle(color(for: item.status))
                        }
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(6)
        }
    }

    private func color(for status: FoundationHealthStatus) -> Color {
        switch status {
        case .ok: .green
        case .warning: .orange
        case .failing: .red
        case .notImplemented: .secondary
        }
    }
}

private struct DiagnosticsSection: View {
    let diagnostics: [AssistantDiagnosticSnapshot]

    var body: some View {
        GroupBox("最近诊断") {
            if diagnostics.isEmpty {
                EmptyText("暂无诊断。")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(diagnostics.prefix(5)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.userText)
                                .font(.headline)
                                .lineLimit(2)
                            Text(item.assistantText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            HStack {
                                Text(item.provider)
                                if let latency = item.latencyMilliseconds {
                                    Text("\(latency)ms")
                                }
                                if let action = item.parsedAction {
                                    Text(action)
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                }
                .padding(6)
            }
        }
    }
}

private struct FeedbackSection: View {
    let feedback: [FeedbackReport]

    var body: some View {
        GroupBox("反馈闭环") {
            if feedback.isEmpty {
                EmptyText("暂无反馈。")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(feedback.prefix(5)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(item.category.title)：\(item.userComplaint)")
                                .font(.headline)
                                .lineLimit(2)
                            Text(item.proposedFix)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                }
                .padding(6)
            }
        }
    }
}

private struct MemorySection: View {
    let memories: [UserOperationMemory]

    var body: some View {
        GroupBox("用户记忆") {
            if memories.isEmpty {
                EmptyText("暂无记忆。")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(memories.prefix(8)) { item in
                        HStack {
                            Text(item.key)
                                .font(.headline)
                            Text("->")
                                .foregroundStyle(.secondary)
                            Text(item.value)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(item.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(6)
            }
        }
    }
}

private struct ProviderHealthSection: View {
    @ObservedObject var controller: AssistantSessionController

    var body: some View {
        GroupBox("Provider 健康") {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    controller.runProviderHealthCheck()
                } label: {
                    Label("检查 Provider", systemImage: "stethoscope")
                }

                if controller.providerHealth.isEmpty {
                    EmptyText("暂无 Provider 检查结果。")
                } else {
                    ForEach(controller.providerHealth) { item in
                        HStack {
                            Text(item.kind.title)
                            Spacer()
                            if let latency = item.latencyMilliseconds {
                                Text("\(latency)ms")
                            }
                            Text(item.status.label)
                                .foregroundStyle(item.status == .ok ? .green : .orange)
                        }
                        .font(.caption)
                        Text(item.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(6)
        }
    }
}

private struct UpgradePlanSection: View {
    let plans: [UpgradePlan]

    var body: some View {
        GroupBox("自优化升级计划") {
            if plans.isEmpty {
                EmptyText("暂无升级计划。")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(plans.prefix(5)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Text(item.steps.joined(separator: " / "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        Divider()
                    }
                }
                .padding(6)
            }
        }
    }
}

private struct EmptyText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
