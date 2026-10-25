import Foundation
import XCTest
@testable import CleanStore

final class MemoryOrdersRepositoryTests: XCTestCase {
    func testDemoSeedsAndSeparateInstancesPreserveProcessOnlyLifetime() async throws {
        let date = Date(timeIntervalSince1970: 12345)
        let seeds = MemoryOrdersRepository.demoOrders(at: date)
        let first = MemoryOrdersRepository(orders: seeds)
        let second = MemoryOrdersRepository(orders: seeds)
        var edited = seeds[0]
        edited.firstName = "Changed"
        _ = try await first.updateOrder(edited)
        let firstOrders = try await first.fetchOrders()
        let secondOrders = try await second.fetchOrders()
        XCTAssertEqual(firstOrders.map(\.firstName), ["Changed", "Bob"])
        XCTAssertEqual(secondOrders.map(\.firstName), ["Amy", "Bob"])
        XCTAssertEqual(secondOrders.map(\.id), ["abc123", "def456"])
        XCTAssertEqual(secondOrders.first?.date, date)
    }

    func testCreateGeneratesIDAndPlaceholderTotalOffMainWithoutChangingOtherFields() async throws {
        let repository = MemoryOrdersRepository(orders: []) {
            XCTAssertFalse(Thread.isMainThread)
            return "generated-order"
        }
        var draft = Seeds.Orders.amy
        draft.id = nil
        draft.total = .notANumber
        let saved = try await repository.createOrder(draft)
        XCTAssertEqual(saved.id, "generated-order")
        XCTAssertEqual(saved.total, .one)
        XCTAssertEqual(saved.date, draft.date)
        XCTAssertEqual(saved.email, draft.email)
        XCTAssertEqual(saved.paymentMethod.expirationDate, draft.paymentMethod.expirationDate)
        let fetched = try await repository.fetchOrders()
        XCTAssertEqual(fetched.map(\.id), ["generated-order"])
    }

    func testUpdateReplacesOnlyItsRecordWithoutChangingOrder() async throws {
        let repository = MemoryOrdersRepository(orders: [Seeds.Orders.amy, Seeds.Orders.bob])
        var edited = Seeds.Orders.amy
        edited.email = "synthetic@example.com"
        _ = try await repository.updateOrder(edited)
        let orders = try await repository.fetchOrders()
        XCTAssertEqual(orders.map(\.id), ["aaa111", "bbb222"])
        XCTAssertEqual(orders.first?.email, "synthetic@example.com")
        XCTAssertEqual(orders.last?.email, Seeds.Orders.bob.email)
        XCTAssertEqual(orders.first?.total, Seeds.Orders.amy.total)
    }

    func testMissingUpdateThrowsAndLeavesExistingOrdersUntouched() async throws {
        let repository = MemoryOrdersRepository(orders: [Seeds.Orders.amy])
        do {
            _ = try await repository.updateOrder(Seeds.Orders.bob)
            XCTFail("Unknown ID must fail, not insert")
        } catch {
            XCTAssertEqual(error as? MemoryOrdersRepository.StorageError, .orderNotFound("bbb222"))
        }
        let orders = try await repository.fetchOrders()
        XCTAssertEqual(orders.map(\.id), ["aaa111"])
    }

    func testConcurrentCreatesRetainBothRecords() async throws {
        let repository = MemoryOrdersRepository(orders: [])
        async let first = repository.createOrder(Seeds.Orders.amy)
        async let second = repository.createOrder(Seeds.Orders.bob)
        _ = try await (first, second)
        let orders = try await repository.fetchOrders()
        XCTAssertEqual(Set(orders.compactMap(\.id)), ["aaa111", "bbb222"])
        XCTAssertEqual(orders.count, 2)
    }
}
