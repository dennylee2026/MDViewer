import AppKit
import SwiftUI

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
}

// MARK: - AppState

class AppState: ObservableObject {
    @Published var fileURL: URL?
    @Published var markdownContent: String = ""
    @Published var headings: [HeadingItem] = []
    @Published var viewMode: ViewMode = .split   // 启动默认分栏
    @Published var isDirty: Bool = false
    @Published var zoomLevel: Double = 1.0
    @Published var editorScrollFraction: Double = 0

    private let fileWatcher = FileWatcher()
    private var isLoadingFromDisk = false

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
        isLoadingFromDisk = true
        reload()
        isLoadingFromDisk = false
        isDirty = false
        viewMode = .viewer   // 打开文件 → 预览模式
        fileWatcher.watch(url: url) { [weak self] in self?.reloadFromDisk() }
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
        guard let url = fileURL, !isDirty else { return }
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
        if let url = fileURL {
            writeContent(to: url)
        } else {
            saveAs()
        }
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

    // MARK: Heading Parser

    private static func parseHeadings(from markdown: String) -> [HeadingItem] {
        var result: [HeadingItem] = []
        var headingIndex = 0
        var inFence = false
        for line in markdown.components(separatedBy: .newlines) {
            if line.hasPrefix("```") || line.hasPrefix("~~~") { inFence.toggle() }
            guard !inFence, line.hasPrefix("#") else { continue }
            let hashes = line.prefix(while: { $0 == "#" })
            let level = hashes.count
            guard level <= 6, line.count > level,
                  line[line.index(line.startIndex, offsetBy: level)] == " "
            else { continue }
            let text = String(line.dropFirst(level + 1)).trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                result.append(HeadingItem(level: level, text: text, index: headingIndex))
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
