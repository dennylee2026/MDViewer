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
                if let url = initialURL { appState.open(url: url) }
                WindowCoordinator.shared.register { windowID in
                    openWindow(value: windowID)
                }
            }
            .onChange(of: appState.fileURL) { _, url in
                guard url != nil else { return }
                // Brief delay so markdownContent is populated before we measure
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    resizeWindow(for: appState.markdownContent)
                }
            }
    }

    // MARK: - Window resize

    private func resizeWindow(for content: String) {
        guard let window = nsWindow else { return }

        let lineCount  = content.components(separatedBy: "\n").count
        let screenH    = window.screen?.visibleFrame.height ?? NSScreen.main?.visibleFrame.height ?? 800
        let rawHeight  = 420 + CGFloat(lineCount) * 13
        let targetH    = max(500, min(rawHeight, screenH * 0.88))

        var frame = window.frame
        // Grow/shrink upward — keep the bottom edge anchored
        frame.origin.y    += frame.height - targetH
        frame.size.height  = targetH

        // Clamp within the screen's visible area
        if let screen = window.screen {
            let vis = screen.visibleFrame
            frame.origin.y = max(vis.minY, min(frame.origin.y, vis.maxY - targetH))
        }

        window.setFrame(frame, display: true, animate: true)
    }
}

// MARK: - NSWindow accessor

/// Captures the NSWindow that hosts this view so we can resize it directly.
private struct WindowFinder: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { window = view.window }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { window = view.window }
    }
}
