import SwiftUI

public struct BurnalyticsBannerView: View {
    let slotID: String

    @State private var ad: BurnalyticsBannerAd?
    @State private var isLoading = true
    @State private var creativeLoaded = false
    @State private var trackedRequestID: String?

    public init(slotID: String) {
        self.slotID = slotID
    }

    public var body: some View {
        Group {
            if let ad {
                banner(ad)
            } else if isLoading {
                Color.clear
                    .frame(width: 320, height: 50)
            } else {
                EmptyView()
            }
        }
        .task(id: slotID) {
            await load()
        }
    }

    private func banner(_ ad: BurnalyticsBannerAd) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if ad.creative.type == "html5", let htmlURL = ad.creative.htmlURL {
                BurnalyticsHTML5View(
                    url: htmlURL,
                    onLoad: { creativeDidLoad(ad) },
                    onFailure: { creativeDidFail(ad) }
                )
            } else if let imageURL = ad.creative.imageURL {
                Link(destination: ad.creative.clickURL) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .onAppear { creativeDidLoad(ad) }
                        case .failure:
                            Color.clear
                                .onAppear { creativeDidFail(ad) }
                        default:
                            Color.clear
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .onAppear { creativeDidFail(ad) }
            }

            if creativeLoaded {
                Link(destination: ad.disclosure.aboutURL) {
                    Text(ad.disclosure.label)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay {
                            Capsule().stroke(.yellow.opacity(0.9), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }
        .frame(
            width: CGFloat(ad.creative.width),
            height: CGFloat(ad.creative.height)
        )
        .clipped()
        .accessibilityLabel(ad.creative.alt)
    }

    private func creativeDidLoad(_ loadedAd: BurnalyticsBannerAd) {
        guard ad?.requestID == loadedAd.requestID else { return }
        creativeLoaded = true
        guard trackedRequestID != loadedAd.requestID else { return }
        trackedRequestID = loadedAd.requestID
        Task {
            await BurnalyticsAdsClient.shared.recordImpression(loadedAd.tracking.impressionURL)
        }
    }

    private func creativeDidFail(_ failedAd: BurnalyticsBannerAd) {
        guard ad?.requestID == failedAd.requestID else { return }
        ad = nil
        isLoading = false
        creativeLoaded = false
    }

    private func load() async {
        ad = nil
        isLoading = true
        creativeLoaded = false
        trackedRequestID = nil
        do {
            ad = try await BurnalyticsAdsClient.shared.loadBanner(slotID: slotID)
            isLoading = false
        } catch {
            ad = nil
            isLoading = false
        }
    }
}
