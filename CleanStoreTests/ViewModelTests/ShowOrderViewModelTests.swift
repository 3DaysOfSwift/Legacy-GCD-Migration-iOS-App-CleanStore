import XCTest
@testable import CleanStore

final class ShowOrderViewModelTests: XCTestCase {
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
