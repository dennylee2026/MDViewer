import AppKit
import SwiftUI
import WebKit

// MARK: - View Mode

enum ViewMode {
    case split    // 分栏：左编辑右预览，无侧栏
    case editor   // 纯编辑，无侧栏
    case viewer   // 纯预览，显示大纲侧栏
}

// MARK: - Folder Model

struct FolderItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    var children: [FolderItem]?
}

// MARK: - Heading Model

struct HeadingItem: Identifiable {
    let id = UUID()
    let level: Int
    let text: String
    let index: Int
    let charOffset: Int   // UTF-16 offset in the markdown string (matches NSRange)
}

// MARK: - AppState

class AppState: ObservableObject {
    @Published var fileURL: URL?
    @Published var markdownContent: String = ""
    @Published var headings: [HeadingItem] = []
    @Published var viewMode: ViewMode = .split
    @Published var isDirty: Bool = false
    @Published var zoomLevel: Double = 1.0   // overwritten in init from UserDefaults
    @Published var recentURLs: [URL] = []
    @Published var folderURL: URL?
    @Published var folderItems: [FolderItem] = []
    @Published var showFolderSidebar: Bool = false
    @Published var showSavedBadge: Bool = false
    @Published var editorScrollTarget: EditorScrollTarget? = nil
    @Published var isExporting: Bool = false

    var webView: WKWebView?
    private var savedBadgeTask: Task<Void, Never>?

    private let fileWatcher = FileWatcher()

    init() {
        let saved = UserDefaults.standard.double(forKey: "MDViewer.zoomLevel")
        if saved > 0 { zoomLevel = min(3.0, max(0.5, saved)) }
        recentURLs = Array(NSDocumentController.shared.recentDocumentURLs.prefix(10))
        StyleManager.shared.setup()
    }

    // MARK: Open

    func open(url: URL) {
        fileURL = url
        reload()
        isDirty = false
        viewMode = .viewer
        fileWatcher.watch(url: url) { [weak self] in self?.reloadFromDisk() }
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        recentURLs = Array(NSDocumentController.shared.recentDocumentURLs.prefix(10))
        // Track last opened file so the picker can open inside its directory next time
        UserDefaults.standard.set(url.path, forKey: "MDViewer.lastOpenedFilePath")
    }

    // MARK: Reload

