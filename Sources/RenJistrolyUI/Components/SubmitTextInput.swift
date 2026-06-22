import SwiftUI
import AppKit

public struct SubmitTextInput: View {
    @Binding private var text: String
    private let placeholder: String
    private let minHeight: CGFloat
    private let maxHeight: CGFloat
    private let onSubmit: () -> Void
    private let focusTrigger: Int

    public init(
        text: Binding<String>,
        placeholder: String,
        minHeight: CGFloat = 24,
        maxHeight: CGFloat = 120,
        focusTrigger: Int = 0,
        onSubmit: @escaping () -> Void
    ) {
        _text = text
        self.placeholder = placeholder
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.focusTrigger = focusTrigger
        self.onSubmit = onSubmit
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            SubmitTextViewRepresentable(
                text: $text,
                minHeight: minHeight,
                maxHeight: maxHeight,
                focusTrigger: focusTrigger,
                onSubmit: onSubmit
            )

            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.top, 3)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: minHeight, maxHeight: maxHeight)
    }
}

private struct SubmitTextViewRepresentable: NSViewRepresentable {
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let focusTrigger: Int
    let onSubmit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        let textView = SubmitTextView()
        textView.delegate = context.coordinator
        textView.onSubmit = onSubmit
        textView.string = text
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.textContainer?.lineFragmentPadding = 0
        textView.minSize = NSSize(width: 0, height: minHeight)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: maxHeight)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView

        DispatchQueue.main.async {
            scrollView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SubmitTextView else { return }
        textView.onSubmit = onSubmit
        if textView.string != text {
            textView.string = text
        }
        if context.coordinator.lastFocusTrigger != focusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async {
                scrollView.window?.makeFirstResponder(textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        var lastFocusTrigger: Int = 0

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

private final class SubmitTextView: NSTextView {
    var onSubmit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        let wantsNewline = event.modifierFlags.contains(.shift)
            || event.modifierFlags.contains(.option)

        if isReturn, !wantsNewline, !hasMarkedText() {
            onSubmit?()
            return
        }

        super.keyDown(with: event)
    }
}
