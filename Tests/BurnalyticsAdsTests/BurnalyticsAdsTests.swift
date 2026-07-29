import XCTest
@testable import BurnalyticsAds

final class BurnalyticsAdsTests: XCTestCase {
    @MainActor
    func testConfigurationStoresPublisherAppID() {
        BurnalyticsAds.configure(appID: "  app-1234567890  ")
        XCTAssertEqual(BurnalyticsAds.appID, "app-1234567890")
    }

    func testLifecycleEventsAreEquatable() {
        XCTAssertEqual(BurnalyticsAdEvent.loaded, .loaded)
        XCTAssertEqual(
            BurnalyticsAdEvent.failed(.noFill),
            .failed(.noFill)
        )
        XCTAssertNotEqual(BurnalyticsAdEvent.skipped, .dismissed)
    }

    func testUnknownErrorMapsToNetworkError() {
        let source = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet
        )
        guard case .network(let message) = BurnalyticsAdsError.from(source) else {
            return XCTFail("Expected a network error")
        }
        XCTAssertFalse(message.isEmpty)
    }
}
