import Foundation
import Observation

@MainActor
@Observable
final class ListOrdersViewModel {
    private let ordersFeature: OrdersFeature
    var showsOrder = false
    var showsEditor = false

    init(ordersFeature: OrdersFeature = AppModel.shared.ordersFeature) {
        self.ordersFeature = ordersFeature
    }

    var rows: [OrderPresentation] {
        ordersFeature.orders.map(OrderPresentation.init)
    }

    func refresh() {
        ordersFeature.refresh()
    }

    func showOrder(id: String?) {
        showsOrder = ordersFeature.selectOrder(id: id)
    }

    func createOrder() {
        ordersFeature.prepareNewOrder()
        showsEditor = true
    }
}
