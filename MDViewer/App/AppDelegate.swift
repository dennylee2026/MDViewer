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
    private var activeMobileImageExporter: MobileImageExporter?

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

    // MARK: Directory persistence helpers

    private var lastOpenedDirectoryURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: "MDViewer.lastOpenedFilePath") else { return nil }
        return URL(fileURLWithPath: path).deletingLastPathComponent()
    }

    private func saveLastOpenedDirectory(_ url: URL) {
        // Persist as a file path so it's compatible with WindowCoordinator's key usage
        let sentinel = url.appendingPathComponent("_dir_sentinel_")
        UserDefaults.standard.set(sentinel.path, forKey: "MDViewer.lastOpenedFilePath")
    }

    private var lastExportDirectoryURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: "MDViewer.lastExportDirectoryPath") else { return nil }
        return URL(fileURLWithPath: path)
    }

    private func saveLastExportDirectory(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: "MDViewer.lastExportDirectoryPath")
    }

    // MARK: Folder

    func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "panel.openFolder.prompt")
        panel.directoryURL = lastOpenedDirectoryURL
        if panel.runModal() == .OK, let url = panel.url {
            saveLastOpenedDirectory(url)
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

    // Mobile overrides: layout-only constraints so the active app style (colors,
    // fonts, headings) is preserved. Only width, padding, word-wrap, overflow,
    // and page-break properties are forced here.
    private func mobileCSSOverrides() -> String {
        """
        @page { margin: 0 !important; size: auto !important; }
        html { overflow-x: hidden !important; }
        * { box-sizing: border-box !important; }
        blockquote, pre, table, figure, img {
            break-inside: avoid !important; page-break-inside: avoid !important;
        }
        h1, h2, h3, h4, h5, h6 {
            break-after: avoid !important; page-break-after: avoid !important;
        }
        p { orphans: 3; widows: 3; }
        body {
            max-width: 100% !important;
            font-size: 22px !important;
            padding: 20px 18px 32px !important;
            word-break: break-word !important;
            margin: 0 !important;
            overflow-x: hidden !important;
            -webkit-print-color-adjust: exact !important;
            print-color-adjust: exact !important;
        }
        #content {
            max-width: 100% !important;
            width: 100% !important;
            margin-left: 0 !important;
            margin-right: 0 !important;
            padding-left: 0 !important;
            padding-right: 0 !important;
        }
        h1, h2, h3, h4, h5, h6 {
            overflow-wrap: break-word !important;
            word-break: break-word !important;
        }
        code {
            white-space: normal !important;
            word-break: break-all !important;
        }
        pre {
            overflow: visible !important;
            white-space: pre-wrap !important;
            word-break: break-word !important;
        }
        pre code {
            white-space: pre-wrap !important;
            word-break: break-word !important;
        }
        table {
            width: 100% !important;
            table-layout: fixed !important;
        }
        th, td {
            word-break: break-word !important;
            overflow-wrap: break-word !important;
        }
        img { max-width: 100% !important; height: auto !important; }
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
        // Remove any lingering mobile-CSS overrides (inline width + @page rule) before
        // capturing. Without this, a previous mobile export that did not finish its async
        // cleanup leaves html/body at 390 px width, causing createPDF to produce a
        // mobile-sized page even though no mobile config was requested.
        let mobileCleanup = """
        (function(){
            removeMobileCSS();
            var h = document.documentElement, b = document.body;
            h.style.removeProperty('width');
            h.style.removeProperty('max-width');
            h.style.removeProperty('overflow-x');
            b.style.removeProperty('width');
            b.style.removeProperty('max-width');
            b.style.removeProperty('overflow-x');
        })()
        """
        // Prevent page-break truncation of content blocks in the desktop PDF.
        // WKWebView.createPDF() honours break-inside/page-break-inside in regular
        // (non-print-media) CSS, so we inject a lightweight rule set here and
        // remove it after the PDF is captured so the live view is unaffected.
        let printBreakCSS = """
        blockquote, pre, table, figure, img {
            break-inside: avoid; page-break-inside: avoid;
        }
        h1, h2, h3, h4, h5, h6 {
            break-after: avoid; page-break-after: avoid;
        }
        p { orphans: 3; widows: 3; }
        """
        let injectPrintCSS = """
        (function(){
            var el = document.getElementById('desktop-print-style');
            if (!el) {
                el = document.createElement('style');
                el.id = 'desktop-print-style';
                document.head.appendChild(el);
            }
            el.textContent = \(printBreakCSS.debugDescription);
        })()
        """
        let removePrintCSS = """
        (function(){
            var el = document.getElementById('desktop-print-style');
            if (el) el.parentNode.removeChild(el);
        })()
        """

        webView.evaluateJavaScript(mobileCleanup) { _, _ in
            webView.evaluateJavaScript(injectPrintCSS) { _, _ in
                webView.createPDF { result in
                    DispatchQueue.main.async {
                        webView.evaluateJavaScript(removePrintCSS, completionHandler: nil)
                        if case .success(let data) = result { try? data.write(to: url) }
                        done()
                    }
                }
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

            // Expand to force WebKit to lay out the entire document before measuring.
            CATransaction.begin(); CATransaction.setDisableActions(true)
            webView.frame = CGRect(x: webView.frame.origin.x, y: webView.frame.origin.y,
                                   width: mobileWidth, height: 30_000)
            CATransaction.commit()

            // Allow the full 390-px reflow to settle.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                webView.evaluateJavaScript(
                    "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)"
                ) { result, _ in
                    DispatchQueue.main.async {
                        let contentH = max(CGFloat((result as? NSNumber)?.doubleValue ?? 1000), 100)
                        let paddedH  = contentH + 100

                        CATransaction.begin(); CATransaction.setDisableActions(true)
                        webView.frame = CGRect(x: webView.frame.origin.x, y: webView.frame.origin.y,
                                               width: mobileWidth, height: paddedH)
                        CATransaction.commit()

                        // Force a single-page PDF by overriding @page size to the exact
                        // content dimensions. Without this, @page { size: auto } causes
                        // WebKit to paginate at its default max height (~14 400 pt), splitting
                        // the output into dozens of pages with content cut at each break.
                        let pageSizeJS = """
                        (function(w,h){
                            var el = document.getElementById('mobile-page-size');
                            if (!el) {
                                el = document.createElement('style');
                                el.id = 'mobile-page-size';
                                document.head.appendChild(el);
                            }
                            el.textContent = '@page { margin: 0 !important; size: ' + w + 'px ' + h + 'px !important; }';
                        })(\(Int(mobileWidth)), \(Int(paddedH)))
                        """
                        // createPDF operates on DOM layout — not on screen rasterization —
                        // so alphaValue=0 does not affect output quality or completeness.
                        webView.evaluateJavaScript(pageSizeJS) { _, _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                let pdfConfig = WKPDFConfiguration()
                                pdfConfig.rect = CGRect(x: 0, y: 0, width: mobileWidth, height: paddedH)
                                webView.createPDF(configuration: pdfConfig) { pdfResult in
                                    DispatchQueue.main.async {
                                        webView.evaluateJavaScript(
                                            "var e=document.getElementById('mobile-page-size');if(e)e.parentNode.removeChild(e);",
                                            completionHandler: nil
                                        )
                                        detach.restore()
                                        removeMobile()
                                        if case .success(let data) = pdfResult {
                                            try? data.write(to: url)
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

    private func _writeMobileImage(to url: URL, done: @escaping () -> Void) {
        let css = StyleManager.shared.activeStyle.displayStyle.toCSS() + "\n" + mobileCSSOverrides()
        let exporter = MobileImageExporter(
            markdown: markdownContent,
            combinedCSS: css,
            outputURL: url,
            done: { [weak self] in
                self?.activeMobileImageExporter = nil
                done()
            }
        )
        activeMobileImageExporter = exporter
        exporter.start()
    }

    // MARK: Export — Public

    func exportHTML() {
        guard let webView else { return }
        let exportDir = lastExportDirectoryURL
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
                panel.directoryURL = exportDir
                if panel.runModal() == .OK, let url = panel.url {
                    try? html.write(to: url, atomically: true, encoding: .utf8)
                    self.saveLastExportDirectory(url.deletingLastPathComponent())
                }
            }
        }
    }

    func exportPDF() {
        guard webView != nil else { return }
        let stem = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        let ts = exportTimestamp()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(stem)_\(ts).pdf"
        panel.directoryURL = lastExportDirectoryURL
        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveLastExportDirectory(url.deletingLastPathComponent())
        _writeDesktopPDF(to: url) { }
    }

    func exportMobilePDF() {
        guard !isExporting, webView != nil else { return }
        let stem = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        let ts = exportTimestamp()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(stem)_\(ts)-mobile.pdf"
        panel.directoryURL = lastExportDirectoryURL
        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveLastExportDirectory(url.deletingLastPathComponent())
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
        panel.directoryURL = lastExportDirectoryURL
        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveLastExportDirectory(url.deletingLastPathComponent())
        isExporting = true
        _writeMobileImage(to: url) { [weak self] in
            DispatchQueue.main.async { self?.isExporting = false }
        }
    }

    func exportAll() {
        guard !isExporting else { return }
        let stem = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        let ts = exportTimestamp()
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "panel.exportAll.prompt")
        panel.message = String(localized: "panel.exportAll.message")
        panel.directoryURL = lastExportDirectoryURL
        guard panel.runModal() == .OK, let dir = panel.url else { return }
        saveLastExportDirectory(dir)
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

// MARK: - Mobile Image Exporter

// Renders markdown in a fresh 390-pt-wide WKWebView and saves the result as a PNG.
// Using a fresh view that was never wider than 390 pt avoids the CSS-reflow / constraint-
// detach dance the live-view approach requires.  Height is measured iteratively to work
// around WebKit's incremental layout for very long documents.
private class MobileImageExporter: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let markdown: String
    private let combinedCSS: String
    private let mobileWidth: CGFloat = 390
    private let outputURL: URL
    private let doneCallback: () -> Void
    private var expandIteration = 0
    private var offscreenWindow: NSWindow?
    private static let maxExpandIterations = 10

    init(markdown: String, combinedCSS: String, outputURL: URL, done: @escaping () -> Void) {
        self.markdown     = markdown
        self.combinedCSS  = combinedCSS
        self.outputURL    = outputURL
        self.doneCallback = done

        let cfg = WKWebViewConfiguration()
        cfg.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        self.webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 900),
            configuration: cfg
        )
        super.init()
        webView.navigationDelegate = self

        // WKWebView on macOS requires a window for loadFileURL navigation to complete.
        // Use an invisible offscreen window placed far outside any screen.
        let win = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 390, height: 900),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        win.contentView = webView
        win.orderBack(nil)
        offscreenWindow = win
    }

    func start() {
        guard let tpl = Bundle.main.url(forResource: "template", withExtension: "html") else {
            cleanup(); return
        }
        webView.loadFileURL(tpl, allowingReadAccessTo: tpl.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let cssEsc = esc(combinedCSS)
        let mdEsc  = esc(markdown)
        webView.evaluateJavaScript("applyCustomStyle(`\(cssEsc)`)") { [weak self] _, _ in
            guard let self else { return }
            self.webView.evaluateJavaScript("renderMarkdownSync(`\(mdEsc)`)") { [weak self] _, _ in
                guard let self else { return }
                // Scale down pre blocks whose content is wider than their container.
                // word-break inherited from body can wrap ASCII art; zoom shrinks the block
                // proportionally and adjusts its layout footprint, preserving the diagram.
                let scalePreJS = """
                (function(){
                    document.querySelectorAll('pre').forEach(function(pre){
                        pre.style.setProperty('white-space','pre','important');
                        pre.style.setProperty('overflow','visible','important');
                        pre.style.setProperty('word-break','normal','important');
                        var code=pre.querySelector('code');
                        if(code){
                            code.style.setProperty('white-space','pre','important');
                            code.style.setProperty('word-break','normal','important');
                        }
                        var cw=(pre.parentElement||document.body).offsetWidth;
                        var nw=pre.scrollWidth;
                        if(nw>cw&&cw>0){ pre.style.zoom=String(cw/nw); }
                    });
                })();
                """
                self.webView.evaluateJavaScript(scalePreJS) { [weak self] _, _ in
                    guard let self else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.expandAndMeasure()
                    }
                }
            }
        }
    }

    // Iteratively expand the webView frame until scrollHeight stabilises.
    // WebKit uses incremental layout: content below the current frame may not be
    // fully laid out yet, causing scrollHeight to be underestimated.  Each time
    // the measured height fills >90 % of the frame we double the frame and re-measure.
    private func expandAndMeasure() {
        webView.evaluateJavaScript(
            "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)"
        ) { [weak self] result, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                let measured = max(CGFloat((result as? NSNumber)?.doubleValue ?? 900), 100)
                let frameH   = self.webView.frame.height

                if measured > frameH * 0.9 && self.expandIteration < Self.maxExpandIterations {
                    self.expandIteration += 1
                    let nextH = measured * 2
                    self.webView.frame = CGRect(x: 0, y: 0, width: self.mobileWidth, height: nextH)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.expandAndMeasure()
                    }
                } else {
                    let finalH = measured + 64
                    self.webView.frame = CGRect(x: 0, y: 0, width: self.mobileWidth, height: finalH)
                    self.offscreenWindow?.setContentSize(NSSize(width: self.mobileWidth, height: finalH))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        self.capturePDF(height: finalH)
                    }
                }
            }
        }
    }

    private func capturePDF(height: CGFloat) {
        let cfg = WKPDFConfiguration()
        cfg.rect = CGRect(x: 0, y: 0, width: mobileWidth, height: height)
        webView.createPDF(configuration: cfg) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                guard case .success(let pdfData) = result,
                      let provider = CGDataProvider(data: pdfData as CFData),
                      let pdfDoc   = CGPDFDocument(provider),
                      let page     = pdfDoc.page(at: 1)
                else { self.cleanup(); return }
                self.renderToImage(page: page)
            }
        }
    }

    private func renderToImage(page: CGPDFPage) {
        let box   = page.getBoxRect(.mediaBox)
        // Clamp pixel count to ~200 M px to avoid CGContext allocation failures
        // on very long documents (~800 MB at 4 bytes/px).
        let natural = NSScreen.main?.backingScaleFactor ?? 2.0
        let maxPx: CGFloat = 200_000_000
        let totalPx = box.width * natural * box.height * natural
        let scale = totalPx > maxPx
            ? max(1.0, sqrt(maxPx / (box.width * box.height)))
            : natural
        let pixW  = Int(box.width  * scale)
        let pixH  = Int(box.height * scale)

        guard let cs  = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: nil, width: pixW, height: pixH,
                  bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { cleanup(); return }

        let bgHex  = StyleManager.shared.activeStyle.displayStyle.global.backgroundColor ?? "#FFFFFF"
        let bgFill = Self.cgColor(fromHex: bgHex) ?? CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.setFillColor(bgFill)
        ctx.fill(CGRect(x: 0, y: 0, width: pixW, height: pixH))
        ctx.scaleBy(x: scale, y: scale)
        ctx.drawPDFPage(page)

        if let cgImg = ctx.makeImage() {
            let rep = NSBitmapImageRep(cgImage: cgImg)
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: outputURL)
            }
        }
        cleanup()
    }

    private func cleanup() {
        offscreenWindow?.close()
        offscreenWindow = nil
        doneCallback()
    }

    private func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "`", with: "\\`")
         .replacingOccurrences(of: "$", with: "\\$")
    }

    private static func cgColor(fromHex hex: String) -> CGColor? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return CGColor(red:   CGFloat((v >> 16) & 0xFF) / 255,
                       green: CGFloat((v >> 8)  & 0xFF) / 255,
                       blue:  CGFloat(v         & 0xFF) / 255,
                       alpha: 1)
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { WindowCoordinator.shared.open(url: url) }
    }
}
