import Foundation

protocol OrdersRepository: Sendable {
    func fetchOrders() async throws -> [Order]
    func createOrder(_ order: Order) async throws -> Order
    func updateOrder(_ order: Order) async throws -> Order
}
