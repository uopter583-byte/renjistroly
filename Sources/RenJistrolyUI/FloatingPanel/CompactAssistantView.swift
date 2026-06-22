import RenJistrolyIntelligence
import RenJistrolyModels
import SwiftUI

public struct CompactAssistantView: View {
    @ObservedObject private var controller: AssistantSessionController
    @State private var inputText = ""
    @State private var showQuitConfirmation = false

    public init(controller: AssistantSessionController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(spacing: 0) {
            compactHeader

            Divider().opacity(0.2)

            compactTranscript

            Divider().opacity(0.2)

            compactInput
        }
        .frame(minWidth: 360, maxWidth: 480)
        .frame(height: 600)
        .alert("退出 RenJistroly", isPresented: $showQuitConfirmation) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        } message: {
            Text("确定要退出 RenJistroly 吗？")
        }
    }

    // MARK: - Header

    private var compactHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(controller.voiceState.isListening ? Color.red
                    : controller.voiceState.isThinking ? Color.blue
                    : controller.voiceState.isSpeaking ? Color.green
                    : Color.green)
                .frame(width: 7, height: 7)

            Text(controller.voiceState.isListening
                ? (controller.voiceState.isConversationMode ? "实时聆听中" : "正在监听")
                : controller.voiceState.isThinking ? "思考中"
                : controller.voiceState.isSpeaking ? "朗读中"
                : "就绪")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Text(controller.providerPreference.title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.blue.opacity(0.12)))

            HStack(spacing: 2) {
                Text("\(controller.contextExchangeCount)")
                    .font(.system(size: 9, weight: .medium))
                Text("轮")
                    .font(.system(size: 8))
            }
            .foregroundColor(.secondary)
            .onTapGesture { controller.clearContext() }
            .help("点击清除上下文")

            Button {
                showQuitConfirmation = true
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("退出 RenJistroly")
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Transcript

    private var compactTranscript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !controller.voiceState.latestTranscript.isEmpty {
                        transcriptBlock(
                            label: "你",
                            icon: "person.fill",
                            color: .blue,
                            text: controller.voiceState.latestTranscript
                        )
                    }

                    if !controller.voiceState.latestAssistantText.isEmpty {
                        transcriptBlock(
                            label: "助手",
                            icon: "sparkles",
                            color: .green,
                            text: controller.voiceState.latestAssistantText
                        )
                        .id("assistant")
                    } else if !controller.voiceState.latestTranscript.isEmpty {
                        ProgressView()
                            .scaleEffect(0.6)
                            .padding(.leading, 8)
                    }

                    if let result = controller.lastActionResult {
                        Text(result.message)
                            .font(.caption2)
                            .foregroundStyle(result.success ? .green : .red)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: controller.voiceState.latestAssistantText) { _, _ in
                withAnimation { proxy.scrollTo("assistant", anchor: .bottom) }
            }
        }
    }

    private func transcriptBlock(label: String, icon: String, color: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
            }
            Text(text)
                .font(.system(size: 12))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(color.opacity(0.06))
                .cornerRadius(8)
        }
    }

    // MARK: - Input

    private var compactInput: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    Task {
                        guard await AssistantSessionController.shared.requestMicrophonePermission() else { return }
                        controller.toggleListening()
                    }
                } label: {
                    Image(systemName: controller.voiceState.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 16))
                        .foregroundColor(controller.voiceState.isListening ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)

                if controller.voiceState.isSpeaking {
                    Button {
                        controller.stopSpeaking()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)
                }

                TextField("输入文字，Enter 发送", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .onSubmit { submit() }

                Button {
                    submit()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .blue)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            HStack {
                Button {
                    controller.clearContext()
                } label: {
                    Label("清除上下文", systemImage: "trash")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                TraceLatencyBar(controller: controller)

                if controller.voiceState.isThinking {
                    ProgressView().scaleEffect(0.5)
                    Text("思考中...")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
        }
        .background(Color.primary.opacity(0.04))
    }

    private func submit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        controller.sendText(text)
        inputText = ""
    }
}
