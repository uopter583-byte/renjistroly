import SwiftUI
import RenJistrolyModels
import RenJistrolyConversation

struct PlanCard: View {
    @Environment(ConversationEngine.self) private var engine
    @Environment(AppState.self) private var appState

    var body: some View {
        if let plan = appState.activePlan {
            VStack(alignment: .leading, spacing: 10) {
                header(plan)
                Divider()
                stepsList(plan)
                if plan.status == .pendingApproval {
                    approvalButtons
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
                    .shadow(color: .black.opacity(0.08), radius: 4)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private func header(_ plan: ExecutionPlan) -> some View {
        HStack {
            Image(systemName: statusIcon(plan.status))
                .foregroundColor(statusColor(plan.status))
            Text(plan.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            Spacer()
            if plan.status == .executing {
                Text("\(plan.currentStepIndex + 1)/\(plan.steps.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
            }
        }
    }

    private func stepsList(_ plan: ExecutionPlan) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(plan.steps.enumerated()), id: \.element.id) { idx, step in
                HStack(spacing: 8) {
                    stepIndicator(idx: idx, step: step, isCurrent: idx == plan.currentStepIndex)
                    Text(step.description)
                        .font(.system(size: 12.5))
                        .foregroundColor(step.status == .skipped ? .secondary : .primary)
                        .strikethrough(step.status == .skipped)
                    Spacer()
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(
                    idx == plan.currentStepIndex && plan.status == .executing
                        ? Color.accentColor.opacity(0.08)
                        : Color.clear
                )
                .cornerRadius(6)
            }
        }
    }

    private func stepIndicator(idx: Int, step: PlanStep, isCurrent: Bool) -> some View {
        Group {
            switch step.status {
            case .pending:
                Text("\(idx + 1)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.secondary.opacity(0.1)))
            case .executing:
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 20, height: 20)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
            case .skipped:
                Image(systemName: "circle.dashed")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
        }
    }

    private var approvalButtons: some View {
        HStack(spacing: 12) {
            Button {
                engine.cancelPlan(appState: appState)
            } label: {
                Text("取消")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(6)

            Button {
                Task { await engine.approvePlan(appState: appState) }
            } label: {
                Text("批准执行")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(6)
        }
        .font(.system(size: 12, weight: .medium))
    }

    private func statusIcon(_ status: PlanStatus) -> String {
        switch status {
        case .drafting, .pendingApproval: return "text.justify.left"
        case .approved, .executing: return "play.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        case .cancelled: return "stop.circle"
        }
    }

    private func statusColor(_ status: PlanStatus) -> Color {
        switch status {
        case .drafting, .pendingApproval: return .orange
        case .approved, .executing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }
}
