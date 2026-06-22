import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import RenJistrolyModels
import ScreenCaptureKit
import Speech

public enum SystemPermissionKind: String, CaseIterable, Identifiable, Sendable, Hashable {
    case accessibility
    case microphone
    case speechRecognition
    case screenRecording
    case appleEvents

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .accessibility: "辅助功能"
        case .microphone: "麦克风"
        case .speechRecognition: "语音识别"
        case .screenRecording: "屏幕录制"
        case .appleEvents: "Apple Events"
        }
    }

    public var description: String {
        switch self {
        case .accessibility: "读取界面状态，输入文字，并按你的指令控制 Mac。"
        case .microphone: "接收语音输入和 Push-to-Talk 指令。"
        case .speechRecognition: "将语音转成文字指令。"
        case .screenRecording: "理解当前屏幕内容，提供上下文辅助。"
        case .appleEvents: "自动化支持 AppleScript 的应用。"
        }
    }

    public var settingsURL: URL? {
        switch self {
        case .accessibility:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .microphone:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .speechRecognition:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
        case .screenRecording:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        case .appleEvents:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        }
    }
}

public enum SystemPermissionStatus: String, Sendable, Hashable {
    case granted
    case denied
    case notDetermined
    case unknown

    public var isGranted: Bool { self == .granted }

    public var displayName: String {
        switch self {
        case .granted: "已授权"
        case .denied: "未授权"
        case .notDetermined: "未请求"
        case .unknown: "需验证"
        }
    }
}

public struct SystemPermissionCheck: Identifiable, Sendable, Hashable {
    public var id: SystemPermissionKind { kind }
    public let kind: SystemPermissionKind
    public let status: SystemPermissionStatus
    public let detail: String

    public init(kind: SystemPermissionKind, status: SystemPermissionStatus, detail: String = "") {
        self.kind = kind
        self.status = status
        self.detail = detail
    }
}

