import Foundation
@preconcurrency import Speech

public enum SpeechAuthorizationRequester {
    public static func requestAuthorizationStatus() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    public static func requestAuthorized() async -> Bool {
        await requestAuthorizationStatus() == .authorized
    }
}
