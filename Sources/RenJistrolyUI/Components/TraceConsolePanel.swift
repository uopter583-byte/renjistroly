import RenJistrolyIntelligence
import RenJistrolyModels
import SwiftUI

public struct TraceConsolePanel: View {
    @ObservedObject var controller: AssistantSessionController

    public init(controller: AssistantSessionController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let summary = controller.recentTraces.first {
                currentTraceSection(summary)
            } else {
                Text("等待首次交互...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }

            if controller.recentTraces.count > 1 {
                Divider()
                historySection
            }
        }
        .padding(12)
    }

    private func currentTraceSection(_ summary: TraceLatencySummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("最近一轮")
                    .font(.caption.weight(.semibold))
                Spacer()
                if let total = summary.totalMs {
                    Text("总耗时 \(total)ms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            latencyRow("语音识别", ms: summary.asrMs)
            latencyRow("上下文采集", ms: summary.observeMs)
            latencyRow("路由选择", ms: summary.routingMs)
            latencyRow("首 Token", ms: summary.firstTokenMs)
            latencyRow("工具执行", ms: summary.toolMs)
            latencyRow("朗读启动", ms: summary.ttsMs)
        }
    }

    private func latencyRow(_ label: String, ms: Int?) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            if let ms {
                RoundedRectangle(cornerRadius: 2)
                    .fill(latencyColor(ms))
                    .frame(width: barWidth(ms), height: 8)
                Text("\(ms)ms")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(latencyColor(ms))
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 4, height: 8)
                Text("--")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("最近 \(controller.recentTraces.count) 轮")
                .font(.caption.weight(.semibold))
                .padding(.bottom, 2)

            ForEach(Array(controller.recentTraces.prefix(10).enumerated()), id: \.offset) { i, summary in
                HStack(spacing: 6) {
                    Text("#\(i + 1)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .leading)
                    if let total = summary.totalMs {
                        Text("\(total)ms")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(latencyColor(total))
                    }
                    if let ttft = summary.firstTokenMs {
                        Text("首Token \(ttft)ms")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let tool = summary.toolMs {
                        Text("工具 \(tool)ms")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    private func latencyColor(_ ms: Int) -> Color {
        ms < 200 ? .green : ms < 500 ? .orange : .red
    }

    private func barWidth(_ ms: Int) -> CGFloat {
        let clamped = min(ms, 2000)
        return max(8, CGFloat(clamped) / 2000 * 120)
    }
}

public struct TraceLatencyBar: View {
    @ObservedObject var controller: AssistantSessionController

    public init(controller: AssistantSessionController) {
        self.controller = controller
    }

    public var body: some View {
        if let summary = controller.recentTraces.first, let total = summary.totalMs {
            HStack(spacing: 3) {
                latencyDot(summary.asrMs)
                latencyDot(summary.observeMs)
                latencyDot(summary.routingMs)
                latencyDot(summary.firstTokenMs)
                latencyDot(summary.toolMs)
                latencyDot(summary.ttsMs)
                Text("\(total)ms")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        } else {
            EmptyView()
        }
    }

    private func latencyDot(_ ms: Int?) -> some View {
        Circle()
            .fill(ms.map { $0 < 200 ? Color.green : $0 < 500 ? Color.orange : Color.red } ?? Color.secondary.opacity(0.2))
            .frame(width: 5, height: 5)
    }
}
