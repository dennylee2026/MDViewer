import SwiftUI

@main
struct MDViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup(for: WindowID.self) { $windowID in
            WindowView(initialURL: windowID?.fileURL)
        }
        .commands { AppCommands() }

        Window("MDViewer 帮助", id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)

        Settings {
            PreferencesView()
        }
    }
}
