import AppKit

/// NSTextStorageDelegate that applies Markdown syntax colors to the editor.
final class MarkdownHighlighter: NSObject, NSTextStorageDelegate {

    var baseFont: NSFont = .systemFont(ofSize: 14)         // updated by EditorView on zoom
    var paragraphStyle: NSParagraphStyle = .default        // updated by EditorView on zoom
    weak var textView: NSTextView?                         // set by EditorView; used for IME check
    var editorStyle: EditorStyle = StylesFile.systemDefaults.styles[0].editorStyle
    private var isWorking = false

    /// Bold version of baseFont, preserving its cascade list (e.g. PingFang SC).
    private func makeBoldFont(size: CGFloat? = nil) -> NSFont {
        let sz = size ?? baseFont.pointSize
        let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.bold)
        return NSFont(descriptor: descriptor, size: sz) ?? NSFont.boldSystemFont(ofSize: sz)
    }

    // MARK: - Delegate

    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range: NSRange,
        changeInLength delta: Int
    ) {
        // Skip during IME composition: setAttributes on the full range would clear
        // the marked-text attributes that the input method writes into the storage,
        // causing the composition to collapse and characters to be lost.
        // textView.hasMarkedText() is checked HERE (synchronously) because
        // textStorage(_:didProcessEditing:) fires before textDidChange — any flag
        // set in textDidChange would arrive too late.
        guard editedMask.contains(.editedCharacters),
              !isWorking,
              textView?.hasMarkedText() != true else { return }
        isWorking = true
        applyHighlights(to: textStorage)
        isWorking = false
    }

    // MARK: - Full-document highlight

    func applyHighlights(to storage: NSTextStorage) {
        let str  = storage.string
        let full = NSRange(str.startIndex..., in: str)

        // 1. Reset everything to base style (include paragraphStyle so line height survives)
        storage.setAttributes([
            .font:               baseFont,
            .foregroundColor:    NSColor.textColor,
            .backgroundColor:    NSColor.clear,
            .obliqueness:        0,
            .strikethroughStyle: 0,
            .paragraphStyle:     paragraphStyle
        ], range: full)

        applyFencedCodeBlocks(storage, str)
        applyHeadings(storage, str)
        applyBlockquotes(storage, str)
        applyBold(storage, str)
        applyItalic(storage, str)
        applyInlineCode(storage, str)
        applyStrikethrough(storage, str)
        applyLinks(storage, str)
    }

    // MARK: - Patterns

    private func applyFencedCodeBlocks(_ s: NSTextStorage, _ str: String) {
        let cb = editorStyle.codeBlock
        var attrs: [NSAttributedString.Key: Any] = [:]
        if cb.useSecondaryLabelColor == true {
            attrs[.foregroundColor] = NSColor.secondaryLabelColor
        } else if let hex = cb.color {
            attrs[.foregroundColor] = NSColor(hex: hex)
        }
        if let hex = cb.backgroundColor {
            attrs[.backgroundColor] = NSColor(hex: hex)
        } else {
            attrs[.backgroundColor] = NSColor.systemGray.withAlphaComponent(0.08)
        }
        apply(to: s, str: str,
              pattern: "^`{3}[\\s\\S]*?^`{3}",
              options: [.anchorsMatchLines],
              attrs: attrs)
    }

    private func applyHeadings(_ s: NSTextStorage, _ str: String) {
        let base = baseFont.pointSize
        let headingLevels: [EditorHeadingLevel?] = [
            editorStyle.headings.h1,
            editorStyle.headings.h2,
            editorStyle.headings.h3,
            editorStyle.headings.h4,
            editorStyle.headings.h5,
            editorStyle.headings.h6
        ]
        let sharedBold = editorStyle.headings.shared?.isBold ?? true

        guard let regex = try? NSRegularExpression(
            pattern: "^(#{1,6}) .+", options: .anchorsMatchLines) else { return }

        regex.enumerateMatches(in: str, range: NSRange(str.startIndex..., in: str)) { m, _, _ in
            guard let m,
                  let hashRange = Range(m.range(at: 1), in: str) else { return }
            let level = min(str.distance(from: hashRange.lowerBound, to: hashRange.upperBound), 6)
            let levelData = headingLevels[level - 1]
            let colorHex  = levelData?.color
            let offset    = levelData?.fontSizeOffset ?? 0
            let isBold    = levelData?.isBold ?? sharedBold

            var attrs: [NSAttributedString.Key: Any] = [:]
            if let hex = colorHex {
                attrs[.foregroundColor] = NSColor(hex: hex)
            }
            let size = base + offset
            attrs[.font] = isBold ? makeBoldFont(size: size) : NSFont(descriptor: baseFont.fontDescriptor, size: size) ?? baseFont
            s.addAttributes(attrs, range: m.range)
        }
    }

    private func applyBlockquotes(_ s: NSTextStorage, _ str: String) {
        let bq = editorStyle.blockquote
        var attrs: [NSAttributedString.Key: Any] = [:]
        if bq.useSecondaryLabelColor == true {
            attrs[.foregroundColor] = NSColor.secondaryLabelColor
        } else if let hex = bq.color {
            attrs[.foregroundColor] = NSColor(hex: hex)
        } else {
            attrs[.foregroundColor] = NSColor.secondaryLabelColor
        }
        apply(to: s, str: str, pattern: "^> .+", options: .anchorsMatchLines, attrs: attrs)
    }

    private func applyBold(_ s: NSTextStorage, _ str: String) {
        let bd = editorStyle.bold
        var attrs: [NSAttributedString.Key: Any] = [.font: makeBoldFont()]
        if let hex = bd.color {
            attrs[.foregroundColor] = NSColor(hex: hex)
        }
        apply(to: s, str: str, pattern: "\\*\\*(?=\\S).+?(?<=\\S)\\*\\*|__(?=\\S).+?(?<=\\S)__",
              attrs: attrs)
    }

    private func applyItalic(_ s: NSTextStorage, _ str: String) {
        let it = editorStyle.italic
        var attrs: [NSAttributedString.Key: Any] = [.obliqueness: it.obliqueness ?? 0.2]
        if let hex = it.color {
            attrs[.foregroundColor] = NSColor(hex: hex)
        }
        // Require that the * is not adjacent to another * on either side,
        // so that ** bold markers are never mistaken for italic delimiters.
        apply(to: s, str: str,
              pattern: "(?<!\\*)\\*(?!\\*)(?=\\S).+?(?<=\\S)(?<!\\*)\\*(?!\\*)|(?<!_)_(?!_)(?=\\S).+?(?<=\\S)(?<!_)_(?!_)",
              attrs: attrs)
    }

    private func applyInlineCode(_ s: NSTextStorage, _ str: String) {
        let ic = editorStyle.inlineCode
        var attrs: [NSAttributedString.Key: Any] = [:]
        if let hex = ic.color {
            attrs[.foregroundColor] = NSColor(hex: hex)
        } else {
            attrs[.foregroundColor] = NSColor.systemRed
        }
        if let hex = ic.backgroundColor {
            attrs[.backgroundColor] = NSColor(hex: hex)
        } else {
            attrs[.backgroundColor] = NSColor.systemGray.withAlphaComponent(0.12)
        }
        apply(to: s, str: str, pattern: "`[^`\\n]+`", attrs: attrs)
    }

    private func applyStrikethrough(_ s: NSTextStorage, _ str: String) {
        let st = editorStyle.strikethrough
        var attrs: [NSAttributedString.Key: Any] = [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
        if st.useSecondaryLabelColor == true {
            attrs[.foregroundColor] = NSColor.secondaryLabelColor
        } else if let hex = st.color {
            attrs[.foregroundColor] = NSColor(hex: hex)
        } else {
            attrs[.foregroundColor] = NSColor.secondaryLabelColor
        }
        apply(to: s, str: str, pattern: "~~(?=\\S).+?(?<=\\S)~~", attrs: attrs)
    }

    private func applyLinks(_ s: NSTextStorage, _ str: String) {
        let lk = editorStyle.link
        var attrs: [NSAttributedString.Key: Any] = [:]
        if lk.useLinkColor == true {
            attrs[.foregroundColor] = NSColor.linkColor
        } else if let hex = lk.color {
            attrs[.foregroundColor] = NSColor(hex: hex)
        } else {
            attrs[.foregroundColor] = NSColor.linkColor
        }
        apply(to: s, str: str, pattern: "\\[([^\\]]+)\\]\\([^)]+\\)", attrs: attrs)
    }

    // MARK: - Helper

    private func apply(
        to storage: NSTextStorage,
        str: String,
        pattern: String,
        options: NSRegularExpression.Options = [],
        attrs: [NSAttributedString.Key: Any]
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        regex.enumerateMatches(in: str, range: NSRange(str.startIndex..., in: str)) { m, _, _ in
            guard let m else { return }
            storage.addAttributes(attrs, range: m.range)
        }
    }
}
