import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let content: String
    let theme: String   // "light", "dark", "sepia"
    let zoomLevel: Double
    let fileURL: URL?
    var onPreviewClick: ((Int, CGFloat, CGFloat) -> Void)? = nil   // (headingIndex, sectionFraction, clickFraction)
    @Binding var webViewRef: WKWebView?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.userContentController.add(context.coordinator, name: "openMDLink")
        config.userContentController.add(context.coordinator, name: "syncToEditor")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        context.coordinator.pendingContent = content
        context.coordinator.pendingFileURL = fileURL
        context.coordinator.theme = theme
        context.coordinator.onPreviewClick = onPreviewClick

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
        coordinator.onPreviewClick = onPreviewClick

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

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var pendingContent: String = ""
        var pendingFileURL: URL? = nil
        var lastContent: String = ""
        var lastFileURL: URL? = nil
        var theme: String = "light"
        var isLoaded: Bool = false
        var onPreviewClick: ((Int, CGFloat, CGFloat) -> Void)?

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

        // MARK: WKScriptMessageHandler — MD link interception

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if message.name == "syncToEditor",
               let dict = message.body as? [String: Any],
               let hiNum  = dict["headingIndex"]   as? NSNumber,
               let sfNum  = dict["sectionFraction"] as? NSNumber,
               let cfNum  = dict["clickFraction"]   as? NSNumber {
                let headingIndex    = hiNum.intValue
                let sectionFraction = CGFloat(sfNum.doubleValue)
                let clickFraction   = CGFloat(cfNum.doubleValue)
                onPreviewClick?(headingIndex, sectionFraction, clickFraction)
                return
            }

            guard message.name == "openMDLink",
                  let href = message.body as? String,
                  let baseDir = lastFileURL?.deletingLastPathComponent() else { return }

            // Resolve href: absolute path, file:// URL, or relative
            let targetURL: URL
            if href.hasPrefix("file://"), let u = URL(string: href) {
                targetURL = u
            } else if href.hasPrefix("/") {
                targetURL = URL(fileURLWithPath: href)
            } else {
                targetURL = baseDir.appendingPathComponent(href)
            }

            let filename = targetURL.lastPathComponent
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "打开 Markdown 文件"
                alert.informativeText = "是否打开「\(filename)」？"
                alert.addButton(withTitle: "打开")
                alert.addButton(withTitle: "取消")
                if alert.runModal() == .alertFirstButtonReturn {
                    WindowCoordinator.shared.open(url: targetURL)
                }
            }
        }
    }
}
