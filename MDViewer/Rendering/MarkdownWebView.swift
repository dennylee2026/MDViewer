import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let content: String
    let isDark: Bool
    let zoomLevel: Double
    let fileURL: URL?
    @Binding var webViewRef: WKWebView?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.pendingContent = content
        context.coordinator.pendingFileURL = fileURL
        context.coordinator.isDark = isDark

        DispatchQueue.main.async { webViewRef = webView }
        loadTemplate(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        let contentChanged = coordinator.lastContent != content
        let themeChanged = coordinator.isDark != isDark
        let fileChanged = coordinator.lastFileURL != fileURL

        coordinator.isDark = isDark
        coordinator.pendingContent = content
        coordinator.pendingFileURL = fileURL

        if themeChanged {
            let theme = isDark ? "dark" : "light"
            webView.evaluateJavaScript("switchTheme('\(theme)')") { _, _ in
                if contentChanged {
                    coordinator.renderContent(content, scrollToTop: fileChanged)
                }
            }
        } else if contentChanged {
            if coordinator.isLoaded {
                coordinator.renderContent(content, scrollToTop: fileChanged)
            }
        }

        if webView.pageZoom != zoomLevel {
            webView.pageZoom = zoomLevel
        }
    }

    private func loadTemplate(in webView: WKWebView) {
        guard let templateURL = Bundle.main.url(forResource: "template", withExtension: "html") else {
            return
        }
        let resourceDir = templateURL.deletingLastPathComponent()
        webView.loadFileURL(templateURL, allowingReadAccessTo: resourceDir)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var pendingContent: String = ""
        var pendingFileURL: URL? = nil
        var lastContent: String = ""
        var lastFileURL: URL? = nil
        var isDark: Bool = false
        var isLoaded: Bool = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            let theme = isDark ? "dark" : "light"
            webView.evaluateJavaScript("switchTheme('\(theme)')") { [weak self] _, _ in
                guard let self else { return }
                // Initial load always scrolls to top
                self.renderContent(self.pendingContent, scrollToTop: true)
            }
        }

        func renderContent(_ markdown: String, scrollToTop: Bool) {
            guard let webView else { return }
            lastContent = markdown
            lastFileURL = pendingFileURL
            let escaped = markdown
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            webView.evaluateJavaScript("renderMarkdown(`\(escaped)`)", completionHandler: nil)
            if scrollToTop {
                webView.evaluateJavaScript("resetScroll()", completionHandler: nil)
            }
        }
    }
}
