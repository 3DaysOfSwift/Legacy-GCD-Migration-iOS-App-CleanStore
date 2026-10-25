import CoreData
import Foundation

/// Optional durable storage; the live app deliberately still uses MemoryOrdersRepository.
/// Managed objects never leave the private context's queue. Only Order values cross it.
actor CoreDataOrdersRepository: OrdersRepository {
    enum StorageError: Error, Equatable {
        case modelUnavailable
        case orderNotFound(String?)
        case invalidRecord(String?)
    }

    private let context: NSManagedObjectContext
    private let makeOrderID: @Sendable () -> String

    private init(context: NSManagedObjectContext, makeOrderID: @escaping @Sendable () -> String) {
        self.context = context
        self.makeOrderID = makeOrderID
    }

    /// Preserve the original alternative store's location. Opening is explicit, not an init side effect.
    static func defaultStoreURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: false)
            .appendingPathComponent("CleanStore.sqlite")
    }

    static func open(at storeURL: URL, modelURL: URL,
                     makeOrderID: @escaping @Sendable () -> String = { String(UInt32.random(in: .min ... .max)) }) async throws -> CoreDataOrdersRepository {
        try Task.checkCancellation()
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            throw StorageError.modelUnavailable
        }
        let container = NSPersistentContainer(name: "CleanStore", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldAddStoreAsynchronously = true
        description.shouldMigrateStoreAutomatically = false
        description.shouldInferMappingModelAutomatically = false
        container.persistentStoreDescriptions = [description]

        // This framework API has no async overload. Exactly one description means one completion.
        // Cancellation cannot interrupt opening; await its result before acknowledging cancellation.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
        try Task.checkCancellation()
        let context = container.newBackgroundContext()
        context.undoManager = nil
        return CoreDataOrdersRepository(context: context, makeOrderID: makeOrderID)
    }

    func fetchOrders() async throws -> [Order] {
        try Task.checkCancellation()
        let context = context
        return try await context.perform(schedule: .enqueued) {
            try context.fetch(ManagedOrder.fetchRequest()).map { try $0.storedOrder() }
        }
    }

    func fetchOrder(id: String) async throws -> Order {
        try Task.checkCancellation()
        let context = context
        return try await context.perform(schedule: .enqueued) {
            try Self.record(id: id, in: context).storedOrder()
        }
    }

    func createOrder(_ draft: Order) async throws -> Order {
        try Task.checkCancellation()
        var order = draft
        if order.id == nil { order.id = makeOrderID() }
        if order.total == .notANumber { order.total = .one }
        let savedOrder = order
        return try await write { context in
            guard let entity = NSEntityDescription.entity(forEntityName: "ManagedOrder", in: context) else {
                throw StorageError.modelUnavailable
            }
            let record = ManagedOrder(entity: entity, insertInto: context)
            record.fromOrder(order: savedOrder)
            return try record.storedOrder()
        }
    }

    func updateOrder(_ order: Order) async throws -> Order {
        try await write { context in
            let record = try Self.record(id: order.id, in: context)
            record.fromOrder(order: order)
            return try record.storedOrder()
        }
    }

    func deleteOrder(id: String) async throws -> Order {
        try await write { context in
            let record = try Self.record(id: id, in: context)
            let order = try record.storedOrder()
            context.delete(record)
            return order
        }
    }

    private func write(_ change: @escaping @Sendable (NSManagedObjectContext) throws -> Order) async throws -> Order {
        try Task.checkCancellation()
        let context = context
        // One enqueued block contains the whole transaction, with no suspension between mutation and save.
        // Once enqueued, report the real commit outcome even if the waiting caller is cancelled.
        return try await context.perform(schedule: .enqueued) {
            do {
                let order = try change(context)
                try context.save() // Direct coordinator-backed context: no deferred parent/deinit save.
                return order
            } catch {
                context.rollback()
                throw error
            }
        }
    }

    private static func record(id: String?, in context: NSManagedObjectContext) throws -> ManagedOrder {
        guard let id else { throw StorageError.orderNotFound(nil) }
        let request = ManagedOrder.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        guard let record = try context.fetch(request).first else {
            throw StorageError.orderNotFound(id)
        }
        return record
    }
}

private extension ManagedOrder {
    /// Keep the existing schema, but reject malformed required values instead of force-unwrapping.
    func storedOrder() throws -> Order {
        guard let firstName, let lastName, let phone, let email, let date, let total,
              let billingAddressStreet1, let billingAddressCity, let billingAddressState, let billingAddressZIP,
              let shipmentAddressStreet1, let shipmentAddressCity, let shipmentAddressState, let shipmentAddressZIP,
              let paymentMethodCreditCardNumber, let paymentMethodExpirationDate, let paymentMethodCVV,
              let shipmentMethodSpeed,
              let speed = ShipmentMethod.ShippingSpeed(rawValue: shipmentMethodSpeed.intValue) else {
            throw CoreDataOrdersRepository.StorageError.invalidRecord(id)
        }
        return Order(firstName: firstName, lastName: lastName, phone: phone, email: email,
                     billingAddress: Address(street1: billingAddressStreet1, street2: billingAddressStreet2,
                                             city: billingAddressCity, state: billingAddressState, zip: billingAddressZIP),
                     paymentMethod: PaymentMethod(creditCardNumber: paymentMethodCreditCardNumber,
                                                 expirationDate: paymentMethodExpirationDate, cvv: paymentMethodCVV),
                     shipmentAddress: Address(street1: shipmentAddressStreet1, street2: shipmentAddressStreet2,
                                              city: shipmentAddressCity, state: shipmentAddressState, zip: shipmentAddressZIP),
                     shipmentMethod: ShipmentMethod(speed: speed), id: id, date: date, total: total)
    }
}
