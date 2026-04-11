import SwiftUI

@main
struct MDViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup(for: WindowID.self) { $windowID in
            WindowView(initialURL: windowID?.fileURL)
        }
        .commands { AppCommands() }

        Settings {
            PreferencesView()
        }
    }
}
