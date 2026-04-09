import AppKit
import SwiftUI

class AppState: ObservableObject {
    @Published var fileURL: URL?
    @Published var markdownContent: String = ""

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
    }

    func reload() {
        guard let url = fileURL else { return }
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            markdownContent = content
        }
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
