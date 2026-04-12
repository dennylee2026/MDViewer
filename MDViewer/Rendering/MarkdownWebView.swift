import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let content: String
    let displayCSS: String
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
        context.coordinator.pendingCSS = displayCSS
        context.coordinator.onPreviewClick = onPreviewClick

        DispatchQueue.main.async { webViewRef = webView }
        loadTemplate(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        let contentChanged = coordinator.lastContent != content
        let cssChanged     = coordinator.lastCSS != displayCSS
        let fileChanged    = coordinator.lastFileURL != fileURL

        coordinator.pendingCSS = displayCSS
        coordinator.pendingContent = content
        coordinator.pendingFileURL = fileURL
        coordinator.onPreviewClick = onPreviewClick

        if cssChanged {
            let escaped = escapedForJS(displayCSS)
            webView.evaluateJavaScript("applyCustomStyle(`\(escaped)`)") { _, _ in
                coordinator.lastCSS = self.displayCSS
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

    private func escapedForJS(_ css: String) -> String {
        css.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "`", with: "\\`")
           .replacingOccurrences(of: "$", with: "\\$")
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var pendingContent: String = ""
        var pendingFileURL: URL? = nil
        var pendingCSS: String = ""
        var lastContent: String = ""
        var lastFileURL: URL? = nil
        var lastCSS: String = ""
        var isLoaded: Bool = false
        var onPreviewClick: ((Int, CGFloat, CGFloat) -> Void)?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            let css = pendingCSS
            let escaped = css
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            webView.evaluateJavaScript("applyCustomStyle(`\(escaped)`)") { [weak self] _, _ in
                guard let self else { return }
                self.lastCSS = css
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
               let hiNum  = dict["headingIndex"]    as? NSNumber,
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
                alert.messageText = String(localized: "alert.openLink.title")
                alert.informativeText = String(format: String(localized: "alert.openLink.message"), filename)
                alert.addButton(withTitle: String(localized: "alert.openLink.open"))
                alert.addButton(withTitle: String(localized: "alert.openLink.cancel"))
                if alert.runModal() == .alertFirstButtonReturn {
                    WindowCoordinator.shared.open(url: targetURL)
                }
            }
        }
    }
}
