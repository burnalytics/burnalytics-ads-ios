import SwiftUI
import AVKit

struct BurnalyticsInterstitialPresenter: ViewModifier {
    let slotID: String
    @Binding var isPresented: Bool

    @State private var ad: BurnalyticsBannerAd?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented, onDismiss: clear) {
                Group {
                    if let ad {
                        BurnalyticsInterstitialView(ad: ad, isPresented: $isPresented)
                    } else {
                        Color.black
                            .ignoresSafeArea()
                            .task { await load() }
                    }
                }
            }
    }

    private func load() async {
        do {
            ad = try await BurnalyticsAdsClient.shared.loadInterstitial(slotID: slotID)
        } catch {
#if DEBUG
            print("Burnalytics interstitial slot \(slotID) failed: \(error.localizedDescription)")
#endif
            isPresented = false
        }
    }

    private func clear() {
        ad = nil
        Task { await BurnalyticsAdsClient.shared.consumeInterstitial(slotID: slotID) }
    }
}

public extension View {
    func burnalyticsInterstitial(slotID: String, isPresented: Binding<Bool>) -> some View {
        modifier(BurnalyticsInterstitialPresenter(slotID: slotID, isPresented: isPresented))
    }
}

private struct BurnalyticsInterstitialView: View {
    let ad: BurnalyticsBannerAd
    @Binding var isPresented: Bool

    @State private var secondsRemaining = 3
    @State private var tracked = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if ad.creative.type == "video", let videoURL = ad.creative.videoURL {
                BurnalyticsVideoPlayer(url: videoURL)
            } else if let imageURL = ad.creative.imageURL {
                Link(destination: ad.creative.clickURL) {
                    AsyncImage(url: imageURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit()
                        } else {
                            Color.black
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            VStack {
                HStack {
                    Link(destination: ad.disclosure.aboutURL) {
                        Text(ad.disclosure.label)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.65), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        isPresented = false
                    } label: {
                        Group {
                            if secondsRemaining > 0 {
                                Text("\(secondsRemaining)")
                            } else {
                                Image(systemName: "xmark")
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.7), in: Circle())
                    }
                    .disabled(secondsRemaining > 0)
                }
                .padding()

                Spacer()

                if ad.creative.type == "video" {
                    Link(destination: ad.creative.clickURL) {
                        Text("Learn more")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
            }
        }
        .accessibilityLabel(ad.creative.alt)
        .task(id: ad.requestID) {
            if !tracked {
                tracked = true
                await BurnalyticsAdsClient.shared.recordImpression(ad.tracking.impressionURL)
            }
            while secondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                secondsRemaining -= 1
            }
        }
    }
}

private struct BurnalyticsVideoPlayer: View {
    @State private var player: AVPlayer

    init(url: URL) {
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player.isMuted = true
                player.play()
            }
            .onDisappear {
                player.pause()
            }
    }
}
