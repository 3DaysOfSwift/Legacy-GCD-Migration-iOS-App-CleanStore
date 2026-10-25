import Foundation
import Observation

@MainActor
@Observable
final class OrdersFeature {
    private(set) var orders: [Order] = []
    private var refreshTask: Task<Void, Never>?
    var isRefreshing: Bool { refreshTask != nil }
    private(set) var refreshError: (any Error)?
    private(set) var saveError: (any Error)?

    // A single-window handoff, not a live binding for an already-open destination.
    // Each destination captures its own record/draft when its ViewModel is created.
    private(set) var selectedOrderID: String?
    private var editingOrderID: String?

    @ObservationIgnored private let repository: any OrdersRepository
    @ObservationIgnored private let currentDate: () -> Date
    @ObservationIgnored private var saveTail: Task<Order, Error>?
    @ObservationIgnored private var latestSaveID: UUID?
    @ObservationIgnored private var mutationRevision = 0
    @ObservationIgnored private var savedOrderRevisions: [String: Int] = [:]

    init(repository: any OrdersRepository, currentDate: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.currentDate = currentDate
    }

    /// Equivalent reads share completion, independent of any one caller's lifetime.
    /// A cancelled caller may still join a read already in progress, but cannot start one.
    func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        guard !Task.isCancelled else { return }
        let requestedRevision = mutationRevision
        let task = Task { [self] in
            defer { refreshTask = nil }
            refreshError = nil
            do {
                let fetchedOrders = try await repository.fetchOrders()
                // Keep unrelated fetched records, even when a save overtakes the first
                // load. Only records committed since this read began override it.
                var mergedOrders = fetchedOrders
                // Index once rather than scanning the fetched array for every newer save.
                // Preserve the first-match policy even if a legacy snapshot repeats an ID.
                var indicesByID: [String: Int] = [:]
                for (index, order) in fetchedOrders.enumerated() {
                    if let id = order.id, indicesByID[id] == nil {
                        indicesByID[id] = index
                    }
                }
                for savedOrder in orders {
                    guard let id = savedOrder.id,
                          let revision = savedOrderRevisions[id], revision > requestedRevision else { continue }
                    if let index = indicesByID[id] {
                        mergedOrders[index] = savedOrder
                    } else {
                        indicesByID[id] = mergedOrders.count
                        mergedOrders.append(savedOrder)
                    }
                }
                orders = mergedOrders
            } catch {
                refreshError = error
            }
        }
        refreshTask = task
        await task.value
    }

    func order(id: String?) -> Order? {
        guard let id else { return nil }
        return orders.first { $0.id == id }
    }

    @discardableResult
    func selectOrder(id: String?) -> Bool {
        guard let order = order(id: id) else { return false }
        selectedOrderID = order.id
        return true
    }

    func prepareNewOrder() {
        editingOrderID = nil
    }

    @discardableResult
    func prepareEditingOrder(id: String?) -> Bool {
        guard let order = order(id: id) else { return false }
        editingOrderID = order.id
        return true
    }

    func makeOrderDraft() -> Order {
        if let order = order(id: editingOrderID) {
            return order
        }
        let date = currentDate()
        let address = Address(street1: "", street2: "", city: "", state: "", zip: "")
        return Order(
            firstName: "", lastName: "", phone: "", email: "",
            billingAddress: address,
            paymentMethod: PaymentMethod(creditCardNumber: "", expirationDate: date, cvv: ""),
            shipmentAddress: address, shipmentMethod: ShipmentMethod(speed: .Standard),
            id: nil, date: date, total: .notANumber
        )
    }

    var shippingSpeeds: [ShipmentMethod.ShippingSpeed] {
        [.Standard, .OneDay, .TwoDay]
    }

    /// Distinct commands queue across suspension points. Cancellation before admission
    /// rejects a command; once admitted, it commits even if its caller goes away.
    func save(_ draft: Order) async throws -> Order {
        try Task.checkCancellation()
        let predecessor = saveTail
        let requestID = UUID()
        let task = Task { [self] in
            // Failure belongs to the earlier caller, not this later command.
            if let predecessor { _ = await predecessor.result }
            defer {
                if latestSaveID == requestID {
                    saveTail = nil
                    latestSaveID = nil
                }
            }
            saveError = nil
            do {
                let savedOrder: Order
                if draft.id == nil {
                    savedOrder = try await repository.createOrder(draft)
                } else {
                    savedOrder = try await repository.updateOrder(draft)
                }
                mutationRevision += 1
                if let id = savedOrder.id { savedOrderRevisions[id] = mutationRevision }
                if let index = orders.firstIndex(where: { $0.id == savedOrder.id }) {
                    orders[index] = savedOrder
                } else {
                    orders.append(savedOrder)
                }
                return savedOrder
            } catch {
                saveError = error
                throw error
            }
        }
        saveTail = task
        latestSaveID = requestID
        return try await task.value
    }
}
