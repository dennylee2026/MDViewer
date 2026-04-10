import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var zoomLevel: Double = 1.0
    var onCursorMove: ((Double) -> Void)?   // scroll fraction 0–1

    private var fontSize: CGFloat { CGFloat(14 * zoomLevel) }

    // MARK: - Paragraph style (CJK-friendly)

    private func makeParagraphStyle() -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.lineHeightMultiple  = 1.6          // comfortable for CJK glyphs
        ps.paragraphSpacing    = fontSize * 0.3
        return ps
    }

    // MARK: - NSViewRepresentable

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView   = scrollView.documentView as! NSTextView

        // Basic setup
        textView.delegate      = context.coordinator
        textView.isEditable    = true
        textView.isRichText    = false
        textView.allowsUndo    = true
        textView.usesFindBar   = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 20, height: 20)

        // Disable smart substitutions (important for CJK punctuation)
        textView.isAutomaticQuoteSubstitutionEnabled  = false
        textView.isAutomaticDashSubstitutionEnabled   = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled     = false
        textView.isGrammarCheckingEnabled             = false

        // Soft wrap
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude)
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask      = [.width, .height]

        // Apply typography
        applyTypography(to: textView)

        // IME composition text appearance
        textView.markedTextAttributes = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: NSColor.secondaryLabelColor,
            .backgroundColor: NSColor.selectedTextBackgroundColor.withAlphaComponent(0.25),
            .foregroundColor: NSColor.textColor
        ]

        // G1: Syntax highlighter
        let highlighter = MarkdownHighlighter()
        highlighter.baseFont      = .systemFont(ofSize: fontSize)
        highlighter.paragraphStyle = makeParagraphStyle()
        textView.textStorage?.delegate = highlighter
        context.coordinator.highlighter = highlighter

        // G2: Line numbers
        let ruler = LineNumberRulerView(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler  = true
        scrollView.rulersVisible     = true

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Zoom: update font + paragraph style if changed
        let newFont = NSFont.systemFont(ofSize: fontSize)
        let newPS   = makeParagraphStyle()
        if textView.font != newFont {
            context.coordinator.highlighter?.baseFont       = newFont
            context.coordinator.highlighter?.paragraphStyle = newPS
            applyTypography(to: textView)
            if let hl = context.coordinator.highlighter,
               let storage = textView.textStorage {
                hl.applyHighlights(to: storage)
            }
        }

        // External text change
        if textView.string != text {
            let sel = textView.selectedRanges
            textView.string = text
            if let hl = context.coordinator.highlighter,
               let storage = textView.textStorage {
                hl.applyHighlights(to: storage)
            }
            textView.selectedRanges = sel
        }

    }

    // MARK: - Typography helper

    private func applyTypography(to textView: NSTextView) {
        let font = NSFont.systemFont(ofSize: fontSize)
        let ps   = makeParagraphStyle()
        textView.font                 = font
        textView.defaultParagraphStyle = ps
        textView.typingAttributes = [
            .font:           font,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: ps
        ]
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent:      EditorView
        weak var textView: NSTextView?
        var highlighter: MarkdownHighlighter?

        init(_ parent: EditorView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv       = notification.object as? NSTextView,
                  let lm       = tv.layoutManager,
                  let tc       = tv.textContainer else { return }

            let cursorChar = tv.selectedRange().location
            let nsStr      = tv.string as NSString
            let safeChar   = min(cursorChar, nsStr.length)
            let glyphCount = lm.numberOfGlyphs
            guard glyphCount > 0 else { parent.onCursorMove?(0); return }

            let glyphIdx = safeChar < nsStr.length
                ? lm.glyphIndexForCharacter(at: safeChar)
                : glyphCount - 1

            let lineRect  = lm.lineFragmentRect(
                forGlyphAt: min(glyphIdx, glyphCount - 1),
                effectiveRange: nil)
            let inset      = tv.textContainerInset
            let cursorY    = lineRect.midY + inset.height
            let totalH     = lm.usedRect(for: tc).height + inset.height * 2
            let fraction   = totalH > 0 ? max(0, min(1, cursorY / totalH)) : 0

            parent.onCursorMove?(Double(fraction))
        }
    }
}
