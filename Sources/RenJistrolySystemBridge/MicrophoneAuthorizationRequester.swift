import AVFoundation

public enum MicrophoneAuthorizationStatus: Sendable, Equatable {
    case authorized
    case denied
    case notDetermined
    case unknown
}

public enum MicrophoneAuthorizationRequester {
    public static func authorizationStatus() -> MicrophoneAuthorizationStatus {
        let audioApplicationStatus = statusFromAudioApplication()
        let captureDeviceStatus = statusFromCaptureDevice()

        if audioApplicationStatus == .authorized || captureDeviceStatus == .authorized {
            return .authorized
        }
        if audioApplicationStatus == .notDetermined && captureDeviceStatus == .notDetermined {
            return .notDetermined
        }
        if audioApplicationStatus == .denied || captureDeviceStatus == .denied {
            return .denied
        }
        return audioApplicationStatus == .unknown ? captureDeviceStatus : audioApplicationStatus
    }

    public static func requestAccess() async -> Bool {
        if authorizationStatus() == .authorized {
            return true
        }

        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            let granted = await requestCaptureDeviceAccess()
            if granted { return true }
        }

        if AVAudioApplication.shared.recordPermission == .undetermined {
            _ = await AVAudioApplication.requestRecordPermission()
        }

        return authorizationStatus() == .authorized
    }

    private static func statusFromAudioApplication() -> MicrophoneAuthorizationStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return .authorized
        case .denied:
            return .denied
        case .undetermined:
            return .notDetermined
        @unknown default:
            return .unknown
        }
    }

    private static func statusFromCaptureDevice() -> MicrophoneAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unknown
        }
    }

    private static func requestCaptureDeviceAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
