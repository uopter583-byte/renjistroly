import Foundation

public enum PermissionKind: String, CaseIterable, Identifiable, Sendable, Hashable, Codable {
    case microphone
    case speechRecognition
    case screenRecording
    case accessibility
    case automation
    case fileSystem
    case shellExecution
    case network
    case apiCredentials
    case stableIdentity

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .microphone: "麦克风"
        case .speechRecognition: "语音识别"
        case .screenRecording: "屏幕录制"
        case .accessibility: "辅助功能"
        case .automation: "自动化"
        case .fileSystem: "文件系统"
        case .shellExecution: "终端执行"
        case .network: "网络访问"
        case .apiCredentials: "模型密钥"
        case .stableIdentity: "签名身份"
        }
    }

    public var purpose: String {
        switch self {
        case .microphone: "接收中文语音输入和 Push-to-Talk 指令。"
        case .speechRecognition: "使用 Apple Speech 作为本地语音转文字候选。"
        case .screenRecording: "在你请求时读取当前屏幕上下文。"
        case .accessibility: "读取控件、选中文本，并执行经过确认的 Mac 动作。"
        case .automation: "控制支持 Apple Events 的应用。"
        case .fileSystem: "读写工作区、桌面、应用安装和基础版本备份。"
        case .shellExecution: "构建、测试、签名、打开 App，并执行经过确认的本机命令。"
        case .network: "访问模型 API、下载依赖、检索资料和诊断 Provider。"
        case .apiCredentials: "通过 Keychain 或环境配置调用 DeepSeek、OpenAI 兼容服务等模型。"
        case .stableIdentity: "保持 Bundle ID、签名身份和安装路径稳定，避免每次重启重复授权。"
        }
    }
}

public enum PermissionStatus: String, Sendable, Hashable {
    case granted
    case denied
    case notDetermined
    case unknown

    public var isGranted: Bool { self == .granted }

    public var label: String {
        switch self {
        case .granted: "已授权"
        case .denied: "未授权"
        case .notDetermined: "未请求"
        case .unknown: "需验证"
        }
    }
}

public struct PermissionSnapshot: Identifiable, Sendable, Hashable {
    public var id: PermissionKind { kind }
    public let kind: PermissionKind
    public let status: PermissionStatus
    public let detail: String

    public init(kind: PermissionKind, status: PermissionStatus, detail: String = "") {
        self.kind = kind
        self.status = status
        self.detail = detail
    }
}

public enum FullAccessCapabilityKind: String, CaseIterable, Identifiable, Sendable, Codable, Hashable {
    case voiceInput
    case voiceOutput
    case screenUnderstanding
    case appControl
    case automation
    case fileSystem
    case shellExecution
    case network
    case modelCredentials
    case stableIdentity
    case safetyPolicy

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .voiceInput: "语音输入"
        case .voiceOutput: "语音输出"
        case .screenUnderstanding: "屏幕理解"
        case .appControl: "App 控制"
        case .automation: "自动化控制"
        case .fileSystem: "文件系统"
        case .shellExecution: "终端执行"
        case .network: "网络"
        case .modelCredentials: "模型密钥"
        case .stableIdentity: "稳定身份"
        case .safetyPolicy: "安全策略"
        }
    }

    public var codexEquivalent: String {
        switch self {
        case .voiceInput: "麦克风 + Apple Speech，把用户语音变成指令。"
        case .voiceOutput: "系统 TTS，把回复读出来。"
        case .screenUnderstanding: "屏幕录制 + OCR + 窗口列表，观察当前电脑状态。"
        case .appControl: "辅助功能 + CGEvent，点击、输入、快捷键、滚动、拖拽、切换 App。"
        case .automation: "Apple Events，控制支持自动化的目标 App。"
        case .fileSystem: "读写工作区、桌面、应用安装目录和恢复备份。"
        case .shellExecution: "执行本机构建、测试、签名、打开应用等命令。"
        case .network: "访问模型、文档、下载源和 Provider endpoint。"
        case .modelCredentials: "Keychain/API Key，让模型能力可用。"
        case .stableIdentity: "固定 Bundle ID、签名和安装路径，让隐私授权不反复失效。"
        case .safetyPolicy: "高风险动作确认，执行后复查结果。"
        }
    }
}

public struct FullAccessCapabilitySnapshot: Identifiable, Sendable, Codable, Equatable {
    public var id: FullAccessCapabilityKind { kind }
    public var kind: FullAccessCapabilityKind
    public var status: FoundationHealthStatus
    public var detail: String
    public var requiredPermissions: [PermissionKind]

    public init(
        kind: FullAccessCapabilityKind,
        status: FoundationHealthStatus,
        detail: String,
        requiredPermissions: [PermissionKind] = []
    ) {
        self.kind = kind
        self.status = status
        self.detail = detail
        self.requiredPermissions = requiredPermissions
    }
}
