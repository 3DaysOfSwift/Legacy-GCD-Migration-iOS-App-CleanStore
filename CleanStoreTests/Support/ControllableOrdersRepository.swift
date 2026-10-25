import Foundation
@testable import CleanStore

@MainActor
final class ControllableOrdersRepository: OrdersRepository {
    var orders: [Order]
    var holdsFetches = false
    var holdsSaves = false
    var failsNextSave = false
    private(set) var fetchCount = 0
    private(set) var submittedOrders: [Order] = []
    private var fetchCompletions: [@MainActor ([Order]) -> Void] = []
    private var saveCompletions: [@MainActor (Order?) -> Void] = []

    init(orders: [Order] = []) {
        self.orders = orders
    }

    func fetchOrders(completion: @escaping @MainActor ([Order]) -> Void) {
        fetchCount += 1
        if holdsFetches {
            fetchCompletions.append(completion)
        } else {
            completion(orders)
        }
    }

    func createOrder(_ order: Order, completion: @escaping @MainActor (Order?) -> Void) {
        submit(order, completion: completion)
    }

    func updateOrder(_ order: Order, completion: @escaping @MainActor (Order?) -> Void) {
        submit(order, completion: completion)
    }

    private func submit(_ order: Order, completion: @escaping @MainActor (Order?) -> Void) {
        submittedOrders.append(order)
        if holdsSaves {
            saveCompletions.append(completion)
        } else if failsNextSave {
            failsNextSave = false
            completion(nil)
        } else {
            completion(order)
        }
    }

    func finishFetch(with orders: [Order]) {
        let completions = fetchCompletions
        fetchCompletions.removeAll()
        completions.forEach { $0(orders) }
    }

    func finishSave(with order: Order?) {
        guard !saveCompletions.isEmpty else { return }
        saveCompletions.removeFirst()(order)
    }
}
