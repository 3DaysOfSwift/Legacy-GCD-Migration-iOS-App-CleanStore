import Foundation
import Observation

@MainActor
@Observable
final class OrdersFeature {
    private(set) var orders: [Order] = []
    private(set) var isRefreshing = false

    // A single-window handoff, not a live binding for an already-open destination.
    // Each destination captures its own record/draft when its ViewModel is created.
    private(set) var selectedOrderID: String?
    private var editingOrderID: String?

    @ObservationIgnored private let repository: any OrdersRepository
    @ObservationIgnored private let currentDate: () -> Date
    @ObservationIgnored private var refreshCompletions: [() -> Void] = []
    @ObservationIgnored private var pendingSaves: [(Order, (Order?) -> Void)] = []
    @ObservationIgnored private var isSaving = false
    @ObservationIgnored private var mutationRevision = 0

    init(repository: any OrdersRepository, currentDate: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.currentDate = currentDate
    }

    func refresh(completion: @escaping () -> Void = {}) {
        refreshCompletions.append(completion)
        guard !isRefreshing else { return }
        isRefreshing = true
        let requestedRevision = mutationRevision
        repository.fetchOrders { [self] fetchedOrders in
            // A delayed read must not undo a save published after it began.
            if requestedRevision == mutationRevision {
                orders = fetchedOrders
            }
            isRefreshing = false
            let completions = refreshCompletions
            refreshCompletions.removeAll()
            completions.forEach { $0() }
        }
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

    /// Every distinct command completes in submission order, even with delayed callbacks.
    /// Storage commits outlive the editor; only its presentation completion may be ignored.
    func save(_ draft: Order, completion: @escaping (Order?) -> Void) {
        pendingSaves.append((draft, completion))
        saveNextOrderIfNeeded()
    }

    private func saveNextOrderIfNeeded() {
        guard !isSaving, !pendingSaves.isEmpty else { return }
        isSaving = true
        let (draft, completion) = pendingSaves.removeFirst()
        let publish: @MainActor (Order?) -> Void = { [self] savedOrder in
            if let savedOrder {
                mutationRevision += 1
                if let index = orders.firstIndex(where: { $0.id == savedOrder.id }) {
                    orders[index] = savedOrder
                } else {
                    orders.append(savedOrder)
                }
            }
            // Keep admission closed while this completion may enqueue another command.
            completion(savedOrder)
            isSaving = false
            saveNextOrderIfNeeded()
        }
        if draft.id == nil {
            repository.createOrder(draft, completion: publish)
        } else {
            repository.updateOrder(draft, completion: publish)
        }
    }
}
