import SwiftUI

public struct BurnalyticsBannerView: View {
    let slotID: String

    @State private var ad: BurnalyticsBannerAd?
    @State private var errorMessage: String?
    @State private var trackedRequestID: String?

    public init(slotID: String) {
        self.slotID = slotID
    }

    public var body: some View {
        Group {
            if let ad {
                banner(ad)
            } else if let errorMessage {
                unavailable(message: errorMessage)
            } else {
                Color.clear
                    .frame(width: 320, height: 50)
            }
        }
        .task(id: slotID) {
            await load()
        }
    }

    private func banner(_ ad: BurnalyticsBannerAd) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if ad.creative.type == "html5", let htmlURL = ad.creative.htmlURL {
                BurnalyticsHTML5View(url: htmlURL)
            } else if let imageURL = ad.creative.imageURL {
                Link(destination: ad.creative.clickURL) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            Color.black.overlay {
                                Text("Ad unavailable")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        default:
                            Color.clear
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                Color.black.overlay {
                    Text("Ad unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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
        .frame(
            width: CGFloat(ad.creative.width),
            height: CGFloat(ad.creative.height)
        )
        .clipped()
        .task(id: ad.requestID) {
            guard trackedRequestID != ad.requestID else { return }
            trackedRequestID = ad.requestID
            await BurnalyticsAdsClient.shared.recordImpression(ad.tracking.impressionURL)
        }
        .accessibilityLabel(ad.creative.alt)
    }

    private func unavailable(message: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .frame(width: 320, height: 50)
            .overlay {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(8)
            }
    }

    private func load() async {
        ad = nil
        errorMessage = nil
        trackedRequestID = nil
        do {
            ad = try await BurnalyticsAdsClient.shared.loadBanner(slotID: slotID)
        } catch BurnalyticsAdsError.noFill {
            errorMessage = "No ad available"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

