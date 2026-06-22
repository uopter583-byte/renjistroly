import SwiftUI
import RenJistrolyModels

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                assistantAvatar
            } else {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if !message.textContent.isEmpty {
                    StreamingMarkdownText(text: message.textContent, isStreaming: message.tokenCount == nil)
                }

                // Tool calls
                ForEach(toolCalls, id: \.id) { call in
                    ToolCallBubble(call: call)
                }

                // Tool results
                ForEach(toolResults, id: \.id) { result in
                    ToolResultBubble(result: result)
                }
            }
            .padding(10)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if message.role == .user {
                userAvatar
            } else {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 2)
    }

    private var toolCalls: [ToolCallRequest] {
        message.content.compactMap { block in
            if case .toolCall(let request) = block { return request }
            return nil
        }
    }

    private var toolResults: [ToolCallResult] {
        message.content.compactMap { block in
            if case .toolResult(let result) = block { return result }
            return nil
        }
    }

    private var bubbleBackground: Color {
        switch message.role {
        case .user: return Color.blue.opacity(0.8)
        case .assistant: return Color.primary.opacity(0.1)
        case .system: return Color.purple.opacity(0.3)
        case .tool: return Color.green.opacity(0.3)
        }
    }

    private var assistantAvatar: some View {
        Image(systemName: "brain.head.profile")
            .font(.system(size: 18))
            .foregroundColor(.accentColor)
            .frame(width: 28, height: 28)
    }

    private var userAvatar: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 22))
            .foregroundColor(.blue)
            .frame(width: 28, height: 28)
    }
}

struct ToolCallBubble: View {
    let call: ToolCallRequest

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "hammer")
                .font(.system(size: 10))
            Text(call.name)
                .font(.system(size: 11, weight: .medium))
            Text("...")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct ToolResultBubble: View {
    let result: ToolCallResult
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.isError ? "失败" : "完成")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(result.isError ? .red : .green)
            Text(result.output)
                .font(.system(size: 11))
                .lineLimit(expanded ? nil : 3)

            if result.output.split(separator: "\n").count > 3 || result.output.count > 200 {
                Button(expanded ? "收起" : "展开") {
                    withAnimation { expanded.toggle() }
                }
                .font(.system(size: 9))
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(result.isError ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
