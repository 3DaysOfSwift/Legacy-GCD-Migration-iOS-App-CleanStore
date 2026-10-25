import CoreData
import XCTest
@testable import CleanStore

final class CoreDataOrdersRepositoryTests: XCTestCase {
    private func temporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanStore-CoreData-Tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Isolated temporary stores are left for the OS to reclaim after all Core Data handles close.
        return directory.appendingPathComponent("CleanStore.sqlite")
    }

    private func modelURL() throws -> URL {
        try XCTUnwrap(Bundle(for: ManagedOrder.self).url(forResource: "CleanStore", withExtension: "momd"))
    }

    private func open(_ url: URL) async throws -> CoreDataOrdersRepository {
        try await CoreDataOrdersRepository.open(at: url, modelURL: modelURL())
    }

    func testCreateUpdateAndDeleteReachDiskBeforeReturning() async throws {
        let url = try temporaryStoreURL()
        let writer = try await open(url)
        var expected = Seeds.Orders.amy
        expected.shipmentMethod.speed = .TwoDay
        expected.shipmentAddress.street2 = nil
        _ = try await writer.createOrder(expected)

        // The writer remains alive: persistence must not depend on deinit or a later parent save.
        let firstReader = try await open(url)
        let id = try XCTUnwrap(expected.id)
        let created = try await firstReader.fetchOrder(id: id)
        assertSnapshot(created, matches: expected)

        expected.email = "updated@example.com"
        expected.date = Date(timeIntervalSince1970: 123456)
        expected.shipmentMethod.speed = .OneDay
        _ = try await writer.updateOrder(expected)
        let secondReader = try await open(url)
        let updated = try await secondReader.fetchOrder(id: id)
        assertSnapshot(updated, matches: expected)

        let deleted = try await writer.deleteOrder(id: id)
        assertSnapshot(deleted, matches: expected)
        let thirdReader = try await open(url)
        let remaining = try await thirdReader.fetchOrders()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testMissingFetchUpdateAndDeleteThrowAndDoNotStrandLaterWrites() async throws {
        let repository = try await open(temporaryStoreURL())
        do {
            _ = try await repository.fetchOrder(id: "missing")
            XCTFail("Missing fetch must throw")
        } catch { XCTAssertEqual(error as? CoreDataOrdersRepository.StorageError, .orderNotFound("missing")) }
        do {
            _ = try await repository.updateOrder(Seeds.Orders.amy)
            XCTFail("Missing update must throw")
        } catch { XCTAssertEqual(error as? CoreDataOrdersRepository.StorageError, .orderNotFound(Seeds.Orders.amy.id)) }
        do {
            _ = try await repository.deleteOrder(id: "missing")
            XCTFail("Missing delete must throw")
        } catch { XCTAssertEqual(error as? CoreDataOrdersRepository.StorageError, .orderNotFound("missing")) }
        var missingID = Seeds.Orders.amy
        missingID.id = nil
        do {
            _ = try await repository.updateOrder(missingID)
            XCTFail("Nil update ID must throw, not crash")
        } catch { XCTAssertEqual(error as? CoreDataOrdersRepository.StorageError, .orderNotFound(nil)) }
        _ = try await repository.createOrder(Seeds.Orders.bob)
        let orders = try await repository.fetchOrders()
        XCTAssertEqual(orders.map(\.id), [Seeds.Orders.bob.id])
    }

    func testGeneratedIDAndTotalPreserveDraftAndRunOffMain() async throws {
        let repository = try await CoreDataOrdersRepository.open(at: temporaryStoreURL(), modelURL: modelURL()) {
            XCTAssertFalse(Thread.isMainThread)
            return "generated"
        }
        var draft = Seeds.Orders.amy
        draft.id = nil
        draft.total = .notANumber
        let saved = try await repository.createOrder(draft)
        draft.id = "generated"
        draft.total = .one
        assertSnapshot(saved, matches: draft)
    }

    func testConcurrentCreatesKeepBothRecordsInIndependentTransactions() async throws {
        let repository = try await open(temporaryStoreURL())
        async let first = repository.createOrder(Seeds.Orders.amy)
        async let second = repository.createOrder(Seeds.Orders.bob)
        _ = try await (first, second)
        let orders = try await repository.fetchOrders()
        XCTAssertEqual(Set(orders.compactMap(\.id)), ["aaa111", "bbb222"])
        XCTAssertEqual(orders.count, 2)
    }

    func testPreCancelledWriteDoesNotMutateStore() async throws {
        let repository = try await open(temporaryStoreURL())
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await repository.createOrder(Seeds.Orders.amy)
        }
        do {
            _ = try await task.value
            XCTFail("Pre-cancelled command must not write")
        } catch { XCTAssertTrue(error is CancellationError) }
        let orders = try await repository.fetchOrders()
        XCTAssertTrue(orders.isEmpty)
    }

    func testOpeningFailureIsReturnedAndCanBeRetried() async throws {
        let url = try temporaryStoreURL()
        // A file where a parent directory is required makes opening fail without touching user data.
        let blockedParent = url.deletingLastPathComponent().appendingPathComponent("blocked")
        try Data("not a directory".utf8).write(to: blockedParent)
        do {
            _ = try await open(blockedParent.appendingPathComponent("CleanStore.sqlite"))
            XCTFail("Invalid location must return an opening error")
        } catch { XCTAssertFalse(error is CancellationError) }
        let repository = try await open(url)
        let orders = try await repository.fetchOrders()
        XCTAssertTrue(orders.isEmpty)
    }

    func testReadsExistingSchemaRecordsWithoutRewritingThem() async throws {
        let url = try temporaryStoreURL()
        let expected = Seeds.Orders.amy
        try await writeLegacyRecord(at: url) { record in record.fromOrder(order: expected) }
        let repository = try await open(url)
        let order = try await repository.fetchOrder(id: XCTUnwrap(expected.id))
        assertSnapshot(order, matches: expected)
        let expectedURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                     appropriateFor: nil, create: false)
            .appendingPathComponent("CleanStore.sqlite")
        XCTAssertEqual(try CoreDataOrdersRepository.defaultStoreURL(), expectedURL)
    }

    func testMalformedRecordReturnsErrorInsteadOfCrashing() async throws {
        let url = try temporaryStoreURL()
        try await writeLegacyRecord(at: url) { record in record.id = "malformed" }
        let repository = try await open(url)
        do {
            _ = try await repository.fetchOrders()
            XCTFail("Missing required domain fields must not become fabricated values")
        } catch { XCTAssertEqual(error as? CoreDataOrdersRepository.StorageError, .invalidRecord("malformed")) }
    }

    private func writeLegacyRecord(at url: URL, populate: @escaping @Sendable (ManagedOrder) -> Void) async throws {
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL()))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try await context.perform {
            XCTAssertFalse(Thread.isMainThread)
            let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                                                          configurationName: nil, at: url, options: nil)
            let entity = try XCTUnwrap(NSEntityDescription.entity(forEntityName: "ManagedOrder", in: context))
            let record = ManagedOrder(entity: entity, insertInto: context)
            populate(record)
            try context.save()
            context.reset()
            try coordinator.remove(store)
        }
    }

    private func assertSnapshot(_ actual: Order, matches expected: Order, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(actual.hasSameSnapshot(as: expected), file: file, line: line)
        // Explicit dates bypass the original one-sided tolerance in Order.==.
        XCTAssertEqual(actual.date, expected.date, file: file, line: line)
        XCTAssertEqual(actual.paymentMethod.expirationDate, expected.paymentMethod.expirationDate, file: file, line: line)
        XCTAssertEqual(actual.shipmentMethod.speed, expected.shipmentMethod.speed, file: file, line: line)
    }
}
