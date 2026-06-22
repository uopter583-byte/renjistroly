import RenJistrolyIntelligence
import SwiftUI

@MainActor
public struct MenuBarExtraView: View {
    @ObservedObject var controller: AssistantSessionController
    let openWindow: () -> Void

    public init(controller: AssistantSessionController, openWindow: @escaping () -> Void) {
        self.controller = controller
        self.openWindow = openWindow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                controller.toggleListening()
            } label: {
                Label(controller.voiceState.isListening ? "停止聆听" : "开始聆听", systemImage: controller.voiceState.isListening ? "stop.fill" : "mic.fill")
            }

            Button {
                openWindow()
            } label: {
                Label("打开面板", systemImage: "rectangle")
            }

            Button {
                Task { await controller.refreshContext(includeScreenImage: false) }
            } label: {
                Label("刷新上下文", systemImage: "arrow.clockwise")
            }

            Divider()

            Text(controller.hotkeyPreset.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(width: 220)
    }
}
