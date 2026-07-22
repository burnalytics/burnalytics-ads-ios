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
    let onLoad: () -> Void
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(creativeURL: url, onLoad: onLoad, onFailure: onFailure)
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
        context.coordinator.onLoad = onLoad
        context.coordinator.onFailure = onFailure
        guard webView.url != url else { return }
        context.coordinator.creativeURL = url
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var creativeURL: URL
        var onLoad: () -> Void
        var onFailure: () -> Void

        init(creativeURL: URL, onLoad: @escaping () -> Void, onFailure: @escaping () -> Void) {
            self.creativeURL = creativeURL
            self.onLoad = onLoad
            self.onFailure = onFailure
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            UIView.animate(
                withDuration: 0.16,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                webView.alpha = 1
            } completion: { [weak self] _ in
                self?.onLoad()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onFailure()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onFailure()
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            onFailure()
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

            if destination.scheme == "about" || destination == creativeURL {
                decisionHandler(.allow)
                return
            }

            openExternally(destination)
            decisionHandler(.cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let destination = navigationAction.request.url {
                openExternally(destination)
            }
            return nil
        }

        private func openExternally(_ destination: URL) {
            guard destination.scheme == "https" || destination.scheme == "http" else { return }
            UIApplication.shared.open(destination)
        }
    }
}
