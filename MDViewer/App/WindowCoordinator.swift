import AppKit

/// Bridges AppDelegate (no SwiftUI environment) with the SwiftUI openWindow action.
/// The active window registers a handler; AppDelegate and Commands call through it.
final class WindowCoordinator {
    static let shared = WindowCoordinator()
    private init() {}

    private var openHandler: ((WindowID) -> Void)?
    private var pendingURLs: [URL] = []

    /// Called by the first window on appear. Drains any URLs queued before a window existed.
    func register(handler: @escaping (WindowID) -> Void) {
        openHandler = handler
        let pending = pendingURLs
        pendingURLs = []
        for url in pending { handler(.forFile(url)) }
    }

    func openEmpty() {
        openHandler?(.empty())
    }

    func open(url: URL) {
        if let h = openHandler { h(.forFile(url)) }
        else { pendingURLs.append(url) }
    }

    func openWithPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { open(url: url) }
    }
}
