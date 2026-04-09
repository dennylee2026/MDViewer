import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let content: String
    let isDark: Bool

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
        context.coordinator.isDark = isDark

        loadTemplate(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        let contentChanged = coordinator.lastContent != content
        let themeChanged = coordinator.isDark != isDark

        coordinator.isDark = isDark
        coordinator.pendingContent = content

        if themeChanged {
            let theme = isDark ? "dark" : "light"
            webView.evaluateJavaScript("switchTheme('\(theme)')") { _, _ in
                if contentChanged {
                    coordinator.renderContent(content)
                }
            }
        } else if contentChanged {
            if coordinator.isLoaded {
                coordinator.renderContent(content)
            }
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
        var lastContent: String = ""
        var isDark: Bool = false
        var isLoaded: Bool = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            let theme = isDark ? "dark" : "light"
            webView.evaluateJavaScript("switchTheme('\(theme)')") { [weak self] _, _ in
                guard let self else { return }
                self.renderContent(self.pendingContent)
            }
        }

        func renderContent(_ markdown: String) {
            guard let webView else { return }
            lastContent = markdown
            let escaped = markdown
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            let js = "renderMarkdown(`\(escaped)`)"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
