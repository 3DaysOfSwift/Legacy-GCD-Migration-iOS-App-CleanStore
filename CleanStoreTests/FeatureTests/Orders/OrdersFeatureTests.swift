import Foundation
import XCTest
@testable import CleanStore

final class OrdersFeatureTests: XCTestCase {
    @MainActor
    func testConstructionDoesNotLoadAndRefreshesShareCompletion() {
        let repository = ControllableOrdersRepository()
        repository.holdsFetches = true
        let feature = OrdersFeature(repository: repository)
        XCTAssertEqual(repository.fetchCount, 0)
        var completions = 0
        feature.refresh { completions += 1 }
        feature.refresh { completions += 1 }
        XCTAssertEqual(repository.fetchCount, 1)
        XCTAssertTrue(feature.isRefreshing)
        XCTAssertEqual(completions, 0)

        repository.finishFetch(with: [Seeds.Orders.amy])
        XCTAssertFalse(feature.isRefreshing)
        XCTAssertEqual(feature.orders.map(\.id), ["aaa111"])
        XCTAssertEqual(completions, 2)
        feature.refresh()
        XCTAssertEqual(repository.fetchCount, 2)
        repository.finishFetch(with: [])
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
    func testSavesQueueDistinctInputsAndPublishOnlyCompletedResults() {
        let repository = ControllableOrdersRepository()
        repository.holdsSaves = true
        let feature = OrdersFeature(repository: repository)
        var completionIDs: [String?] = []
        feature.save(Seeds.Orders.amy) { completionIDs.append($0?.id) }
        feature.save(Seeds.Orders.bob) { completionIDs.append($0?.id) }
        XCTAssertEqual(repository.submittedOrders.count, 1)
        XCTAssertTrue(feature.orders.isEmpty)

        repository.finishSave(with: Seeds.Orders.amy)
        XCTAssertEqual(feature.orders.map(\.id), ["aaa111"])
        XCTAssertEqual(repository.submittedOrders.map(\.id), ["aaa111", "bbb222"])
        repository.finishSave(with: Seeds.Orders.bob)
        XCTAssertEqual(feature.orders.map(\.id), ["aaa111", "bbb222"])
        XCTAssertEqual(completionIDs, ["aaa111", "bbb222"])
    }

    @MainActor
    func testFailedSaveDoesNotPublishOrStrandNextCommand() {
        let repository = ControllableOrdersRepository()
        repository.holdsSaves = true
        let feature = OrdersFeature(repository: repository)
        var didFail = false
        feature.save(Seeds.Orders.amy) { didFail = $0 == nil }
        feature.save(Seeds.Orders.bob) { _ in }
        repository.finishSave(with: nil)
        XCTAssertTrue(didFail)
        XCTAssertTrue(feature.orders.isEmpty)
        XCTAssertEqual(repository.submittedOrders.count, 2)
        repository.finishSave(with: Seeds.Orders.bob)
        XCTAssertEqual(feature.orders.map(\.id), ["bbb222"])
    }

    @MainActor
    func testLateRefreshCannotOverwriteAnEditedOrder() {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        feature.refresh()
        repository.holdsFetches = true
        feature.refresh()
        var edited = Seeds.Orders.amy
        edited.firstName = "Updated"
        feature.save(edited) { _ in }
        repository.finishFetch(with: [Seeds.Orders.amy])
        XCTAssertEqual(feature.orders.first?.firstName, "Updated")
        XCTAssertEqual(feature.orders.count, 1)
        XCTAssertFalse(feature.isRefreshing)
    }

    @MainActor
    func testSelectionAndDraftPreparationDoNotMutateStoredRecords() {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        feature.refresh()
        XCTAssertFalse(feature.selectOrder(id: "absent"))
        XCTAssertTrue(feature.selectOrder(id: "aaa111"))
        XCTAssertTrue(feature.prepareEditingOrder(id: "aaa111"))
        var draft = feature.makeOrderDraft()
        draft.firstName = "Uncommitted"
        XCTAssertEqual(feature.orders.first?.firstName, "Amy")
        XCTAssertEqual(draft.id, "aaa111")
        XCTAssertEqual(draft.date, Seeds.Orders.amy.date)
        feature.prepareNewOrder()
        XCTAssertNil(feature.makeOrderDraft().id)
        XCTAssertTrue(repository.submittedOrders.isEmpty)
    }
}
