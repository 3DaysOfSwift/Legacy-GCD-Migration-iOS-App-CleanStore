import Foundation
import Observation

@MainActor
@Observable
final class ShowOrderViewModel {
    private let ordersFeature: OrdersFeature
    private let orderID: String?
    var showsEditor = false

    init(ordersFeature: OrdersFeature = AppModel.shared.ordersFeature) {
        self.ordersFeature = ordersFeature
        self.orderID = ordersFeature.selectedOrderID
    }

    var order: OrderPresentation? {
        ordersFeature.order(id: orderID).map(OrderPresentation.init)
    }

    func editOrder() {
        showsEditor = ordersFeature.prepareEditingOrder(id: orderID)
    }
}
