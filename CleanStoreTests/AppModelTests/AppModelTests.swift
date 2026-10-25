import XCTest
@testable import CleanStore

final class AppModelTests: XCTestCase {
    @MainActor
    func testLaunchRequestsOneRefreshWithoutHidingTheFeature() async throws {
        let repository = ControllableOrdersRepository()
        repository.holdsFetches = true
        let feature = OrdersFeature(repository: repository)
        let appModel = AppModel(ordersFeature: feature)
        XCTAssertEqual(repository.fetchCount, 0)
        let started = expectation(description: "Launch fetch began")
        repository.fetchStarted = { started.fulfill() }
        defer { repository.releasePendingRequests() }
        let launch = Task { await appModel.applicationDidFinishLaunching() }
        await fulfillment(of: [started], timeout: 2)
        await appModel.applicationDidFinishLaunching()
        XCTAssertTrue(appModel.ordersFeature === feature)
        XCTAssertEqual(repository.fetchCount, 1)
        XCTAssertTrue(feature.isRefreshing)
        repository.finishFetch(with: [Seeds.Orders.amy])
        await launch.value
        XCTAssertEqual(feature.orders.count, 1)
    }

    @MainActor
    func testIsolatedGraphsDoNotShareOrders() async throws {
        let first = AppModel(ordersFeature: OrdersFeature(
            repository: ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        ))
        let second = AppModel(ordersFeature: OrdersFeature(
            repository: ControllableOrdersRepository(orders: [Seeds.Orders.bob])
        ))
        await first.applicationDidFinishLaunching()
        await second.applicationDidFinishLaunching()
        XCTAssertEqual(first.ordersFeature.orders.map(\.id), ["aaa111"])
        XCTAssertEqual(second.ordersFeature.orders.map(\.id), ["bbb222"])
    }
}
