import SwiftUI
import RenJistrolyEnterprise
import os

// MARK: - Model

struct SafetyMode: Identifiable {
    let id: String
    let title: String
    let icon: String
    var enabled: Bool
    var riskLevel: RiskLevel
    var locked: Bool
    var description: String
}

enum RiskLevel: String, CaseIterable {
    case low, medium, high

    var color: Color {
        switch self {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }

    var label: String {
        switch self {
        case .low: "安全"
        case .medium: "警告"
        case .high: "危险"
        }
    }
}

// MARK: - View

public struct ModeControlPanel: View {
    @State private var modes: [SafetyMode] = Self.defaultModes()
    @State private var globalPolicyLocked = true
    @State private var animatedModeId: String?

    private static func defaultModes() -> [SafetyMode] {
        [
            SafetyMode(id: "file-access", title: "文件访问", icon: "doc", enabled: true, riskLevel: .low, locked: true, description: "控制文件读写权限"),
            SafetyMode(id: "network", title: "网络请求", icon: "network", enabled: true, riskLevel: .medium, locked: true, description: "限制对外网络通信"),
            SafetyMode(id: "clipboard", title: "剪贴板监控", icon: "clipboard", enabled: true, riskLevel: .low, locked: false, description: "监控剪贴板内容变化"),
            SafetyMode(id: "screen-capture", title: "截屏防护", icon: "display", enabled: false, riskLevel: .high, locked: false, description: "阻止未经授权的屏幕截取"),
            SafetyMode(id: "microphone", title: "麦克风", icon: "mic", enabled: true, riskLevel: .medium, locked: true, description: "控制麦克风访问时机"),
            SafetyMode(id: "automation", title: "自动化脚本", icon: "gearshape.2", enabled: false, riskLevel: .high, locked: false, description: "阻止未知来源的 AppleEvents"),
            SafetyMode(id: "keyboard", title: "键盘注入", icon: "keyboard", enabled: true, riskLevel: .low, locked: true, description: "过滤模拟键盘输入"),
            SafetyMode(id: "accessibility", title: "辅助功能", icon: "hand.point.up", enabled: true, riskLevel: .medium, locked: true, description: "控制 AX API 调用范围"),
            SafetyMode(id: "location", title: "位置信息", icon: "location", enabled: false, riskLevel: .high, locked: false, description: "阻止位置数据泄露"),
            SafetyMode(id: "process", title: "进程管理", icon: "terminal", enabled: true, riskLevel: .medium, locked: false, description: "控制外部进程执行"),
        ]
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            policyLockBar
            modeGrid
        }
        .padding(16)
        .onAppear {
            syncFromModeManager()
            os_log(.debug, "ModeControlPanel: synced from ModeManager, %d modes active", ModeManager().config.activeModes.count)
        }
    }

    private func syncFromModeManager() {
        let manager = ModeManager()
        for i in modes.indices {
            let opId = modes[i].id.replacingOccurrences(of: "-", with: "")
            if let opMode = OperationMode(rawValue: opId) {
                modes[i].enabled = manager.isActive(opMode)
            }
        }
        globalPolicyLocked = manager.config.lockedModes.contains(.policyLock)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("模式控制面板")
                    .font(.title2.bold())
                Text("安全管理策略配置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("运行中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var policyLockBar: some View {
        HStack {
            Image(systemName: globalPolicyLocked ? "lock.fill" : "lock.open")
                .foregroundStyle(globalPolicyLocked ? .green : .orange)
            Text(globalPolicyLocked ? "策略已锁定" : "策略未锁定")
                .font(.subheadline)
            Spacer()
            Toggle(isOn: $globalPolicyLocked) { }
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(10)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var modeGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
            ForEach(modes) { mode in
                modeCard(mode)
            }
        }
    }

    private func modeCard(_ mode: SafetyMode) -> some View {
        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else {
            return AnyView(EmptyView())
        }
        return AnyView(GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: mode.icon)
                        .font(.title3)
                        .foregroundStyle(mode.riskLevel.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.title)
                            .font(.headline)
                        Text(mode.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    riskBadge(mode.riskLevel)
                }

                HStack {
                    statusIndicator(mode)
                    Spacer()
                    if mode.locked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: Binding(
                    get: { modes[index].enabled },
                    set: { newValue in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            modes[index].enabled = newValue
                            animatedModeId = mode.id
                            let manager = ModeManager()
                            let opId = mode.id.replacingOccurrences(of: "-", with: "")
                            if let opMode = OperationMode(rawValue: opId) {
                                if newValue { manager.activate(opMode) }
                                else { manager.deactivate(opMode) }
                            }
                        }
                        Task {
                            try? await Task.sleep(for: .milliseconds(500))
                            animatedModeId = nil
                        }
                    }
                )) {
                    Text(modes[index].enabled ? "已启用" : "已禁用")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(mode.locked)
                .scaleEffect(animatedModeId == mode.id ? 1.05 : 1.0)
            }
        })
    }

    private func statusIndicator(_ mode: SafetyMode) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(mode.enabled ? mode.riskLevel.color : .gray)
                .frame(width: 8, height: 8)
                .brightness(mode.enabled ? 0 : -0.4)
            Text(mode.enabled ? mode.riskLevel.label : "停用")
                .font(.caption2)
                .foregroundStyle(mode.enabled ? mode.riskLevel.color : .gray)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(mode.enabled ? mode.riskLevel.color.opacity(0.1) : Color.gray.opacity(0.1))
        .clipShape(Capsule())
    }

    private func riskBadge(_ level: RiskLevel) -> some View {
        Text(level.label)
            .font(.caption2.bold())
            .foregroundStyle(level.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(level.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#if DEBUG
struct ModeControlPanel_Previews: PreviewProvider {
    static var previews: some View {
        ModeControlPanel()
            .frame(width: 700, height: 600)
    }
}
#endif
