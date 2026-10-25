import Foundation
import XCTest
@testable import CleanStore

final class ShowOrderViewModelTests: XCTestCase {
    @MainActor
    func testDetailsExposeAllLegacyDisplayFieldsUsingCurrentLocale() async throws {
        let expected = Seeds.Orders.amy
        let feature = OrdersFeature(repository: ControllableOrdersRepository(orders: [expected]))
        await feature.refresh()
        feature.selectOrder(id: expected.id)
        let viewModel = ShowOrderViewModel(ordersFeature: feature)
        let details = try XCTUnwrap(viewModel.order)
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        XCTAssertEqual(details.id, expected.id)
        XCTAssertEqual(details.email, expected.email)
        XCTAssertEqual(details.name, "Amy Apple")
        XCTAssertEqual(details.date, dateFormatter.string(from: expected.date))
        XCTAssertEqual(details.total, currencyFormatter.string(from: expected.total))
    }
    @MainActor
    func testOpenDetailsKeepTheirIdentityWhenAnotherOrderIsSelected() async throws {
        let feature = OrdersFeature(repository: ControllableOrdersRepository(
            orders: [Seeds.Orders.amy, Seeds.Orders.bob]
        ))
        await feature.refresh()
        feature.selectOrder(id: "aaa111")
        let first = ShowOrderViewModel(ordersFeature: feature)
        feature.selectOrder(id: "bbb222")
        let second = ShowOrderViewModel(ordersFeature: feature)
        XCTAssertEqual(first.order?.name, "Amy Apple")
        XCTAssertEqual(second.order?.name, "Bob Battery")
        first.editOrder()
        XCTAssertTrue(first.showsEditor)
        XCTAssertEqual(feature.makeOrderDraft().id, "aaa111")
    }

    @MainActor
    func testExistingDetailsReflectCommittedEditWithoutCopyingFeatureState() async throws {
        let feature = OrdersFeature(repository: ControllableOrdersRepository(orders: [Seeds.Orders.amy]))
        await feature.refresh()
        feature.selectOrder(id: "aaa111")
        let viewModel = ShowOrderViewModel(ordersFeature: feature)
        var updatedOrder = Seeds.Orders.amy
        updatedOrder.firstName = "Amelia"
        _ = try await feature.save(updatedOrder)
        XCTAssertEqual(viewModel.order?.name, "Amelia Apple")
        XCTAssertEqual(viewModel.order?.email, Seeds.Orders.amy.email)
    }
}
