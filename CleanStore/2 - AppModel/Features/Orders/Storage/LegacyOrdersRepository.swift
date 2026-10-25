import Foundation

/// Preserves the live demo's memory-only storage and its main-queue callbacks.
/// Core Data remains an alternative, not a silently substituted live store.
@MainActor
final class LegacyOrdersRepository: OrdersRepository {
    private let ordersWorker: OrdersWorker

    init(ordersWorker: OrdersWorker) {
        self.ordersWorker = ordersWorker
    }

    func fetchOrders(completion: @escaping @MainActor ([Order]) -> Void) {
        ordersWorker.fetchOrders(completionHandler: completion)
    }

    func createOrder(_ order: Order, completion: @escaping @MainActor (Order?) -> Void) {
        ordersWorker.createOrder(orderToCreate: order, completionHandler: completion)
    }

    func updateOrder(_ order: Order, completion: @escaping @MainActor (Order?) -> Void) {
        ordersWorker.updateOrder(orderToUpdate: order, completionHandler: completion)
    }
}
