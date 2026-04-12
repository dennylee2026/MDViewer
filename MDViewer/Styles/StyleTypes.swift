import Foundation
import AppKit

// MARK: - Top-level container

struct StylesFile: Codable, Equatable {
    var schemaVersion: Int
    var activeStyle: String
    var styles: [MarkdownStyle]

    static var configURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MDViewer")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("styles.json")
    }

    func resolvedActiveStyle() -> MarkdownStyle {
        styles.first(where: { $0.name == activeStyle })
            ?? styles.first
            ?? StylesFile.systemDefaults.styles[0]
    }

    static func load() -> StylesFile {
        let url = configURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(StylesFile.self, from: data)
        else { return systemDefaults }
        return file
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: Self.configURL, options: .atomic)
    }
}

// MARK: - Single named style

struct MarkdownStyle: Codable, Equatable, Identifiable {
    var id: String { name }
    var name: String
    var displayStyle: DisplayStyle
    var editorStyle: EditorStyle
}

// MARK: - Display Style (CSS / WKWebView)

struct DisplayStyle: Codable, Equatable {
    var global: DisplayGlobal
    var headings: DisplayHeadings
    var paragraph: DisplayParagraph
    var bold: DisplayBold
    var italic: DisplayItalic
    var inlineCode: DisplayInlineCode
    var codeBlock: DisplayCodeBlock
    var blockquote: DisplayBlockquote
    var horizontalRule: DisplayHorizontalRule
    var link: DisplayLink
    var list: DisplayList
    var table: DisplayTable
    var strikethrough: DisplayStrikethrough
    var image: DisplayImage
    var taskList: DisplayTaskList?
    var customCSS: String?
}

struct DisplayGlobal: Codable, Equatable {
    var backgroundColor: String?
    var textColor: String?
    var fontFamily: String?
    var fontSize: String?
    var lineHeight: String?
    var maxWidth: String?
    var padding: String?
    /// "github-light" or "github-dark" — selects embedded hljs syntax highlight theme
    var codeHighlightTheme: String?
}

struct DisplayHeadings: Codable, Equatable {
    var shared: DisplayHeadingShared?
    var h1: DisplayHeadingLevel?
    var h2: DisplayHeadingLevel?
    var h3: DisplayHeadingLevel?
    var h4: DisplayHeadingLevel?
    var h5: DisplayHeadingLevel?
    var h6: DisplayHeadingLevel?
}

struct DisplayHeadingShared: Codable, Equatable {
    var fontWeight: String?
    var lineHeight: String?
    var letterSpacing: String?
    var marginTop: String?
    var marginBottom: String?
}

struct DisplayHeadingLevel: Codable, Equatable {
    var fontSize: String?
    var fontWeight: String?
    var color: String?
    var lineHeight: String?
    var marginTop: String?
    var marginBottom: String?
    var borderBottom: String?
    var paddingBottom: String?
}

struct DisplayParagraph: Codable, Equatable {
    var marginTop: String?
    var marginBottom: String?
    var lineHeight: String?
    var color: String?
}

struct DisplayBold: Codable, Equatable {
    var fontWeight: String?
    var color: String?
}

struct DisplayItalic: Codable, Equatable {
    var fontStyle: String?
    var color: String?
}

struct DisplayInlineCode: Codable, Equatable {
    var fontFamily: String?
    var fontSize: String?
    var color: String?
    var backgroundColor: String?
    var borderColor: String?
    var borderRadius: String?
    var paddingHorizontal: String?
    var paddingVertical: String?
}

struct DisplayCodeBlock: Codable, Equatable {
    var fontFamily: String?
    var fontSize: String?
    var backgroundColor: String?
    var borderColor: String?
    var borderRadius: String?
    var padding: String?
    var lineHeight: String?
    var margin: String?
}

struct DisplayBlockquote: Codable, Equatable {
    var fontStyle: String?
    var color: String?
    var backgroundColor: String?
    var borderLeftColor: String?
    var borderLeftWidth: String?
    var borderRadius: String?
    var padding: String?
    var margin: String?
}

struct DisplayHorizontalRule: Codable, Equatable {
    var color: String?
    var height: String?
    var margin: String?
}

struct DisplayLink: Codable, Equatable {
    var color: String?
    var hoverColor: String?
    var underline: Bool?
    var hoverUnderline: Bool?
}

struct DisplayList: Codable, Equatable {
    var marginTop: String?
    var marginBottom: String?
    var paddingLeft: String?
    var itemSpacing: String?
    var nestedSpacing: String?
}

struct DisplayTable: Codable, Equatable {
    var fontSize: String?
    var headerBackgroundColor: String?
    var headerFontWeight: String?
    var alternateRowColor: String?
    var borderColor: String?
    var cellPadding: String?
    var margin: String?
}

struct DisplayStrikethrough: Codable, Equatable {
    var color: String?
}

