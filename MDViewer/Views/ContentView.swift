import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var webViewRef: WKWebView?

    var windowTitle: String {
        let name = appState.fileURL?.lastPathComponent ?? "未命名"
        return appState.isDirty ? "\(name) •" : name
    }

    var body: some View {
        Group {
            switch appState.viewMode {
            case .split:
                HSplitView {
                    editorView.frame(minWidth: 200)
                    previewPane.frame(minWidth: 200)
                }

            case .editor:
                EditorView(
                    text: editorBinding,
                    zoomLevel: appState.zoomLevel,
                    headings: appState.headings
                )

            case .viewer:
                NavigationSplitView {
                    OutlineView(webView: webViewRef)
                        .environmentObject(appState)
                        .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 280)
                } detail: {
                    previewPane
                }
            }
        }
        .frame(minWidth: 680, minHeight: 400)
        .navigationTitle(windowTitle)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .toolbar { toolbarContent }
    }

    // MARK: Editor (split mode — with cursor sync)

    private var editorView: some View {
        EditorView(
            text: editorBinding,
            zoomLevel: appState.zoomLevel,
            headings: appState.headings,
            onCursorMove: { headingIndex in
                guard headingIndex >= 0 else { return }
                webViewRef?.evaluateJavaScript(
                    "scrollToHeading(\(headingIndex))",
                    completionHandler: nil
                )
            }
        )
    }

    // MARK: Preview pane

    private var previewPane: some View {
        MarkdownWebView(
            content: appState.markdownContent,
            isDark: colorScheme == .dark,
            zoomLevel: appState.zoomLevel,
            webViewRef: $webViewRef
        )
        .ignoresSafeArea()
    }

    // MARK: Editor binding

    private var editorBinding: Binding<String> {
        Binding(
            get: { appState.markdownContent },
            set: { appState.editorDidChange(to: $0) }
        )
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("", selection: $appState.viewMode) {
                Image(systemName: "square.and.pencil").tag(ViewMode.editor)
                Image(systemName: "rectangle.split.2x1").tag(ViewMode.split)
                Image(systemName: "eye").tag(ViewMode.viewer)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .help("⌘1 编辑  ⌘2 分栏  ⌘3 预览")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button { appState.zoomLevel = max(0.5, appState.zoomLevel - 0.1) } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("缩小 (⌘-)")

            Text(String(format: "%.0f%%", appState.zoomLevel * 100))
                .monospacedDigit()
                .frame(width: 44)
                .onTapGesture { appState.zoomLevel = 1.0 }
                .help("点击重置 (⌘0)")

            Button { appState.zoomLevel = min(3.0, appState.zoomLevel + 0.1) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("放大 (⌘=)")

            Divider()

            Button { appState.openFilePicker() } label: {
                Label("打开", systemImage: "folder")
            }
            .help("打开文件 (⌘O)")
        }
    }

    // MARK: Drag-drop

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        providers.first?.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension == "md" || url.pathExtension == "markdown"
            else { return }
            DispatchQueue.main.async { appState.open(url: url) }
        }
        return true
    }
}
