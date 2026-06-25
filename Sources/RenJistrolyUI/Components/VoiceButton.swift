import SwiftUI
import RenJistrolyModels

/// 两个录音按钮：按住录音 + 连续录音
@MainActor
public struct VoiceButton: View {
    @Environment(AppState.self) private var appState

    let onStart: () -> Void
    let onFinish: () -> Void
    let onToggle: () -> Void
    let onPause: (() -> Void)?
    let onResume: (() -> Void)?

    public init(onStart: @escaping () -> Void, onFinish: @escaping () -> Void, onToggle: @escaping () -> Void,
                onPause: (() -> Void)? = nil, onResume: (() -> Void)? = nil) {
        self.onStart = onStart
        self.onFinish = onFinish
        self.onToggle = onToggle
        self.onPause = onPause
        self.onResume = onResume
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
        let pause = onPause
        let resume = onResume
        return Button {
            if appState.voiceState.isPaused {
                resume?()
            } else if appState.voiceState.canFinishListening {
                if let pause {
                    pause()
                } else {
                    finish()
                }
            } else {
                start()
            }
        } label: {
            Image(systemName: pushToTalkIcon)
                .font(.system(size: 14))
                .foregroundColor(pushToTalkColor)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .background(Color.secondary.opacity(0.001))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(pushToTalkLabel)
        .accessibilityHint(pushToTalkHint)
        .accessibilityIdentifier("primaryVoiceButton")
        .help(pushToTalkHint)
    }

    private var pushToTalkIcon: String {
        if appState.voiceState.isPaused {
            return "mic.fill"
        }
        if appState.voiceState.isCapturingAudio {
            return "pause.fill"
        }
        return "mic"
    }

    private var pushToTalkColor: Color {
        if appState.voiceState.isPaused {
            return .orange
        }
        if appState.voiceState.isCapturingAudio {
            return .blue
        }
        return .secondary
    }

    private var pushToTalkLabel: String {
        if appState.voiceState.isPaused {
            return "继续录音"
        }
        if appState.voiceState.canFinishListening {
            return "暂停录音"
        }
        return "开始录音"
    }

    private var pushToTalkHint: String {
        if appState.voiceState.isPaused {
            return "点按继续录音"
        }
        if appState.voiceState.canFinishListening {
            return "点按暂停录音"
        }
        return "点按开始录音"
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
        case .idle, .failed, .requestingPermission, .paused:
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
            if appState.voiceState.isPaused {
                Text("已暂停")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
            } else if appState.voiceState.isCapturingAudio {
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
