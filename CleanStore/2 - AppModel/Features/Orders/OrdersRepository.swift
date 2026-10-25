import Foundation

// Temporary callback boundary for the architecture checkpoint.
// The next checkpoint converts this boundary, not the Views, to async operations.
@MainActor
protocol OrdersRepository {
    func fetchOrders(completion: @escaping @MainActor ([Order]) -> Void)
    func createOrder(_ order: Order, completion: @escaping @MainActor (Order?) -> Void)
    func updateOrder(_ order: Order, completion: @escaping @MainActor (Order?) -> Void)
}
