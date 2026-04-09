import AppKit
import SwiftUI

struct HeadingItem: Identifiable {
    let id = UUID()
    let level: Int   // 1–6
    let text: String
    let index: Int   // DOM order for scroll targeting
}

class AppState: ObservableObject {
    @Published var fileURL: URL?
    @Published var markdownContent: String = ""
    @Published var headings: [HeadingItem] = []

    private let fileWatcher = FileWatcher()

    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            open(url: url)
        }
    }

    func open(url: URL) {
        fileURL = url
        reload()
        fileWatcher.watch(url: url) { [weak self] in
            self?.reload()
        }
    }

    func reload() {
        guard let url = fileURL else { return }
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            markdownContent = content
            headings = Self.parseHeadings(from: content)
        }
    }

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
            let text = String(line.dropFirst(level + 1))
                .trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                result.append(HeadingItem(level: level, text: text, index: headingIndex))
                headingIndex += 1
            }
        }
        return result
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            appState.open(url: url)
        }
    }
}
