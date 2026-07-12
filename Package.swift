// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BurnalyticsAds",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "BurnalyticsAds", targets: ["BurnalyticsAds"])
    ],
    targets: [
        .target(name: "BurnalyticsAds"),
        .testTarget(name: "BurnalyticsAdsTests", dependencies: ["BurnalyticsAds"])
    ]
)
