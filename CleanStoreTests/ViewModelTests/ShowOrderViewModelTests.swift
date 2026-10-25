import XCTest
@testable import CleanStore

final class ShowOrderViewModelTests: XCTestCase {
    @MainActor
    func testOpenDetailsKeepTheirIdentityWhenAnotherOrderIsSelected() {
        let feature = OrdersFeature(repository: ControllableOrdersRepository(
            orders: [Seeds.Orders.amy, Seeds.Orders.bob]
        ))
        feature.refresh()
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
    func testExistingDetailsReflectCommittedEditWithoutCopyingFeatureState() {
        let feature = OrdersFeature(repository: ControllableOrdersRepository(orders: [Seeds.Orders.amy]))
        feature.refresh()
        feature.selectOrder(id: "aaa111")
        let viewModel = ShowOrderViewModel(ordersFeature: feature)
        var updatedOrder = Seeds.Orders.amy
        updatedOrder.firstName = "Amelia"
        feature.save(updatedOrder) { _ in }
        XCTAssertEqual(viewModel.order?.name, "Amelia Apple")
        XCTAssertEqual(viewModel.order?.email, Seeds.Orders.amy.email)
    }
}
