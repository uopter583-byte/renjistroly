import SwiftUI
import RenJistrolyModels
import RenJistrolyConversation
import RenJistrolyIntelligence
import RenJistrolyCapability
import RenJistrolyUI

@main
struct RenJistrolyApp: App {
    @State private var appState = AppState()
    @State private var engine = ConversationEngine.shared
    @StateObject private var assistantController = AssistantSessionController.shared

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        appDelegate.engine = engine
        appDelegate.appState = appState
        appDelegate.assistantController = assistantController
        assistantController.appState = appState
        AssistantSessionController.shared.appState = appState

        // 实时语音对话完成后，把消息保存到主对话列表
        AssistantSessionController.shared.onMessagePair = { userText, assistantText in
            Task { @MainActor in
                let session = ConversationEngine.shared.sessionManager
                let id = session.activeConversationID ?? session.createConversation().id
                session.appendMessage(Message(role: .user, content: [.text(userText)]), to: id)
                session.appendMessage(Message(role: .assistant, content: [.text(assistantText)]), to: id)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AssistantRootView(controller: assistantController)
                .environment(appState)
                .environment(engine)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 600)

        MenuBarExtra("RenJistroly", systemImage: "brain.head.profile") {
            MenuBarView()
                .environment(appState)
                .environment(engine)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appState)
                .environment(engine)
        }
    }
}