    func reload() {
        guard let url = fileURL else { return }
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            markdownContent = content
            headings = Self.parseHeadings(from: content)
        }
    }

    private func reloadFromDisk() {
        guard fileURL != nil, !isDirty else { return }
        reload()
    }

    // MARK: Save

    func save() {
        if let url = fileURL { writeContent(to: url) } else { saveAs() }
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "Untitled.md"
        if panel.runModal() == .OK, let url = panel.url {
            fileURL = url
            writeContent(to: url)
            fileWatcher.watch(url: url) { [weak self] in self?.reloadFromDisk() }
        }
    }

    private func writeContent(to url: URL) {
        try? markdownContent.write(to: url, atomically: true, encoding: .utf8)
        isDirty = false
        flashSavedBadge()
    }

    private func flashSavedBadge() {
        savedBadgeTask?.cancel()
        showSavedBadge = true
        savedBadgeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self.showSavedBadge = false
        }
    }

    // MARK: Content change from editor

    func editorDidChange(to text: String) {
        markdownContent = text
        headings = Self.parseHeadings(from: text)
        isDirty = true
    }

    // MARK: Folder

    func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "panel.openFolder.prompt")
        if panel.runModal() == .OK, let url = panel.url {
            openFolder(url: url)
        }
    }

    func openFolder(url: URL) {
        folderURL = url
        folderItems = Self.scanFolder(url)
        showFolderSidebar = true
    }

    static func scanFolder(_ url: URL) -> [FolderItem] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return contents
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .compactMap { itemURL in
                let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                if isDir {
                    let children = scanFolder(itemURL)
                    guard !children.isEmpty else { return nil }
                    return FolderItem(url: itemURL, name: itemURL.lastPathComponent, isDirectory: true, children: children)
                } else if itemURL.pathExtension == "md" || itemURL.pathExtension == "markdown" {
                    return FolderItem(url: itemURL, name: itemURL.lastPathComponent, isDirectory: false, children: nil)
                }
                return nil
            }
    }

    // MARK: Export — Helpers

    private func exportTimestamp() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd'T'HHmm"
        return fmt.string(from: Date())
    }

    // MARK: Export — Mobile CSS helpers

    // MARK: Mobile CSS — Google brand color scheme (per MOBILE_STYLE_GUIDE.md)
    // Blue:#4285F4  Red:#EA4335  Yellow:#FBBC05  Green:#34A853
    private func mobileCSSOverrides() -> String {
        """
        @page { margin: 0 !important; size: auto !important; }
        html {
            overflow-x: hidden !important;
        }
        * {
            box-sizing: border-box !important;
            page-break-inside: avoid !important; break-inside: avoid !important;
            page-break-before: avoid !important; break-before: avoid !important;
            page-break-after: avoid !important; break-after: avoid !important;
        }
        body {
            font-family: 'PingFang SC', 'Hiragino Sans GB', 'Noto Sans CJK SC',
                         'Microsoft YaHei', -apple-system, BlinkMacSystemFont,
                         'Segoe UI', 'Helvetica Neue', Arial, sans-serif !important;
            font-size: 18px !important;
            line-height: 1.25 !important;
            color: #1a1a1a !important;
            max-width: 100% !important;
            padding: 20px 18px 32px !important;
            word-break: break-word !important;
            margin: 0 !important;
            background: #fff !important;
            overflow-x: hidden !important;
        }
        #content {
            max-width: 100% !important;
            width: 100% !important;
            margin-left: 0 !important;
            margin-right: 0 !important;
            padding-left: 0 !important;
            padding-right: 0 !important;
        }
        h1 {
            font-size: 28px !important;
            color: #4285F4 !important;
            border-left: 4px solid #4285F4 !important;
            padding-left: 10px !important;
            margin-top: 1.4em !important;
            margin-bottom: 0.4em !important;
            background: none !important;
            overflow-wrap: break-word !important;
            word-break: break-word !important;
        }
        h2 {
            font-size: 24px !important;
            color: #EA4335 !important;
            border-left: 4px solid #EA4335 !important;
            padding-left: 10px !important;
            margin-top: 1.3em !important;
            margin-bottom: 0.4em !important;
            background: none !important;
            overflow-wrap: break-word !important;
            word-break: break-word !important;
        }
        h3 {
            font-size: 22px !important;
            color: #34A853 !important;
            border-left: 4px solid #34A853 !important;
            padding-left: 10px !important;
            margin-top: 1.2em !important;
            margin-bottom: 0.3em !important;
            background: none !important;
            overflow-wrap: break-word !important;
            word-break: break-word !important;
        }
        h4 {
            font-size: 20px !important;
            background: #FBBC05 !important;
            color: #1a1a1a !important;
            display: inline-block !important;
            max-width: 100% !important;
            padding: 0 6px 1px !important;
            border-radius: 3px !important;
            border-left: none !important;
            margin-top: 1.1em !important;
            margin-bottom: 0.3em !important;
            overflow-wrap: break-word !important;
            word-break: break-word !important;
        }
        h5 {
            font-size: 18px !important;
            color: #4285F4 !important;
            border-left: none !important;
            background: none !important;
            margin-top: 1em !important;
            margin-bottom: 0.3em !important;
            overflow-wrap: break-word !important;
            word-break: break-word !important;
        }
        h6 {
            font-size: 17px !important;
            color: #EA4335 !important;
            border-left: none !important;
            background: none !important;
            margin-top: 1em !important;
            margin-bottom: 0.3em !important;
            overflow-wrap: break-word !important;
            word-break: break-word !important;
        }
        strong, b {
            background: rgba(251, 188, 5, 0.28) !important;
            padding: 0 2px !important;
            border-radius: 2px !important;
            font-weight: 700 !important;
        }
        p { margin: 0.75em 0 !important; }
        a {
            color: #4285F4 !important;
            text-decoration: none !important;
            border-bottom: 1px solid rgba(66, 133, 244, 0.3) !important;
        }
        blockquote {
            border-left: 4px solid #FBBC05 !important;
            margin: 1em 0 !important;
            padding: 6px 12px !important;
            background: rgba(251, 188, 5, 0.08) !important;
            color: #444 !important;
        }
        code {
            font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace !important;
            font-size: 14px !important;
            background: #f1f3f4 !important;
            padding: 1px 5px !important;
            border-radius: 3px !important;
            white-space: normal !important;
            word-break: break-all !important;
        }
        pre {
            background: #f1f3f4 !important;
            padding: 12px 14px !important;
            border-radius: 6px !important;
            overflow: visible !important;
            font-size: 13px !important;
            line-height: 1.55 !important;
            margin: 1em 0 !important;
            white-space: pre-wrap !important;
            word-break: break-word !important;
        }
        pre code {
            background: none !important;
            padding: 0 !important;
            font-size: inherit !important;
            white-space: pre-wrap !important;
            word-break: break-word !important;
        }
        table {
            width: 100% !important;
            border-collapse: collapse !important;
            font-size: 14px !important;
            margin: 1em 0 !important;
            table-layout: fixed !important;
        }
        th {
            background: #4285F4 !important;
            color: #fff !important;
            padding: 6px 8px !important;
            text-align: left !important;
            word-break: break-word !important;
            overflow-wrap: break-word !important;
        }
        td {
            border-bottom: 1px solid #e0e0e0 !important;
            padding: 5px 8px !important;
            word-break: break-word !important;
            overflow-wrap: break-word !important;
        }
        tr:nth-child(even) td { background: #f8f9fa !important; }
        ul, ol { padding-left: 1.4em !important; margin: 0.6em 0 !important; }
        li { margin: 0.3em 0 !important; }
        img { max-width: 100% !important; height: auto !important; border-radius: 6px !important; }
        hr { border: none !important; border-top: 2px solid #e0e0e0 !important; margin: 1.5em 0 !important; }
        """
    }

    /// Injects mobile CSS overrides, waits for layout, calls action(done).
    /// Caller must invoke the `done` closure to remove the overrides.
    private func withMobileCSS(action: @escaping (@escaping () -> Void) -> Void) {
        guard let webView else { return }
        let css = mobileCSSOverrides()
        let escaped = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        webView.evaluateJavaScript("applyMobileCSS(`\(escaped)`)") { _, _ in
            // Force html + body to exactly 390px wide using inline !important styles.
            // On macOS, WKWebView's CSS viewport width follows the WINDOW width, not the
            // view frame — so resizing the frame to 390pt does NOT change window.innerWidth.
            // Inline !important overrides all external-stylesheet !important rules and forces
            // layout to 390px regardless of what the CSS viewport reports.
            let forceWidth = """
            (function(){
                var h = document.documentElement, b = document.body;
                h.style.setProperty('width',       '390px',  'important');
                h.style.setProperty('max-width',   '390px',  'important');
                h.style.setProperty('overflow-x',  'hidden', 'important');
                b.style.setProperty('width',       '390px',  'important');
                b.style.setProperty('max-width',   '390px',  'important');
                b.style.setProperty('overflow-x',  'hidden', 'important');
            })();
            """
            webView.evaluateJavaScript(forceWidth) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    action {
                        // Remove all inline overrides so the live preview is unaffected
                        let cleanup = """
                        (function(){
                            var h = document.documentElement, b = document.body;
                            h.style.removeProperty('width');
                            h.style.removeProperty('max-width');
                            h.style.removeProperty('overflow-x');
                            b.style.removeProperty('width');
                            b.style.removeProperty('max-width');
                            b.style.removeProperty('overflow-x');
                        })();
                        """
                        webView.evaluateJavaScript(cleanup, completionHandler: nil)
                        webView.evaluateJavaScript("removeMobileCSS()", completionHandler: nil)
                    }
                }
            }
        }
    }

    // MARK: Export — Private write helpers (used by exportAll for chaining)

    private func _writeDesktopPDF(to url: URL, done: @escaping () -> Void) {
        guard let webView else { done(); return }
        webView.createPDF { result in
            DispatchQueue.main.async {
                if case .success(let data) = result { try? data.write(to: url) }
                done()
            }
        }
    }

    /// Temporarily detach the webView from SwiftUI's AutoLayout so that manual
    /// frame changes are not reverted by the layout engine. Returns a restore
    /// closure that re-enables AutoLayout and restores the original frame/alpha/zoom.
    private func detachWebViewForExport(mobileWidth: CGFloat)
        -> (originalFrame: CGRect, savedConstraints: [NSLayoutConstraint], restore: () -> Void)?
    {
        guard let webView else { return nil }
        let originalFrame = webView.frame
        let originalAlpha = webView.alphaValue
        let originalZoom  = webView.pageZoom
        let originalTAMIC = webView.translatesAutoresizingMaskIntoConstraints

        // Gather all constraints in the superview that reference this webView.
        let savedConstraints: [NSLayoutConstraint] = webView.superview?
            .constraints.filter { $0.firstItem === webView || $0.secondItem === webView } ?? []
        NSLayoutConstraint.deactivate(savedConstraints)

        // Also deactivate constraints owned by the webView itself (width/height).
        let ownConstraints = webView.constraints.filter { $0.firstItem === webView || $0.secondItem === webView }
        NSLayoutConstraint.deactivate(ownConstraints)

        webView.translatesAutoresizingMaskIntoConstraints = true

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        webView.alphaValue = 0
        webView.pageZoom = 1.0
        var narrowFrame = originalFrame
        narrowFrame.size.width = mobileWidth
        webView.frame = narrowFrame
        CATransaction.commit()

        let restore: () -> Void = {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            webView.translatesAutoresizingMaskIntoConstraints = originalTAMIC
            NSLayoutConstraint.activate(savedConstraints)
            NSLayoutConstraint.activate(ownConstraints)
            webView.frame = originalFrame
            webView.alphaValue = originalAlpha
            webView.pageZoom = originalZoom
            CATransaction.commit()
            // Force layout pass so SwiftUI reclaims correct geometry immediately.
            webView.superview?.needsLayout = true
        }
        return (originalFrame, savedConstraints, restore)
    }

    private func _writeMobilePDF(to url: URL, done: @escaping () -> Void) {
        guard webView != nil else { done(); return }
        withMobileCSS { [weak self] removeMobile in
            guard let self, let webView = self.webView,
                  let detach = self.detachWebViewForExport(mobileWidth: 390)
            else { removeMobile(); done(); return }
            let mobileWidth: CGFloat = 390

            // Wait for reflow after frame narrowing + viewport override
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                webView.evaluateJavaScript(
                    "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)"
                ) { result, _ in
                    DispatchQueue.main.async {
                        let h1 = max(CGFloat((result as? NSNumber)?.doubleValue ?? 800), 1)

                        // Resize webView to full content height
                        CATransaction.begin(); CATransaction.setDisableActions(true)
                        webView.frame = CGRect(x: webView.frame.origin.x, y: webView.frame.origin.y,
                                               width: mobileWidth, height: h1)
                        CATransaction.commit()

                        // Re-query height after resize (layout may shift)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            webView.evaluateJavaScript(
                                "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)"
                            ) { result2, _ in
                                DispatchQueue.main.async {
                                    let h2 = CGFloat((result2 as? NSNumber)?.doubleValue ?? Double(h1))
                                    let finalH = max(h1, h2) + 32  // small bottom buffer

                                    CATransaction.begin(); CATransaction.setDisableActions(true)
                                    webView.frame = CGRect(x: webView.frame.origin.x, y: webView.frame.origin.y,
                                                           width: mobileWidth, height: finalH)
                                    CATransaction.commit()

                                    // Short settle before snapshot
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        let snapCfg = WKSnapshotConfiguration()
                                        snapCfg.rect = CGRect(x: 0, y: 0, width: mobileWidth, height: finalH)
                                        webView.takeSnapshot(with: snapCfg) { image, _ in
                                            DispatchQueue.main.async {
                                                detach.restore()
                                                removeMobile()
                                                if let image {
                                                    let pdfData = Self.pdfData(from: image)
                                                    try? pdfData?.write(to: url)
                                                }
                                                done()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func _writeMobileImage(to url: URL, done: @escaping () -> Void) {
        guard webView != nil else { done(); return }
        withMobileCSS { [weak self] removeMobile in
            guard let self, let webView = self.webView,
                  let detach = self.detachWebViewForExport(mobileWidth: 390)
            else { removeMobile(); done(); return }
            let mobileWidth: CGFloat = 390

            // Wait for reflow after frame narrowing + viewport override
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                webView.evaluateJavaScript(
                    "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)"
                ) { result, _ in
                    DispatchQueue.main.async {
                        let h1 = max(CGFloat((result as? NSNumber)?.doubleValue ?? 800), 1)

                        // Resize webView to full content height
                        CATransaction.begin(); CATransaction.setDisableActions(true)
                        webView.frame = CGRect(x: webView.frame.origin.x, y: webView.frame.origin.y,
                                               width: mobileWidth, height: h1)
                        CATransaction.commit()

                        // Re-query height after resize (layout may shift)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            webView.evaluateJavaScript(
                                "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)"
                            ) { result2, _ in
                                DispatchQueue.main.async {
                                    let h2 = CGFloat((result2 as? NSNumber)?.doubleValue ?? Double(h1))
                                    let finalH = max(h1, h2) + 32  // small bottom buffer

                                    CATransaction.begin(); CATransaction.setDisableActions(true)
                                    webView.frame = CGRect(x: webView.frame.origin.x, y: webView.frame.origin.y,
                                                           width: mobileWidth, height: finalH)
                                    CATransaction.commit()

                                    // Short settle before snapshot
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        let snapCfg = WKSnapshotConfiguration()
                                        snapCfg.rect = CGRect(x: 0, y: 0, width: mobileWidth, height: finalH)
                                        webView.takeSnapshot(with: snapCfg) { image, _ in
                                            DispatchQueue.main.async {
                                                detach.restore()
                                                removeMobile()
                                                if let image,
                                                   let cgImg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                                                    let rep = NSBitmapImageRep(cgImage: cgImg)
                                                    if let png = rep.representation(using: .png, properties: [:]) {
                                                        try? png.write(to: url)
                                                    }
                                                }
                                                done()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Converts an NSImage into a single-page PDF data blob using CGContext.
    private static func pdfData(from image: NSImage) -> Data? {
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: image.size)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return nil }
        ctx.beginPDFPage(nil)
        let gc = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gc
        image.draw(in: mediaBox)
        NSGraphicsContext.restoreGraphicsState()
        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }

    // MARK: Export — Public

    func exportHTML() {
        guard let webView else { return }
        webView.evaluateJavaScript("document.getElementById('content').innerHTML") { [weak self] result, _ in
            guard let self, let innerHtml = result as? String else { return }
            let styleCSS = StyleManager.shared.activeStyle.displayStyle.toCSS()
            let title = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
            let html = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="UTF-8">
              <title>\(title)</title>
              <style>\(styleCSS)</style>
            </head>
            <body>
              <div id="content">\(innerHtml)</div>
            </body>
            </html>
            """
            DispatchQueue.main.async {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.html]
                panel.nameFieldStringValue = title + ".html"
                if panel.runModal() == .OK, let url = panel.url {
                    try? html.write(to: url, atomically: true, encoding: .utf8)
                }
            }
        }
    }

    func exportPDF() {
        guard let webView else { return }
        let stem = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        let ts = exportTimestamp()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(stem)_\(ts).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        webView.createPDF { result in
            DispatchQueue.main.async {
                if case .success(let data) = result { try? data.write(to: url) }
            }
        }
    }

    func exportMobilePDF() {
        guard !isExporting, webView != nil else { return }
        let stem = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        let ts = exportTimestamp()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(stem)_\(ts)-mobile.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isExporting = true
        _writeMobilePDF(to: url) { [weak self] in
            DispatchQueue.main.async { self?.isExporting = false }
        }
    }

    func exportMobileImage() {
        guard !isExporting, webView != nil else { return }
        let stem = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        let ts = exportTimestamp()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(stem)_\(ts)-mobile.png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isExporting = true
        _writeMobileImage(to: url) { [weak self] in
            DispatchQueue.main.async { self?.isExporting = false }
        }
    }

    func exportAll() {
        guard !isExporting, let fileURL else { return }
        let stem = fileURL.deletingPathExtension().lastPathComponent
        let ts = exportTimestamp()
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "panel.exportAll.prompt")
        panel.message = String(localized: "panel.exportAll.message")
        guard panel.runModal() == .OK, let dir = panel.url else { return }
        isExporting = true
        let pdfURL       = dir.appendingPathComponent("\(stem)_\(ts).pdf")
        let mobilePDFURL = dir.appendingPathComponent("\(stem)_\(ts)-mobile.pdf")
        let mobileImgURL = dir.appendingPathComponent("\(stem)_\(ts)-mobile.png")
        _writeDesktopPDF(to: pdfURL) { [weak self] in
            self?._writeMobilePDF(to: mobilePDFURL) { [weak self] in
                self?._writeMobileImage(to: mobileImgURL) { [weak self] in
                    DispatchQueue.main.async { self?.isExporting = false }
                }
            }
        }
    }

    // MARK: Heading Parser

    static func parseHeadings(from markdown: String) -> [HeadingItem] {
        var result: [HeadingItem] = []
        var headingIndex = 0
        var inFence = false
        var charOffset = 0

        for line in markdown.components(separatedBy: "\n") {
            defer { charOffset += (line as NSString).length + 1 }   // +1 for \n

            if line.hasPrefix("```") || line.hasPrefix("~~~") { inFence.toggle() }
            guard !inFence, line.hasPrefix("#") else { continue }

            let hashes = line.prefix(while: { $0 == "#" })
            let level  = hashes.count
            guard level <= 6, line.count > level,
                  line[line.index(line.startIndex, offsetBy: level)] == " "
            else { continue }

            let text = String(line.dropFirst(level + 1)).trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                result.append(HeadingItem(level: level, text: text,
                                          index: headingIndex, charOffset: charOffset))
                headingIndex += 1
            }
        }
        return result
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { WindowCoordinator.shared.open(url: url) }
    }
}
