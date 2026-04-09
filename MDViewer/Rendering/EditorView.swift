import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    /// Called with scroll fraction (0–1) whenever the editor scrolls.
    var onScroll: ((Double) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView   = scrollView.documentView as! NSTextView

        // Basic setup
        textView.delegate      = context.coordinator
        textView.isEditable    = true
        textView.isRichText    = false
        textView.allowsUndo    = true
        textView.usesFindBar   = true          // G4: ⌘F
        textView.isIncrementalSearchingEnabled = true
        textView.font          = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset            = NSSize(width: 20, height: 20)
        textView.isAutomaticQuoteSubstitutionEnabled  = false
        textView.isAutomaticDashSubstitutionEnabled   = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled     = false

        // Soft wrap
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude)
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask      = [.width, .height]

        // G1: Syntax highlighter
        let highlighter = MarkdownHighlighter()
        textView.textStorage?.delegate = highlighter
        context.coordinator.highlighter = highlighter

        // G2: Line numbers
        let ruler = LineNumberRulerView(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler  = true
        scrollView.rulersVisible     = true

        // G3: Scroll sync observer
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollDidChange(_:)),
            name: NSScrollView.didLiveScrollNotification,
            object: scrollView
        )
        context.coordinator.scrollView = scrollView
        context.coordinator.textView   = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let sel = textView.selectedRanges
            textView.string = text
            // Re-apply highlights after programmatic set
            if let hl = context.coordinator.highlighter,
               let storage = textView.textStorage {
                hl.applyHighlights(to: storage)
            }
            textView.selectedRanges = sel
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        weak var textView:  NSTextView?
        weak var scrollView: NSScrollView?
        var highlighter: MarkdownHighlighter?

        init(_ parent: EditorView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        @objc func scrollDidChange(_ note: Notification) {
            guard let sv = scrollView,
                  let dv = sv.documentView else { return }
            let visH   = sv.contentView.bounds.height
            let totalH = dv.frame.height
            guard totalH > visH else { return }
            let fraction = sv.contentView.bounds.minY / (totalH - visH)
            parent.onScroll?(max(0, min(1, fraction)))
        }
    }
}
