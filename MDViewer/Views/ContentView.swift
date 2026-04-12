import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var webViewRef: WKWebView?
    @ObservedObject private var styleManager = StyleManager.shared

    @State private var isDragTargeted = false
    @State private var outlineVisible: NavigationSplitViewVisibility = .detailOnly
    // editorScrollTarget is now on appState (@Published) for reliable
    // cross-component state propagation from the WKWebView callback.

    var windowTitle: String {
        let name = appState.fileURL?.lastPathComponent ?? String(localized: "window.untitled")
        return appState.isDirty ? "\(name) •" : name
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
        .onDrop(of: [.fileURL], isTargeted: $isDragTargeted, perform: handleDrop)
        .overlay {
            if isDragTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .background(Color.accentColor.opacity(0.06)
                        .clipShape(RoundedRectangle(cornerRadius: 8)))
                    .allowsHitTesting(false)
                    .padding(4)
            }
        }
        .toolbar { toolbarContent }
        .onChange(of: webViewRef)        { _, ref in appState.webView = ref }
        .onChange(of: appState.zoomLevel){ _, val in UserDefaults.standard.set(val, forKey: "MDViewer.zoomLevel") }
        .onChange(of: appState.fileURL)  { _, _   in outlineVisible = .detailOnly }
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
                previewPane(onPreviewClick: syncEditorToPreviewClick).frame(minWidth: 200)
            }

        case .editor:
            EditorView(
                text: editorBinding,
                zoomLevel: appState.zoomLevel,
                editorStyle: styleManager.activeStyle.editorStyle
            )

        case .viewer:
            NavigationSplitView(columnVisibility: $outlineVisible) {
                OutlineView(webView: webViewRef)
                    .environmentObject(appState)
                    .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 280)
            } detail: {
                previewPane()
            }
        }
    }

    // MARK: Editor (split mode — with cursor sync)

    private var editorView: some View {
        EditorView(
            text: editorBinding,
            zoomLevel: appState.zoomLevel,
            editorStyle: styleManager.activeStyle.editorStyle,
            onCursorMove: { lineText, fraction, lineFraction, charOffset in
                let headings = appState.headings

                // If headings exist, use heading-anchored scrolling
                if !headings.isEmpty {
                    // Find the last heading whose charOffset <= cursor charOffset
                    let anchorIndex = headings.lastIndex(where: { $0.charOffset <= charOffset })

                    if let ai = anchorIndex {
                        let anchor = headings[ai]
                        let anchorCharOffset = anchor.charOffset

                        // Next heading charOffset, or end of document
                        let nextCharOffset: Int
                        if ai + 1 < headings.count {
                            nextCharOffset = headings[ai + 1].charOffset
                        } else {
                            nextCharOffset = (appState.markdownContent as NSString).length
                        }

                        // Compute section fraction (clamped 0–1)
                        let sectionLength = nextCharOffset - anchorCharOffset
                        let sectionFraction: CGFloat
                        if sectionLength > 0 {
                            sectionFraction = min(1.0, max(0.0, CGFloat(charOffset - anchorCharOffset) / CGFloat(sectionLength)))
                        } else {
                            sectionFraction = 0.0
                        }

                        let headingIndex = anchor.index
                        webViewRef?.evaluateJavaScript(
                            "scrollToHeadingWithFraction(\(headingIndex), \(sectionFraction), \(fraction))",
                            completionHandler: nil
                        )
                    } else {
                        // Cursor is before the first heading — scroll proportionally within the pre-heading area
                        let firstHeadingCharOffset = headings[0].charOffset
                        let sectionFraction: CGFloat
                        if firstHeadingCharOffset > 0 {
                            sectionFraction = min(1.0, max(0.0, CGFloat(charOffset) / CGFloat(firstHeadingCharOffset)))
                        } else {
                            sectionFraction = 0.0
                        }
                        // Use -1 to signal "before first heading" to JS
                        webViewRef?.evaluateJavaScript(
                            "scrollToHeadingWithFraction(-1, \(sectionFraction), \(fraction))",
                            completionHandler: nil
                        )
                    }
                } else {
                    // No headings — fall back to existing text-match / fraction logic
                    if lineText.isEmpty {
                        webViewRef?.evaluateJavaScript(
                            "scrollToFraction(\(lineFraction))",
                            completionHandler: nil
                        )
                    } else if let jsonStr = try? String(data: JSONEncoder().encode(lineText), encoding: .utf8) {
                        webViewRef?.evaluateJavaScript(
                            "scrollToEditorText(\(jsonStr), \(fraction), \(lineFraction))",
                            completionHandler: nil
                        )
                    }
                }
            },
            scrollTarget: appState.editorScrollTarget
        )
    }

    // MARK: Preview pane

    private func previewPane(onPreviewClick: ((Int, CGFloat, CGFloat) -> Void)? = nil) -> some View {
        MarkdownWebView(
            content: appState.markdownContent,
            displayCSS: styleManager.activeStyle.displayStyle.toCSS(),
            zoomLevel: appState.zoomLevel,
            fileURL: appState.fileURL,
            onPreviewClick: onPreviewClick,
            webViewRef: $webViewRef
        )
        .ignoresSafeArea()
    }

    // MARK: Reverse sync helper

    private func syncEditorToPreviewClick(headingIndex: Int, sectionFraction: CGFloat, clickFraction: CGFloat) {
        let headings = appState.headings
        let totalLen = (appState.markdownContent as NSString).length
        guard totalLen > 0 else { return }

        let targetOffset: Int
        if headings.isEmpty || headingIndex < 0 {
            // No headings or before first — treat sectionFraction as doc fraction
            targetOffset = Int(sectionFraction * CGFloat(totalLen))
        } else if headingIndex < headings.count {
            let heading = headings[headingIndex]
            let nextOffset = headingIndex + 1 < headings.count
                ? headings[headingIndex + 1].charOffset
                : totalLen
            let sectionLen = nextOffset - heading.charOffset
            targetOffset = heading.charOffset + Int(sectionFraction * CGFloat(sectionLen))
        } else {
            return
        }

        appState.editorScrollTarget = EditorScrollTarget(
            charOffset: min(max(0, targetOffset), totalLen),
            viewportFraction: clickFraction,
            token: UUID()
        )
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
            .help(String(localized: "toolbar.folderSidebar.help"))
            .disabled(appState.folderURL == nil)
        }

        ToolbarItem(placement: .principal) {
            Picker("", selection: $appState.viewMode) {
                Image(systemName: "square.and.pencil").tag(ViewMode.editor)
                Image(systemName: "rectangle.split.2x1").tag(ViewMode.split)
                Image(systemName: "eye").tag(ViewMode.viewer)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
            .help(String(localized: "toolbar.viewMode.help"))
            .overlay(alignment: .bottom) {
                Text("toolbar.unsaved")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .opacity(appState.isDirty ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: appState.isDirty)
                    .offset(y: 14)
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button { appState.zoomLevel = max(0.5, appState.zoomLevel - 0.1) } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help(String(localized: "toolbar.zoomOut.help"))

            Text(String(format: "%.0f%%", appState.zoomLevel * 100))
                .monospacedDigit()
                .frame(width: 44)
                .onTapGesture { appState.zoomLevel = 1.0 }
                .help(String(localized: "toolbar.zoomReset.help"))

            Button { appState.zoomLevel = min(3.0, appState.zoomLevel + 0.1) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help(String(localized: "toolbar.zoomIn.help"))

            Divider()

            Button { WindowCoordinator.shared.openWithPicker() } label: {
                Label("toolbar.open.label", systemImage: "folder")
            }
            .help(String(localized: "toolbar.open.help"))

            Menu {
                Button(String(localized: "toolbar.export.pdf"))         { appState.exportPDF() }
                Button(String(localized: "toolbar.export.mobilePDF"))   { appState.exportMobilePDF() }
                Button(String(localized: "toolbar.export.mobileImage")) { appState.exportMobileImage() }
                Divider()
                Button(String(localized: "toolbar.export.all"))         { appState.exportAll() }
            } label: {
                Label("toolbar.export.label", systemImage: "square.and.arrow.up")
            }
            .help(String(localized: "toolbar.export.help"))
            .disabled(appState.fileURL == nil || appState.isExporting)
        }
    }

    // MARK: Saved badge

    @ViewBuilder
    private var savedBadge: some View {
        if appState.showSavedBadge {
            Label("badge.saved", systemImage: "checkmark.circle.fill")
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
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
            // NSItemProvider returns either Data or NSURL depending on macOS version
            var fileURL: URL?
            if let data = item as? Data {
                fileURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let nsURL = item as? NSURL {
                fileURL = nsURL as URL
            }
            guard let url = fileURL,
                  ["md", "markdown"].contains(url.pathExtension.lowercased())
            else { return }
            // Route through WindowCoordinator so multi-window reuse logic applies
            DispatchQueue.main.async { WindowCoordinator.shared.open(url: url) }
        }
        return true
    }
}
