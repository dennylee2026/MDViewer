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

    // MARK: Export — Mobile CSS helpers

    private func mobileCSSOverrides() -> String {
        """
        body {
            font-size: 18px !important;
            max-width: 100% !important;
            padding: 16px 20px 40px !important;
            line-height: 1.6 !important;
        }
        h1 { font-size: 1.8em !important; }
        h2 { font-size: 1.4em !important; }
        h3 { font-size: 1.2em !important; }
        h4 { font-size: 1.05em !important; }
        h5 { font-size: 0.95em !important; }
        h6 { font-size: 0.85em !important; }
        pre, code { font-size: 0.82em !important; }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action {
                    webView.evaluateJavaScript("removeMobileCSS()", completionHandler: nil)
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

    private func _writeMobilePDF(to url: URL, done: @escaping () -> Void) {
        guard webView != nil else { done(); return }
        withMobileCSS { [weak self] removeMobile in
            guard let webView = self?.webView else { removeMobile(); done(); return }
            webView.createPDF { result in
                DispatchQueue.main.async {
                    removeMobile()
                    if case .success(let data) = result { try? data.write(to: url) }
                    done()
                }
            }
        }
    }

    private func _writeMobileImage(to url: URL, done: @escaping () -> Void) {
        guard webView != nil else { done(); return }
        withMobileCSS { [weak self] removeMobile in
            guard let self, let webView = self.webView else { removeMobile(); done(); return }
            let originalFrame = webView.frame
            var narrowFrame = originalFrame
            narrowFrame.size.width = 390
            webView.frame = narrowFrame

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                    let height = (result as? NSNumber)?.doubleValue ?? Double(originalFrame.height)
                    var tallFrame = narrowFrame
                    tallFrame.size.height = CGFloat(height)
                    webView.frame = tallFrame

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let config = WKSnapshotConfiguration()
                        config.rect = CGRect(origin: .zero, size: tallFrame.size)
                        webView.takeSnapshot(with: config) { image, _ in
                            DispatchQueue.main.async {
                                webView.frame = originalFrame
                                removeMobile()
                                if let image,
                                   let tiff = image.tiffRepresentation,
                                   let rep = NSBitmapImageRep(data: tiff),
                                   let png = rep.representation(using: .png, properties: [:]) {
                                    try? png.write(to: url)
                                }
                                done()
                            }
                        }
                    }
                }
            }
        }
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
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = stem + ".pdf"
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
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = stem + "-mobile.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isExporting = true
        _writeMobilePDF(to: url) { [weak self] in
            DispatchQueue.main.async { self?.isExporting = false }
        }
    }

    func exportMobileImage() {
        guard !isExporting, webView != nil else { return }
        let stem = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = stem + "-mobile.png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isExporting = true
        _writeMobileImage(to: url) { [weak self] in
            DispatchQueue.main.async { self?.isExporting = false }
        }
    }

    func exportAll() {
        guard !isExporting, let fileURL else { return }
        let stem = fileURL.deletingPathExtension().lastPathComponent
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "panel.exportAll.prompt")
        panel.message = String(localized: "panel.exportAll.message")
        guard panel.runModal() == .OK, let dir = panel.url else { return }
        isExporting = true
        let pdfURL        = dir.appendingPathComponent(stem + ".pdf")
        let mobilePDFURL  = dir.appendingPathComponent(stem + "-mobile.pdf")
        let mobileImgURL  = dir.appendingPathComponent(stem + "-mobile.png")
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
