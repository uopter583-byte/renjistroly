import SwiftUI
import RenJistrolyModels
import RenJistrolyConversation
import RenJistrolyIntelligence

@MainActor
public struct ModernInputBar: View {
    @Environment(ConversationEngine.self) private var engine
    @Environment(AppState.self) private var appState

    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3)

            HStack(alignment: .bottom, spacing: 6) {
                voiceButton
                    .frame(width: 68, height: 32)
                    .contentShape(Rectangle())
                    .zIndex(2)
                if appState.voiceState == .speaking {
                    stopSpeakingButton
                }
                textField
                    .zIndex(0)
                sendButton
                    .zIndex(1)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs + 2)

            bottomBar
        }
        .background(.ultraThinMaterial)
    }

    private var textField: some View {
        TextField("输入消息...", text: $text, axis: .vertical)
            .font(.system(size: 13))
            .textFieldStyle(.plain)
            .focused($isFocused)
            .lineLimit(1...6)
            .onSubmit(of: .text) {
                if !canSubmit { return }
                // Shift+Enter for newline; plain Enter to submit
                // .onSubmit fires on Enter with no modifier
                onSubmit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.surfaceInput)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private var voiceButton: some View {
        let controller = AssistantSessionController.shared
        return HStack(spacing: 4) {
            Button {
                if appState.voiceState.canFinishListening {
                    controller.stopListening()
                    return
                }
                Task {
                    guard await controller.requestMicrophonePermission() else { return }
                    controller.startListening()
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

            Button {
                if appState.voiceState.canFinishListening {
                    controller.stopListening()
                } else {
                    Task {
                        guard await controller.requestMicrophonePermission() else { return }
                        controller.toggleConversationMode()
                    }
                }
            } label: {
                Image(systemName: appState.voiceState.isCapturingAudio ? "waveform" : "mic.badge.plus")
                    .font(.system(size: 14))
                    .foregroundColor(appState.voiceState.isCapturingAudio ? .blue : .secondary)
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
        .frame(width: 68, height: 32)
        .contentShape(Rectangle())
    }

    private var sendButton: some View {
        Button(action: onSubmit) {
            Image(systemName: engine.isProcessing ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(canSubmit ? .accentColor : .secondary.opacity(0.4))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
    }

    private var stopSpeakingButton: some View {
        Button {
            AssistantSessionController.shared.stopSpeaking()
        } label: {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 15))
                .foregroundColor(.orange)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help("停止朗读")
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                if let projectType = engine.contextCompiler.currentContext?.projectType {
                    Badge(text: projectType.rawValue)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                if appState.voiceState.isCapturingAudio {
                    Badge(text: "聆听中", color: .blue)
                } else {
                    Text("按住🎤说话 · 点按🎤+实时对话")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                if engine.isProcessing {
                    HStack(spacing: 3) {
                        ProgressView()
                            .scaleEffect(0.4)
                            .frame(width: 10, height: 10)
                        Text("思考中...")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.bottom, 5)
    }

    private func toggleVoice() {
        let controller = AssistantSessionController.shared
        switch appState.voiceState {
        case .idle, .failed:
            Task {
                guard await controller.requestMicrophonePermission() else { return }
                try? await Task.sleep(for: .milliseconds(120))
                controller.toggleListening()
            }
        case .listening, .lockedListening, .transcribing:
            controller.toggleListening()
        default:
            controller.stopSpeaking()
        }
    }
}
