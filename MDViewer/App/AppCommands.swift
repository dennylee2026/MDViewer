import SwiftUI

struct AppCommands: Commands {
    @FocusedObject private var appState: AppState?
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // File — New / Open
        CommandGroup(replacing: .newItem) {
            Button("新建") { WindowCoordinator.shared.openEmpty() }
                .keyboardShortcut("n", modifiers: .command)
            Button("打开…") { WindowCoordinator.shared.openWithPicker() }
                .keyboardShortcut("o", modifiers: .command)
        }

        CommandGroup(after: .newItem) {
            Button("打开文件夹…") { appState?.openFolderPicker() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(appState == nil)

            Menu("打开最近文件") {
                if let urls = appState?.recentURLs, !urls.isEmpty {
                    ForEach(urls, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            WindowCoordinator.shared.open(url: url)
                        }
                    }
                    Divider()
                    Button("清除最近打开") {
                        NSDocumentController.shared.clearRecentDocuments(nil)
                        appState?.recentURLs = []
                    }
                } else {
                    Text("无最近文件")
                }
            }
        }

        // File — Save / Export
        CommandGroup(after: .saveItem) {
            Button("保存") { appState?.save() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState == nil)
            Button("另存为…") { appState?.saveAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appState == nil)
            Divider()
            Button("导出为 HTML…") { appState?.exportHTML() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(appState == nil)
            Button("导出为 PDF…") { appState?.exportPDF() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(appState == nil)
        }

        // Edit — Find (forwards to NSTextView's built-in find bar via responder chain)
        CommandGroup(after: .textEditing) {
            Divider()
            Button("查找…") {
                let item = NSMenuItem()
                item.tag = NSTextFinder.Action.showFindInterface.rawValue
                NSApp.sendAction(Selector(("performTextFinderAction:")), to: nil, from: item)
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("查找并替换…") {
                let item = NSMenuItem()
                item.tag = NSTextFinder.Action.showReplaceInterface.rawValue
                NSApp.sendAction(Selector(("performTextFinderAction:")), to: nil, from: item)
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

            Button("查找下一个") {
                let item = NSMenuItem()
                item.tag = NSTextFinder.Action.nextMatch.rawValue
                NSApp.sendAction(Selector(("performTextFinderAction:")), to: nil, from: item)
            }
            .keyboardShortcut("g", modifiers: .command)

            Button("查找上一个") {
                let item = NSMenuItem()
                item.tag = NSTextFinder.Action.previousMatch.rawValue
                NSApp.sendAction(Selector(("performTextFinderAction:")), to: nil, from: item)
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
        }

        // Help
        CommandGroup(replacing: .help) {
            Button("MDViewer 帮助") {
                openWindow(id: "help")
            }
            .keyboardShortcut("?", modifiers: .command)
        }

        // View
        CommandMenu("视图") {
            Button("编辑模式") { appState?.viewMode = .editor }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(appState == nil)
            Button("分栏模式") { appState?.viewMode = .split }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(appState == nil)
            Button("预览模式") { appState?.viewMode = .viewer }
                .keyboardShortcut("3", modifiers: .command)
                .disabled(appState == nil)

            Divider()

            Button("放大") {
                guard let z = appState?.zoomLevel else { return }
                appState?.zoomLevel = min(3.0, z + 0.1)
            }
            .keyboardShortcut("=", modifiers: .command)
            .disabled(appState == nil)

            Button("缩小") {
                guard let z = appState?.zoomLevel else { return }
                appState?.zoomLevel = max(0.5, z - 0.1)
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(appState == nil)

            Button("实际大小") { appState?.zoomLevel = 1.0 }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(appState == nil)
        }
    }
}
