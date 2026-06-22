import RenJistrolyIntelligence
import RenJistrolyModels
import SwiftUI

public struct SettingsPanel: View {
    @ObservedObject var controller: AssistantSessionController
    private let onClose: () -> Void

    public init(controller: AssistantSessionController, onClose: @escaping () -> Void = {}) {
        self.controller = controller
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("设置")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .help("关闭")
                .accessibilityLabel("关闭设置")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                Form {
                Section("语音路线") {
                Picker("默认 Provider", selection: $controller.providerPreference) {
                    ForEach(ProviderPreference.selectableCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("对话上下文") {
                HStack {
                    Text("已保存")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(controller.contextExchangeCount) 轮对话")
                        .monospacedDigit()
                    if controller.contextExchangeCount > 0 {
                        Button("清除") {
                            controller.clearContext()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                    }
                }
                Text("上下文写入本地文件，每次请求只带最近 3 轮，节省 token。清除后对话从零开始。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Claude Code") {
                LabeledContent("登录命令") {
                    Text(ClaudeCodeLoginGuide.command)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }

                HStack {
                    Button {
                        controller.copyClaudeCodeLoginCommand()
                    } label: {
                        Label("复制命令", systemImage: "doc.on.doc")
                    }

                    Button {
                        controller.openTerminalForClaudeCodeLogin()
                    } label: {
                        Label("打开终端", systemImage: "terminal")
                    }
                }

                Text("如果对话里提示 Claude Code 未登录，先复制命令，在终端执行登录，完成后回到 RenJistroly 重试。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("安全策略") {
                LabeledContent("默认动作") {
                    Text("只读和可撤销输入可自动执行")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("高风险动作") {
                    Text("默认阻止")
                        .foregroundStyle(.secondary)
                }
            }

            Section("语音输出") {
                HStack {
                    Text("朗读速度")
                    Slider(value: $controller.speechRateMultiplier, in: 0.8...2.4, step: 0.1)
                    Text(String(format: "%.1fx", controller.speechRateMultiplier))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
            }

            Section("语音输入") {
                Toggle("Gate 语音转发", isOn: $controller.gateEnabled)
                if controller.gateEnabled {
                    Text("语音转写通过 \(controller.gateDir)/speech_in.txt 转发到外部（如 Claude Code），App 轮询 reply_out.txt 朗读回复。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("发送方式", selection: $controller.voiceSubmitMode) {
                    ForEach(VoiceSubmitMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("自动发送停顿")
                    Slider(value: $controller.autoSubmitSilenceSeconds, in: 1.0...4.0, step: 0.1)
                        .disabled(controller.voiceSubmitMode == .manual)
                    Text(String(format: "%.1fs", controller.autoSubmitSilenceSeconds))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)
                }
            }

            Section("快捷键") {
                Picker("Push-to-Talk", selection: $controller.hotkeyPreset) {
                    ForEach(HotkeyPreset.selectableCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                if let warning = controller.hotkeyPreset.warning {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text("修改后立即生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("兼容 Provider") {
                ProviderCredentialRow(controller: controller, kind: .deepSeek)
                ProviderCredentialRow(controller: controller, kind: .qwen)
                ProviderCredentialRow(controller: controller, kind: .moonshot)
                ProviderCredentialRow(controller: controller, kind: .openAICompatibleChat)
                LabeledContent("本地") {
                    Text("LM Studio / Ollama / MLX OpenAI-compatible")
                        .foregroundStyle(.secondary)
                }
                Text("本地智能回复建议走 Apple Silicon 的 GPU/Metal/MLX，而不是纯 CPU。把本地服务暴露成 OpenAI-compatible `/v1` 后，选择“本地端点”即可。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
                }
                .formStyle(.grouped)
            }
        }
        .padding(16)
    }
}

private struct ProviderCredentialRow: View {
    @ObservedObject var controller: AssistantSessionController
    let kind: ProviderKind
    @State private var key = ""
    @State private var model = ""
    @State private var baseURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(kind.title)
                    .font(.headline)
                Spacer()
                Text(ProviderEndpoint.defaultEnvironmentVariable(for: kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                TextField("模型", text: $model)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 160)
                TextField("Base URL", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 220)
                SecureField("API Key", text: $key)
                    .textFieldStyle(.roundedBorder)
                Button("保存") {
                    controller.updateProviderModel(kind: kind, model: model)
                    controller.updateProviderBaseURL(kind: kind, baseURL: baseURL)
                    controller.saveProviderKey(kind: kind, key: key)
                }
            }

            Text(kind.defaultBaseURL?.absoluteString ?? "系统本地能力")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .onAppear {
            model = controller.providerModels[kind] ?? kind.defaultModel
            baseURL = controller.providerBaseURLs[kind] ?? kind.defaultBaseURL?.absoluteString ?? ""
            let account = ProviderEndpoint.defaultEnvironmentVariable(for: kind)
            key = controller.providerKeys[account] ?? ProcessInfo.processInfo.environment[account] ?? ""
        }
    }
}
