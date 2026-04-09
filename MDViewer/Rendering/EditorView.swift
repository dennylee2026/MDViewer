import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true               // ⌘F 支持（G 组）
        textView.isIncrementalSearchingEnabled = true
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false

        // 软换行：宽度跟随容器，不水平滚动
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                                        height: CGFloat.greatestFiniteMagnitude)
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // 只在外部变更时更新（避免编辑中循环赋值）
        if textView.string != text {
            let selection = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selection
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        weak var textView: NSTextView?

        init(_ parent: EditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}
