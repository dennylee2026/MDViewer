import AppKit

/// Vertical ruler view that draws line numbers alongside an NSTextView.
final class LineNumberRulerView: NSRulerView {

    private weak var textView: NSTextView?
    private let numberFont  = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
    private let rightPad: CGFloat = 8

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView   = textView
        ruleThickness = 42

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(refresh),
                       name: NSText.didChangeNotification, object: textView)
        nc.addObserver(self, selector: #selector(refresh),
                       name: NSView.boundsDidChangeNotification,
                       object: scrollView.contentView)
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func refresh() { needsDisplay = true }

    // MARK: - Drawing

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let container     = textView.textContainer else { return }

        // Background
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        // Right border
        NSColor.separatorColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.maxX - 0.5, y: 0))
        path.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        path.lineWidth = 1
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font:            numberFont,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        let string      = textView.string as NSString
        let length      = string.length
        let inset       = textView.textContainerInset
        let visibleRect = textView.visibleRect

        var charIndex = 0
        var lineNumber = 1

        while charIndex <= length {
            let lineRange = string.lineRange(for: NSRange(location: charIndex, length: 0))
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange,
                                                       actualCharacterRange: nil)
            if glyphRange.length > 0 || charIndex == length {
                var fragmentRect = NSRect.zero
                if glyphRange.length > 0 {
                    fragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location,
                                                                   effectiveRange: nil)
                } else {
                    // Empty last line – use end-of-text rect
                    let usedRect = layoutManager.usedRect(for: container)
                    fragmentRect = NSRect(x: 0, y: usedRect.maxY, width: 0, height: numberFont.pointSize * 1.5)
                }

                let lineY = fragmentRect.minY + inset.height

                // Only draw if in visible area
                if lineY + fragmentRect.height >= visibleRect.minY &&
                   lineY <= visibleRect.maxY {

                    // Convert text-view Y → ruler-view Y
                    let pointInTextView = NSPoint(x: 0, y: lineY + fragmentRect.height / 2)
                    let pointInRuler   = convert(pointInTextView, from: textView)

                    let label     = "\(lineNumber)" as NSString
                    let labelSize = label.size(withAttributes: attrs)
                    let drawX     = bounds.maxX - labelSize.width - rightPad
                    let drawY     = pointInRuler.y - labelSize.height / 2

                    label.draw(at: NSPoint(x: drawX, y: drawY), withAttributes: attrs)
                }
            }

            if charIndex >= length { break }
            charIndex = NSMaxRange(lineRange)
            lineNumber += 1
        }
    }
}
