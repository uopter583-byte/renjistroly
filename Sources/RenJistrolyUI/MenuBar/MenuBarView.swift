import SwiftUI
import RenJistrolyIntelligence
import RenJistrolyModels
import RenJistrolyConversation

public struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(ConversationEngine.self) private var engine

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusSection
            Divider()
            quickActionsSection
            Divider()
            conversationList
            Divider()
            providerSection
            Divider()
            bottomSection
        }
        .frame(width: 280)
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentColor)
                Text("RenJistroly")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                StatusDot(color: appState.isOnline ? .green : .red)
            }

            if let title = engine.sessionManager.activeConversation?.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            MenuBarRow(icon: "plus.bubble", title: "新建对话") {
                _ = engine.sessionManager.createConversation()
            }

            MenuBarRow(icon: "rectangle.3.group", title: "打开主窗口") {
                appState.mode = .immersive
            }

            MenuBarRow(icon: appState.voiceState.isCapturingAudio ? "mic.fill" : "mic", title: "语音输入") {
                if appState.voiceState.canStartListening {
                    Task { await engine.startVoiceInput(appState: appState) }
                } else if appState.voiceState.canFinishListening {
                    Task { await engine.finishVoiceInputAndSend(appState: appState) }
                } else {
                    engine.cancelVoiceInput(appState: appState)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Recent Conversations

    private var conversationList: some View {
        let recent = engine.sessionManager.conversations
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(5)
        return VStack(alignment: .leading, spacing: 1) {
            SectionHeader(title: "最近对话", icon: "clock")
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 2)

            if recent.isEmpty {
                Text("暂无对话")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            } else {
                ForEach(Array(recent)) { conv in
                    MenuBarRow(icon: conv.metadata.isPinned ? "pin.fill" : "bubble.left", title: conv.title) {
                        engine.sessionManager.setActiveConversation(conv.id)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Provider

    private var providerSection: some View {
        Menu {
            ForEach(LLMProvider.allCases, id: \.self) { provider in
                Button {
                    appState.activeProvider = provider
                    syncControllerProvider(to: provider)
                } label: {
                    HStack {
                        Text(provider.displayName)
                        if appState.activeProvider == provider {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: appState.activeProvider.isLocal ? "cpu" : "cloud")
                    .font(.system(size: 11))
                Text("模型: \(appState.activeProvider.displayName)")
                    .font(.system(size: 11))
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom

    private var bottomSection: some View {
        HStack(spacing: 0) {
            MenuBarRow(icon: "gearshape", title: "设置") {
                NSApp.sendAction(Selector(("showSettingsWindow")), to: nil, from: nil)
            }

            Spacer()

            MenuBarRow(icon: "power", title: "退出")
                .foregroundColor(.red)
                .onTapGesture { NSApp.terminate(nil) }

            Spacer()

            MenuBarRow(icon: "questionmark.circle", title: "关于") {
                NSApp.orderFrontStandardAboutPanel()
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private func syncControllerProvider(to provider: LLMProvider) {
        let pref: ProviderPreference = switch provider {
        case .claudeCodeCLI: .claudeCode
        case .deepseek: .deepSeek
        case .localMLX, .ollama: .localEndpoint
        case .custom: .localFirst
        default: .deepSeek
        }
        if AssistantSessionController.shared.providerPreference != pref {
            AssistantSessionController.shared.providerPreference = pref
        }
    }
}

private struct MenuBarRow: View {
    let icon: String
    let title: String
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