struct DisplayImage: Codable, Equatable {
    var maxWidth: String?
    var borderRadius: String?
    var margin: String?
}

struct DisplayTaskList: Codable, Equatable {
    var checkboxMarginRight: String?
}

// MARK: - Editor Style (NSTextView / NSAttributedString)

struct EditorStyle: Codable, Equatable {
    var global: EditorGlobal
    var headings: EditorHeadings
    var bold: EditorBold
    var italic: EditorItalic
    var inlineCode: EditorInlineCode
    var codeBlock: EditorCodeBlock
    var blockquote: EditorBlockquote
    var strikethrough: EditorStrikethrough
    var link: EditorLink
}

struct EditorGlobal: Codable, Equatable {
    var fontFamily: String?           // "system", "menlo", "palatino"
    var fontSize: CGFloat?            // points; null = 18
    var lineHeightMultiple: CGFloat?  // NSParagraphStyle.lineHeightMultiple; null = 1.25
    var cascadeFonts: [String]?       // NSFont PostScript names for cascade list
}

struct EditorHeadings: Codable, Equatable {
    var shared: EditorHeadingShared?
    var h1: EditorHeadingLevel?
    var h2: EditorHeadingLevel?
    var h3: EditorHeadingLevel?
    var h4: EditorHeadingLevel?
    var h5: EditorHeadingLevel?
    var h6: EditorHeadingLevel?
}

struct EditorHeadingShared: Codable, Equatable {
    var isBold: Bool?
}

struct EditorHeadingLevel: Codable, Equatable {
    var color: String?            // hex
    var fontSizeOffset: CGFloat?  // added to base fontSize (preserves zoom scaling)
    var isBold: Bool?
}

struct EditorBold: Codable, Equatable {
    var color: String?
}

struct EditorItalic: Codable, Equatable {
    var obliqueness: CGFloat?
    var color: String?
}

struct EditorInlineCode: Codable, Equatable {
    var color: String?
    var backgroundColor: String?  // hex with optional alpha (#RRGGBBAA)
}

struct EditorCodeBlock: Codable, Equatable {
    var color: String?
    var backgroundColor: String?
    var useSecondaryLabelColor: Bool?
}

struct EditorBlockquote: Codable, Equatable {
    var color: String?
    var useSecondaryLabelColor: Bool?
}

struct EditorStrikethrough: Codable, Equatable {
    var color: String?
    var useSecondaryLabelColor: Bool?
}

struct EditorLink: Codable, Equatable {
    var color: String?
    var useLinkColor: Bool?
}

// MARK: - CSS Generation

