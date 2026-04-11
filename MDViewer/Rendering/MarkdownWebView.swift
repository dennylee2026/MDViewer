import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let content: String
    let theme: String   // "light", "dark", "sepia"
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
        context.coordinator.theme = theme

        DispatchQueue.main.async { webViewRef = webView }
        loadTemplate(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        let contentChanged = coordinator.lastContent != content
        let themeChanged   = coordinator.theme != theme
        let fileChanged    = coordinator.lastFileURL != fileURL

        coordinator.theme = theme
        coordinator.pendingContent = content
        coordinator.pendingFileURL = fileURL

        if themeChanged {
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
        var theme: String = "light"
        var isLoaded: Bool = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            webView.evaluateJavaScript("switchTheme('\(theme)')") { [weak self] _, _ in
                guard let self else { return }
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
