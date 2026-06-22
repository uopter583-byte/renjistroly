import SwiftUI
import UniformTypeIdentifiers

// MARK: - Model

struct AuditEntry: Identifiable {
    let id: String
    let timestamp: Date
    let action: String
    let category: String
    let riskLevel: RiskLevel
    let status: AuditStatus
    let detail: String
}

enum AuditStatus: String {
    case approved, denied, pending, failed

    var color: Color {
        switch self {
        case .approved: .green
        case .denied: .red
        case .pending: .orange
        case .failed: .purple
        }
    }

    var label: String {
        switch self {
        case .approved: "已放行"
        case .denied: "已拦截"
        case .pending: "待审核"
        case .failed: "执行失败"
        }
    }
}

// MARK: - View

public struct ActionAuditView: View {
    @State private var searchText = ""
    @State private var selectedRiskFilter: RiskLevel? = nil
    @State private var logs: [AuditEntry] = Self.sampleLogs()
    @State private var showingExporter = false
    @State private var exportedContent = ""

    private static func sampleLogs() -> [AuditEntry] {
        let now = Date()
        return [
            AuditEntry(id: "1", timestamp: now.addingTimeInterval(-30), action: "读取 ~/Documents/report.pdf", category: "文件访问", riskLevel: .low, status: .approved, detail: "权限内正常读取"),
            AuditEntry(id: "2", timestamp: now.addingTimeInterval(-90), action: "curl https://api.example.com/data", category: "网络请求", riskLevel: .medium, status: .approved, detail: "目标在允许列表"),
            AuditEntry(id: "3", timestamp: now.addingTimeInterval(-150), action: "/usr/bin/osascript -e 'tell app ...'", category: "自动化脚本", riskLevel: .high, status: .denied, detail: "未签名脚本被拦截"),
            AuditEntry(id: "4", timestamp: now.addingTimeInterval(-300), action: "SCCapture entitlement 检查", category: "截屏防护", riskLevel: .high, status: .approved, detail: "应用自有截屏权限"),
            AuditEntry(id: "5", timestamp: now.addingTimeInterval(-600), action: "AX API: 获取窗口列表", category: "辅助功能", riskLevel: .medium, status: .approved, detail: "当前焦点应用窗口"),
            AuditEntry(id: "6", timestamp: now.addingTimeInterval(-1200), action: "剪贴板读取: com.apple.Security", category: "剪贴板监控", riskLevel: .low, status: .pending, detail: "等待策略裁决"),
            AuditEntry(id: "7", timestamp: now.addingTimeInterval(-2400), action: "NSTask: /usr/bin/git push", category: "进程管理", riskLevel: .medium, status: .failed, detail: "远程连接超时"),
            AuditEntry(id: "8", timestamp: now.addingTimeInterval(-3600), action: "AX API: 模拟键盘输入", category: "键盘注入", riskLevel: .low, status: .approved, detail: "用户主动触发"),
        ]
    }

    public init() {}

    public var body: some View {
        let visibleLogs = filteredLogs
        return VStack(alignment: .leading, spacing: 12) {
            header
            filterBar
            summaryBar(logs: visibleLogs)
            logList(logs: visibleLogs)
        }
        .padding(16)
        .fileExporter(
            isPresented: $showingExporter,
            document: TextFile(text: exportedContent),
            contentType: .plainText,
            defaultFilename: "audit-export"
        ) { _ in }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("操作审计")
                    .font(.title2.bold())
                Text("所有安全模式触发的操作记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                exportedContent = buildExportText()
                showingExporter = true
            } label: {
                Label("导出", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索操作记录…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            ForEach(RiskLevel.allCases, id: \.self) { level in
                riskFilterButton(level: level)
            }
        }
    }

    private func summaryBar(logs: [AuditEntry]) -> some View {
        let total = logs.count
        let denied = logs.filter { $0.status == .denied }.count
        let pending = logs.filter { $0.status == .pending }.count

        return HStack(spacing: 16) {
            summaryItem(value: "\(total)", label: "总计", color: .primary)
            Divider().frame(height: 20)
            summaryItem(value: "\(denied)", label: "已拦截", color: .red)
            Divider().frame(height: 20)
            summaryItem(value: "\(pending)", label: "待审核", color: .orange)
        }
        .padding(8)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func riskFilterButton(level: RiskLevel) -> some View {
        let isSelected = selectedRiskFilter == level
        let bg = isSelected ? level.color.opacity(0.15) : Color.clear
        let fg = isSelected ? level.color : Color.secondary
        let border: Color = isSelected ? level.color : .gray.opacity(0.3)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedRiskFilter = isSelected ? nil : level
            }
        } label: {
            Text(level.label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(bg)
                .foregroundStyle(fg)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func logList(logs: [AuditEntry]) -> some View {
        List {
            ForEach(logs) { entry in
                logRow(entry)
                    .listRowSeparator(.visible)
            }
        }
        .listStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func logRow(_ entry: AuditEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.timestamp, style: .time)
                    .font(.caption.monospacedDigit())
                Text(entry.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 70)

            RoundedRectangle(cornerRadius: 2)
                .fill(entry.riskLevel.color)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.action)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(entry.category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(entry.status.label)
                .font(.caption2.bold())
                .foregroundStyle(entry.status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(entry.status.color.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private var filteredLogs: [AuditEntry] {
        logs
            .filter { entry in
                if let level = selectedRiskFilter, entry.riskLevel != level { return false }
                if !searchText.isEmpty {
                    let q = searchText.lowercased()
                    return entry.action.lowercased().contains(q)
                        || entry.category.lowercased().contains(q)
                        || entry.detail.lowercased().contains(q)
                }
                return true
            }
    }

    private func buildExportText() -> String {
        let header = "时间\t操作\t分类\t风险\t状态\t详情"
        let rows = filteredLogs.map { entry in
            let df = ISO8601DateFormatter()
            return "\(df.string(from: entry.timestamp))\t\(entry.action)\t\(entry.category)\t\(entry.riskLevel.label)\t\(entry.status.label)\t\(entry.detail)"
        }
        return ([header] + rows).joined(separator: "\n")
    }
}

// MARK: - FileDocument for export

private struct TextFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String

    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

#if DEBUG
struct ActionAuditView_Previews: PreviewProvider {
    static var previews: some View {
        ActionAuditView()
            .frame(width: 700, height: 500)
    }
}
#endif
