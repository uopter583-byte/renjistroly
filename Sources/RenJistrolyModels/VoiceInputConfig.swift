import Foundation

public enum VoiceSubmitMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case manual
    case automatic

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .manual: "手动停止发送"
        case .automatic: "停顿自动发送"
        }
    }
}

/// 语音按钮交互模式
public enum VoiceInteractionMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case pushToTalk
    case alwaysOn

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pushToTalk: "按键录音"
        case .alwaysOn: "一直录音"
        }
    }

    public var icon: String {
        switch self {
        case .pushToTalk: "hand.point.up.fill"
        case .alwaysOn: "infinity"
        }
    }

    public var help: String {
        switch self {
        case .pushToTalk: "按住录音，松手发送"
        case .alwaysOn: "点击开关持续录音"
        }
    }
}
