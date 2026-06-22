import AVFoundation
import Foundation
import os
import RenJistrolyModels
import RenJistrolySystemBridge

private let voiceLog = OSLog(subsystem: "com.renjistroly", category: "voice")

@MainActor
public final class VoiceSessionManager {
    public var voiceText: String = ""
    public var voiceError: String?

    private let speechRecognizer: MacOSSpeechRecognizer
    private let systemDictation: SystemDictationBridge
    private let textToSpeech: MacOSTextToSpeech
    private var voiceTask: Task<Void, Never>?

    public init(
        speechRecognizer: MacOSSpeechRecognizer = MacOSSpeechRecognizer(),
        systemDictation: SystemDictationBridge = SystemDictationBridge(),
        textToSpeech: MacOSTextToSpeech = MacOSTextToSpeech()
    ) {
        self.speechRecognizer = speechRecognizer
        self.systemDictation = systemDictation
        self.textToSpeech = textToSpeech
    }

    // MARK: - Voice Output

    public func speakIfNeeded(_ text: String, appState: AppState?) async {
        guard let appState, appState.isVoiceOutputEnabled else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        appState.voiceState = .speaking
        await textToSpeech.speak(trimmed)
        if appState.voiceState == .speaking {
            appState.voiceState = .idle
        }
    }

    public func stopVoiceOutput(appState: AppState) {
        textToSpeech.stop()
        if appState.voiceState == .speaking {
            appState.voiceState = .idle
        }
    }

    // MARK: - Voice Input

    public func startVoiceInput(appState: AppState) async {
        os_log("[startVoiceInput] mode=%{public}@ voiceState=%{public}@", log: voiceLog, type: .info, appState.voiceInputMode.rawValue, "\(appState.voiceState)")

        voiceTask?.cancel()
        voiceTask = nil
        voiceError = nil
        voiceText = ""

        // Always check microphone permission first, regardless of input mode
        let micStatus = MicrophoneAuthorizationRequester.authorizationStatus()
        os_log("[startVoiceInput] micStatus=%{public}@", log: voiceLog, type: .info, "\(micStatus)")
        if micStatus != .authorized {
            appState.voiceState = .requestingPermission
            let micGranted = await MicrophoneAuthorizationRequester.requestAccess()
            os_log("[startVoiceInput] mic request result=%{public}@", log: voiceLog, type: .info, micGranted ? "granted" : "denied")
            guard micGranted else {
                voiceError = "麦克风权限未授权。请在系统设置中启用麦克风权限。"
                appState.voiceState = .failed
                return
            }
        }

        // Always check speech recognition permission too
        if !speechRecognizer.isAuthorized {
            appState.voiceState = .requestingPermission
            let srGranted = await speechRecognizer.requestAuthorization()
            os_log("[startVoiceInput] sr request result=%{public}@", log: voiceLog, type: .info, srGranted ? "granted" : "denied")
            guard srGranted else {
                voiceError = "语音识别权限未授权。请在系统设置中启用语音识别。"
                appState.voiceState = .failed
                return
            }
        }

        if appState.voiceInputMode == .accessibilityVoiceInput {
            os_log("[startVoiceInput] mode=accessibilityVoiceInput, starting streaming", log: voiceLog, type: .info)
            await startRecognizerStreaming(appState: appState)
            return
        }

        if appState.voiceInputMode == .systemDictationShortcut {
            os_log("[startVoiceInput] mode=systemDictationShortcut", log: voiceLog, type: .info)
            appState.voiceState = .listening
            do {
                try await systemDictation.triggerDictationShortcut()
                voiceError = nil
                os_log("[startVoiceInput] dictation shortcut triggered", log: voiceLog, type: .info)
            } catch {
                os_log("[startVoiceInput] dictation shortcut failed: %{public}@", log: voiceLog, type: .error, error.localizedDescription)
                voiceError = "无法启动系统听写: \(error.localizedDescription)"
                appState.voiceState = .failed
            }
            return
        }

        // Fallback: .builtInSpeechRecognition
        os_log("[startVoiceInput] mode=builtInSpeechRecognition", log: voiceLog, type: .info)
        if !speechRecognizer.isAuthorized {
            appState.voiceState = .requestingPermission
            let granted = await speechRecognizer.requestAuthorization()
            if !granted {
                voiceError = "语音识别权限未授权。请在系统设置中启用语音识别和麦克风权限。"
                appState.voiceState = .failed
                return
            }
        }

        await startRecognizerStreaming(appState: appState)
    }

