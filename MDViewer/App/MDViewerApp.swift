import SwiftUI

@main
struct MDViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.appState)
        }
        .commands {
            // File
            CommandGroup(replacing: .newItem) {
                Button("新建") { appDelegate.appState.newFile() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("打开…") { appDelegate.appState.openFilePicker() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Menu("打开最近文件") {
                    if appDelegate.appState.recentURLs.isEmpty {
                        Text("无最近文件")
                    } else {
                        ForEach(appDelegate.appState.recentURLs, id: \.self) { url in
                            Button(url.lastPathComponent) {
                                appDelegate.appState.open(url: url)
                            }
                        }
                        Divider()
                        Button("清除最近打开") {
                            NSDocumentController.shared.clearRecentDocuments(nil)
                            appDelegate.appState.recentURLs = []
                        }
                    }
                }
            }
            CommandGroup(after: .saveItem) {
                Button("保存") { appDelegate.appState.save() }
                    .keyboardShortcut("s", modifiers: .command)
                Button("另存为…") { appDelegate.appState.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Divider()
                Button("导出为 HTML…") { appDelegate.appState.exportHTML() }
                    .keyboardShortcut("e", modifiers: .command)
                Button("导出为 PDF…") { appDelegate.appState.exportPDF() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            // View mode
            CommandMenu("视图") {
                Button("编辑模式") { appDelegate.appState.viewMode = .editor }
                    .keyboardShortcut("1", modifiers: .command)
                Button("分栏模式") { appDelegate.appState.viewMode = .split }
                    .keyboardShortcut("2", modifiers: .command)
                Button("预览模式") { appDelegate.appState.viewMode = .viewer }
                    .keyboardShortcut("3", modifiers: .command)

                Divider()

                Button("放大") { appDelegate.appState.zoomLevel = min(3.0, appDelegate.appState.zoomLevel + 0.1) }
                    .keyboardShortcut("=", modifiers: .command)
                Button("缩小") { appDelegate.appState.zoomLevel = max(0.5, appDelegate.appState.zoomLevel - 0.1) }
                    .keyboardShortcut("-", modifiers: .command)
                Button("实际大小") { appDelegate.appState.zoomLevel = 1.0 }
                    .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}