public actor PermissionCenter {
    public static let shared = PermissionCenter()

    public init() {}

    public func checkSystemPermissions() async -> [SystemPermissionCheck] {
        var results: [SystemPermissionCheck] = []
        for kind in SystemPermissionKind.allCases {
            let check = await checkSystemPermission(kind)
            results.append(check)
            Task.detached { await AgentEventBus.shared.publish(.system(.permissionChanged(permission: kind.title, granted: check.status.isGranted))) }
        }
        return results
    }

    public func checkSystemPermission(_ kind: SystemPermissionKind) async -> SystemPermissionCheck {
        switch kind {
        case .accessibility:
            let granted = AXIsProcessTrusted()
            return SystemPermissionCheck(
                kind: kind,
                status: granted ? .granted : .denied,
                detail: granted ? "RenJistroly 可以读取和控制可访问 UI。" : "需要在系统设置中手动启用。"
            )

        case .microphone:
            switch MicrophoneAuthorizationRequester.authorizationStatus() {
            case .authorized:
                return SystemPermissionCheck(kind: kind, status: .granted)
            case .notDetermined:
                return SystemPermissionCheck(kind: kind, status: .notDetermined)
            case .denied:
                return SystemPermissionCheck(kind: kind, status: .denied)
            case .unknown:
                return SystemPermissionCheck(kind: kind, status: .unknown)
            }

        case .speechRecognition:
            switch SFSpeechRecognizer.authorizationStatus() {
            case .authorized:
                return SystemPermissionCheck(kind: kind, status: .granted)
            case .notDetermined:
                return SystemPermissionCheck(kind: kind, status: .notDetermined)
            case .denied, .restricted:
                return SystemPermissionCheck(kind: kind, status: .denied)
            @unknown default:
                return SystemPermissionCheck(kind: kind, status: .unknown)
            }

        case .screenRecording:
            if CGPreflightScreenCaptureAccess() {
                return SystemPermissionCheck(kind: kind, status: .granted, detail: "屏幕录制已授权。")
            }

            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                return SystemPermissionCheck(kind: kind, status: .granted, detail: "屏幕录制已授权。")
            } catch {
                return SystemPermissionCheck(
                    kind: kind,
                    status: .unknown,
                    detail: "暂时无法确认屏幕录制权限：\(error.localizedDescription)"
                )
            }

        case .appleEvents:
            return SystemPermissionCheck(
                kind: kind,
                status: .unknown,
                detail: "Apple Events 权限按目标应用授予，会在首次自动化具体 App 时由系统确认。"
            )
        }
    }

    public func requestSystemPermission(_ kind: SystemPermissionKind) async -> SystemPermissionCheck {
        switch kind {
        case .accessibility:
            let key = "AXTrustedCheckOptionPrompt" as CFString
            let options: NSDictionary = [key: true]
            let granted = AXIsProcessTrustedWithOptions(options)
            return SystemPermissionCheck(
                kind: kind,
                status: granted ? .granted : .denied,
                detail: granted ? "已授权。" : "系统设置已打开或即将显示授权提示。"
            )

        case .microphone:
            let granted = await MicrophoneAuthorizationRequester.requestAccess()
            return SystemPermissionCheck(kind: kind, status: granted ? .granted : .denied)

        case .speechRecognition:
            let status = await SpeechAuthorizationRequester.requestAuthorizationStatus()
            switch status {
            case .authorized:
                return SystemPermissionCheck(kind: kind, status: .granted)
            case .notDetermined:
                return SystemPermissionCheck(kind: kind, status: .notDetermined)
            case .denied, .restricted:
                return SystemPermissionCheck(kind: kind, status: .denied)
            @unknown default:
                return SystemPermissionCheck(kind: kind, status: .unknown)
            }

        case .screenRecording:
            // Attempt to enumerate shareable content — on first call without
            // permission macOS 26 triggers the standard Screen Recording dialog.
            let granted: Bool
            if CGPreflightScreenCaptureAccess() {
                granted = true
            } else {
                granted = (try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)) != nil
            }
            return SystemPermissionCheck(
                kind: kind,
                status: granted ? .granted : .denied,
                detail: granted ? "已授权。" : "请在系统设置中启用屏幕录制后重启应用。"
            )

        case .appleEvents:
            let script = """
            tell application "System Events"
                return name of first application process whose frontmost is true
            end tell
            """
            var error: NSDictionary?
            let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
            if result?.stringValue != nil {
                return SystemPermissionCheck(kind: kind, status: .granted)
            }
            let message = error?[NSAppleScript.errorMessage] as? String ?? "等待系统授权具体自动化目标。"
            return SystemPermissionCheck(kind: kind, status: .unknown, detail: message)
        }
    }

    @MainActor
    public func openSystemSettings(for kind: SystemPermissionKind) {
        guard let url = kind.settingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - MacVoice PermissionKind methods

    public func checkAll() async -> [PermissionSnapshot] {
        var snapshots: [PermissionSnapshot] = []
        for kind in PermissionKind.allCases {
            snapshots.append(await check(kind))
        }
        return snapshots
    }

    public func check(_ kind: PermissionKind) async -> PermissionSnapshot {
        switch kind {
        case .microphone:
            return switch MicrophoneAuthorizationRequester.authorizationStatus() {
            case .authorized: PermissionSnapshot(kind: kind, status: .granted)
            case .notDetermined: PermissionSnapshot(kind: kind, status: .notDetermined)
            case .denied: PermissionSnapshot(kind: kind, status: .denied)
            case .unknown: PermissionSnapshot(kind: kind, status: .unknown)
            }
        case .speechRecognition:
            return switch SFSpeechRecognizer.authorizationStatus() {
            case .authorized: PermissionSnapshot(kind: kind, status: .granted)
            case .notDetermined: PermissionSnapshot(kind: kind, status: .notDetermined)
            case .denied, .restricted: PermissionSnapshot(kind: kind, status: .denied)
            @unknown default: PermissionSnapshot(kind: kind, status: .unknown)
            }
        case .screenRecording:
            let check = await checkSystemPermission(.screenRecording)
            return PermissionSnapshot(
                kind: kind,
                status: Self.permissionStatus(from: check.status),
                detail: check.detail.isEmpty ? check.status.displayName : check.detail
            )
        case .accessibility:
            let granted = AXIsProcessTrusted()
            return PermissionSnapshot(
                kind: kind,
                status: granted ? .granted : .denied,
                detail: granted ? "可以读取和控制可访问 UI。" : "需要在系统设置中给 ~/Applications/RenJistroly.app 启用辅助功能；刚授权后请重启 App。"
            )
        case .automation:
            return PermissionSnapshot(
                kind: kind,
                status: .unknown,
                detail: "自动化不能预先全部授权；当 App 第一次控制 Finder、日历等目标应用时，macOS 会按目标应用弹窗。"
            )
        case .fileSystem:
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let writable = appSupport.map { FileManager.default.isWritableFile(atPath: $0.path) } ?? false
            return PermissionSnapshot(
                kind: kind,
                status: writable ? .granted : .denied,
                detail: writable ? "可以写入用户级应用数据；桌面/下载/文稿等目录会按 macOS 规则单独授权。" : "无法写入用户级应用数据目录。"
            )
        case .shellExecution:
            let canRunOpen = FileManager.default.isExecutableFile(atPath: "/usr/bin/open")
            let canRunSwift = FileManager.default.isExecutableFile(atPath: "/usr/bin/swift")
            return PermissionSnapshot(
                kind: kind,
                status: canRunOpen ? .granted : .denied,
                detail: canRunSwift ? "可执行系统命令和 Swift 构建工具。" : "可执行基础系统命令；Swift 工具链可能不可用。"
            )
        case .network:
            return PermissionSnapshot(
                kind: kind,
                status: .unknown,
                detail: "网络由系统和当前连接决定；Provider 健康检查会验证具体 endpoint。"
            )
        case .apiCredentials:
            return PermissionSnapshot(
                kind: kind,
                status: .unknown,
                detail: "模型密钥存放在 Keychain 或用户配置中；Provider 健康检查会验证 DeepSeek/OpenAI 兼容配置。"
            )
        case .stableIdentity:
            let installedPath = "\(NSHomeDirectory())/Applications/RenJistroly.app"
            let installed = FileManager.default.fileExists(atPath: installedPath)
            let bundle = Bundle.main.bundleIdentifier ?? ""
            return PermissionSnapshot(
                kind: kind,
                status: installed && bundle == "com.renjistroly.app" ? .granted : .denied,
                detail: installed ? "Bundle ID：\(bundle)。安装路径稳定。" : "建议从 ~/Applications/RenJistroly.app 运行，避免授权对象变化。"
            )
        }
    }

    private static func permissionStatus(from status: SystemPermissionStatus) -> PermissionStatus {
        switch status {
        case .granted: .granted
        case .denied: .denied
        case .notDetermined: .notDetermined
        case .unknown: .unknown
        }
    }

    public func request(_ kind: PermissionKind) async -> PermissionSnapshot {
        switch kind {
        case .microphone:
            let status = MicrophoneAuthorizationRequester.authorizationStatus()
            if status != .notDetermined {
                return PermissionSnapshot(kind: kind, status: status == .authorized ? .granted : .denied)
            }
            let granted = await MicrophoneAuthorizationRequester.requestAccess()
            return PermissionSnapshot(kind: kind, status: granted ? .granted : .denied)
        case .speechRecognition:
            let status = await SpeechAuthorizationRequester.requestAuthorizationStatus()
            switch status {
            case .authorized: return PermissionSnapshot(kind: kind, status: .granted)
            case .notDetermined: return PermissionSnapshot(kind: kind, status: .notDetermined)
            case .denied, .restricted: return PermissionSnapshot(kind: kind, status: .denied)
            @unknown default: return PermissionSnapshot(kind: kind, status: .unknown)
            }
        case .screenRecording:
            let granted: Bool
            if CGPreflightScreenCaptureAccess() {
                granted = true
            } else {
                granted = (try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)) != nil
            }
            return PermissionSnapshot(
                kind: kind,
                status: granted ? .granted : .denied,
                detail: granted ? "已授权；如果状态未刷新，请重启 App。" : "已打开系统授权流程。启用屏幕录制后请重启 App。"
            )
        case .accessibility:
            let key = "AXTrustedCheckOptionPrompt" as CFString
            let options: NSDictionary = [key: true]
            let granted = AXIsProcessTrustedWithOptions(options)
            return PermissionSnapshot(
                kind: kind,
                status: granted ? .granted : .denied,
                detail: granted ? "已授权。" : "系统设置已打开或即将显示授权提示。"
            )
        case .automation:
            return PermissionSnapshot(
                kind: kind,
                status: .unknown,
                detail: "自动化授权会在第一次控制具体目标应用时由 macOS 弹出。"
            )
        case .fileSystem, .shellExecution, .network, .apiCredentials, .stableIdentity:
            return await check(kind)
        }
    }

    @MainActor
    public func openSettings(for kind: PermissionKind) {
        let url: URL?
        switch kind {
        case .microphone:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .speechRecognition:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
        case .screenRecording:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        case .accessibility:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .automation:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        case .fileSystem:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")
        case .shellExecution:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_DeveloperTools")
        case .network:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.network")
        case .apiCredentials:
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security")
        case .stableIdentity:
            url = URL(fileURLWithPath: "\(NSHomeDirectory())/Applications")
        }
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    public func fullAccessCapabilities(
        permissions: [PermissionSnapshot],
        hasModelCredential: Bool,
        providerName: String,
        installedAppPath: String
    ) -> [FullAccessCapabilitySnapshot] {
        let permissionByKind = Dictionary(uniqueKeysWithValues: permissions.map { ($0.kind, $0) })
        func granted(_ kind: PermissionKind) -> Bool {
            permissionByKind[kind]?.status.isGranted == true
        }

        let installed = FileManager.default.fileExists(atPath: installedAppPath)
        let bundleStable = Bundle.main.bundleIdentifier == "com.renjistroly.app"

        return [
            FullAccessCapabilitySnapshot(
                kind: .voiceInput,
                status: granted(.microphone) && granted(.speechRecognition) ? .ok : .warning,
                detail: granted(.microphone) && granted(.speechRecognition) ? "可用 Apple Speech 接收中文语音。" : "需要麦克风和语音识别权限。",
                requiredPermissions: [.microphone, .speechRecognition]
            ),
            FullAccessCapabilitySnapshot(
                kind: .voiceOutput,
                status: .ok,
                detail: "使用 macOS 系统 TTS，不依赖云端语音模型。"
            ),
            FullAccessCapabilitySnapshot(
                kind: .screenUnderstanding,
                status: granted(.screenRecording) ? .ok : .warning,
                detail: granted(.screenRecording) ? "可读取屏幕、窗口和 OCR 上下文。" : "需要屏幕录制权限，授权后通常要重启 App。",
                requiredPermissions: [.screenRecording]
            ),
            FullAccessCapabilitySnapshot(
                kind: .appControl,
                status: granted(.accessibility) ? .ok : .warning,
                detail: granted(.accessibility) ? "可点击、输入、滚动、快捷键、切换第三方 App。" : "需要在系统设置 > 隐私与安全性 > 辅助功能中启用 RenJistroly。",
                requiredPermissions: [.accessibility]
            ),
            FullAccessCapabilitySnapshot(
                kind: .automation,
                status: .warning,
                detail: "macOS 按目标 App 分别弹窗授权；不能一次性静默全开。",
                requiredPermissions: [.automation]
            ),
            FullAccessCapabilitySnapshot(
                kind: .fileSystem,
                status: granted(.fileSystem) ? .ok : .warning,
                detail: granted(.fileSystem) ? "可写入应用数据、安装目录和基础版本备份。" : "文件系统写入能力不完整。",
                requiredPermissions: [.fileSystem]
            ),
            FullAccessCapabilitySnapshot(
                kind: .shellExecution,
                status: granted(.shellExecution) ? .ok : .warning,
                detail: granted(.shellExecution) ? "可执行本机构建、测试、签名和 open 命令。" : "本机命令执行能力不完整。",
                requiredPermissions: [.shellExecution]
            ),
            FullAccessCapabilitySnapshot(
                kind: .network,
                status: .warning,
                detail: "网络需通过具体 Provider 健康检查确认。"
            ),
            FullAccessCapabilitySnapshot(
                kind: .modelCredentials,
                status: hasModelCredential ? .ok : .warning,
                detail: hasModelCredential ? "\(providerName) 密钥可用或当前 Provider 不需要密钥。" : "\(providerName) 需要配置 API Key。",
                requiredPermissions: [.apiCredentials]
            ),
            FullAccessCapabilitySnapshot(
                kind: .stableIdentity,
                status: installed && bundleStable ? .ok : .failing,
                detail: installed && bundleStable ? "安装路径、Bundle ID 和签名对象稳定。" : "请从固定安装路径运行，避免授权重置。",
                requiredPermissions: [.stableIdentity]
            ),
            FullAccessCapabilitySnapshot(
                kind: .safetyPolicy,
                status: .ok,
                detail: "高风险动作确认，动作后重新观察并校验结果。"
            )
        ]
    }
}
