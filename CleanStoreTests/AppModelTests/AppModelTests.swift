import XCTest
@testable import CleanStore

final class AppModelTests: XCTestCase {
    @MainActor
    func testLaunchRequestsOneRefreshWithoutHidingTheFeature() {
        let repository = ControllableOrdersRepository()
        repository.holdsFetches = true
        let feature = OrdersFeature(repository: repository)
        let appModel = AppModel(ordersFeature: feature)
        XCTAssertEqual(repository.fetchCount, 0)
        appModel.applicationDidFinishLaunching()
        appModel.applicationDidFinishLaunching()
        XCTAssertTrue(appModel.ordersFeature === feature)
        XCTAssertEqual(repository.fetchCount, 1)
        XCTAssertTrue(feature.isRefreshing)
        repository.finishFetch(with: [Seeds.Orders.amy])
        XCTAssertEqual(feature.orders.count, 1)
    }

    @MainActor
    func testIsolatedGraphsDoNotShareOrders() {
        let first = AppModel(ordersFeature: OrdersFeature(
            repository: ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        ))
        let second = AppModel(ordersFeature: OrdersFeature(
            repository: ControllableOrdersRepository(orders: [Seeds.Orders.bob])
        ))
        first.applicationDidFinishLaunching()
        second.applicationDidFinishLaunching()
        XCTAssertEqual(first.ordersFeature.orders.map(\.id), ["aaa111"])
        XCTAssertEqual(second.ordersFeature.orders.map(\.id), ["bbb222"])
    }
}
