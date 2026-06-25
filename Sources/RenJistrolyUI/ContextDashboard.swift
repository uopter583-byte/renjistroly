import SwiftUI

// MARK: - Model

struct WindowInfo: Identifiable {
    let id = UUID()
    let title: String
    let appName: String
    let isFocused: Bool
}

struct ClipboardWarning: Identifiable {
    let id = UUID()
    let type: String
    let preview: String
    let riskLevel: RiskLevel
    let timestamp: Date
}

struct PermissionStatus: Identifiable {
    let id: String
    let title: String
    let granted: Bool
    let lastChecked: Date
}

struct DevContext {
    let branch: String
    let hasUncommitted: Bool
    let uncommittedCount: Int
    let testStatus: TestStatus
}

enum TestStatus {
    case passed, running, failed(count: Int)

    var color: Color {
        switch self {
        case .passed: .green
        case .running: .orange
        case .failed: .red
        }
    }

    var label: String {
        switch self {
        case .passed: RenJistrolyStrings.text("dashboardCheckPassed")
        case .running: RenJistrolyStrings.text("dashboardCheckRunning")
        case .failed(let c): String(format: RenJistrolyStrings.text("dashboardCheckFailed"), c)
        }
    }
}

// MARK: - View

public struct ContextDashboard: View {
    @State private var windows: [WindowInfo] = Self.sampleWindows()
    @State private var clipboardWarnings: [ClipboardWarning] = Self.sampleWarnings()
    @State private var permissions: [PermissionStatus] = Self.samplePermissions()
    @State private var devContext = DevContext(branch: "feature/enterprise-ui", hasUncommitted: true, uncommittedCount: 3, testStatus: .passed)

    private static func sampleWindows() -> [WindowInfo] {
        [
            WindowInfo(title: "RenJistroly – 主窗口", appName: "RenJistroly", isFocused: true),
            WindowInfo(title: "Terminal – swift build", appName: "Terminal", isFocused: false),
            WindowInfo(title: "Xcode – RenJistrolyUI", appName: "Xcode", isFocused: false),
        ]
    }

    private static func sampleWarnings() -> [ClipboardWarning] {
        [
            ClipboardWarning(type: "文本", preview: "git token ghp_xxxx…", riskLevel: .high, timestamp: Date().addingTimeInterval(-60)),
            ClipboardWarning(type: "图片", preview: "截屏_2026-06-19 含敏感信息", riskLevel: .medium, timestamp: Date().addingTimeInterval(-300)),
        ]
    }

    private static func samplePermissions() -> [PermissionStatus] {
        [
            PermissionStatus(id: "ax", title: "辅助功能 (AX API)", granted: true, lastChecked: Date().addingTimeInterval(-30)),
            PermissionStatus(id: "screen", title: "屏幕录制", granted: true, lastChecked: Date().addingTimeInterval(-60)),
            PermissionStatus(id: "mic", title: "麦克风", granted: false, lastChecked: Date().addingTimeInterval(-120)),
            PermissionStatus(id: "automation", title: "Apple Events", granted: true, lastChecked: Date().addingTimeInterval(-300)),
        ]
    }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    currentContextSection
                    clipboardSection
                    permissionsSection
                    devContextSection
                }
            }
            .padding(16)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(RenJistrolyStrings.text("dashboardTitle"))
                    .font(.title2.bold())
                Text(RenJistrolyStrings.text("dashboardSubtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text(RenJistrolyStrings.text("dashboardRefreshed"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var currentContextSection: some View {
        GroupBox(RenJistrolyStrings.text("dashboardScreenWindow")) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(windows) { win in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(win.isFocused ? Color.green : Color.clear)
                            .frame(width: 6, height: 6)
                            .overlay(Circle().stroke(win.isFocused ? Color.green : Color.gray.opacity(0.4), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(win.title)
                                .font(.caption)
                                .foregroundStyle(win.isFocused ? .primary : .secondary)
                                .lineLimit(1)
                            Text(win.appName)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var clipboardSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(RenJistrolyStrings.text("dashboardClipboardRisk"), systemImage: "exclamationmark.shield")
                        .font(.subheadline.bold())
                    Spacer()
                    if !clipboardWarnings.isEmpty {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }

                if clipboardWarnings.isEmpty {
                    Text(RenJistrolyStrings.text("dashboardClipboardSafe"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(clipboardWarnings) { warning in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(warning.riskLevel.color)
                                .frame(width: 3, height: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(warning.preview)
                                    .font(.caption)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(warning.type)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(warning.riskLevel.label)
                                        .font(.caption2)
                                        .foregroundStyle(warning.riskLevel.color)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var permissionsSection: some View {
        GroupBox(RenJistrolyStrings.text("dashboardPermissions")) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(permissions) { perm in
                    HStack(spacing: 8) {
                        Image(systemName: perm.granted ? "checkmark.shield.fill" : "xmark.shield.fill")
                            .foregroundStyle(perm.granted ? .green : .red)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(perm.title)
                                .font(.caption)
                            Text(RenJistrolyStrings.text("dashboardLastCheck")) + Text(perm.lastChecked, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var devContextSection: some View {
        GroupBox(RenJistrolyStrings.text("dashboardDevContext")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.branch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(devContext.branch)
                        .font(.caption.monospaced())
                    Spacer()
                }

                HStack(spacing: 8) {
                    Label(
                        devContext.hasUncommitted ? "\(devContext.uncommittedCount)\(RenJistrolyStrings.text("dashboardUncommitted"))" : RenJistrolyStrings.text("dashboardWorkspaceClean"),
                        systemImage: devContext.hasUncommitted ? "doc.text" : "checkmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(devContext.hasUncommitted ? .orange : .green)
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(devContext.testStatus.color)
                        .frame(width: 6, height: 6)
                    Text(devContext.testStatus.label)
                        .font(.caption)
                        .foregroundStyle(devContext.testStatus.color)
                }

                Divider()

                Button {
                    // 刷新上下文
                } label: {
                    Label(RenJistrolyStrings.text("dashboardRefreshContext"), systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
        }
    }
}

#if DEBUG
struct ContextDashboard_Previews: PreviewProvider {
    static var previews: some View {
        ContextDashboard()
            .frame(width: 700, height: 500)
    }
}
#endif
