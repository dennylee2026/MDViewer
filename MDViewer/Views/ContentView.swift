import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Group {
            if appState.fileURL != nil {
                MarkdownWebView(
                    content: appState.markdownContent,
                    isDark: colorScheme == .dark
                )
                .ignoresSafeArea()
            } else {
                WelcomeView()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle(appState.fileURL?.lastPathComponent ?? "MDViewer")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.openFilePicker()
                } label: {
                    Label("Open File", systemImage: "folder")
                }
                .help("Open a Markdown file")
            }
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("MDViewer")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("A beautiful Markdown reader for macOS")
                .font(.body)
                .foregroundStyle(.secondary)

            Button("Open Markdown File…") {
                appState.openFilePicker()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)

            Text("You can also drag a .md file onto this window")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            providers.first?.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.pathExtension == "md" || url.pathExtension == "markdown"
                else { return }
                DispatchQueue.main.async {
                    appState.open(url: url)
                }
            }
            return true
        }
    }
}
