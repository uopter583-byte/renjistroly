import SwiftUI
import RenJistrolyModels
import RenJistrolyConversation

@MainActor
public struct ConversationSidebar: View {
    @Environment(ConversationEngine.self) private var engine
    @State private var searchText = ""
    @State private var isHovered: UUID? = nil

    private var sortedConversations: [Conversation] {
        let convs = engine.sessionManager.conversations
        let searched = searchText.isEmpty ? convs : convs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
        return searched.sorted { a, b in
            if a.metadata.isPinned != b.metadata.isPinned { return a.metadata.isPinned }
            return a.updatedAt > b.updatedAt
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            searchBar
            conversationList
        }
        .frame(minWidth: 220, maxWidth: 280)
        .background(Color.surfaceSidebar)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accentColor)
            Text("对话")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button {
                _ = engine.sessionManager.createConversation()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help("新建对话")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }

    private var searchBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            TextField("搜索对话...", text: $searchText)
                .font(.system(size: 11))
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.surfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.xs)
    }

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(sortedConversations) { conv in
                    conversationRow(conv)
                        .onHover { isHovered = $0 ? conv.id : nil }
                }
            }
            .padding(.vertical, DS.Spacing.xxs)
        }
    }

    private func conversationRow(_ conv: Conversation) -> some View {
        let isActive = conv.id == engine.sessionManager.activeConversationID
        return Button {
            engine.sessionManager.setActiveConversation(conv.id)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if conv.metadata.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 7))
                                .foregroundColor(.secondary)
                        }
                        Text(conv.title)
                            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                            .lineLimit(1)
                    }
                    Text(timeAgo(conv.updatedAt))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isHovered == conv.id {
                    Menu {
                        Button {
                            togglePin(conv)
                        } label: {
                            Label(conv.metadata.isPinned ? "取消置顶" : "置顶", systemImage: "pin")
                        }
                        Button(role: .destructive) {
                            engine.sessionManager.deleteConversation(conv.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                    }
                    .menuStyle(.borderlessButton)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 6)
            .background(isActive ? Color.surfaceSelected : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func togglePin(_ conv: Conversation) {
        var updated = conv
        updated.metadata.isPinned.toggle()
        engine.sessionManager.activeConversation = updated
    }

    private func timeAgo(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff / 60))分钟前" }
        if diff < 86400 { return "\(Int(diff / 3600))小时前" }
        if diff < 604800 { return "\(Int(diff / 86400))天前" }
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return fmt.string(from: date)
    }
}
