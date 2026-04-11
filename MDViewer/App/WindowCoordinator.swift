import AppKit

/// Bridges AppDelegate (no SwiftUI environment) with the SwiftUI openWindow action.
/// The active window registers a handler; AppDelegate and Commands call through it.
final class WindowCoordinator {
    static let shared = WindowCoordinator()
    private init() {}

    private var openHandler: ((WindowID) -> Void)?
    private var pendingURLs: [URL] = []

    // Weak references to all live AppState instances
    private struct WeakRef { weak var appState: AppState? }
    private var registeredStates: [WeakRef] = []

    /// Each WindowView registers its AppState so we can reuse empty windows.
    func registerAppState(_ appState: AppState) {
        registeredStates.removeAll { $0.appState == nil }
        registeredStates.append(WeakRef(appState: appState))
    }

    /// Called by the first window on appear. Drains any URLs queued before a window existed.
    func register(handler: @escaping (WindowID) -> Void) {
        openHandler = handler
        let pending = pendingURLs
        pendingURLs = []
        for url in pending { open(url: url) }
    }

    func openEmpty() {
        openHandler?(.empty())
    }

    func open(url: URL) {
        registeredStates.removeAll { $0.appState == nil }
        // Reuse an empty, unedited window instead of spawning a new one
        if let state = registeredStates.first(where: { ref in
            guard let a = ref.appState else { return false }
            return a.fileURL == nil && !a.isDirty && a.markdownContent.isEmpty
        })?.appState {
            state.open(url: url)
            return
        }
        if let h = openHandler { h(.forFile(url)) }
        else { pendingURLs.append(url) }
    }

    func openWithPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!, .init(filenameExtension: "markdown")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        // Build directory URL from the last opened file path (tracked in AppState.open).
        // Using deletingLastPathComponent() on a file URL naturally produces a directory
        // URL with hasDirectoryPath = true, which NSOpenPanel navigates INTO correctly.
        if let filePath = UserDefaults.standard.string(forKey: "MDViewer.lastOpenedFilePath") {
            let fileURL = URL(fileURLWithPath: filePath)
            let dirURL  = fileURL.deletingLastPathComponent()
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: dirURL.path, isDirectory: &isDir), isDir.boolValue {
                panel.directoryURL = dirURL
            }
        }
        if panel.runModal() == .OK, let url = panel.url { open(url: url) }
    }
}
