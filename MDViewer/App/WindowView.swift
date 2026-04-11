import SwiftUI

/// Root view for every window. Owns its own AppState so windows are fully independent.
struct WindowView: View {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    let initialURL: URL?

    var body: some View {
        ContentView()
            .environmentObject(appState)
            .focusedSceneObject(appState)
            .onAppear {
                if let url = initialURL { appState.open(url: url) }
                // Register this window as the global URL opener.
                // Each new window overwrites the previous registration; openWindow
                // is an app-level action so it works from any window's context.
                WindowCoordinator.shared.register { windowID in
                    openWindow(value: windowID)
                }
            }
    }
}