extension DisplayStyle {
    /// Generates a complete CSS string from this DisplayStyle.
    /// Injected into <style id="custom-style"> in the WKWebView.
    func toCSS() -> String {
        var lines: [String] = []

        // Highlight.js theme
        let hlTheme = global.codeHighlightTheme ?? "github-light"
        if hlTheme == "github-dark" {
            lines.append(DisplayStyle.hljsDarkCSS)
        } else {
            lines.append(DisplayStyle.hljsLightCSS)
        }

        // Reset
        lines.append("* { box-sizing: border-box; margin: 0; padding: 0; }")

        // Body / global
        lines.append("""
        body {
          background-color: \(global.backgroundColor ?? "#FFFFFF");
          color: \(global.textColor ?? "#1A1A1A");
          font-family: \(global.fontFamily ?? "-apple-system, \"SF Pro Text\", \"PingFang SC\", sans-serif");
          font-size: \(global.fontSize ?? "18px");
          line-height: \(global.lineHeight ?? "1.5");
          max-width: \(global.maxWidth ?? "860px");
          padding: \(global.padding ?? "40px 48px 80px");
          margin: 0 auto;
          min-height: 100vh;
        }
        @media (max-width: 700px) { body { padding: 24px 20px; } }
        """)

        // Headings shared
        if let sh = headings.shared {
            var rules: [String] = []
            if let fw = sh.fontWeight { rules.append("font-weight: \(fw);") }
            if let lh = sh.lineHeight { rules.append("line-height: \(lh);") }
            if let ls = sh.letterSpacing { rules.append("letter-spacing: \(ls);") }
            if let mt = sh.marginTop { rules.append("margin-top: \(mt);") }
            if let mb = sh.marginBottom { rules.append("margin-bottom: \(mb);") }
            if !rules.isEmpty {
                lines.append("h1, h2, h3, h4, h5, h6 { \(rules.joined(separator: " ")) }")
            }
        }

        // Individual heading levels
        let hLevels: [(String, DisplayHeadingLevel?)] = [
            ("h1", headings.h1), ("h2", headings.h2), ("h3", headings.h3),
            ("h4", headings.h4), ("h5", headings.h5), ("h6", headings.h6)
        ]
        for (tag, level) in hLevels {
            guard let l = level else { continue }
            var rules: [String] = []
            if let v = l.fontSize      { rules.append("font-size: \(v);") }
            if let v = l.fontWeight    { rules.append("font-weight: \(v);") }
            if let v = l.color         { rules.append("color: \(v);") }
            if let v = l.lineHeight    { rules.append("line-height: \(v);") }
            if let v = l.marginTop     { rules.append("margin-top: \(v);") }
            if let v = l.marginBottom  { rules.append("margin-bottom: \(v);") }
            if let v = l.borderBottom  { rules.append("border-bottom: \(v);") }
            if let v = l.paddingBottom { rules.append("padding-bottom: \(v);") }
            if !rules.isEmpty {
                lines.append("\(tag) { \(rules.joined(separator: " ")) }")
            }
        }

        // Paragraph
        do {
            var rules: [String] = []
            if let v = paragraph.marginTop    { rules.append("margin-top: \(v);") }
            if let v = paragraph.marginBottom { rules.append("margin-bottom: \(v);") }
            if let v = paragraph.lineHeight   { rules.append("line-height: \(v);") }
            if let v = paragraph.color        { rules.append("color: \(v);") }
            if !rules.isEmpty { lines.append("p { \(rules.joined(separator: " ")) }") }
        }

        // Bold / italic
        if let v = bold.fontWeight { lines.append("strong { font-weight: \(v); }") }
        if let v = bold.color      { lines.append("strong { color: \(v); }") }
        if let v = italic.fontStyle { lines.append("em { font-style: \(v); }") }
        if let v = italic.color    { lines.append("em { color: \(v); }") }

        // Inline code
        do {
            var rules: [String] = []
            if let v = inlineCode.fontFamily      { rules.append("font-family: \(v);") }
            if let v = inlineCode.fontSize        { rules.append("font-size: \(v);") }
            if let v = inlineCode.color           { rules.append("color: \(v);") }
            if let v = inlineCode.backgroundColor { rules.append("background-color: \(v);") }
            if let v = inlineCode.borderColor     { rules.append("border: 1px solid \(v);") }
            if let v = inlineCode.borderRadius    { rules.append("border-radius: \(v);") }
            let ph = inlineCode.paddingHorizontal ?? "0.4em"
            let pv = inlineCode.paddingVertical   ?? "0.15em"
            rules.append("padding: \(pv) \(ph);")
            rules.append("white-space: nowrap;")
            if !rules.isEmpty {
                lines.append("code:not(pre code) { \(rules.joined(separator: " ")) }")
            }
        }

        // Code block
        do {
            var rules: [String] = []
            if let v = codeBlock.fontFamily      { rules.append("font-family: \(v);") }
            if let v = codeBlock.fontSize        { rules.append("font-size: \(v);") }
            if let v = codeBlock.backgroundColor { rules.append("background-color: \(v);") }
            if let v = codeBlock.borderColor     { rules.append("border: 1px solid \(v);") }
            if let v = codeBlock.borderRadius    { rules.append("border-radius: \(v);") }
            if let v = codeBlock.padding         { rules.append("padding: \(v);") }
            if let v = codeBlock.lineHeight      { rules.append("line-height: \(v);") }
            if let v = codeBlock.margin          { rules.append("margin: \(v);") }
            rules.append("overflow-x: auto;")
            if !rules.isEmpty { lines.append("pre { \(rules.joined(separator: " ")) }") }
            // override hljs background inside pre to match codeBlock style
            if let v = codeBlock.backgroundColor {
                lines.append("pre code.hljs { background: \(v); padding: 0; }")
            }
        }

        // Blockquote
        do {
            var rules: [String] = []
            if let v = blockquote.fontStyle       { rules.append("font-style: \(v);") }
            if let v = blockquote.color           { rules.append("color: \(v);") }
            if let v = blockquote.backgroundColor { rules.append("background-color: \(v);") }
            let blc = blockquote.borderLeftColor ?? "#D0D7DE"
            let blw = blockquote.borderLeftWidth ?? "4px"
            rules.append("border-left: \(blw) solid \(blc);")
            if let v = blockquote.borderRadius    { rules.append("border-radius: \(v);") }
            if let v = blockquote.padding         { rules.append("padding: \(v);") }
            if let v = blockquote.margin          { rules.append("margin: \(v);") }
            if !rules.isEmpty { lines.append("blockquote { \(rules.joined(separator: " ")) }") }
            // reset inner paragraphs
            lines.append("blockquote p { margin: 0; }")
        }

        // HR
        do {
            var rules: [String] = []
            let color  = horizontalRule.color  ?? "#D0D7DE"
            let height = horizontalRule.height ?? "1px"
            rules.append("border: none; border-top: \(height) solid \(color);")
            if let v = horizontalRule.margin { rules.append("margin: \(v);") }
            if !rules.isEmpty { lines.append("hr { \(rules.joined(separator: " ")) }") }
        }

        // Link
        do {
            let color        = link.color ?? "#0969DA"
            let underline    = link.underline ?? false
            let hoverUnder   = link.hoverUnderline ?? true
            let hoverColor   = link.hoverColor ?? color
            lines.append("a { color: \(color); text-decoration: \(underline ? "underline" : "none"); }")
            lines.append("a:hover { color: \(hoverColor); text-decoration: \(hoverUnder ? "underline" : "none"); }")
        }

        // Lists
        do {
            var rules: [String] = []
            if let v = list.marginTop    { rules.append("margin-top: \(v);") }
            if let v = list.marginBottom { rules.append("margin-bottom: \(v);") }
            let pl = list.paddingLeft ?? "1.75em"
            rules.append("padding-left: \(pl);")
            if !rules.isEmpty { lines.append("ul, ol { \(rules.joined(separator: " ")) }") }
            if let v = list.itemSpacing   { lines.append("li + li { margin-top: \(v); }") }
            if let v = list.nestedSpacing { lines.append("li ul, li ol { margin-top: \(v); }") }
        }

        // Table
        do {
            if let v = table.fontSize {
                lines.append("table { font-size: \(v); width: 100%; border-collapse: collapse; \(table.margin.map { "margin: \($0);" } ?? "") }")
            }
            let bc = table.borderColor ?? "#E1E4E8"
            let cp = table.cellPadding ?? "0.5em 0.75em"
            lines.append("th, td { border: 1px solid \(bc); padding: \(cp); text-align: left; }")
            if let v = table.headerBackgroundColor {
                lines.append("th { background-color: \(v); font-weight: \(table.headerFontWeight ?? "600"); }")
            }
            if let v = table.alternateRowColor {
                lines.append("tr:nth-child(even) { background-color: \(v); }")
            }
        }

        // Strikethrough
        if let v = strikethrough.color { lines.append("del { color: \(v); }") }
        lines.append("del { text-decoration: line-through; }")

        // Image
        do {
            var rules: [String] = []
            if let v = image.maxWidth    { rules.append("max-width: \(v);") }
            if let v = image.borderRadius { rules.append("border-radius: \(v);") }
            if let v = image.margin      { rules.append("margin: \(v);") }
            rules.append("height: auto; display: block;")
            lines.append("img { \(rules.joined(separator: " ")) }")
        }

        // Task list
        if let tl = taskList, let v = tl.checkboxMarginRight {
            lines.append("input[type=checkbox] { margin-right: \(v); }")
        }

        // Custom CSS override
        if let css = customCSS, !css.isEmpty {
            lines.append(css)
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Embedded hljs themes

private extension DisplayStyle {
    static let hljsLightCSS = #"pre code.hljs{display:block;overflow-x:auto;padding:1em}code.hljs{padding:3px 5px}.hljs{color:#24292e;background:#fff}.hljs-doctag,.hljs-keyword,.hljs-meta .hljs-keyword,.hljs-template-tag,.hljs-template-variable,.hljs-type,.hljs-variable.language_{color:#d73a49}.hljs-title,.hljs-title.class_,.hljs-title.class_.inherited__,.hljs-title.function_{color:#6f42c1}.hljs-attr,.hljs-attribute,.hljs-literal,.hljs-meta,.hljs-number,.hljs-operator,.hljs-selector-attr,.hljs-selector-class,.hljs-selector-id,.hljs-variable{color:#005cc5}.hljs-meta .hljs-string,.hljs-regexp,.hljs-string{color:#032f62}.hljs-built_in,.hljs-symbol{color:#e36209}.hljs-code,.hljs-comment,.hljs-formula{color:#6a737d}.hljs-name,.hljs-quote,.hljs-selector-pseudo,.hljs-selector-tag{color:#22863a}.hljs-subst{color:#24292e}.hljs-section{color:#005cc5;font-weight:700}.hljs-bullet{color:#735c0f}.hljs-emphasis{color:#24292e;font-style:italic}.hljs-strong{color:#24292e;font-weight:700}.hljs-addition{color:#22863a;background-color:#f0fff4}.hljs-deletion{color:#b31d28;background-color:#ffeef0}"#

    static let hljsDarkCSS = #"pre code.hljs{display:block;overflow-x:auto;padding:1em}code.hljs{padding:3px 5px}.hljs{color:#c9d1d9;background:#0d1117}.hljs-doctag,.hljs-keyword,.hljs-meta .hljs-keyword,.hljs-template-tag,.hljs-template-variable,.hljs-type,.hljs-variable.language_{color:#ff7b72}.hljs-title,.hljs-title.class_,.hljs-title.class_.inherited__,.hljs-title.function_{color:#d2a8ff}.hljs-attr,.hljs-attribute,.hljs-literal,.hljs-meta,.hljs-number,.hljs-operator,.hljs-selector-attr,.hljs-selector-class,.hljs-selector-id,.hljs-variable{color:#79c0ff}.hljs-meta .hljs-string,.hljs-regexp,.hljs-string{color:#a5d6ff}.hljs-built_in,.hljs-symbol{color:#ffa657}.hljs-code,.hljs-comment,.hljs-formula{color:#8b949e}.hljs-name,.hljs-quote,.hljs-selector-pseudo,.hljs-selector-tag{color:#7ee787}.hljs-subst{color:#c9d1d9}.hljs-section{color:#1f6feb;font-weight:700}.hljs-bullet{color:#f2cc60}.hljs-emphasis{color:#c9d1d9;font-style:italic}.hljs-strong{color:#c9d1d9;font-weight:700}.hljs-addition{color:#aff5b4;background-color:#033a16}.hljs-deletion{color:#ffdcd7;background-color:#67060c}"#
}

// MARK: - System defaults (hardcoded fallback)
extension StylesFile {
    static let systemDefaults = StylesFile(
        schemaVersion: 1,
        activeStyle: "GDS-Style",
        styles: [
            // ── GDS-Style ──────────────────────────────────────────────────
            MarkdownStyle(
                name: "GDS-Style",
                displayStyle: DisplayStyle(
                    global: DisplayGlobal(
                        backgroundColor: "#FFFFFF",
                        textColor: "#1A1A1A",
                        fontFamily: #"-apple-system, "SF Pro Text", "PingFang SC", "Heiti SC", "Helvetica Neue", Arial, sans-serif"#,
                        fontSize: "18px",
                        lineHeight: "1.5",
                        maxWidth: "860px",
                        padding: "40px 48px 80px",
                        codeHighlightTheme: "github-light"
                    ),
                    headings: DisplayHeadings(
                        shared: DisplayHeadingShared(fontWeight: "600", lineHeight: "1.3", letterSpacing: "-0.01em", marginTop: "1.4em", marginBottom: "0.5em"),
                        h1: DisplayHeadingLevel(fontSize: "2em",    fontWeight: "600", color: "#4285F4", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: "2px solid #4285F4", paddingBottom: "0.25em"),
                        h2: DisplayHeadingLevel(fontSize: "1.5em",  fontWeight: "600", color: "#EA4335", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: "1px solid #E1E4E8", paddingBottom: "0.2em"),
                        h3: DisplayHeadingLevel(fontSize: "1.25em", fontWeight: "600", color: "#FBBC05", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: nil, paddingBottom: nil),
                        h4: DisplayHeadingLevel(fontSize: "1.1em",  fontWeight: "600", color: "#34A853", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: nil, paddingBottom: nil),
                        h5: DisplayHeadingLevel(fontSize: "1em",    fontWeight: "600", color: "#4285F4", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: nil, paddingBottom: nil),
                        h6: DisplayHeadingLevel(fontSize: "0.9em",  fontWeight: "600", color: "#EA4335", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: nil, paddingBottom: nil)
                    ),
                    paragraph:  DisplayParagraph(marginTop: "0.75em", marginBottom: "0.75em", lineHeight: nil, color: nil),
                    bold:       DisplayBold(fontWeight: "600", color: nil),
                    italic:     DisplayItalic(fontStyle: "italic", color: nil),
                    inlineCode: DisplayInlineCode(fontFamily: #""SF Mono", Menlo, Consolas, "Courier New", monospace"#, fontSize: "0.875em", color: "#D63384", backgroundColor: "#F6F8FA", borderColor: "#E1E4E8", borderRadius: "4px", paddingHorizontal: "0.4em", paddingVertical: "0.15em"),
                    codeBlock:  DisplayCodeBlock(fontFamily: #""SF Mono", Menlo, Consolas, "Courier New", monospace"#, fontSize: "0.85em", backgroundColor: "#F6F8FA", borderColor: "#E1E4E8", borderRadius: "8px", padding: "1em 1.25em", lineHeight: "1.6", margin: "1em 0"),
                    blockquote: DisplayBlockquote(fontStyle: nil, color: "#656D76", backgroundColor: "#F6F8FA", borderLeftColor: "#D0D7DE", borderLeftWidth: "4px", borderRadius: "0 4px 4px 0", padding: "0.5em 1em", margin: "1em 0"),
                    horizontalRule: DisplayHorizontalRule(color: "#D0D7DE", height: "1px", margin: "1.5em 0"),
                    link:       DisplayLink(color: "#0969DA", hoverColor: nil, underline: false, hoverUnderline: true),
                    list:       DisplayList(marginTop: "0.75em", marginBottom: "0.75em", paddingLeft: "1.75em", itemSpacing: "0.3em", nestedSpacing: "0.2em"),
                    table:      DisplayTable(fontSize: "0.95em", headerBackgroundColor: "#F6F8FA", headerFontWeight: "600", alternateRowColor: "#F9FAFB", borderColor: "#E1E4E8", cellPadding: "0.5em 0.75em", margin: "1em 0"),
                    strikethrough: DisplayStrikethrough(color: nil),
                    image:      DisplayImage(maxWidth: "100%", borderRadius: "6px", margin: "0.75em 0"),
                    taskList:   DisplayTaskList(checkboxMarginRight: "0.4em"),
                    customCSS:  nil
                ),
                editorStyle: EditorStyle(
                    global: EditorGlobal(fontFamily: "system", fontSize: 18, lineHeightMultiple: 1.25, cascadeFonts: ["PingFangSC-Regular"]),
                    headings: EditorHeadings(
                        shared: EditorHeadingShared(isBold: true),
                        h1: EditorHeadingLevel(color: "#4285F4", fontSizeOffset: 6, isBold: true),
                        h2: EditorHeadingLevel(color: "#EA4335", fontSizeOffset: 4, isBold: true),
                        h3: EditorHeadingLevel(color: "#FBBC05", fontSizeOffset: 2, isBold: true),
                        h4: EditorHeadingLevel(color: "#34A853", fontSizeOffset: 1, isBold: true),
                        h5: EditorHeadingLevel(color: "#4285F4", fontSizeOffset: 0, isBold: true),
                        h6: EditorHeadingLevel(color: "#EA4335", fontSizeOffset: 0, isBold: true)
                    ),
                    bold:          EditorBold(color: nil),
                    italic:        EditorItalic(obliqueness: 0.2, color: nil),
                    inlineCode:    EditorInlineCode(color: "#FF3B30", backgroundColor: "#8E8E9326"),
                    codeBlock:     EditorCodeBlock(color: nil, backgroundColor: "#8E8E9314", useSecondaryLabelColor: true),
                    blockquote:    EditorBlockquote(color: nil, useSecondaryLabelColor: true),
                    strikethrough: EditorStrikethrough(color: nil, useSecondaryLabelColor: true),
                    link:          EditorLink(color: nil, useLinkColor: true)
                )
            ),
            // ── Dark ───────────────────────────────────────────────────────
            MarkdownStyle(
                name: "Dark",
                displayStyle: DisplayStyle(
                    global: DisplayGlobal(
                        backgroundColor: "#0D1117", textColor: "#E6EDF3",
                        fontFamily: #"-apple-system, "SF Pro Text", "PingFang SC", "Heiti SC", "Helvetica Neue", Arial, sans-serif"#,
                        fontSize: "18px", lineHeight: "1.5", maxWidth: "860px",
                        padding: "40px 48px 80px", codeHighlightTheme: "github-dark"
                    ),
                    headings: DisplayHeadings(
                        shared: DisplayHeadingShared(fontWeight: "600", lineHeight: "1.3", letterSpacing: "-0.01em", marginTop: "1.4em", marginBottom: "0.5em"),
                        h1: DisplayHeadingLevel(fontSize: "2em",    fontWeight: "600", color: "#6AA9F8", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: "2px solid #6AA9F8", paddingBottom: "0.25em"),
                        h2: DisplayHeadingLevel(fontSize: "1.5em",  fontWeight: "600", color: "#F28B82", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: "1px solid #30363D", paddingBottom: "0.2em"),
                        h3: DisplayHeadingLevel(fontSize: "1.25em", fontWeight: "600", color: "#FDD663", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: nil, paddingBottom: nil),
                        h4: DisplayHeadingLevel(fontSize: "1.1em",  fontWeight: "600", color: "#57BB8A", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: nil, paddingBottom: nil),
                        h5: DisplayHeadingLevel(fontSize: "1em",    fontWeight: "600", color: "#6AA9F8", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: nil, paddingBottom: nil),
                        h6: DisplayHeadingLevel(fontSize: "0.9em",  fontWeight: "600", color: "#F28B82", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: nil, paddingBottom: nil)
                    ),
                    paragraph:  DisplayParagraph(marginTop: "0.75em", marginBottom: "0.75em", lineHeight: nil, color: nil),
                    bold:       DisplayBold(fontWeight: "600", color: nil),
                    italic:     DisplayItalic(fontStyle: "italic", color: nil),
                    inlineCode: DisplayInlineCode(fontFamily: #""SF Mono", Menlo, Consolas, "Courier New", monospace"#, fontSize: "0.875em", color: "#FF7B72", backgroundColor: "#161B22", borderColor: "#30363D", borderRadius: "4px", paddingHorizontal: "0.4em", paddingVertical: "0.15em"),
                    codeBlock:  DisplayCodeBlock(fontFamily: #""SF Mono", Menlo, Consolas, "Courier New", monospace"#, fontSize: "0.85em", backgroundColor: "#161B22", borderColor: "#30363D", borderRadius: "8px", padding: "1em 1.25em", lineHeight: "1.6", margin: "1em 0"),
                    blockquote: DisplayBlockquote(fontStyle: nil, color: "#9198A1", backgroundColor: "#161B22", borderLeftColor: "#3D444D", borderLeftWidth: "4px", borderRadius: "0 4px 4px 0", padding: "0.5em 1em", margin: "1em 0"),
                    horizontalRule: DisplayHorizontalRule(color: "#30363D", height: "1px", margin: "1.5em 0"),
                    link:       DisplayLink(color: "#4493F8", hoverColor: nil, underline: false, hoverUnderline: true),
                    list:       DisplayList(marginTop: "0.75em", marginBottom: "0.75em", paddingLeft: "1.75em", itemSpacing: "0.3em", nestedSpacing: "0.2em"),
                    table:      DisplayTable(fontSize: "0.95em", headerBackgroundColor: "#161B22", headerFontWeight: "600", alternateRowColor: "#0D1117", borderColor: "#30363D", cellPadding: "0.5em 0.75em", margin: "1em 0"),
                    strikethrough: DisplayStrikethrough(color: nil),
                    image:      DisplayImage(maxWidth: "100%", borderRadius: "6px", margin: "0.75em 0"),
                    taskList:   DisplayTaskList(checkboxMarginRight: "0.4em"),
                    customCSS:  nil
                ),
                editorStyle: EditorStyle(
                    global: EditorGlobal(fontFamily: "system", fontSize: 18, lineHeightMultiple: 1.25, cascadeFonts: ["PingFangSC-Regular"]),
                    headings: EditorHeadings(
                        shared: EditorHeadingShared(isBold: true),
                        h1: EditorHeadingLevel(color: "#6AA9F8", fontSizeOffset: 6, isBold: true),
                        h2: EditorHeadingLevel(color: "#F28B82", fontSizeOffset: 4, isBold: true),
                        h3: EditorHeadingLevel(color: "#FDD663", fontSizeOffset: 2, isBold: true),
                        h4: EditorHeadingLevel(color: "#57BB8A", fontSizeOffset: 1, isBold: true),
                        h5: EditorHeadingLevel(color: "#6AA9F8", fontSizeOffset: 0, isBold: true),
                        h6: EditorHeadingLevel(color: "#F28B82", fontSizeOffset: 0, isBold: true)
                    ),
                    bold:          EditorBold(color: nil),
                    italic:        EditorItalic(obliqueness: 0.2, color: nil),
                    inlineCode:    EditorInlineCode(color: "#FF7B72", backgroundColor: "#8E8E9326"),
                    codeBlock:     EditorCodeBlock(color: nil, backgroundColor: "#8E8E9314", useSecondaryLabelColor: true),
                    blockquote:    EditorBlockquote(color: nil, useSecondaryLabelColor: true),
                    strikethrough: EditorStrikethrough(color: nil, useSecondaryLabelColor: true),
                    link:          EditorLink(color: nil, useLinkColor: true)
                )
            ),
            // ── Sepia ──────────────────────────────────────────────────────
            MarkdownStyle(
                name: "Sepia",
                displayStyle: DisplayStyle(
                    global: DisplayGlobal(
                        backgroundColor: "#F8F2E4", textColor: "#3B2F2F",
                        fontFamily: #"-apple-system, "SF Pro Text", "PingFang SC", "Heiti SC", "Helvetica Neue", Arial, sans-serif"#,
                        fontSize: "18px", lineHeight: "1.5", maxWidth: "860px",
                        padding: "40px 48px 80px", codeHighlightTheme: "github-light"
                    ),
                    headings: DisplayHeadings(
                        shared: DisplayHeadingShared(fontWeight: "600", lineHeight: "1.3", letterSpacing: "-0.01em", marginTop: "1.4em", marginBottom: "0.5em"),
                        h1: DisplayHeadingLevel(fontSize: "2em",    fontWeight: "600", color: "#5C7A9E", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: "2px solid #5C7A9E", paddingBottom: "0.25em"),
                        h2: DisplayHeadingLevel(fontSize: "1.5em",  fontWeight: "600", color: "#9E3D3D", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: "1px solid #D4C4A8", paddingBottom: "0.2em"),
                        h3: DisplayHeadingLevel(fontSize: "1.25em", fontWeight: "600", color: "#9E7C2A", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: nil, paddingBottom: nil),
                        h4: DisplayHeadingLevel(fontSize: "1.1em",  fontWeight: "600", color: "#4A7C5E", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: nil, paddingBottom: nil),
                        h5: DisplayHeadingLevel(fontSize: "1em",    fontWeight: "600", color: "#5C7A9E", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: nil, paddingBottom: nil),
                        h6: DisplayHeadingLevel(fontSize: "0.9em",  fontWeight: "600", color: "#9E3D3D", lineHeight: nil, marginTop: nil, marginBottom: nil, borderBottom: nil, paddingBottom: nil)
                    ),
                    paragraph:  DisplayParagraph(marginTop: "0.75em", marginBottom: "0.75em", lineHeight: nil, color: nil),
                    bold:       DisplayBold(fontWeight: "600", color: nil),
                    italic:     DisplayItalic(fontStyle: "italic", color: nil),
                    inlineCode: DisplayInlineCode(fontFamily: #""SF Mono", Menlo, Consolas, "Courier New", monospace"#, fontSize: "0.875em", color: "#7C3D2F", backgroundColor: "#EDE7D9", borderColor: "#D4C4A8", borderRadius: "4px", paddingHorizontal: "0.4em", paddingVertical: "0.15em"),
                    codeBlock:  DisplayCodeBlock(fontFamily: #""SF Mono", Menlo, Consolas, "Courier New", monospace"#, fontSize: "0.85em", backgroundColor: "#EDE7D9", borderColor: "#D4C4A8", borderRadius: "8px", padding: "1em 1.25em", lineHeight: "1.6", margin: "1em 0"),
                    blockquote: DisplayBlockquote(fontStyle: nil, color: "#7A6652", backgroundColor: "#EDE7D9", borderLeftColor: "#C4A882", borderLeftWidth: "4px", borderRadius: "0 4px 4px 0", padding: "0.5em 1em", margin: "1em 0"),
                    horizontalRule: DisplayHorizontalRule(color: "#C4A882", height: "1px", margin: "1.5em 0"),
                    link:       DisplayLink(color: "#8B4513", hoverColor: nil, underline: false, hoverUnderline: true),
                    list:       DisplayList(marginTop: "0.75em", marginBottom: "0.75em", paddingLeft: "1.75em", itemSpacing: "0.3em", nestedSpacing: "0.2em"),
                    table:      DisplayTable(fontSize: "0.95em", headerBackgroundColor: "#EDE7D9", headerFontWeight: "600", alternateRowColor: "#F2EBE0", borderColor: "#D4C4A8", cellPadding: "0.5em 0.75em", margin: "1em 0"),
                    strikethrough: DisplayStrikethrough(color: nil),
                    image:      DisplayImage(maxWidth: "100%", borderRadius: "6px", margin: "0.75em 0"),
                    taskList:   DisplayTaskList(checkboxMarginRight: "0.4em"),
                    customCSS:  nil
                ),
                editorStyle: EditorStyle(
                    global: EditorGlobal(fontFamily: "system", fontSize: 18, lineHeightMultiple: 1.25, cascadeFonts: ["PingFangSC-Regular"]),
                    headings: EditorHeadings(
                        shared: EditorHeadingShared(isBold: true),
                        h1: EditorHeadingLevel(color: "#5C7A9E", fontSizeOffset: 6, isBold: true),
                        h2: EditorHeadingLevel(color: "#9E3D3D", fontSizeOffset: 4, isBold: true),
                        h3: EditorHeadingLevel(color: "#9E7C2A", fontSizeOffset: 2, isBold: true),
                        h4: EditorHeadingLevel(color: "#4A7C5E", fontSizeOffset: 1, isBold: true),
                        h5: EditorHeadingLevel(color: "#5C7A9E", fontSizeOffset: 0, isBold: true),
                        h6: EditorHeadingLevel(color: "#9E3D3D", fontSizeOffset: 0, isBold: true)
                    ),
                    bold:          EditorBold(color: nil),
                    italic:        EditorItalic(obliqueness: 0.2, color: nil),
                    inlineCode:    EditorInlineCode(color: "#7C3D2F", backgroundColor: "#8E8E9326"),
                    codeBlock:     EditorCodeBlock(color: nil, backgroundColor: "#8E8E9314", useSecondaryLabelColor: true),
                    blockquote:    EditorBlockquote(color: nil, useSecondaryLabelColor: true),
                    strikethrough: EditorStrikethrough(color: nil, useSecondaryLabelColor: true),
                    link:          EditorLink(color: nil, useLinkColor: true)
                )
            )
        ]
    )
}

// MARK: - NSColor hex helper (shared)
extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let len = hex.count
        if len == 8 {
            // #RRGGBBAA
            self.init(
                red:   CGFloat((int >> 24) & 0xFF) / 255,
                green: CGFloat((int >> 16) & 0xFF) / 255,
                blue:  CGFloat((int >>  8) & 0xFF) / 255,
                alpha: CGFloat( int        & 0xFF) / 255
            )
        } else {
            // #RRGGBB
            self.init(
                red:   CGFloat((int >> 16) & 0xFF) / 255,
                green: CGFloat((int >>  8) & 0xFF) / 255,
                blue:  CGFloat( int        & 0xFF) / 255,
                alpha: 1
            )
        }
    }
}
