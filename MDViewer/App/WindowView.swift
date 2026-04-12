import SwiftUI
import AppKit

/// Root view for every window. Owns its own AppState so windows are fully independent.
struct WindowView: View {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow
    @State private var nsWindow: NSWindow?

    let initialURL: URL?

    /// Tracks whether we still need to resize for the current file.
    /// Set `true` when `fileURL` changes; cleared after a successful resize.
    @State private var needsResize = false

    var body: some View {
        ContentView()
            .environmentObject(appState)
            .focusedSceneObject(appState)
            .background(WindowFinder(window: $nsWindow))
            .onAppear {
                // open() is synchronous — markdownContent is ready immediately after
                if let url = initialURL { appState.open(url: url) }

                // Register before draining pending URLs so empty windows are reusable
                WindowCoordinator.shared.registerAppState(appState)
                WindowCoordinator.shared.register { windowID in
                    openWindow(value: windowID)
                }
            }
            // Resize whenever a file is loaded — covers both new windows and reused
            // empty windows (where onAppear already ran without a file).
            .onChange(of: appState.fileURL) { _, url in
                guard url != nil else { return }
                needsResize = true
                scheduleResize()
            }
            // When nsWindow becomes available, fire a pending resize that was waiting
            // for the window reference.  This covers the case where fileURL was set
            // (in onAppear) before WindowFinder could discover the hosting NSWindow.
            .onChange(of: nsWindow) { _, win in
                guard win != nil, needsResize else { return }
                scheduleResize()
            }
    }

    /// Schedules a resize attempt after a short delay.  If nsWindow is still
    /// nil when the closure fires and no keyWindow fallback is available,
    /// the resize is skipped — but `needsResize` stays true so the
    /// `onChange(of: nsWindow)` observer can retry once the window is known.
    private func scheduleResize() {
        let content = appState.markdownContent
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let win = nsWindow else { return }
            resizeWindow(win, for: content)
            needsResize = false
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

/// Captures the hosting NSWindow via updateNSView.
/// If the NSView has not yet been added to a window at the time updateNSView
/// is called, a short async retry loop ensures the binding is eventually set.
private struct WindowFinder: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        guard window == nil else { return }
        if let w = view.window {
            DispatchQueue.main.async { window = w }
        } else {
            // The view is not yet in a window (can happen when many windows
            // are created in quick succession).  Poll briefly until it is.
            pollForWindow(view, remainingAttempts: 10)
        }
    }

    private func pollForWindow(_ view: NSView, remainingAttempts: Int) {
        guard window == nil, remainingAttempts > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let w = view.window {
                window = w
            } else {
                pollForWindow(view, remainingAttempts: remainingAttempts - 1)
            }
        }
    }
}
