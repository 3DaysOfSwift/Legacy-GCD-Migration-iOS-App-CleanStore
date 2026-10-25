import Foundation
import Observation

@MainActor
@Observable
final class ListOrdersViewModel {
    private let ordersFeature: OrdersFeature
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    var showsOrder = false
    var showsEditor = false

    init(ordersFeature: OrdersFeature = AppModel.shared.ordersFeature) {
        self.ordersFeature = ordersFeature
    }

    var rows: [OrderPresentation] {
        ordersFeature.orders.map(OrderPresentation.init)
    }

    var isRefreshing: Bool { ordersFeature.isRefreshing }
    var refreshErrorMessage: String? {
        ordersFeature.refreshError == nil ? nil : "Orders could not be loaded. Please try again."
    }

    @discardableResult
    func refresh() -> Task<Void, Never> {
        if let refreshTask { return refreshTask }
        let task = Task { [weak self, ordersFeature] in
            defer { self?.refreshTask = nil }
            await ordersFeature.refresh()
        }
        refreshTask = task
        return task
    }

    func showOrder(id: String?) {
        showsOrder = ordersFeature.selectOrder(id: id)
    }

    func createOrder() {
        ordersFeature.prepareNewOrder()
        showsEditor = true
    }
}
