import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var webViewRef: WKWebView?

    @AppStorage("colorTheme") private var colorTheme: String = "auto"
    @AppStorage("editorFont")  private var editorFont:  String = "system"

    var windowTitle: String {
        let name = appState.fileURL?.lastPathComponent ?? "未命名"
        return appState.isDirty ? "\(name) •" : name
    }

    private var effectiveTheme: String {
        switch colorTheme {
        case "light", "dark", "sepia": return colorTheme
        default: return colorScheme == .dark ? "dark" : "light"
        }
    }

    var body: some View {
        Group {
            if appState.showFolderSidebar {
                HSplitView {
                    FolderTreeView()
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
                    viewContent
                }
            } else {
                viewContent
            }
        }
        .frame(minWidth: 680, minHeight: 400)
        .navigationTitle(windowTitle)
        .onDrop(of: [.fileURL], isTargeted: nil, perform: handleDrop)
        .toolbar { toolbarContent }
        .onChange(of: webViewRef)   { _, ref in appState.webView = ref }
        .onChange(of: colorScheme)  { _, _   in appState.currentTheme = effectiveTheme }
        .onChange(of: colorTheme)   { _, _   in appState.currentTheme = effectiveTheme }
        .onAppear { appState.currentTheme = effectiveTheme }
        .overlay(alignment: .top) { savedBadge }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appState.showSavedBadge)
    }

    // MARK: View switcher

    @ViewBuilder
    private var viewContent: some View {
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
                fontFamily: editorFont
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

    // MARK: Editor (split mode — with cursor sync)

    private var editorView: some View {
        EditorView(
            text: editorBinding,
            zoomLevel: appState.zoomLevel,
            fontFamily: editorFont,
            onCursorMove: { lineText in
                if let jsonStr = try? String(data: JSONEncoder().encode(lineText), encoding: .utf8) {
                    webViewRef?.evaluateJavaScript(
                        "scrollToEditorText(\(jsonStr))",
                        completionHandler: nil
                    )
                }
            }
        )
    }

    // MARK: Preview pane

    private var previewPane: some View {
        MarkdownWebView(
            content: appState.markdownContent,
            theme: effectiveTheme,
            zoomLevel: appState.zoomLevel,
            fileURL: appState.fileURL,
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
        ToolbarItem(placement: .navigation) {
            Button {
                appState.showFolderSidebar.toggle()
            } label: {
                Image(systemName: "sidebar.leading")
            }
            .help("文件夹侧栏")
            .disabled(appState.folderURL == nil)
        }

        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Picker("", selection: $appState.viewMode) {
                    Image(systemName: "square.and.pencil").tag(ViewMode.editor)
                    Image(systemName: "rectangle.split.2x1").tag(ViewMode.split)
                    Image(systemName: "eye").tag(ViewMode.viewer)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .help("⌘1 编辑  ⌘2 分栏  ⌘3 预览")

                Text("Unsaved")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .opacity(appState.isDirty ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: appState.isDirty)
            }
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

            Button { WindowCoordinator.shared.openWithPicker() } label: {
                Label("打开", systemImage: "folder")
            }
            .help("打开文件 (⌘O)")
        }
    }

    // MARK: Saved badge

    @ViewBuilder
    private var savedBadge: some View {
        if appState.showSavedBadge {
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
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
