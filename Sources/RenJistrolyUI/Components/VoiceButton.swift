import SwiftUI
import RenJistrolyModels

/// 两个录音按钮：按住录音 + 连续录音
@MainActor
public struct VoiceButton: View {
    @Environment(AppState.self) private var appState

    let onStart: () -> Void
    let onFinish: () -> Void
    let onToggle: () -> Void

    public init(onStart: @escaping () -> Void, onFinish: @escaping () -> Void, onToggle: @escaping () -> Void) {
        self.onStart = onStart
        self.onFinish = onFinish
        self.onToggle = onToggle
    }

    public var body: some View {
        HStack(spacing: 4) {
            pushToTalkButton
            alwaysOnButton
        }
        .frame(width: 76, height: 34)
        .contentShape(Rectangle())
    }

    // MARK: - 按住说话（Push-to-Talk）

    private var pushToTalkButton: some View {
        let start = onStart
        let finish = onFinish
        return Button {
            if appState.voiceState.canFinishListening {
                finish()
            } else {
                start()
            }
        } label: {
            Image(systemName: appState.voiceState.isCapturingAudio ? "mic.fill" : "mic")
                .font(.system(size: 14))
                .foregroundColor(appState.voiceState.isCapturingAudio ? .blue : .secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .background(Color.secondary.opacity(0.001))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(appState.voiceState.canFinishListening ? "停止录音" : "开始录音")
        .accessibilityHint("点按开始或停止录音")
        .accessibilityIdentifier("primaryVoiceButton")
        .help("点按开始或停止录音")
    }

    // MARK: - 连续说话（Always-On）

    private var alwaysOnButton: some View {
        Button {
            onToggle()
        } label: {
            Image(systemName: alwaysOnIcon)
                .font(.system(size: 14))
                .foregroundColor(alwaysOnColor)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .background(Color.secondary.opacity(0.001))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("实时对话")
        .accessibilityHint("点按开启或关闭连续对话")
        .accessibilityIdentifier("conversationVoiceButton")
        .help("点按开启或关闭连续对话")
    }

    private var alwaysOnIcon: String {
        switch appState.voiceState {
        case .idle, .failed, .requestingPermission:
            return "mic.badge.plus"
        case .listening, .lockedListening:
            return "waveform"
        case .transcribing, .processing:
            return "waveform"
        case .speaking:
            return "speaker.wave.2"
        }
    }

    private var alwaysOnColor: Color {
        if appState.voiceState.isCapturingAudio {
            return .blue
        }
        return .secondary
    }

    /// 底部状态标签
    public var statusBadge: some View {
        Group {
            if appState.voiceState.isCapturingAudio {
                Text("聆听中...")
                    .font(.system(size: 9))
                    .foregroundColor(.blue)
            } else {
                Text("按住🎤说话 · 点按🎤+实时对话")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
}
