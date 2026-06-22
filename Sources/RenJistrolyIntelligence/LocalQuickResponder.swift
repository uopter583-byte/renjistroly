import Foundation

public struct LocalQuickResponder: Sendable {
    public init() {}

    public func reply(to text: String) -> String? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()

        guard !normalized.isEmpty else { return nil }
        if looksLikeActionCommand(normalized) {
            return nil
        }

        if ["能不能听到", "听得到", "听到吗", "可以听到"].contains(where: { normalized.contains($0) }) {
            return "可以，我已经听到并转成文字了。"
        }

        if ["发送不出去", "能不能发送", "直接发送", "发出去了吗"].contains(where: { normalized.contains($0) }) {
            return "可以发送给助手处理。外部发送消息需要你指定对象和内容，并确认后执行。"
        }

        if ["速度太慢", "回答太慢", "太慢了", "快两倍", "加快"].contains(where: { normalized.contains($0) }) {
            return "收到。我会优先用本地即时回复，复杂问题再走云端。"
        }

        if ["本地回复", "本地无法回复", "无法回复语音", "可以本地回复"].contains(where: { normalized.contains($0) }) {
            return "可以。本地可以先做即时回复和系统语音朗读，复杂推理再接本地模型或云端。"
        }

        if ["你好", "您好", "在吗", "测试"].contains(normalized) {
            return "在，我能听到。"
        }

        return nil
    }

    private func looksLikeActionCommand(_ text: String) -> Bool {
        ["微信", "打开", "切换", "切到", "输入", "发送", "发给", "告诉", "点击", "复制", "粘贴", "回车", "关闭", "最小化"].contains { text.contains($0) }
    }
}
