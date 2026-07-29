import AVFoundation
import Combine
import SwiftUI
import UIKit

struct BurnalyticsRewardedAdPresenter: ViewModifier {
    let slotID: String
    @Binding var isPresented: Bool
    let onReward: () -> Void

    @State private var ad: BurnalyticsBannerAd?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented, onDismiss: clear) {
                Group {
                    if let ad {
                        BurnalyticsRewardedAdView(
                            ad: ad,
                            isPresented: $isPresented,
                            onReward: onReward
                        )
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
            ad = try await BurnalyticsAdsClient.shared.loadRewardedAd(slotID: slotID)
        } catch {
#if DEBUG
            print("Burnalytics rewarded ad slot \(slotID) failed: \(error.localizedDescription)")
#endif
            isPresented = false
        }
    }

    private func clear() {
        ad = nil
        Task { await BurnalyticsAdsClient.shared.consumeRewardedAd(slotID: slotID) }
    }
}

public extension View {
    func burnalyticsRewardedAd(
        slotID: String,
        isPresented: Binding<Bool>,
        onReward: @escaping () -> Void
    ) -> some View {
        modifier(
            BurnalyticsRewardedAdPresenter(
                slotID: slotID,
                isPresented: isPresented,
                onReward: onReward
            )
        )
    }
}

private struct BurnalyticsRewardedAdView: View {
    let ad: BurnalyticsBannerAd
    @Binding var isPresented: Bool
    let onReward: () -> Void

    @State private var secondsUntilClose = 3
    @State private var tracked = false
    @State private var rewardGranted = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let videoURL = ad.creative.videoURL {
                BurnalyticsRewardedVideoPlayer(url: videoURL, onCompleted: grantReward)
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
                            if secondsUntilClose > 0 {
                                Text("\(secondsUntilClose)")
                            } else {
                                Image(systemName: "xmark")
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.7), in: Circle())
                    }
                    .disabled(secondsUntilClose > 0)
                    .accessibilityLabel(secondsUntilClose > 0 ? "Close available in \(secondsUntilClose) seconds" : "Close ad")
                }
                .padding()

                Spacer()

                VStack(spacing: 10) {
                    Text("Watch the full video to earn your reward")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.65), in: Capsule())

                    Link(destination: ad.creative.clickURL) {
                        Text("Learn more")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
        }
        .accessibilityLabel(ad.creative.alt)
        .task(id: ad.requestID) {
            if !tracked {
                tracked = true
                await BurnalyticsAdsClient.shared.recordImpression(ad.tracking.impressionURL)
            }
            while secondsUntilClose > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                secondsUntilClose -= 1
            }
        }
    }

    private func grantReward() {
        guard !rewardGranted else { return }
        rewardGranted = true
        Task {
            if let completionURL = ad.tracking.completionURL {
                await BurnalyticsAdsClient.shared.recordCompletion(completionURL)
            }
            onReward()
            isPresented = false
        }
    }
}

private struct BurnalyticsRewardedVideoPlayer: View {
    @State private var player: AVPlayer
    let onCompleted: () -> Void

    init(url: URL, onCompleted: @escaping () -> Void) {
        let item = AVPlayerItem(url: url)
        _player = State(initialValue: AVPlayer(playerItem: item))
        self.onCompleted = onCompleted
    }

    var body: some View {
        BurnalyticsPlayerSurface(player: player)
            .ignoresSafeArea()
            .onAppear {
                player.isMuted = false
                player.play()
            }
            .onDisappear {
                player.pause()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .AVPlayerItemDidPlayToEndTime,
                    object: player.currentItem
                )
            ) { _ in
                onCompleted()
            }
    }
}

private struct BurnalyticsPlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
    }
}
