import RenJistrolyIntelligence
import RenJistrolyModels
import SwiftUI

public struct PermissionsView: View {
    @ObservedObject var controller: AssistantSessionController

    public init(controller: AssistantSessionController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("权限中心")
                    .font(.title2.bold())
                Spacer()
                Button {
                    controller.restartInstalledApp()
                } label: {
                    Label("重启稳定版", systemImage: "arrow.triangle.2.circlepath")
                }
                Button {
                    controller.refreshPermissions()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                Button {
                    controller.requestAllPermissions()
                } label: {
                    Label("请求全部", systemImage: "checkmark.shield")
                }
                .buttonStyle(.borderedProminent)
            }

            Text(controller.installedAppPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GroupBox("Codex 完全访问能力") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(controller.fullAccessCapabilities) { capability in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: icon(for: capability.status))
                                        .foregroundStyle(color(for: capability.status))
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(capability.kind.title)
                                                .font(.headline)
                                            Text(capability.status.label)
                                                .font(.caption2)
                                                .foregroundStyle(color(for: capability.status))
                                        }
                                        Text(capability.kind.codexEquivalent)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(capability.detail)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let firstPermission = capability.requiredPermissions.first {
                                        Button {
                                            controller.openSettings(for: firstPermission)
                                        } label: {
                                            Label("设置", systemImage: "gear")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    GroupBox("macOS 原生辅助功能接入") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 8)], spacing: 8) {
                            ForEach(controller.nativeAccessibilityFeatures) { feature in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(feature.kind.title)
                                            .font(.headline)
                                        Spacer()
                                        Text(feature.mode.title)
                                            .font(.caption2.bold())
                                            .foregroundStyle(color(for: feature.mode))
                                    }
                                    Text(feature.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(4)
                                    Button {
                                        controller.openNativeAccessibilitySetting(feature.kind)
                                    } label: {
                                        Label("打开系统设置", systemImage: "gearshape")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(8)
                                .background(.quaternary.opacity(0.35))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(6)
                    }

                    List(controller.permissions) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.status.isGranted ? "checkmark.circle.fill" : "exclamationmark.circle")
                                .foregroundStyle(item.status.isGranted ? .green : .orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.kind.title)
                                    .font(.headline)
                                Text(item.kind.purpose)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !item.detail.isEmpty {
                                    Text(item.detail)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(item.status.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("请求") {
                                controller.request(item.kind)
                            }
                            Button {
                                controller.openSettings(for: item.kind)
                            } label: {
                                Image(systemName: "gear")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 6)
                    }
                    .frame(minHeight: 200)
                }
            }
        }
        .padding(16)
    }

    private func icon(for status: FoundationHealthStatus) -> String {
        switch status {
        case .ok: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .failing: "xmark.octagon.fill"
        case .notImplemented: "minus.circle.fill"
        }
    }

    private func color(for status: FoundationHealthStatus) -> Color {
        switch status {
        case .ok: .green
        case .warning: .orange
        case .failing: .red
        case .notImplemented: .gray
        }
    }

    private func color(for mode: NativeAccessibilityIntegrationMode) -> Color {
        switch mode {
        case .direct: .green
        case .assisted: .blue
        case .settingsOnly: .secondary
        }
    }
}
