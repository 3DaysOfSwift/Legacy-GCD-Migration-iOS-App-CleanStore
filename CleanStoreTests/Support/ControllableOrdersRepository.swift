import Foundation
@testable import CleanStore

/// Test controls stay on MainActor. Production uses a separate storage actor.
@MainActor
final class ControllableOrdersRepository: OrdersRepository {
    enum Failure: Error { case unavailable }
    var orders: [Order]
    var holdsFetches = false
    var holdsSaves = false
    var failsNextFetch = false
    var failsNextSave = false
    var fetchStarted: (() -> Void)?
    var saveStarted: (() -> Void)?
    private(set) var fetchCount = 0
    private(set) var submittedOrders: [Order] = []
    private var fetchContinuations: [CheckedContinuation<[Order], Error>] = []
    private var saveContinuations: [CheckedContinuation<Order, Error>] = []

    init(orders: [Order] = []) { self.orders = orders }

    func fetchOrders() async throws -> [Order] {
        fetchCount += 1
        if holdsFetches {
            return try await withCheckedThrowingContinuation { continuation in
                fetchContinuations.append(continuation)
                fetchStarted?()
            }
        }
        fetchStarted?()
        if failsNextFetch {
            failsNextFetch = false
            throw Failure.unavailable
        }
        return orders
    }

    func createOrder(_ order: Order) async throws -> Order { try await submit(order) }
    func updateOrder(_ order: Order) async throws -> Order { try await submit(order) }

    private func submit(_ order: Order) async throws -> Order {
        submittedOrders.append(order)
        if holdsSaves {
            return try await withCheckedThrowingContinuation { continuation in
                saveContinuations.append(continuation)
                saveStarted?()
            }
        }
        saveStarted?()
        if failsNextSave {
            failsNextSave = false
            throw Failure.unavailable
        }
        var saved = order
        if saved.id == nil { saved.id = "created-\(submittedOrders.count)" }
        if saved.total == .notANumber { saved.total = .one }
        return saved
    }

    func finishFetch(with orders: [Order]) {
        let continuations = fetchContinuations
        fetchContinuations.removeAll()
        continuations.forEach { $0.resume(returning: orders) }
    }

    func finishSave(with order: Order?) {
        guard !saveContinuations.isEmpty else { return }
        let continuation = saveContinuations.removeFirst()
        if let order { continuation.resume(returning: order) }
        else { continuation.resume(throwing: Failure.unavailable) }
    }

    /// Release suspended requests even when a test expectation fails.
    func releasePendingRequests() {
        holdsFetches = false
        holdsSaves = false
        let fetches = fetchContinuations
        let saves = saveContinuations
        fetchContinuations.removeAll()
        saveContinuations.removeAll()
        fetches.forEach { $0.resume(throwing: CancellationError()) }
        saves.forEach { $0.resume(throwing: CancellationError()) }
    }
}
