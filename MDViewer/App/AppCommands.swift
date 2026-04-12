import SwiftUI

struct AppCommands: Commands {
    @FocusedObject private var appState: AppState?
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // File — New / Open
        CommandGroup(replacing: .newItem) {
            Button("menu.file.new") { WindowCoordinator.shared.openEmpty() }
                .keyboardShortcut("n", modifiers: .command)
            Button("menu.file.open") { WindowCoordinator.shared.openWithPicker() }
                .keyboardShortcut("o", modifiers: .command)
        }

        CommandGroup(after: .newItem) {
            Button("menu.file.openFolder") { appState?.openFolderPicker() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(appState == nil)

            Menu("menu.file.openRecent") {
                if let urls = appState?.recentURLs, !urls.isEmpty {
                    ForEach(urls, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            WindowCoordinator.shared.open(url: url)
                        }
                    }
                    Divider()
                    Button("menu.file.openRecent.clear") {
                        NSDocumentController.shared.clearRecentDocuments(nil)
                        appState?.recentURLs = []
                    }
                } else {
                    Text("menu.file.openRecent.none")
                }
            }
        }

        // File — Save / Export
        CommandGroup(after: .saveItem) {
            Button("menu.file.save") { appState?.save() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState == nil)
            Button("menu.file.saveAs") { appState?.saveAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appState == nil)
            Divider()
            Button("menu.file.exportHTML") { appState?.exportHTML() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(appState == nil)
            Button("menu.file.exportPDF") { appState?.exportPDF() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(appState == nil)
        }

        // Edit — Find (forwards to NSTextView's built-in find bar via responder chain)
        CommandGroup(after: .textEditing) {
            Divider()
            Button("menu.edit.find") {
                let item = NSMenuItem()
                item.tag = NSTextFinder.Action.showFindInterface.rawValue
                NSApp.sendAction(#selector(NSTextView.performTextFinderAction(_:)), to: nil, from: item)
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("menu.edit.findReplace") {
                let item = NSMenuItem()
                item.tag = NSTextFinder.Action.showReplaceInterface.rawValue
                NSApp.sendAction(#selector(NSTextView.performTextFinderAction(_:)), to: nil, from: item)
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

            Button("menu.edit.findNext") {
                let item = NSMenuItem()
                item.tag = NSTextFinder.Action.nextMatch.rawValue
                NSApp.sendAction(#selector(NSTextView.performTextFinderAction(_:)), to: nil, from: item)
            }
            .keyboardShortcut("g", modifiers: .command)

            Button("menu.edit.findPrevious") {
                let item = NSMenuItem()
                item.tag = NSTextFinder.Action.previousMatch.rawValue
                NSApp.sendAction(#selector(NSTextView.performTextFinderAction(_:)), to: nil, from: item)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
        }

        // Help
        CommandGroup(replacing: .help) {
            Button("menu.help.mdviewer") {
                openWindow(id: "help")
            }
            .keyboardShortcut("?", modifiers: .command)
        }

        // View
        CommandMenu("menu.view") {
            Button("menu.view.editor") { appState?.viewMode = .editor }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(appState == nil)
            Button("menu.view.split") { appState?.viewMode = .split }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(appState == nil)
            Button("menu.view.viewer") { appState?.viewMode = .viewer }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(appState == nil)

            Divider()

            Button("menu.view.zoomIn") {
                guard let z = appState?.zoomLevel else { return }
                appState?.zoomLevel = min(3.0, z + 0.1)
            }
            .keyboardShortcut("=", modifiers: .command)
            .disabled(appState == nil)

            Button("menu.view.zoomOut") {
                guard let z = appState?.zoomLevel else { return }
                appState?.zoomLevel = max(0.5, z - 0.1)
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(appState == nil)

            Button("menu.view.actualSize") { appState?.zoomLevel = 1.0 }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(appState == nil)
        }
    }
}
