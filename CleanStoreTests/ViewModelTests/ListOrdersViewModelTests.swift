import Foundation
import XCTest
@testable import CleanStore

final class ListOrdersViewModelTests: XCTestCase {
    @MainActor
    func testCancelledRefreshHandleIsReleasedAndRetryCanLoad() async {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        let viewModel = ListOrdersViewModel(ordersFeature: OrdersFeature(repository: repository))
        let cancelled = viewModel.refresh()
        cancelled.cancel()
        await cancelled.value
        XCTAssertEqual(repository.fetchCount, 0)
        XCTAssertFalse(viewModel.isRefreshing)
        XCTAssertNil(viewModel.refreshErrorMessage)
        await viewModel.refresh().value
        XCTAssertEqual(repository.fetchCount, 1)
        XCTAssertEqual(viewModel.rows.map(\.id), ["aaa111"])
    }

    @MainActor
    func testReadSurvivesListReleaseAndCancellationWithoutRetainingScreen() async {
        let repository = ControllableOrdersRepository()
        repository.holdsFetches = true
        defer { repository.releasePendingRequests() }
        let feature = OrdersFeature(repository: repository)
        var viewModel: ListOrdersViewModel? = ListOrdersViewModel(ordersFeature: feature)
        let screenWasReleased = { [weak viewModel] in viewModel == nil }
        let started = expectation(description: "Read reached repository")
        repository.fetchStarted = { started.fulfill() }
        let read = viewModel?.refresh()
        await fulfillment(of: [started], timeout: 2)
        guard repository.fetchCount == 1 else {
            XCTFail("Unexpected repository request count before completing the suspended operation")
            return
        }
        read?.cancel()
        viewModel = nil
        XCTAssertTrue(screenWasReleased())
        XCTAssertTrue(feature.isRefreshing)
        repository.finishFetch(with: [Seeds.Orders.amy])
        await read?.value
        let replacement = ListOrdersViewModel(ordersFeature: feature)
        XCTAssertFalse(replacement.isRefreshing)
        XCTAssertEqual(replacement.rows.map(\.id), ["aaa111"])
        XCTAssertEqual(repository.fetchCount, 1)
    }

    @MainActor
    func testRepeatedRefreshWaitsForOneRequestAndPublishesTogether() async {
        let repository = ControllableOrdersRepository()
        repository.holdsFetches = true
        defer { repository.releasePendingRequests() }
        let started = expectation(description: "One read started")
        repository.fetchStarted = { started.fulfill() }
        let viewModel = ListOrdersViewModel(ordersFeature: OrdersFeature(repository: repository))
        let first = viewModel.refresh()
        let repeated = viewModel.refresh()
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(viewModel.isRefreshing)
        XCTAssertTrue(viewModel.rows.isEmpty)
        XCTAssertEqual(repository.fetchCount, 1)
        repository.finishFetch(with: [Seeds.Orders.amy])
        await first.value
        await repeated.value
        XCTAssertFalse(viewModel.isRefreshing)
        XCTAssertEqual(viewModel.rows.map(\.id), ["aaa111"])
    }

    @MainActor
    func testFailedInitialLoadIsVisibleAndRetryRecoversWithoutReplacingViewModel() async {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        repository.failsNextFetch = true
        let viewModel = ListOrdersViewModel(ordersFeature: OrdersFeature(repository: repository))
        await viewModel.refresh().value
        XCTAssertNotNil(viewModel.refreshErrorMessage)
        XCTAssertTrue(viewModel.rows.isEmpty)
        await viewModel.refresh().value
        XCTAssertNil(viewModel.refreshErrorMessage)
        XCTAssertEqual(viewModel.rows.map(\.id), ["aaa111"])
        repository.failsNextFetch = true
        await viewModel.refresh().value
        XCTAssertNotNil(viewModel.refreshErrorMessage)
        XCTAssertEqual(viewModel.rows.map(\.id), ["aaa111"])
    }

    @MainActor
    func testRefreshDisplaysRepositoryOrderAndUsesCurrentLocale() async throws {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.bob, Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        let viewModel = ListOrdersViewModel(ordersFeature: feature)
        await viewModel.refresh().value
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        XCTAssertEqual(viewModel.rows.map(\.id), ["bbb222", "aaa111"])
        XCTAssertEqual(viewModel.rows.first?.date, dateFormatter.string(from: Seeds.Orders.bob.date))
        XCTAssertEqual(viewModel.rows.first?.total, currencyFormatter.string(from: Seeds.Orders.bob.total))
    }

    @MainActor
    func testSelectingOrderAndCreatingDraftUseTheSameFeature() async throws {
        let feature = OrdersFeature(repository: ControllableOrdersRepository(orders: [Seeds.Orders.amy]))
        let viewModel = ListOrdersViewModel(ordersFeature: feature)
        await viewModel.refresh().value
        viewModel.showOrder(id: "aaa111")
        XCTAssertTrue(viewModel.showsOrder)
        XCTAssertEqual(feature.selectedOrderID, "aaa111")
        feature.prepareEditingOrder(id: "aaa111")
        viewModel.createOrder()
        XCTAssertTrue(viewModel.showsEditor)
        XCTAssertNil(feature.makeOrderDraft().id)
    }
}
