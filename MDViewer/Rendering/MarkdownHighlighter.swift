import AppKit

/// NSTextStorageDelegate that applies Markdown syntax colors to the editor.
final class MarkdownHighlighter: NSObject, NSTextStorageDelegate {

    var baseFont: NSFont = .systemFont(ofSize: 14)         // updated by EditorView on zoom
    var paragraphStyle: NSParagraphStyle = .default        // updated by EditorView on zoom
    /// Set to true by the coordinator while IME is composing; highlights are deferred.
    var isComposing: Bool = false
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
        guard editedMask.contains(.editedCharacters), !isWorking, !isComposing else { return }
        isWorking = true
        applyHighlights(to: textStorage)
        isWorking = false
    }

    // MARK: - Full-document highlight

    func applyHighlights(to storage: NSTextStorage) {
        let str    = storage.string
        let full   = NSRange(str.startIndex..., in: str)

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
        apply(to: s, str: str,
              pattern: "^`{3}[\\s\\S]*?^`{3}",
              options: [.anchorsMatchLines],
              attrs: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .backgroundColor: NSColor.systemGray.withAlphaComponent(0.08)
              ])
    }

    private func applyHeadings(_ s: NSTextStorage, _ str: String) {
        let base = baseFont.pointSize
        let colors: [(NSColor, CGFloat)] = [
            (.init(hex: "#4285F4"), base + 6), // H1
            (.init(hex: "#EA4335"), base + 4), // H2
            (.init(hex: "#FBBC05"), base + 2), // H3
            (.init(hex: "#34A853"), base + 1), // H4
            (.init(hex: "#4285F4"), base),     // H5
            (.init(hex: "#EA4335"), base),     // H6
        ]
        guard let regex = try? NSRegularExpression(
            pattern: "^(#{1,6}) .+", options: .anchorsMatchLines) else { return }

        regex.enumerateMatches(in: str, range: NSRange(str.startIndex..., in: str)) { m, _, _ in
            guard let m,
                  let hashRange = Range(m.range(at: 1), in: str) else { return }
            let level = min(str.distance(from: hashRange.lowerBound, to: hashRange.upperBound), 6)
            let (color, size) = colors[level - 1]
            s.addAttributes([
                .foregroundColor: color,
                .font: makeBoldFont(size: size)
            ], range: m.range)
        }
    }

    private func applyBlockquotes(_ s: NSTextStorage, _ str: String) {
        apply(to: s, str: str, pattern: "^> .+", options: .anchorsMatchLines,
              attrs: [.foregroundColor: NSColor.secondaryLabelColor])
    }

    private func applyBold(_ s: NSTextStorage, _ str: String) {
        apply(to: s, str: str, pattern: "\\*\\*(?=\\S).+?(?<=\\S)\\*\\*|__(?=\\S).+?(?<=\\S)__",
              attrs: [.font: makeBoldFont()])
    }

    private func applyItalic(_ s: NSTextStorage, _ str: String) {
        // Require that the * is not adjacent to another * on either side,
        // so that ** bold markers are never mistaken for italic delimiters.
        apply(to: s, str: str,
              pattern: "(?<!\\*)\\*(?!\\*)(?=\\S).+?(?<=\\S)(?<!\\*)\\*(?!\\*)|(?<!_)_(?!_)(?=\\S).+?(?<=\\S)(?<!_)_(?!_)",
              attrs: [.obliqueness: 0.2])
    }

    private func applyInlineCode(_ s: NSTextStorage, _ str: String) {
        apply(to: s, str: str, pattern: "`[^`\\n]+`",
              attrs: [
                .foregroundColor: NSColor.systemRed,
                .backgroundColor: NSColor.systemGray.withAlphaComponent(0.12)
              ])
    }

    private func applyStrikethrough(_ s: NSTextStorage, _ str: String) {
        apply(to: s, str: str, pattern: "~~(?=\\S).+?(?<=\\S)~~",
              attrs: [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: NSColor.secondaryLabelColor
              ])
    }

    private func applyLinks(_ s: NSTextStorage, _ str: String) {
        apply(to: s, str: str, pattern: "\\[([^\\]]+)\\]\\([^)]+\\)",
              attrs: [.foregroundColor: NSColor.linkColor])
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

private extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red:   CGFloat((int >> 16) & 0xFF) / 255,
            green: CGFloat((int >>  8) & 0xFF) / 255,
            blue:  CGFloat( int        & 0xFF) / 255,
            alpha: 1
        )
    }
}
