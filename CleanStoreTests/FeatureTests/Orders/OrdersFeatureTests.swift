import Foundation
import XCTest
@testable import CleanStore

final class OrdersFeatureTests: XCTestCase {
    @MainActor
    func testPreCancelledRefreshDoesNotStartReadAndLaterRefreshWorks() async {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        // This task cannot enter MainActor until this synchronous turn suspends.
        let cancelled = Task { await feature.refresh() }
        cancelled.cancel()
        await cancelled.value
        XCTAssertEqual(repository.fetchCount, 0)
        XCTAssertFalse(feature.isRefreshing)
        XCTAssertNil(feature.refreshError)
        await feature.refresh()
        XCTAssertEqual(repository.fetchCount, 1)
        XCTAssertEqual(feature.orders.map(\.id), ["aaa111"])
    }

    @MainActor
    func testSharedReadFailureReleasesAllWaitersAndAllowsRetry() async {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        await feature.refresh()
        repository.holdsFetches = true
        defer { repository.releasePendingRequests() }
        let started = expectation(description: "Shared refresh started")
        repository.fetchStarted = { started.fulfill() }
        let first = Task { await feature.refresh() }
        await fulfillment(of: [started], timeout: 2)
        guard repository.fetchCount == 2 else {
            XCTFail("Unexpected repository request count before completing the suspended operation")
            return
        }
        let joined = expectation(description: "Cancelled reader joined existing refresh")
        var secondCompleted = false
        let second = Task {
            joined.fulfill()
            await feature.refresh()
            secondCompleted = true
        }
        second.cancel()
        await fulfillment(of: [joined], timeout: 2)
        XCTAssertTrue(feature.isRefreshing)
        XCTAssertFalse(secondCompleted)
        XCTAssertEqual(repository.fetchCount, 2)
        repository.failFetch()
        await first.value
        await second.value
        XCTAssertTrue(secondCompleted)
        XCTAssertFalse(feature.isRefreshing)
        XCTAssertNotNil(feature.refreshError)
        XCTAssertEqual(feature.orders.map(\.id), ["aaa111"])
        repository.holdsFetches = false
        repository.fetchStarted = nil
        repository.orders = [Seeds.Orders.bob]
        await feature.refresh()
        XCTAssertEqual(repository.fetchCount, 3)
        XCTAssertNil(feature.refreshError)
        XCTAssertEqual(feature.orders.map(\.id), ["bbb222"])
    }

    @MainActor
    func testQueuedSaveSurvivesCancellationBeforeItsRepositoryCall() async throws {
        let repository = ControllableOrdersRepository()
        repository.holdsSaves = true
        defer { repository.releasePendingRequests() }
        let feature = OrdersFeature(repository: repository)
        let started = expectation(description: "First write is suspended")
        repository.saveStarted = { started.fulfill() }
        let first = Task { try await feature.save(Seeds.Orders.amy) }
        await fulfillment(of: [started], timeout: 2)
        guard repository.submittedOrders.count == 1 else {
            XCTFail("Unexpected repository request count before completing the suspended operation")
            return
        }
        let admitted = expectation(description: "Second command enters feature")
        let second = Task {
            admitted.fulfill()
            // Feature admission has no suspension before retaining its own task.
            return try await feature.save(Seeds.Orders.bob)
        }
        await fulfillment(of: [admitted], timeout: 2)
        second.cancel()
        XCTAssertEqual(repository.submittedOrders.count, 1)
        let nextStarted = expectation(description: "Cancelled caller's queued write still starts")
        repository.saveStarted = { nextStarted.fulfill() }
        repository.finishSave(with: Seeds.Orders.amy)
        _ = try await first.value
        await fulfillment(of: [nextStarted], timeout: 2)
        guard repository.submittedOrders.count == 2 else {
            XCTFail("Unexpected repository request count before completing the suspended operation")
            return
        }
        repository.finishSave(with: Seeds.Orders.bob)
        let result = try await second.value
        XCTAssertEqual(result.id, "bbb222")
        XCTAssertEqual(feature.orders.map(\.id), ["aaa111", "bbb222"])
        repository.holdsSaves = false
        repository.saveStarted = nil
        var edited = Seeds.Orders.amy
        edited.firstName = "Later edit"
        _ = try await feature.save(edited)
        XCTAssertEqual(repository.submittedOrders.count, 3)
        XCTAssertEqual(feature.orders.first?.firstName, "Later edit")
    }

    @MainActor
    func testLateRefreshKeepsLatestOfRepeatedSavesAndAppendsNewRecord() async throws {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        await feature.refresh()
        repository.holdsFetches = true
        defer { repository.releasePendingRequests() }
        let started = expectation(description: "Old snapshot requested")
        repository.fetchStarted = { started.fulfill() }
        let read = Task { await feature.refresh() }
        await fulfillment(of: [started], timeout: 2)
        guard repository.fetchCount == 2 else {
            XCTFail("Unexpected repository request count before completing the suspended operation")
            return
        }
        var edited = Seeds.Orders.amy
        edited.firstName = "First edit"
        _ = try await feature.save(edited)
        edited.firstName = "Latest edit"
        _ = try await feature.save(edited)
        _ = try await feature.save(Seeds.Orders.bob)
        repository.finishFetch(with: [Seeds.Orders.amy])
        await read.value
        XCTAssertEqual(feature.orders.map(\.id), ["aaa111", "bbb222"])
        XCTAssertEqual(feature.orders.map(\.firstName), ["Latest edit", "Bob"])
    }

    @MainActor
    func testRefreshMergePreservesLegacyDuplicateAndMissingIDsWithoutTrapping() async throws {
        let repository = ControllableOrdersRepository()
        repository.holdsFetches = true
        defer { repository.releasePendingRequests() }
        let feature = OrdersFeature(repository: repository)
        let started = expectation(description: "Legacy snapshot requested")
        repository.fetchStarted = { started.fulfill() }
        let read = Task { await feature.refresh() }
        await fulfillment(of: [started], timeout: 2)
        guard repository.fetchCount == 1 else {
            XCTFail("Unexpected repository request count before completing the suspended operation")
            return
        }
        var edited = Seeds.Orders.amy
        edited.firstName = "Updated"
        _ = try await feature.save(edited)
        var missingID = Seeds.Orders.bob
        missingID.id = nil
        repository.finishFetch(with: [Seeds.Orders.amy, Seeds.Orders.amy, missingID])
        await read.value
        XCTAssertEqual(feature.orders.map(\.firstName), ["Updated", "Amy", "Bob"])
        XCTAssertNil(feature.orders.last?.id)
    }

    @MainActor
    func testRefreshFinishingBeforePendingSaveDoesNotPublishUncommittedDraft() async throws {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        await feature.refresh()
        repository.holdsSaves = true
        defer { repository.releasePendingRequests() }
        let started = expectation(description: "Write suspended before commit")
        repository.saveStarted = { started.fulfill() }
        var edited = Seeds.Orders.amy
        edited.firstName = "Committed later"
        let savedDraft = edited
        let save = Task { try await feature.save(savedDraft) }
        await fulfillment(of: [started], timeout: 2)
        guard repository.submittedOrders.count == 1 else {
            XCTFail("Unexpected repository request count before completing the suspended operation")
            return
        }
        await feature.refresh()
        XCTAssertEqual(feature.orders.first?.firstName, "Amy")
        repository.finishSave(with: savedDraft)
        _ = try await save.value
        XCTAssertEqual(feature.orders.first?.firstName, "Committed later")
    }

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
