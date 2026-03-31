import SwiftUI
import WebKit
import UIKit

struct MarkdownWebView: UIViewRepresentable {
    let markdown: String
    let isDarkMode: Bool
    @Binding var calculatedHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(calculatedHeight: $calculatedHeight)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: Coordinator.heightMessageName)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        context.coordinator.webView = webView
        context.coordinator.load(markdown: markdown, isDarkMode: isDarkMode)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.webView = webView
        context.coordinator.load(markdown: markdown, isDarkMode: isDarkMode)
    }

    func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.heightMessageName)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        static let heightMessageName = "heightChange"

        @Binding private var calculatedHeight: CGFloat
        weak var webView: WKWebView?

        private var lastMarkdown: String = ""
        private var lastIsDarkMode: Bool = false

        init(calculatedHeight: Binding<CGFloat>) {
            _calculatedHeight = calculatedHeight
        }

        func load(markdown: String, isDarkMode: Bool) {
            guard let webView else { return }

            if markdown == lastMarkdown, isDarkMode == lastIsDarkMode {
                return
            }

            lastMarkdown = markdown
            lastIsDarkMode = isDarkMode

            let html = Self.html(markdown: markdown, isDarkMode: isDarkMode)
            DispatchQueue.main.async {
                self.calculatedHeight = 1
            }
            webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == Self.heightMessageName else { return }

            let newHeight: CGFloat?
            if let number = message.body as? NSNumber {
                newHeight = CGFloat(truncating: number)
            } else if let doubleValue = message.body as? Double {
                newHeight = CGFloat(doubleValue)
            } else if let intValue = message.body as? Int {
                newHeight = CGFloat(intValue)
            } else {
                newHeight = nil
            }

            guard let height = newHeight else { return }

            DispatchQueue.main.async {
                let clamped = max(20, ceil(height))
                if abs(self.calculatedHeight - clamped) > 0.5 {
                    self.calculatedHeight = clamped
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false
            let scheme = url.scheme?.lowercased()

            if !isMainFrame || scheme == "http" || scheme == "https", navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let js = "window.__reportHeight && window.__reportHeight();"
            webView.evaluateJavaScript(js, completionHandler: nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }

        private static func html(markdown: String, isDarkMode: Bool) -> String {
            let escapedMarkdown = jsEscaped(markdown)
            let theme = isDarkMode ? "dark" : "light"

            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta
                    name="viewport"
                    content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"
                >
                <style>
                    :root {
                        color-scheme: \(theme);
                        --text: \(isDarkMode ? "#E8E8EA" : "#1C1C1E");
                        --muted: \(isDarkMode ? "#A1A1AA" : "#666666");
                        --link: \(isDarkMode ? "#7CC4FF" : "#0A84FF");
                        --code-bg: \(isDarkMode ? "#1B1C1F" : "#F4F4F5");
                        --inline-code-bg: \(isDarkMode ? "#2A2C31" : "#ECECEF");
                        --border: \(isDarkMode ? "#3A3A3C" : "#DCDCE0");
                        --quote-border: \(isDarkMode ? "#4B5563" : "#C7C7CC");
                        --table-header: \(isDarkMode ? "#23252A" : "#F7F7F8");
                        --selection: \(isDarkMode ? "rgba(124,196,255,0.25)" : "rgba(10,132,255,0.18)");
                    }

                    * {
                        box-sizing: border-box;
                    }

                    html,
                    body {
                        margin: 0;
                        padding: 0;
                        background: transparent;
                        color: var(--text);
                        -webkit-text-size-adjust: 100%;
                    }

                    body {
                        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                        font-size: 17px;
                        line-height: 1.55;
                        overflow-x: hidden;
                        word-wrap: break-word;
                    }

                    ::selection {
                        background: var(--selection);
                    }

                    #markdown-root {
                        width: 100%;
                        min-height: 1px;
                    }

                    h1, h2, h3, h4, h5, h6 {
                        margin: 0 0 0.55em 0;
                        line-height: 1.25;
                        font-weight: 700;
                        color: var(--text);
                    }

                    h1 { font-size: 1.7rem; }
                    h2 { font-size: 1.45rem; }
                    h3 { font-size: 1.25rem; }
                    h4 { font-size: 1.1rem; }
                    h5 { font-size: 1rem; }
                    h6 { font-size: 0.95rem; }

                    p,
                    ul,
                    ol,
                    blockquote,
                    pre,
                    table,
                    hr {
                        margin: 0 0 0.8em 0;
                    }

                    ul,
                    ol {
                        padding-left: 1.35em;
                    }

                    li + li {
                        margin-top: 0.2em;
                    }

                    blockquote {
                        padding: 0.1em 0 0.1em 0.9em;
                        border-left: 3px solid var(--quote-border);
                        color: var(--muted);
                    }

                    a {
                        color: var(--link);
                        text-decoration: none;
                    }

                    a:hover {
                        text-decoration: underline;
                    }

                    hr {
                        border: 0;
                        border-top: 1px solid var(--border);
                    }

                    code,
                    pre,
                    kbd,
                    samp {
                        font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
                    }

                    :not(pre) > code {
                        background: var(--inline-code-bg);
                        border-radius: 6px;
                        padding: 0.14em 0.38em;
                        font-size: 0.92em;
                    }

                    .code-block {
                        position: relative;
                        margin: 0 0 0.8em 0;
                    }

                    .code-copy {
                        position: absolute;
                        top: 8px;
                        right: 8px;
                        z-index: 2;
                        border: 1px solid var(--border);
                        background: rgba(255,255,255,0.08);
                        color: var(--text);
                        border-radius: 8px;
                        padding: 4px 8px;
                        font-size: 12px;
                        cursor: pointer;
                        backdrop-filter: blur(8px);
                    }

                    .code-copy:active {
                        transform: scale(0.98);
                    }

                    pre {
                        background: var(--code-bg);
                        border: 1px solid var(--border);
                        border-radius: 12px;
                        padding: 12px;
                        overflow-x: auto;
                        overflow-y: hidden;
                    }

                    pre code {
                        background: transparent !important;
                        padding: 0 !important;
                        border-radius: 0 !important;
                        font-size: 13px;
                        line-height: 1.5;
                        white-space: pre;
                        display: block;
                    }

                    .table-scroll {
                        width: 100%;
                        overflow-x: auto;
                        -webkit-overflow-scrolling: touch;
                        margin: 0 0 0.8em 0;
                    }

                    table {
                        border-collapse: collapse;
                        width: max-content;
                        min-width: 100%;
                    }

                    th,
                    td {
                        border: 1px solid var(--border);
                        padding: 8px 10px;
                        text-align: left;
                        vertical-align: top;
                    }

                    th {
                        background: var(--table-header);
                        font-weight: 600;
                    }

                    img {
                        max-width: 100%;
                        height: auto;
                        border-radius: 10px;
                    }

                    .hljs {
                        background: transparent !important;
                        color: inherit;
                    }

                    .hljs-comment,
                    .hljs-quote {
                        color: \(isDarkMode ? "#8B949E" : "#6A737D");
                    }

                    .hljs-keyword,
                    .hljs-selector-tag,
                    .hljs-literal,
                    .hljs-section,
                    .hljs-link {
                        color: \(isDarkMode ? "#FF7B72" : "#CF222E");
                    }

                    .hljs-string,
                    .hljs-title,
                    .hljs-name,
                    .hljs-type,
                    .hljs-attribute,
                    .hljs-symbol,
                    .hljs-bullet,
                    .hljs-addition,
                    .hljs-template-tag,
                    .hljs-template-variable {
                        color: \(isDarkMode ? "#A5D6FF" : "#0A3069");
                    }

                    .hljs-number,
                    .hljs-regexp,
                    .hljs-variable,
                    .hljs-selector-id,
                    .hljs-selector-class {
                        color: \(isDarkMode ? "#79C0FF" : "#0550AE");
                    }

                    .hljs-meta,
                    .hljs-built_in,
                    .hljs-doctag {
                        color: \(isDarkMode ? "#D2A8FF" : "#8250DF");
                    }

                    .hljs-emphasis {
                        font-style: italic;
                    }

                    .hljs-strong {
                        font-weight: 700;
                    }

                    mjx-container {
                        margin: 0 !important;
                    }

                    mjx-container[jax="CHTML"][display="true"] {
                        overflow-x: auto;
                        overflow-y: hidden;
                        padding: 2px 0;
                    }
                </style>

                <script>
                    window.__IS_DARK_MODE__ = \(isDarkMode ? "true" : "false");
                    window.__MARKDOWN_CONTENT__ = "\(escapedMarkdown)";
                    window.MathJax = {
                        tex: {
                            inlineMath: [['$', '$'], ['\\\\(', '\\\\)']],
                            displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']],
                            processEscapes: true,
                            processEnvironments: true
                        },
                        options: {
                            skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code']
                        },
                        chtml: {
                            scale: 1
                        },
                        startup: {
                            typeset: false
                        }
                    };

                    function reportHeight() {
                        const body = document.body;
                        const html = document.documentElement;
                        const height = Math.max(
                            body.scrollHeight,
                            body.offsetHeight,
                            html.scrollHeight,
                            html.offsetHeight,
                            html.clientHeight
                        );
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.heightChange) {
                            window.webkit.messageHandlers.heightChange.postMessage(Math.ceil(height));
                        }
                    }
                    window.__reportHeight = reportHeight;
                </script>

                <script src="marked.js"></script>
                <script src="highlight.js"></script>
                <script src="MathJax-4.1.1/tex-mml-chtml.js"></script>
                <script src="markdown.js"></script>
                </head>
                <body>
                    <div id="markdown-root"></div>
                    <script src="markdown.js"></script>
                </body>
                </html>
            """
        }

        private static func jsEscaped(_ text: String) -> String {
            var result = ""
            result.reserveCapacity(text.count)

            for scalar in text.unicodeScalars {
                switch scalar.value {
                case 0x08:
                    result += "\\b"
                case 0x09:
                    result += "\\t"
                case 0x0A:
                    result += "\\n"
                case 0x0C:
                    result += "\\f"
                case 0x0D:
                    result += "\\r"
                case 0x22:
                    result += "\\\""
                case 0x27:
                    result += "\\'"
                case 0x5C:
                    result += "\\\\"
                case 0x2028:
                    result += "\\u2028"
                case 0x2029:
                    result += "\\u2029"
                default:
                    result.append(String(scalar))
                }
            }

            return result
        }
    }
}
