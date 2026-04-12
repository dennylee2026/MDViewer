import SwiftUI
import AppKit

// Identifies a scroll-to command from the preview → editor reverse sync.
struct EditorScrollTarget: Equatable {
    let charOffset: Int
    let viewportFraction: CGFloat   // target line should appear at this fraction of the visible area
    let token: UUID                 // changes each time to force a new scroll
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.token == rhs.token }
}

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var zoomLevel: Double = 1.0
    var editorStyle: EditorStyle = StylesFile.systemDefaults.styles[0].editorStyle
    /// Plain text of the cursor's line (Markdown syntax stripped), used to locate the element in the preview.
    /// Parameters: (lineText, editorFraction, lineFraction, charOffset)
    ///   - editorFraction: cursor's vertical fraction within the visible editor area (0.0 = top, 1.0 = bottom)
    ///   - lineFraction: cursor's line number / total line count (0.0 = first line, 1.0 = last line)
    ///   - charOffset: cursor's UTF-16 character offset in the full string (matches NSRange)
    var onCursorMove: ((String, CGFloat, CGFloat, Int) -> Void)?
    var scrollTarget: EditorScrollTarget? = nil

    private var fontSize: CGFloat {
        let base = editorStyle.global.fontSize ?? 18
        return base * CGFloat(zoomLevel)
    }

    // MARK: - Font with cascade for CJK

    private func makeFont() -> NSFont {
        let family = editorStyle.global.fontFamily ?? "system"
        let base: NSFont
        switch family {
        case "menlo":
            base = NSFont(name: "Menlo", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        case "palatino":
            base = NSFont(name: "Palatino", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        default:
            base = NSFont.systemFont(ofSize: fontSize)
        }
        let cascadeNames = editorStyle.global.cascadeFonts ?? ["PingFangSC-Regular"]
        let cascadeDescriptors = cascadeNames.map { NSFontDescriptor(fontAttributes: [.name: $0]) }
        let cascaded = base.fontDescriptor.addingAttributes([
            .cascadeList: cascadeDescriptors
        ])
        return NSFont(descriptor: cascaded, size: fontSize) ?? base
    }

    // MARK: - Paragraph style

    private func makeParagraphStyle() -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.lineHeightMultiple = editorStyle.global.lineHeightMultiple ?? 1.25
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
        highlighter.baseFont       = makeFont()
        highlighter.paragraphStyle = makeParagraphStyle()
        highlighter.editorStyle    = editorStyle
        highlighter.textView       = textView          // needed for hasMarkedText() check
        textView.textStorage?.delegate = highlighter
        context.coordinator.highlighter = highlighter

        // G2: Line numbers
        let ruler = LineNumberRulerView(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler  = true
        scrollView.rulersVisible     = true

        context.coordinator.textView = textView
        context.coordinator.currentFontFamily = editorStyle.global.fontFamily ?? "system"
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Zoom or font family change: update typography
        let newFont = makeFont()
        let newPS   = makeParagraphStyle()
        let currentFamily = editorStyle.global.fontFamily ?? "system"
        let fontFamilyChanged = context.coordinator.currentFontFamily != currentFamily
        if fontFamilyChanged { context.coordinator.currentFontFamily = currentFamily }

        // Also detect editorStyle changes (e.g. style switched)
        let styleChanged = context.coordinator.lastEditorStyle != editorStyle
        if styleChanged {
            context.coordinator.lastEditorStyle = editorStyle
            context.coordinator.highlighter?.editorStyle = editorStyle
        }

        if textView.font?.pointSize != newFont.pointSize || fontFamilyChanged || styleChanged {
            context.coordinator.highlighter?.baseFont       = newFont
            context.coordinator.highlighter?.paragraphStyle = newPS
            applyTypography(to: textView)
            if let hl = context.coordinator.highlighter,
               let storage = textView.textStorage {
                hl.applyHighlights(to: storage)
            }
        }

        // External text change — never interrupt an active IME composition
        if textView.string != text && !textView.hasMarkedText() {
            let sel = textView.selectedRanges
            textView.string = text
            if let hl = context.coordinator.highlighter,
               let storage = textView.textStorage {
                hl.applyHighlights(to: storage)
            }
            textView.selectedRanges = sel
        }

        // Reverse sync: scroll editor to match preview click
        if let target = scrollTarget, target.token != context.coordinator.lastScrollToken {
            context.coordinator.lastScrollToken = target.token
            applyScroll(to: target.charOffset, viewportFraction: target.viewportFraction, in: textView)
        }
    }

    private func applyScroll(to charOffset: Int, viewportFraction: CGFloat, in textView: NSTextView) {
        let nsStr = textView.string as NSString
        guard nsStr.length > 0 else { return }
        let safeOffset = min(max(0, charOffset), nsStr.length)
        // Use a range with length ≥ 1 so layout managers return a real rect
        let rangeLen = min(1, nsStr.length - safeOffset)
        let range = NSRange(location: safeOffset, length: rangeLen)

        guard let scrollView = textView.enclosingScrollView else { return }

        // Ensure glyphs/layout are generated up to this point
        textView.scrollRangeToVisible(range)

        // Compute the line rect using TextKit1 (layoutManager) or TextKit2 (textLayoutManager)
        var lineY: CGFloat = 0
        let inset = textView.textContainerInset.height
        if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
            // TextKit1 path
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let lineRect   = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            lineY = lineRect.midY + inset
        } else if #available(macOS 12.0, *), let tlm = textView.textLayoutManager {
            // TextKit2 path
            let docRange = NSTextRange(
                location: tlm.documentRange.location,
                end: tlm.documentRange.endLocation
            )
            if let docRange = docRange {
                let off = tlm.offset(from: docRange.location, to: docRange.endLocation)
                let _ = off  // ensure layout
            }
            // Convert charOffset to NSTextRange
            if let start = tlm.location(tlm.documentRange.location, offsetBy: safeOffset),
               let end   = tlm.location(start, offsetBy: max(1, rangeLen)),
               let textRange = NSTextRange(location: start, end: end) {
                tlm.ensureLayout(for: textRange)
                var rect = CGRect.zero
                tlm.enumerateTextSegments(in: textRange, type: .standard,
                                          options: []) { _, segRect, _, _ in
                    rect = segRect
                    return false  // stop after first
                }
                lineY = rect.midY + inset
            }
        } else {
            // Fallback: scrollRangeToVisible already did the best we can
            return
        }

        let visibleH = scrollView.contentView.bounds.height
        let targetY  = max(0, lineY - viewportFraction * visibleH)

        scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    // MARK: - Typography helper

    private func applyTypography(to textView: NSTextView) {
        let font = makeFont()
        let ps   = makeParagraphStyle()
        textView.font                  = font
        textView.defaultParagraphStyle = ps
        textView.typingAttributes = [
            .font:            font,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle:  ps
        ]
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent:      EditorView
        weak var textView: NSTextView?
        var highlighter: MarkdownHighlighter?
        var currentFontFamily: String = "system"
        var lastScrollToken: UUID? = nil
        var lastEditorStyle: EditorStyle? = nil

        init(_ parent: EditorView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            // Don't propagate partial IME composition — wait for confirmed text
            guard !tv.hasMarkedText() else { return }
            parent.text = tv.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            // Skip cursor-sync while IME is composing
            guard !tv.hasMarkedText() else { return }
            let cursor = tv.selectedRange().location
            let nsStr  = tv.string as NSString
            let safePos = min(cursor, nsStr.length)
            let lineRange = nsStr.lineRange(for: NSRange(location: safePos, length: 0))
            var line = nsStr.substring(with: lineRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Strip Markdown syntax to get the plain text shown in the preview
            let opts: NSString.CompareOptions = .regularExpression
            line = line.replacingOccurrences(of: "^#{1,6}\\s+",  with: "", options: opts)
            line = line.replacingOccurrences(of: "^>+\\s*",       with: "", options: opts)
            line = line.replacingOccurrences(of: "^[-*+]\\s+",    with: "", options: opts)
            line = line.replacingOccurrences(of: "^\\d+\\.\\s+",  with: "", options: opts)
            line = line.replacingOccurrences(of: "\\*{1,3}|_{1,3}|~~|`+", with: "", options: opts)
            line = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Need ≥ 2 chars to search reliably; take first 40 to keep it unique
            let searchText = String(line.prefix(40))

            // Compute lineFraction = cursorLine / totalLines (0.0 .. 1.0)
            var lineFraction: CGFloat = 0.0
            let totalLines = nsStr.components(separatedBy: "\n").count
            if totalLines > 1 {
                // Count newlines before cursor to get zero-based line index
                let beforeCursor = nsStr.substring(to: safePos)
                let cursorLine = beforeCursor.components(separatedBy: "\n").count - 1
                lineFraction = CGFloat(cursorLine) / CGFloat(totalLines - 1)
                lineFraction = max(0.0, min(1.0, lineFraction))
            }

            // If text is too short to search, still fall back to lineFraction
            guard searchText.count >= 2 else {
                parent.onCursorMove?("", 0.0, lineFraction, safePos)
                return
            }

            // Compute the cursor's vertical fraction within the visible editor area
            var fraction: CGFloat = 0.0
            if let layoutManager = tv.layoutManager,
               let textContainer = tv.textContainer {
                let glyphRange = layoutManager.glyphRange(
                    forCharacterRange: NSRange(location: safePos, length: 0),
                    actualCharacterRange: nil
                )
                let cursorRect = layoutManager.boundingRect(
                    forGlyphRange: glyphRange,
                    in: textContainer
                )
                let visibleRect = tv.visibleRect
                let cursorY = cursorRect.midY - visibleRect.origin.y
                let visibleHeight = visibleRect.height
                if visibleHeight > 0 {
                    fraction = max(0.0, min(1.0, cursorY / visibleHeight))
                }
            }

            parent.onCursorMove?(searchText, fraction, lineFraction, safePos)
        }
    }
}
