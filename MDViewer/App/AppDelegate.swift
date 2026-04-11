import AppKit
import SwiftUI
import WebKit

// MARK: - View Mode

enum ViewMode {
    case split    // 分栏：左编辑右预览，无侧栏
    case editor   // 纯编辑，无侧栏
    case viewer   // 纯预览，显示大纲侧栏
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
    @Published var zoomLevel: Double = 1.0
    @Published var recentURLs: [URL] = []

    var webView: WKWebView?
    var isDark: Bool = false

    private let fileWatcher = FileWatcher()

    init() {
        recentURLs = Array(NSDocumentController.shared.recentDocumentURLs.prefix(10))
    }

    // MARK: File Picker

    func openFilePicker() {
        if isDirty { guardUnsaved { self.presentOpenPanel() } } else { presentOpenPanel() }
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { open(url: url) }
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

    // MARK: New File

    func newFile() {
        if isDirty { guardUnsaved { self.doNewFile() } } else { doNewFile() }
    }

    private func doNewFile() {
        fileURL = nil
        markdownContent = ""
        headings = []
        isDirty = false
        viewMode = .split
        fileWatcher.stop()
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
    }

    // MARK: Content change from editor

    func editorDidChange(to text: String) {
        markdownContent = text
        headings = Self.parseHeadings(from: text)
        isDirty = true
    }

    // MARK: Unsaved guard

    private func guardUnsaved(then action: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "未保存的更改"
        alert.informativeText = "是否在继续之前保存对 \"\(fileURL?.lastPathComponent ?? "未命名")\" 的更改？"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "不保存")
        alert.addButton(withTitle: "取消")
        switch alert.runModal() {
        case .alertFirstButtonReturn:  save(); action()
        case .alertSecondButtonReturn: isDirty = false; action()
        default: break
        }
    }

    // MARK: Export

    func exportHTML() {
        guard let webView else { return }
        webView.evaluateJavaScript("document.getElementById('content').innerHTML") { [weak self] result, _ in
            guard let self, let innerHtml = result as? String else { return }
            let bundle = Bundle.main
            func readResource(_ name: String, ext: String) -> String {
                guard let url = bundle.url(forResource: name, withExtension: ext),
                      let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
                return text
            }
            let mdCSS   = readResource(isDark ? "dark" : "light", ext: "css")
            let hljsCSS = readResource(isDark ? "hljs-dark" : "hljs-light", ext: "css")
            let bodyClass = isDark ? "dark" : "light"
            let title = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
            let html = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="UTF-8">
              <title>\(title)</title>
              <style>\(hljsCSS)</style>
              <style>\(mdCSS)</style>
              <style>*{box-sizing:border-box;margin:0;padding:0}body{padding:40px 48px;max-width:860px;margin:0 auto}</style>
            </head>
            <body class="\(bodyClass)">
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
        webView.createPDF { [weak self] result in
            guard let self, case .success(let data) = result else { return }
            DispatchQueue.main.async {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.pdf]
                panel.nameFieldStringValue = (self.fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled") + ".pdf"
                if panel.runModal() == .OK, let url = panel.url {
                    try? data.write(to: url)
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
    let appState = AppState()

    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first { appState.open(url: url) }
    }
}
