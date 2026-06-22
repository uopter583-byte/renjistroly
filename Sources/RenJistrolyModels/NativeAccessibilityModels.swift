import Foundation

public enum NativeAccessibilityIntegrationMode: String, Sendable, Codable {
    case direct
    case assisted
    case settingsOnly

    public var title: String {
        switch self {
        case .direct: "已直接接入"
        case .assisted: "可协同使用"
        case .settingsOnly: "系统级设置"
        }
    }
}

public enum NativeAccessibilityFeatureKind: String, CaseIterable, Identifiable, Sendable, Codable, Hashable {
    case voiceControl
    case keyboard
    case pointerControl
    case switchControl
    case liveSpeech
    case personalVoice
    case vocalShortcuts
    case liveCaptions
    case spokenContent
    case dictation
    case rtt
    case audio
    case captions
    case hoverText

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .voiceControl: "语音控制"
        case .keyboard: "键盘"
        case .pointerControl: "指针控制"
        case .switchControl: "切换控制"
        case .liveSpeech: "实时语音"
        case .personalVoice: "个人声音"
        case .vocalShortcuts: "人声快捷指令"
        case .liveCaptions: "实时字幕"
        case .spokenContent: "阅读与朗读"
        case .dictation: "听写"
        case .rtt: "RTT"
        case .audio: "音频"
        case .captions: "字幕"
        case .hoverText: "悬停文本"
        }
    }

    public var settingURLString: String {
        switch self {
        case .voiceControl: "x-apple.systempreferences:com.apple.Accessibility?VoiceControl"
        case .keyboard: "x-apple.systempreferences:com.apple.Accessibility?Keyboard"
        case .pointerControl: "x-apple.systempreferences:com.apple.Accessibility?PointerControl"
        case .switchControl: "x-apple.systempreferences:com.apple.Accessibility?SwitchControl"
        case .liveSpeech: "x-apple.systempreferences:com.apple.Accessibility?LiveSpeech"
        case .personalVoice: "x-apple.systempreferences:com.apple.Accessibility?PersonalVoice"
        case .vocalShortcuts: "x-apple.systempreferences:com.apple.Accessibility?VocalShortcuts"
        case .liveCaptions: "x-apple.systempreferences:com.apple.Accessibility?LiveCaptions"
        case .spokenContent: "x-apple.systempreferences:com.apple.Accessibility?SpokenContent"
        case .dictation: "x-apple.systempreferences:com.apple.preference.keyboard?Dictation"
        case .rtt: "x-apple.systempreferences:com.apple.Accessibility?RTT"
        case .audio: "x-apple.systempreferences:com.apple.Accessibility?Audio"
        case .captions: "x-apple.systempreferences:com.apple.Accessibility?Captions"
        case .hoverText: "x-apple.systempreferences:com.apple.Accessibility?HoverText"
        }
    }

    public var mode: NativeAccessibilityIntegrationMode {
        switch self {
        case .dictation, .spokenContent, .keyboard, .pointerControl:
            .direct
        case .voiceControl, .liveSpeech, .personalVoice, .vocalShortcuts, .liveCaptions, .switchControl:
            .assisted
        case .rtt, .audio, .captions, .hoverText:
            .settingsOnly
        }
    }

    public var appUsage: String {
        switch self {
        case .voiceControl:
            "系统语音控制可作为备用入口；本 app 自己使用 Apple Speech 识别中文指令，并用 Accessibility/CGEvent 执行动作。"
        case .keyboard:
            "本 app 直接发送快捷键、Tab、Return、Escape、方向键和组合键。"
        case .pointerControl:
            "本 app 直接使用 CGEvent 点击、双击、右键、滚动和拖拽。"
        case .switchControl:
            "系统切换控制可辅助无鼠标操作；本 app 可打开设置，但不能静默接管系统切换扫描器。"
        case .liveSpeech:
            "系统实时语音可把输入文字读出；本 app 已内置 macOS TTS，可直接朗读助手回复。"
        case .personalVoice:
            "个人声音属于系统隐私声音资产；本 app 可打开设置，朗读默认走系统 TTS。"
        case .vocalShortcuts:
            "人声快捷指令可触发系统动作；本 app 的热键和语音命令可与其并行使用。"
        case .liveCaptions:
            "实时字幕是系统级字幕层；本 app 可打开设置，自身语音转文字走 Apple Speech。"
        case .spokenContent:
            "本 app 直接使用系统朗读能力输出语音，并支持停止朗读和语速设置。"
        case .dictation:
            "系统听写可作为文本输入备用；本 app 自己接入 Apple Speech 作为指令输入。"
        case .rtt:
            "RTT 是通话辅助功能；本 app 不接管通话链路，只提供设置入口。"
        case .audio:
            "音频辅助设置可配合听觉体验；本 app 使用系统音频输入和 TTS 输出。"
        case .captions:
            "字幕设置影响系统字幕体验；本 app 可打开入口，后续可接入回复字幕面板。"
        case .hoverText:
            "悬停文本是系统视觉辅助；本 app 不复制该功能，只提供入口。"
        }
    }
}

public struct NativeAccessibilityFeatureSnapshot: Identifiable, Sendable, Codable, Equatable {
    public var id: NativeAccessibilityFeatureKind { kind }
    public var kind: NativeAccessibilityFeatureKind
    public var mode: NativeAccessibilityIntegrationMode
    public var detail: String
    public var settingURLString: String

    public init(kind: NativeAccessibilityFeatureKind) {
        self.kind = kind
        self.mode = kind.mode
        self.detail = kind.appUsage
        self.settingURLString = kind.settingURLString
    }
}

public struct NativeAccessibilityFeatureCatalog: Sendable {
    public static let all: [NativeAccessibilityFeatureSnapshot] = NativeAccessibilityFeatureKind.allCases.map {
        NativeAccessibilityFeatureSnapshot(kind: $0)
    }

    public static func match(_ text: String) -> NativeAccessibilityFeatureKind? {
        let normalized = text.lowercased().replacingOccurrences(of: " ", with: "")
        let aliases: [(NativeAccessibilityFeatureKind, [String])] = [
            (.voiceControl, ["语音控制", "voicecontrol"]),
            (.keyboard, ["键盘", "keyboard"]),
            (.pointerControl, ["指针控制", "鼠标控制", "pointercontrol"]),
            (.switchControl, ["切换控制", "switchcontrol"]),
            (.liveSpeech, ["实时语音", "livespeech"]),
            (.personalVoice, ["个人声音", "personalvoice"]),
            (.vocalShortcuts, ["人声快捷指令", "声音快捷指令", "vocalshortcuts"]),
            (.liveCaptions, ["实时字幕", "livecaptions"]),
            (.spokenContent, ["阅读与朗读", "朗读内容", "spokencontent"]),
            (.dictation, ["听写", "语音输入", "dictation"]),
            (.rtt, ["rtt"]),
            (.audio, ["音频", "audio"]),
            (.captions, ["字幕", "captions"]),
            (.hoverText, ["悬停文本", "hovertext"])
        ]
        return aliases.first { _, names in
            names.contains { normalized.contains($0.lowercased().replacingOccurrences(of: " ", with: "")) }
        }?.0
    }
}
