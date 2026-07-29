# Burnalytics Ads SDK for iOS

Official Burnalytics Ads SDK for iOS apps. Serve Burnalytics banner, HTML5, image interstitial, video interstitial, and rewarded video ads from SwiftUI.

## Requirements

- iOS 16.0+
- Swift 5.9+
- Xcode 15+

## Installation

In Xcode, open your app project and choose:

`File` > `Add Package Dependencies...`

Use this package URL:

```text
https://github.com/burnalytics/burnalytics-ads-ios.git
```

Then add the `BurnalyticsAds` product to your app target.

## Configure

Configure the SDK once when your app starts:

```swift
import SwiftUI
import BurnalyticsAds

@main
struct MyApp: App {
    init() {
        BurnalyticsAds.configure(appID: "app-1669474039")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Use the App ID from your Burnalytics publisher dashboard.

## Banner Ads

Add a banner placement anywhere in SwiftUI:

```swift
import SwiftUI
import BurnalyticsAds

struct ContentView: View {
    var body: some View {
        BurnalyticsBannerView(slotID: "4165549702")
    }
}
```

Banner slots can serve image or HTML5 ads, depending on the publisher slot settings in Burnalytics.

## Interstitial Ads

Use the interstitial modifier on a parent view:

```swift
import SwiftUI
import BurnalyticsAds

struct ContentView: View {
    @State private var showInterstitial = false

    var body: some View {
        Button("Show interstitial") {
            showInterstitial = true
        }
        .burnalyticsInterstitial(
            slotID: "2911997583",
            isPresented: $showInterstitial
        )
    }
}
```

Use an image interstitial slot for image creatives, or a video interstitial slot for video creatives:

```swift
.burnalyticsInterstitial(
    slotID: "5207566349",
    isPresented: $showVideoInterstitial
)
```

## Preloading

Preload ads before showing them:

```swift
BurnalyticsAds.preloadBanner(slotID: "4165549702")
BurnalyticsAds.preloadInterstitial(slotID: "5207566349")
BurnalyticsAds.preloadRewardedAd(slotID: "YOUR_REWARDED_SLOT_ID")
```

## Rewarded Video Ads

Present a rewarded video from a `rewarded_video` slot. The callback runs only after the video reaches the end; closing the ad early does not grant the reward.

```swift
import SwiftUI
import BurnalyticsAds

struct ContentView: View {
    @State private var showRewardedAd = false
    @State private var coins = 0

    var body: some View {
        Button("Watch ad for 10 coins") {
            showRewardedAd = true
        }
        .burnalyticsRewardedAd(
            slotID: "YOUR_REWARDED_SLOT_ID",
            isPresented: $showRewardedAd
        ) {
            coins += 10
        }
    }
}
```

## Test IDs

Use the IDs from your Burnalytics publisher dashboard:

```text
App ID: app-1669474039
Banner Slot ID: 4165549702
Image Interstitial Slot ID: 2911997583
Video Interstitial Slot ID: 5207566349
```

## Notes

- Impression tracking is handled automatically.
- Interstitial close controls are handled by the SDK.
- Reward callbacks fire only after a rewarded video finishes playback.
- Rewarded-video completion tracking is sent automatically before the app reward callback runs.
- When the server zone uses completion billing, closing early does not consume a paid campaign view.
- HTML5 banner rendering can be disabled per slot in the Burnalytics publisher dashboard.

## License

MIT
