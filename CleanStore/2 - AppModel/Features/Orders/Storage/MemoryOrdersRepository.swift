import Foundation

/// Process-only storage. Each application/test graph owns an independent actor.
/// No method suspends between reading and mutating its collection.
actor MemoryOrdersRepository: OrdersRepository {
    enum StorageError: Error, Equatable {
        case orderNotFound(String?)
    }

    private var orders: [Order]
    private let makeOrderID: @Sendable () -> String

    init(orders: [Order], makeOrderID: @escaping @Sendable () -> String = { String(UInt32.random(in: .min ... .max)) }) {
        self.orders = orders
        self.makeOrderID = makeOrderID
    }

    func fetchOrders() throws -> [Order] {
        try Task.checkCancellation()
        return orders
    }

    func createOrder(_ draft: Order) throws -> Order {
        try Task.checkCancellation()
        var order = draft
        if order.id == nil { order.id = makeOrderID() }
        if order.total == .notANumber { order.total = .one }
        orders.append(order)
        return order
    }

    func updateOrder(_ order: Order) throws -> Order {
        try Task.checkCancellation()
        guard let index = orders.firstIndex(where: { $0.id == order.id }) else {
            throw StorageError.orderNotFound(order.id)
        }
        orders[index] = order
        return order
    }

    /// Preserve the original sample records without consulting its mutable static store.
    static func demoOrders(at date: Date) -> [Order] {
        let billing = Address(street1: "1 Infinite Loop", street2: "", city: "Cupertino", state: "CA", zip: "95014")
        let shipping = Address(street1: "One Microsoft Way", street2: "", city: "Redmond", state: "WA", zip: "98052-7329")
        let payment = PaymentMethod(creditCardNumber: "1234-123456-1234", expirationDate: date, cvv: "999")
        let method = ShipmentMethod(speed: .OneDay)
        return [
            Order(firstName: "Amy", lastName: "Apple", phone: "111-111-1111", email: "amy.apple@clean-swift.com",
                  billingAddress: billing, paymentMethod: payment, shipmentAddress: shipping, shipmentMethod: method,
                  id: "abc123", date: date, total: NSDecimalNumber(string: "1.23")),
            Order(firstName: "Bob", lastName: "Battery", phone: "222-222-2222", email: "bob.battery@clean-swift.com",
                  billingAddress: billing, paymentMethod: payment, shipmentAddress: shipping, shipmentMethod: method,
                  id: "def456", date: date, total: NSDecimalNumber(string: "4.56"))
        ]
    }
}