    private func startRecognizerStreaming(appState: AppState) async {
        os_log("[startRecognizerStreaming] starting...", log: voiceLog, type: .info)
        appState.voiceState = .listening
        do {
            let stream = try await speechRecognizer.startStreaming()
            os_log("[startRecognizerStreaming] stream obtained", log: voiceLog, type: .info)
            appState.voiceState = .listening

            voiceTask = Task { [weak self] in
                guard let self else { return }
                for await text in stream {
                    if Task.isCancelled { break }
                    os_log("[voiceTask] received text: %{public}@", log: voiceLog, type: .debug, text)
                    await MainActor.run {
                        self.voiceText = text
                    }
                }
                os_log("[voiceTask] stream ended", log: voiceLog, type: .info)
                await MainActor.run {
                    if appState.voiceState.isCapturingAudio {
                        appState.voiceState = .idle
                    }
                }
            }
        } catch {
            let desc = error.localizedDescription
            os_log("[startRecognizerStreaming] failed: %{public}@", log: voiceLog, type: .error, desc)
            if desc.contains("connect") || desc.contains("server") {
                voiceError = "麦克风或音频服务不可用，请检查麦克风权限和音频输入设备。"
            } else {
                voiceError = "语音输入启动失败: \(desc)"
            }
            appState.voiceState = .failed
        }
    }

    public func stopVoiceInput(appState: AppState) {
        os_log("[stopVoiceInput] voiceState=%{public}@", log: voiceLog, type: .info, "\(appState.voiceState)")
        voiceTask?.cancel()
        voiceTask = nil
        if appState.voiceInputMode == .accessibilityVoiceInput {
            speechRecognizer.stopStreaming()
            appState.voiceState = .idle
            return
        }

        if appState.voiceInputMode == .systemDictationShortcut {
            Task { [systemDictation] in
                try? await systemDictation.stopDictationShortcut()
            }
            appState.voiceState = .idle
            return
        }
        speechRecognizer.stopStreaming()
        appState.voiceState = .idle
    }

    public func cancelVoiceInput(appState: AppState) {
        os_log("[cancelVoiceInput]", log: voiceLog, type: .info)
        stopVoiceInput(appState: appState)
        voiceText = ""
        voiceError = nil
    }

    @discardableResult
    public func finishVoiceInput(appState: AppState) -> String {
        os_log("[finishVoiceInput] voiceState=%{public}@ text=%{public}@", log: voiceLog, type: .info, "\(appState.voiceState)", voiceText)
        voiceTask?.cancel()
        voiceTask = nil
        if appState.voiceInputMode == .accessibilityVoiceInput {
            appState.voiceState = .transcribing
            speechRecognizer.stopStreaming()
            appState.voiceState = .idle
            let text = voiceText.trimmingCharacters(in: .whitespacesAndNewlines)
            voiceText = ""
            os_log("[finishVoiceInput] returning text: '%{public}@'", log: voiceLog, type: .info, text)
            return text
        }

        if appState.voiceInputMode == .systemDictationShortcut {
            Task { [systemDictation] in
                try? await systemDictation.stopDictationShortcut()
            }
            appState.voiceState = .idle
            return ""
        }
        appState.voiceState = .transcribing
        speechRecognizer.stopStreaming()
        appState.voiceState = .idle
        let text = voiceText.trimmingCharacters(in: .whitespacesAndNewlines)
        voiceText = ""
        os_log("[finishVoiceInput] returning text: '%{public}@'", log: voiceLog, type: .info, text)
        return text
    }

    public func finishVoiceInputAndSend(appState: AppState, isProcessing: Bool, activePlan: Any?, pendingConfirmation: Any?, sendMessage: @escaping (String, AppState?) async -> Void) async {
        os_log("[finishVoiceInputAndSend] voiceState=%{public}@", log: voiceLog, type: .info, "\(appState.voiceState)")
        let text = finishVoiceInput(appState: appState)
        guard !text.isEmpty else {
            os_log("[finishVoiceInputAndSend] text empty, isContinuousVoiceMode=%{public}@", log: voiceLog, type: .info, appState.isContinuousVoiceModeEnabled ? "true" : "false")
            if appState.isContinuousVoiceModeEnabled {
                await startVoiceInput(appState: appState)
            }
            return
        }

        os_log("[finishVoiceInputAndSend] sending message: '%{public}@'", log: voiceLog, type: .info, text)
        await sendMessage(text, appState)

        if appState.isContinuousVoiceModeEnabled,
           appState.voiceState.canStartListening,
           !isProcessing,
           activePlan == nil,
           pendingConfirmation == nil {
            os_log("[finishVoiceInputAndSend] restarting voice input (continuous mode)", log: voiceLog, type: .info)
            await startVoiceInput(appState: appState)
        }
    }
}
