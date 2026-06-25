import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Tab = .controlPanel
    private let overallRiskLevel: RiskLevel = .medium
    private let activeModeCount = 7
    private let totalModeCount = 10

    public enum Tab: String, CaseIterable {
        case controlPanel
        case auditLog
        case dashboard

        var icon: String {
            switch self {
            case .controlPanel: "switch.2"
            case .auditLog: "list.bullet.clipboard"
            case .dashboard: "gauge.with.dots.needle.33percent"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            contentView
            Divider()
            statusBar
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        Text(RenJistrolyStrings.text("mainTab\(tab.rawValue)"))
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.08) : .clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .controlPanel:
            ModeControlPanel()
        case .auditLog:
            ActionAuditView()
        case .dashboard:
            ContextDashboard()
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Circle()
                    .fill(overallRiskLevel.color)
                    .frame(width: 6, height: 6)
                Text(overallRiskLevel.label)
                    .font(.caption2)
            }
            .foregroundStyle(overallRiskLevel.color)

            Text(String(format: RenJistrolyStrings.text("mainTabModeCountFormat"), activeModeCount, totalModeCount))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 4) {
                Circle().fill(.green).frame(width: 5, height: 5)
                Text("RenJistroly Enterprise v0.1")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

#if DEBUG
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .frame(width: 750, height: 600)
    }
}
#endif
