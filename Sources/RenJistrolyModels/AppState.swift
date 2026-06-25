import CoreGraphics
import Foundation

public enum AppMode: String, Codable, Sendable, Hashable {
    case compact
    case expanded
    case immersive
}

public enum VoiceInputState: String, Codable, Sendable, Hashable {
    case idle
    case requestingPermission
    case listening
    case lockedListening
    case paused
    case transcribing
    case processing
    case speaking
    case failed

    public var isCapturingAudio: Bool {
        switch self {
        case .listening, .lockedListening, .transcribing:
            true
        case .paused, .idle, .requestingPermission, .processing, .speaking, .failed:
            false
        }
    }

    public var canStartListening: Bool {
        switch self {
        case .idle, .failed, .paused:
            true
        case .requestingPermission, .listening, .lockedListening, .transcribing, .processing, .speaking:
            false
        }
    }

    public var canFinishListening: Bool {
        switch self {
        case .listening, .lockedListening, .transcribing, .paused:
            true
        case .idle, .requestingPermission, .processing, .speaking, .failed:
            false
        }
    }

    public var isActive: Bool {
        self != .idle
    }

    public var isPaused: Bool {
        self == .paused
    }
}

public enum VoiceInputMode: String, Codable, Sendable, Hashable, CaseIterable {
    case accessibilityVoiceInput
    case systemDictationShortcut
    case builtInSpeechRecognition
}

@MainActor
@Observable
public final class AppState {
    public var mode: AppMode = .compact
    public var voiceState: VoiceInputState = .idle
    public var isHotkeyEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isHotkeyEnabled, forKey: "appstate.hotkeyEnabled") }
    }
    public var isVoiceOutputEnabled: Bool = false {
        didSet { UserDefaults.standard.set(isVoiceOutputEnabled, forKey: "appstate.voiceOutput") }
    }
    public var isContinuousVoiceModeEnabled: Bool = false {
        didSet { UserDefaults.standard.set(isContinuousVoiceModeEnabled, forKey: "appstate.continuousVoice") }
    }
    public var voiceInputMode: VoiceInputMode = .accessibilityVoiceInput {
        didSet { UserDefaults.standard.set(voiceInputMode.rawValue, forKey: "appstate.voiceInputMode") }
    }
    public var voiceInteractionMode: VoiceInteractionMode = .pushToTalk {
        didSet { UserDefaults.standard.set(voiceInteractionMode.rawValue, forKey: "appstate.voiceInteraction") }
    }
    public var activeConversationID: UUID?
    public var activeProvider: LLMProvider = .claudeCodeCLI {
        didSet { UserDefaults.standard.set(activeProvider.rawValue, forKey: "appstate.activeProvider") }
    }
    public var preferredCloudProvider: LLMProvider = .anthropic
    public var isOnline: Bool = true
    public var isPermissionGranted: PermissionGrant = PermissionGrant()
    public var isStreaming: Bool = false
    public var isScreenStreamActive: Bool = false
    public var cursorPosition: CGPoint?
    public var toolExecutionPolicy: ToolExecutionPolicy = .default {
        didSet { Self.saveExecutionPolicy(toolExecutionPolicy) }
    }
    public var toolAuditLog: [ToolExecutionRecord] = []
    public var pendingConfirmation: ToolRiskAssessment?
    public var activePlan: ExecutionPlan?
    public var devMode: DevModeState = .disabled
    public var ocrEngine: OCREngine = .both {
        didSet { UserDefaults.standard.set(ocrEngine.rawValue, forKey: "appstate.ocrEngine") }
    }
    public var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "appstate.onboarding")
    public var isSafeMode: Bool = false

    public init() {
        // Bool UserDefaults — use object(forKey:) to detect unset keys (default false)
        if UserDefaults.standard.object(forKey: "appstate.hotkeyEnabled") != nil {
            isHotkeyEnabled = UserDefaults.standard.bool(forKey: "appstate.hotkeyEnabled")
        }
        if UserDefaults.standard.object(forKey: "appstate.voiceOutput") != nil {
            isVoiceOutputEnabled = UserDefaults.standard.bool(forKey: "appstate.voiceOutput")
        }
        if UserDefaults.standard.object(forKey: "appstate.continuousVoice") != nil {
            isContinuousVoiceModeEnabled = UserDefaults.standard.bool(forKey: "appstate.continuousVoice")
        }
        // String enum values
        if let raw = UserDefaults.standard.string(forKey: "appstate.voiceInputMode"),
           let val = VoiceInputMode(rawValue: raw) { voiceInputMode = val }
        if let raw = UserDefaults.standard.string(forKey: "appstate.voiceInteraction"),
           let val = VoiceInteractionMode(rawValue: raw) { voiceInteractionMode = val }
        if let raw = UserDefaults.standard.string(forKey: "appstate.activeProvider"),
           let val = LLMProvider(rawValue: raw) { activeProvider = val }
        if let raw = UserDefaults.standard.string(forKey: "appstate.ocrEngine"),
           let val = OCREngine(rawValue: raw) { ocrEngine = val }
        toolExecutionPolicy = Self.loadExecutionPolicy()
    }

    private static func saveExecutionPolicy(_ policy: ToolExecutionPolicy) {
        let data = try? JSONEncoder().encode(policy)
        UserDefaults.standard.set(data, forKey: "appstate.toolExecutionPolicy")
    }

    private static func loadExecutionPolicy() -> ToolExecutionPolicy {
        guard let data = UserDefaults.standard.data(forKey: "appstate.toolExecutionPolicy"),
              let policy = try? JSONDecoder().decode(ToolExecutionPolicy.self, from: data)
        else { return .default }
        return policy
    }

    public func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "appstate.onboarding")
    }

    public struct PermissionGrant: Codable, Sendable, Hashable {
        public var accessibility: Bool = false
        public var microphone: Bool = false
        public var speechRecognition: Bool = false
        public var screenRecording: Bool = false
        public var appleEvents: Bool = false

        public init() {}

        public var allGranted: Bool {
            accessibility && microphone && speechRecognition && screenRecording && appleEvents
        }
    }
}
