import SwiftUI
import RenJistrolyModels

public struct ModernMessageBubble: View {
    let message: Message
    let isLast: Bool

    @State private var showingTimestamp = false
    @State private var showFullToolResult: Set<String> = []

    public init(message: Message, isLast: Bool = false) {
        self.message = message
        self.isLast = isLast
    }

    public var body: some View {
        VStack(spacing: 2) {
            if message.role == .user {
                userMessage
            } else if message.role == .assistant {
                assistantMessage
            } else if message.role == .system {
                systemMessage
            }
        }
    }

    // MARK: - User

    private var userMessage: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Spacer(minLength: 48)
            VStack(alignment: .trailing, spacing: 3) {
                Text(message.textContent)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Gradients.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .bottomTrailing) {
                        if isLast {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .offset(x: -4, y: -4)
                        }
                    }
            }
        }
        .padding(.leading, 48)
        .onTapGesture { withAnimation(.easeInOut(duration: DS.Animation.fast)) { showingTimestamp.toggle() } }
    }

    // MARK: - Assistant

    private var assistantMessage: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentDim)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 6) {
                Text(message.textContent)
                    .font(.system(size: Typography.Size.bodyLarge))
                    .textSelection(.enabled)
                    .lineSpacing(2)

                if message.hasToolCalls {
                    toolCallsSection
                }
            }
            .padding(.trailing, 48)
            .onTapGesture { withAnimation(.easeInOut(duration: DS.Animation.fast)) { showingTimestamp.toggle() } }
        }
        .padding(.trailing, 48)
    }

    // MARK: - System

    private var systemMessage: some View {
        HStack {
            Image(systemName: "gearshape")
                .font(.system(size: Typography.Size.caption))
                .foregroundColor(.textSecondary)
            Text(message.textContent)
                .font(.system(size: Typography.Size.small))
                .foregroundColor(.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Tool Calls

    private var toolCallsSection: some View {
        VStack(spacing: 4) {
            ForEach(toolCalls, id: \.id) { call in
                ToolCallRow(call: call)
            }
            ForEach(toolResults, id: \.id) { result in
                ToolResultRow(result: result, isExpanded: showFullToolResult.contains(result.id))
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: DS.Animation.fast)) {
                            if showFullToolResult.contains(result.id) {
                                showFullToolResult.remove(result.id)
                            } else {
                                showFullToolResult.insert(result.id)
                            }
                        }
                    }
            }
        }
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
}

// MARK: - Tool Call Row

private struct ToolCallRow: View {
    let call: ToolCallRequest

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 8))
                .foregroundColor(.statusOrange)
            Text(call.name)
                .font(.system(size: Typography.Size.small, weight: .medium))
            Text("...")
                .font(.system(size: Typography.Size.small))
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.statusOrangeDim)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Tool Result Row

private struct ToolResultRow: View {
    let result: ToolCallResult
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: result.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(result.isError ? .statusRed : .statusGreen)
                Text(result.isError ? "失败" : "成功")
                    .font(.system(size: Typography.Size.caption, weight: .medium))
                    .foregroundColor(result.isError ? .statusRed : .statusGreen)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(.textSecondary)
            }
            if isExpanded {
                Text(result.output)
                    .font(Typography.mono(Typography.Size.caption))
                    .foregroundColor(.textSecondary)
                    .lineLimit(20)
                    .textSelection(.enabled)
            }
        }
        .padding(8)
        .background(result.isError ? Color.statusRedDim : Color.statusGreenDim)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}
