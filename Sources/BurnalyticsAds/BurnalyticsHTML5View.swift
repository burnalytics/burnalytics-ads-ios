import SwiftUI
import WebKit

@MainActor
final class BurnalyticsWebViewEnvironment {
    static let shared = BurnalyticsWebViewEnvironment()

    let dataStore = WKWebsiteDataStore.nonPersistent()

    private init() {}

    func configuration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        return configuration
    }

}

struct BurnalyticsHTML5View: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(allowedHost: url.host)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(
            frame: .zero,
            configuration: BurnalyticsWebViewEnvironment.shared.configuration()
        )
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = false
        webView.alpha = 0
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        context.coordinator.allowedHost = url.host
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var allowedHost: String?

        init(allowedHost: String?) {
            self.allowedHost = allowedHost
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            UIView.animate(
                withDuration: 0.16,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                webView.alpha = 1
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let destination = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            if destination.scheme == "about" || destination.host == allowedHost {
                decisionHandler(.allow)
                return
            }

            if destination.scheme == "https" || destination.scheme == "http" {
                UIApplication.shared.open(destination)
            }
            decisionHandler(.cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let destination = navigationAction.request.url {
                if destination.host == allowedHost {
                    webView.load(URLRequest(url: destination))
                } else if destination.scheme == "https" || destination.scheme == "http" {
                    UIApplication.shared.open(destination)
                }
            }
            return nil
        }
    }
}

