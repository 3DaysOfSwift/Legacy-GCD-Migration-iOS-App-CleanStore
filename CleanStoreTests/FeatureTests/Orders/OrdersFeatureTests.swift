import Foundation
import XCTest
@testable import CleanStore

final class OrdersFeatureTests: XCTestCase {
    @MainActor
    func testConstructionDoesNotLoadAndRefreshesShareCompletionDespiteCallerCancellation() async {
        let repository = ControllableOrdersRepository()
        repository.holdsFetches = true
        defer { repository.releasePendingRequests() }
        let feature = OrdersFeature(repository: repository)
        XCTAssertEqual(repository.fetchCount, 0)
        let started = expectation(description: "Repository read started")
        repository.fetchStarted = { started.fulfill() }
        var completions = 0
        let first = Task { await feature.refresh(); completions += 1 }
        await fulfillment(of: [started], timeout: 2)
        let joined = expectation(description: "Second reader joined")
        let second = Task { joined.fulfill(); await feature.refresh(); completions += 1 }
        await fulfillment(of: [joined], timeout: 2)
        first.cancel()
        XCTAssertEqual(repository.fetchCount, 1)
        XCTAssertTrue(feature.isRefreshing)
        XCTAssertEqual(completions, 0)
        repository.finishFetch(with: [Seeds.Orders.amy])
        await first.value
        await second.value
        XCTAssertFalse(feature.isRefreshing)
        XCTAssertEqual(feature.orders.map(\.id), ["aaa111"])
        XCTAssertEqual(completions, 2)
        repository.holdsFetches = false
        repository.fetchStarted = nil
        await feature.refresh()
        XCTAssertEqual(repository.fetchCount, 2)
    }

    @MainActor
    func testNewDraftUsesInjectedDateWithoutLoadingOrWriting() {
        let repository = ControllableOrdersRepository()
        let date = Date(timeIntervalSince1970: 12345)
        let feature = OrdersFeature(repository: repository, currentDate: { date })
        let draft = feature.makeOrderDraft()
        XCTAssertNil(draft.id)
        XCTAssertEqual(draft.date, date)
        XCTAssertEqual(draft.paymentMethod.expirationDate, date)
        XCTAssertEqual(draft.total, .notANumber)
        XCTAssertEqual(draft.shipmentMethod.speed, .Standard)
        XCTAssertTrue(repository.submittedOrders.isEmpty)
        XCTAssertEqual(repository.fetchCount, 0)
    }

    @MainActor
    func testSavesQueueDistinctInputsAndPublishOnlyCompletedResults() async throws {
        let repository = ControllableOrdersRepository()
        repository.holdsSaves = true
        defer { repository.releasePendingRequests() }
        let feature = OrdersFeature(repository: repository)
        let started = expectation(description: "First save began")
        repository.saveStarted = { started.fulfill() }
        let first = Task { try await feature.save(Seeds.Orders.amy) }
        await fulfillment(of: [started], timeout: 2)
        let admitted = expectation(description: "Second save admitted")
        let second = Task { admitted.fulfill(); return try await feature.save(Seeds.Orders.bob) }
        await fulfillment(of: [admitted], timeout: 2)
        XCTAssertEqual(repository.submittedOrders.count, 1)
        XCTAssertTrue(feature.orders.isEmpty)
        let nextStarted = expectation(description: "Queued save began after predecessor")
        repository.saveStarted = { nextStarted.fulfill() }
        repository.finishSave(with: Seeds.Orders.amy)
        let firstResult = try await first.value
        await fulfillment(of: [nextStarted], timeout: 2)
        XCTAssertEqual(feature.orders.map(\.id), ["aaa111"])
        XCTAssertEqual(repository.submittedOrders.map(\.id), ["aaa111", "bbb222"])
        repository.finishSave(with: Seeds.Orders.bob)
        let secondResult = try await second.value
        XCTAssertEqual(firstResult.id, "aaa111")
        XCTAssertEqual(secondResult.id, "bbb222")
        XCTAssertEqual(feature.orders.map(\.id), ["aaa111", "bbb222"])
    }

