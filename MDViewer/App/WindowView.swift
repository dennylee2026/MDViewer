import SwiftUI
import AppKit

/// Root view for every window. Owns its own AppState so windows are fully independent.
struct WindowView: View {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow
    @State private var nsWindow: NSWindow?

    let initialURL: URL?

    var body: some View {
        ContentView()
            .environmentObject(appState)
            .focusedSceneObject(appState)
            .background(WindowFinder(window: $nsWindow))
            .onAppear {
                // open() is synchronous — markdownContent is ready immediately after
                if let url = initialURL { appState.open(url: url) }

                WindowCoordinator.shared.register { windowID in
                    openWindow(value: windowID)
                }

                // Resize only for file-based windows.
                // 0.2 s lets the WindowFinder binding propagate through a render cycle;
                // keyWindow fallback covers the (rare) case where nsWindow is still nil.
                guard initialURL != nil else { return }
                let content = appState.markdownContent
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    guard let win = nsWindow ?? NSApplication.shared.keyWindow else { return }
                    resizeWindow(win, for: content)
                }
            }
    }

    // MARK: - Resize

    private func resizeWindow(_ window: NSWindow, for content: String) {
        let lines   = content.components(separatedBy: "\n").count
        let screenH = window.screen?.visibleFrame.height
                      ?? NSScreen.main?.visibleFrame.height
                      ?? 800
        let target  = max(500, min(420 + CGFloat(lines) * 13, screenH * 0.88))

        var frame = window.frame
        // Grow / shrink upward; keep bottom edge anchored
        frame.origin.y   += frame.height - target
        frame.size.height = target

        // Stay within the screen's visible area
        if let vis = window.screen?.visibleFrame {
            frame.origin.y = max(vis.minY, min(frame.origin.y, vis.maxY - target))
        }

        window.setFrame(frame, display: true, animate: true)
    }
}

// MARK: - NSWindow accessor

/// Synchronously captures the hosting NSWindow via updateNSView,
/// which SwiftUI calls on the main thread after the view is in the hierarchy.
private struct WindowFinder: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        // Only assign once; avoids spurious re-renders on every parent update
        guard window == nil, let w = view.window else { return }
        window = w
    }
}
