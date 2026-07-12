import Foundation

@MainActor
public enum BurnalyticsAds {
    public static let sdkVersion = "1.0.0"

    private(set) static var appID = ""
    private(set) static var baseURL = URL(string: "https://www.burnalytics.com")!

    public static func configure(appID: String, baseURL: URL? = nil) {
        self.appID = appID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let baseURL {
            self.baseURL = baseURL
        }
    }

    public static func preloadBanner(slotID: String) {
        Task {
            _ = try? await BurnalyticsAdsClient.shared.loadBanner(slotID: slotID)
        }
    }

    public static func preloadInterstitial(slotID: String) {
        Task {
            _ = try? await BurnalyticsAdsClient.shared.loadInterstitial(slotID: slotID)
        }
    }
}

nonisolated struct BurnalyticsBannerAd: Decodable, Identifiable {
    struct Creative: Decodable {
        let type: String
        let imageURL: URL?
        let htmlURL: URL?
        let videoURL: URL?
        let clickURL: URL
        let width: Int
        let height: Int
        let alt: String
        let durationSeconds: Double?

        enum CodingKeys: String, CodingKey {
            case type
            case imageURL = "image_url"
            case htmlURL = "html_url"
            case videoURL = "video_url"
            case clickURL = "click_url"
            case width
            case height
            case alt
            case durationSeconds = "duration_seconds"
        }
    }

    struct Tracking: Decodable {
        let impressionURL: URL

        enum CodingKeys: String, CodingKey {
            case impressionURL = "impression_url"
        }
    }

    struct Disclosure: Decodable {
        let aboutURL: URL
        let label: String

        enum CodingKeys: String, CodingKey {
            case aboutURL = "about_url"
            case label
        }
    }

    let requestID: String
    let format: String
    let creative: Creative
    let tracking: Tracking
    let disclosure: Disclosure

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case format
        case creative
        case tracking
        case disclosure
    }

    var id: String { requestID }
}

enum BurnalyticsAdsError: LocalizedError {
    case notConfigured
    case invalidResponse
    case noFill
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Burnalytics Ads has not been configured."
        case .invalidResponse:
            return "The ad server returned an invalid response."
        case .noFill:
            return "No ad is available for this placement."
        case .server(let message):
            return message
        }
    }
}

actor BurnalyticsAdsClient {
    static let shared = BurnalyticsAdsClient()
    private let cacheLifetime: TimeInterval = 5 * 60
    private var bannerCache: [String: (ad: BurnalyticsBannerAd, loadedAt: Date)] = [:]
    private var interstitialCache: [String: (ad: BurnalyticsBannerAd, loadedAt: Date)] = [:]

    private struct AdRequest: Encodable {
        let appID: String
        let slotID: String
        let bundleID: String
        let sdkVersion: String

        enum CodingKeys: String, CodingKey {
            case appID = "app_id"
            case slotID = "slot_id"
            case bundleID = "bundle_id"
            case sdkVersion = "sdk_version"
        }
    }

    private struct ErrorResponse: Decodable {
        let error: String
    }

    func loadBanner(slotID: String) async throws -> BurnalyticsBannerAd {
        if let cached = bannerCache[slotID],
           Date().timeIntervalSince(cached.loadedAt) < cacheLifetime {
            return cached.ad
        }
        let ad = try await requestAd(slotID: slotID)
        guard ad.format == "banner" else {
            throw BurnalyticsAdsError.invalidResponse
        }
        bannerCache[slotID] = (ad, Date())
        return ad
    }

    func loadInterstitial(slotID: String) async throws -> BurnalyticsBannerAd {
        if let cached = interstitialCache[slotID],
           Date().timeIntervalSince(cached.loadedAt) < cacheLifetime {
            return cached.ad
        }
        let ad = try await requestAd(slotID: slotID)
        guard ad.format == "interstitial_image" || ad.format == "interstitial_video" else {
            throw BurnalyticsAdsError.invalidResponse
        }
        interstitialCache[slotID] = (ad, Date())
        return ad
    }

    func consumeInterstitial(slotID: String) {
        interstitialCache[slotID] = nil
    }

    private func requestAd(slotID: String) async throws -> BurnalyticsBannerAd {
        let configuration = await MainActor.run {
            (
                appID: BurnalyticsAds.appID,
                baseURL: BurnalyticsAds.baseURL,
                sdkVersion: BurnalyticsAds.sdkVersion
            )
        }
        guard !configuration.appID.isEmpty else {
            throw BurnalyticsAdsError.notConfigured
        }
        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else {
            throw BurnalyticsAdsError.invalidResponse
        }

        let endpoint = configuration.baseURL.appending(path: "/api/sdk/v1/ios/ads/request")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("BurnalyticsAds-iOS/(configuration.sdkVersion)", forHTTPHeaderField: "User-Agent")

        let payload = AdRequest(
            appID: configuration.appID,
            slotID: slotID,
            bundleID: bundleID,
            sdkVersion: configuration.sdkVersion
        )
        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BurnalyticsAdsError.invalidResponse
        }
        if httpResponse.statusCode == 204 {
            throw BurnalyticsAdsError.noFill
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let serverError = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw BurnalyticsAdsError.server(serverError?.error ?? "Ad request failed.")
        }

        let ad = try JSONDecoder().decode(BurnalyticsBannerAd.self, from: data)
        return ad
    }

    func recordImpression(_ url: URL) async {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try? await URLSession.shared.data(for: request)
    }
}
