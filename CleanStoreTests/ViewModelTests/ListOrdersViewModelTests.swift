import Foundation
import XCTest
@testable import CleanStore

final class ListOrdersViewModelTests: XCTestCase {
    @MainActor
    func testRefreshDisplaysRepositoryOrderAndUsesCurrentLocale() {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.bob, Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        let viewModel = ListOrdersViewModel(ordersFeature: feature)
        viewModel.refresh()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        XCTAssertEqual(viewModel.rows.map(\.id), ["bbb222", "aaa111"])
        XCTAssertEqual(viewModel.rows.first?.date, dateFormatter.string(from: Seeds.Orders.bob.date))
        XCTAssertEqual(viewModel.rows.first?.total, currencyFormatter.string(from: Seeds.Orders.bob.total))
    }

    @MainActor
    func testSelectingOrderAndCreatingDraftUseTheSameFeature() {
        let feature = OrdersFeature(repository: ControllableOrdersRepository(orders: [Seeds.Orders.amy]))
        let viewModel = ListOrdersViewModel(ordersFeature: feature)
        viewModel.refresh()
        viewModel.showOrder(id: "aaa111")
        XCTAssertTrue(viewModel.showsOrder)
        XCTAssertEqual(feature.selectedOrderID, "aaa111")
        feature.prepareEditingOrder(id: "aaa111")
        viewModel.createOrder()
        XCTAssertTrue(viewModel.showsEditor)
        XCTAssertNil(feature.makeOrderDraft().id)
    }
}
