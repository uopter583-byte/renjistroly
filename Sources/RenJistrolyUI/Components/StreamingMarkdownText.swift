import SwiftUI

struct StreamingMarkdownText: View, @unchecked Sendable {
    let text: String
    let isStreaming: Bool

    @State private var blocks: [String] = []
    @State private var attrCache: [String: AttributedString] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(blocks.indices, id: \.self) { idx in
                renderBlock(blocks[idx])
            }
        }
        .onChange(of: text, initial: true) { _, newText in
            let newBlocks = newText.split(separator: "\n\n", omittingEmptySubsequences: false).map(String.init)
            blocks = newBlocks
            // Trim attr cache if it has grown significantly stale to avoid unbounded memory
            if attrCache.count > newBlocks.count * 3 {
                attrCache = attrCache.filter { newBlocks.contains($0.key) }
            }
        }
    }

    private func renderAttributedMarkdown(_ block: String) -> AttributedString {
        if let cached = attrCache[block] { return cached }
        let attr = (try? AttributedString(markdown: block)) ?? AttributedString(block)
        attrCache[block] = attr
        return attr
    }

    @ViewBuilder
    private func renderBlock(_ block: String) -> some View {
        if block.hasPrefix("```") {
            CodeBlock(block)
        } else if block.hasPrefix("# ") {
            Text(renderAttributedMarkdown(block))
                .font(.system(size: 18, weight: .bold))
        } else if block.hasPrefix("## ") {
            Text(renderAttributedMarkdown(block))
                .font(.system(size: 16, weight: .semibold))
        } else if block.hasPrefix("- ") || block.hasPrefix("* ") {
            Text(renderAttributedMarkdown(block))
                .font(.system(size: 14))
        } else if block.hasPrefix("> ") {
            Text(renderAttributedMarkdown(block))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.leading, 8)
                .overlay(
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 3)
                        .padding(.leading, -8),
                    alignment: .leading
                )
        } else {
            Text(renderAttributedMarkdown(block))
                .font(.system(size: 14))
        }
    }
}

struct CodeBlock: View {
    private let language: String?
    private let code: String

    init(_ block: String) {
        var lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let header = lines.isEmpty ? "" : lines.removeFirst()

        if header.count > 3 {
            language = String(header.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        } else {
            language = nil
        }

        if lines.last?.hasPrefix("```") == true {
            lines.removeLast()
        }

        code = lines.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language {
                HStack {
                    Text(language)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(12)
            }
        }
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
