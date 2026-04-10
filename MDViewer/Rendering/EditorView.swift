import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var zoomLevel: Double = 1.0
    var headings: [HeadingItem] = []
    /// Called with the heading index (0-based) closest to the cursor; -1 if none.
    var onCursorMove: ((Int) -> Void)?

    private var fontSize: CGFloat { CGFloat(14 * zoomLevel) }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView   = scrollView.documentView as! NSTextView

        textView.delegate      = context.coordinator
        textView.isEditable    = true
        textView.isRichText    = false
        textView.allowsUndo    = true
        textView.usesFindBar   = true                          // ⌘F
        textView.isIncrementalSearchingEnabled = true
        textView.font          = .systemFont(ofSize: fontSize) // Task 4
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
        highlighter.baseFont = .systemFont(ofSize: fontSize)
        textView.textStorage?.delegate = highlighter
        context.coordinator.highlighter = highlighter

        // G2: Line numbers
        let ruler = LineNumberRulerView(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler  = true
        scrollView.rulersVisible     = true

        context.coordinator.textView  = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Task 1: sync font size to zoom level
        let newFont = NSFont.systemFont(ofSize: fontSize)
        if textView.font != newFont {
            context.coordinator.highlighter?.baseFont = newFont
            textView.font = newFont
            if let hl = context.coordinator.highlighter,
               let storage = textView.textStorage {
                hl.applyHighlights(to: storage)
            }
        }

        // Update text content (only when externally changed)
        if textView.string != text {
            let sel = textView.selectedRanges
            textView.string = text
            if let hl = context.coordinator.highlighter,
               let storage = textView.textStorage {
                hl.applyHighlights(to: storage)
            }
            textView.selectedRanges = sel
        }

        // Keep headings in sync for cursor calculations
        context.coordinator.headings = headings
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        weak var textView: NSTextView?
        var highlighter: MarkdownHighlighter?
        var headings: [HeadingItem] = []

        init(_ parent: EditorView) { self.parent = parent }

        // Text content changed
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        // Task 3: cursor moved → find nearest heading → notify
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let cursor = tv.selectedRange().location
            // Last heading whose charOffset <= cursor position
            let heading = headings.last(where: { $0.charOffset <= cursor })
            parent.onCursorMove?(heading?.index ?? -1)
        }
    }
}
