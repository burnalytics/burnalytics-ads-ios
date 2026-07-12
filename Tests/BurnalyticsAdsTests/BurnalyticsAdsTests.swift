import XCTest
@testable import BurnalyticsAds

final class BurnalyticsAdsTests: XCTestCase {
    @MainActor
    func testConfigurationStoresPublisherAppID() {
        BurnalyticsAds.configure(appID: "  app-1234567890  ")
        XCTAssertEqual(BurnalyticsAds.appID, "app-1234567890")
    }
}
