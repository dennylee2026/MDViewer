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

    var webView: WKWebView?
    var currentTheme: String = "light"
    private var savedBadgeTask: Task<Void, Never>?

    private let fileWatcher = FileWatcher()

    init() {
        let saved = UserDefaults.standard.double(forKey: "MDViewer.zoomLevel")
        if saved > 0 { zoomLevel = min(3.0, max(0.5, saved)) }
        recentURLs = Array(NSDocumentController.shared.recentDocumentURLs.prefix(10))
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
        panel.prompt = "选择文件夹"
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
            let mdCSS   = readResource(currentTheme, ext: "css")
            let hljsCSS = readResource(currentTheme == "dark" ? "hljs-dark" : "hljs-light", ext: "css")
            let bodyClass = currentTheme
            let title = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
            let html = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="UTF-8">
              <title>\(title)</title>
              <style>\(hljsCSS)</style>
              <style>\(mdCSS)</style>
              <style>*{box-sizing:border-box;margin:0;padding:0}body{padding:40px 48px 80px;max-width:860px;margin:0 auto}</style>
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
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { WindowCoordinator.shared.open(url: url) }
    }
}
