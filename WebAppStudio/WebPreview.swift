import SwiftUI
import WebKit

struct WebPreview: NSViewRepresentable {
    let html: String
    let userAgent: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = userAgent
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadHTMLString(html, baseURL: URL(fileURLWithPath: NSTemporaryDirectory()))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.customUserAgent = userAgent
        webView.loadHTMLString(html, baseURL: URL(fileURLWithPath: NSTemporaryDirectory()))
    }
}