    @MainActor
    func testFailedSaveDoesNotPublishOrStrandNextCommand() async throws {
        let repository = ControllableOrdersRepository()
        repository.holdsSaves = true
        defer { repository.releasePendingRequests() }
        let feature = OrdersFeature(repository: repository)
        let started = expectation(description: "First save began")
        repository.saveStarted = { started.fulfill() }
        let first = Task { try await feature.save(Seeds.Orders.amy) }
        await fulfillment(of: [started], timeout: 2)
        let second = Task { try await feature.save(Seeds.Orders.bob) }
        let nextStarted = expectation(description: "Later command proceeds after failure")
        repository.saveStarted = { nextStarted.fulfill() }
        repository.finishSave(with: nil)
        switch await first.result {
        case .success: XCTFail("Failure must reach its caller")
        case .failure: break
        }
        await fulfillment(of: [nextStarted], timeout: 2)
        XCTAssertTrue(feature.orders.isEmpty)
        repository.finishSave(with: Seeds.Orders.bob)
        _ = try await second.value
        XCTAssertNil(feature.saveError)
        XCTAssertEqual(feature.orders.map(\.id), ["bbb222"])
    }

    @MainActor
    func testLateInitialRefreshPreservesUnrelatedOrdersAndNewerEdit() async throws {
        let repository = ControllableOrdersRepository()
        repository.holdsFetches = true
        defer { repository.releasePendingRequests() }
        let feature = OrdersFeature(repository: repository)
        let started = expectation(description: "Initial snapshot requested")
        repository.fetchStarted = { started.fulfill() }
        let read = Task { await feature.refresh() }
        await fulfillment(of: [started], timeout: 2)
        var edited = Seeds.Orders.amy
        edited.firstName = "Updated"
        _ = try await feature.save(edited)
        repository.finishFetch(with: [Seeds.Orders.amy, Seeds.Orders.bob])
        await read.value
        XCTAssertEqual(feature.orders.map(\.firstName), ["Updated", "Bob"])
        XCTAssertFalse(feature.isRefreshing)
    }

    @MainActor
    func testRefreshFailureRetainsOrdersAndRetryClearsError() async {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        await feature.refresh()
        repository.failsNextFetch = true
        await feature.refresh()
        XCTAssertNotNil(feature.refreshError)
        XCTAssertFalse(feature.isRefreshing)
        XCTAssertEqual(feature.orders.map(\.id), ["aaa111"])
        repository.orders = [Seeds.Orders.bob]
        await feature.refresh()
        XCTAssertNil(feature.refreshError)
        XCTAssertEqual(feature.orders.map(\.id), ["bbb222"])
    }

    @MainActor
    func testAdmittedSaveSurvivesCallerCancellation() async throws {
        let repository = ControllableOrdersRepository()
        repository.holdsSaves = true
        defer { repository.releasePendingRequests() }
        let feature = OrdersFeature(repository: repository)
        let started = expectation(description: "Save reached repository")
        repository.saveStarted = { started.fulfill() }
        let caller = Task { try await feature.save(Seeds.Orders.amy) }
        await fulfillment(of: [started], timeout: 2)
        caller.cancel()
        repository.finishSave(with: Seeds.Orders.amy)
        let saved = try await caller.value
        XCTAssertEqual(saved.id, "aaa111")
        XCTAssertEqual(feature.orders.count, 1)
    }

    @MainActor
    func testCancellationBeforeAdmissionDoesNotWriteAndLaterSaveWorks() async throws {
        let repository = ControllableOrdersRepository()
        let feature = OrdersFeature(repository: repository)
        let cancelled = Task { try await feature.save(Seeds.Orders.amy) }
        cancelled.cancel()
        switch await cancelled.result {
        case .success: XCTFail("A pre-cancelled command must not be admitted")
        case .failure(let error): XCTAssertTrue(error is CancellationError)
        }
        XCTAssertTrue(repository.submittedOrders.isEmpty)
        _ = try await feature.save(Seeds.Orders.bob)
        XCTAssertEqual(feature.orders.map(\.id), ["bbb222"])
    }

    @MainActor
    func testSelectionAndDraftPreparationDoNotMutateStoredRecords() async {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        await feature.refresh()
        XCTAssertFalse(feature.selectOrder(id: "absent"))
        XCTAssertTrue(feature.selectOrder(id: "aaa111"))
        XCTAssertTrue(feature.prepareEditingOrder(id: "aaa111"))
        var draft = feature.makeOrderDraft()
        draft.firstName = "Uncommitted"
        XCTAssertEqual(feature.orders.first?.firstName, "Amy")
        XCTAssertEqual(draft.id, "aaa111")
        feature.prepareNewOrder()
        XCTAssertNil(feature.makeOrderDraft().id)
        XCTAssertTrue(repository.submittedOrders.isEmpty)
    }
}
