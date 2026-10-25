import Foundation
import XCTest
@testable import CleanStore

final class CreateOrderViewModelTests: XCTestCase {
    @MainActor
    func testEditingLoadsEveryFieldAndFormatsExistingPickerValues() async throws {
        let expected = Seeds.Orders.amy
        let feature = OrdersFeature(repository: ControllableOrdersRepository(orders: [expected]))
        await feature.refresh()
        feature.prepareEditingOrder(id: expected.id)
        let viewModel = CreateOrderViewModel(ordersFeature: feature)
        XCTAssertTrue(viewModel.draft.hasSameSnapshot(as: expected))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        XCTAssertEqual(viewModel.expirationDateText, formatter.string(from: expected.paymentMethod.expirationDate))
        XCTAssertEqual(viewModel.shippingSpeedText, "Standard Shipping")
        for (speed, title) in [(ShipmentMethod.ShippingSpeed.Standard, "Standard Shipping"), (.OneDay, "One-Day Shipping"), (.TwoDay, "Two-Day Shipping")] {
            viewModel.selectShippingSpeed(speed)
            XCTAssertEqual(viewModel.draft.shipmentMethod.speed, speed)
            XCTAssertEqual(viewModel.shippingSpeedText, title)
        }
        let changedDate = Date(timeIntervalSince1970: 123456789)
        viewModel.selectExpirationDate(changedDate)
        XCTAssertEqual(viewModel.expirationDateText, formatter.string(from: changedDate))
    }

    @MainActor
    func testFailedEditRetainsAllFieldsAndRetryUpdatesWithoutInserting() async throws {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        await feature.refresh()
        feature.prepareEditingOrder(id: "aaa111")
        let viewModel = CreateOrderViewModel(ordersFeature: feature)
        viewModel.draft.email = "retry@example.com"
        let edited = viewModel.draft
        repository.failsNextSave = true
        await viewModel.save()?.value
        XCTAssertEqual(viewModel.failureTitle, "Failed to update order")
        XCTAssertTrue(viewModel.showsSaveError)
        XCTAssertFalse(viewModel.didSave)
        XCTAssertTrue(viewModel.draft.hasSameSnapshot(as: edited))
        XCTAssertTrue(try XCTUnwrap(feature.orders.first).hasSameSnapshot(as: Seeds.Orders.amy))
        await viewModel.save()?.value
        XCTAssertTrue(viewModel.didSave)
        XCTAssertFalse(viewModel.showsSaveError)
        XCTAssertEqual(feature.orders.count, 1)
        XCTAssertTrue(try XCTUnwrap(feature.orders.first).hasSameSnapshot(as: edited))
    }

    @MainActor
    func testBlankFormRemainsSaveableWithoutInventingValidation() async throws {
        let repository = MemoryOrdersRepository(orders: [], makeOrderID: { "blank-order" })
        let feature = OrdersFeature(repository: repository)
        let viewModel = CreateOrderViewModel(ordersFeature: feature)
        await viewModel.save()?.value
        XCTAssertTrue(viewModel.didSave)
        let saved = try XCTUnwrap(feature.orders.first)
        XCTAssertEqual(saved.id, "blank-order")
        XCTAssertEqual(saved.total, .one)
        XCTAssertEqual(saved.email, "")
        XCTAssertEqual(saved.paymentMethod.creditCardNumber, "")
    }
    @MainActor
    func testIdenticalTextFieldWritebackDuringSaveStillCompletesEditor() async {
        let repository = ControllableOrdersRepository()
        repository.holdsSaves = true
        defer { repository.releasePendingRequests() }
        let started = expectation(description: "Save began")
        repository.saveStarted = { started.fulfill() }
        let viewModel = CreateOrderViewModel(ordersFeature: OrdersFeature(repository: repository))
        viewModel.draft.firstName = "Demo"
        let save = viewModel.save()
        await fulfillment(of: [started], timeout: 2)
        let sameDraft = viewModel.draft
        viewModel.draft = sameDraft
        repository.finishSave(with: Seeds.Orders.amy)
        await save?.value
        XCTAssertTrue(viewModel.didSave)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertEqual(repository.submittedOrders.count, 1)
    }

    @MainActor
    func testChangedDateIsNotMistakenForIdenticalWriteback() async {
        let repository = ControllableOrdersRepository()
        repository.holdsSaves = true
        defer { repository.releasePendingRequests() }
        let started = expectation(description: "Save began")
        repository.saveStarted = { started.fulfill() }
        let viewModel = CreateOrderViewModel(ordersFeature: OrdersFeature(repository: repository))
        let save = viewModel.save()
        await fulfillment(of: [started], timeout: 2)
        let changedDate = viewModel.draft.paymentMethod.expirationDate.addingTimeInterval(-100)
        viewModel.selectExpirationDate(changedDate)
        repository.finishSave(with: Seeds.Orders.amy)
        await save?.value
        XCTAssertFalse(viewModel.didSave)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertEqual(viewModel.draft.paymentMethod.expirationDate, changedDate)
    }

    @MainActor
    func testDistinctDraftDuringSaveIsQueuedAndOnlyLatestDraftDismissesEditor() async throws {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        await feature.refresh()
        feature.prepareEditingOrder(id: "aaa111")
        repository.holdsSaves = true
        defer { repository.releasePendingRequests() }
        let started = expectation(description: "First edit began")
        repository.saveStarted = { started.fulfill() }
        let viewModel = CreateOrderViewModel(ordersFeature: feature)
        viewModel.draft.firstName = "First edit"
        let firstDraft = viewModel.draft
        let first = viewModel.save()
        await fulfillment(of: [started], timeout: 2)
        viewModel.draft.firstName = "Second edit"
        let secondDraft = viewModel.draft
        let second = viewModel.save()
        let nextStarted = expectation(description: "Second edit began")
        repository.saveStarted = { nextStarted.fulfill() }
        repository.finishSave(with: firstDraft)
        await first?.value
        await fulfillment(of: [nextStarted], timeout: 2)
        XCTAssertFalse(viewModel.didSave)
        XCTAssertTrue(viewModel.isSaving)
        XCTAssertEqual(viewModel.draft.firstName, "Second edit")
        repository.finishSave(with: secondDraft)
        await second?.value
        XCTAssertTrue(viewModel.didSave)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertEqual(feature.orders.first?.firstName, "Second edit")
        XCTAssertEqual(repository.submittedOrders.map(\.firstName), ["First edit", "Second edit"])
    }

    @MainActor
    func testNewFormStartsBlankWithLegacyPickerDefaults() async throws {
        let feature = OrdersFeature(repository: ControllableOrdersRepository())
        let viewModel = CreateOrderViewModel(ordersFeature: feature)
        XCTAssertEqual(viewModel.draft.firstName, "")
        XCTAssertNil(viewModel.draft.id)
        XCTAssertEqual(viewModel.shippingSpeedText, "")
        XCTAssertEqual(viewModel.expirationDateText, "")
        XCTAssertEqual(viewModel.shippingOptions.map(\.title), [
            "Standard Shipping", "One-Day Shipping", "Two-Day Shipping"
        ])
        viewModel.selectShippingSpeed(.TwoDay)
        XCTAssertEqual(viewModel.shippingSpeedText, "Two-Day Shipping")
        let date = Date(timeIntervalSince1970: 1000)
        viewModel.selectExpirationDate(date)
        XCTAssertEqual(viewModel.draft.paymentMethod.expirationDate, date)
        XCTAssertFalse(viewModel.expirationDateText.isEmpty)
    }

    @MainActor
    func testEditingDraftPreservesUnchangedFieldsAndOnlyPublishesOnSave() async throws {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        repository.holdsSaves = true
        defer { repository.releasePendingRequests() }
        let started = expectation(description: "Save reached repository")
        repository.saveStarted = { started.fulfill() }
        let feature = OrdersFeature(repository: repository)
        await feature.refresh()
        feature.prepareEditingOrder(id: "aaa111")
        let viewModel = CreateOrderViewModel(ordersFeature: feature)
        viewModel.draft.firstName = "Amelia"
        XCTAssertEqual(feature.orders.first?.firstName, "Amy")
        let save = viewModel.save()
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(viewModel.isSaving)
        XCTAssertFalse(viewModel.didSave)
        XCTAssertEqual(repository.submittedOrders.first?.date, Seeds.Orders.amy.date)
        XCTAssertEqual(repository.submittedOrders.first?.total, Seeds.Orders.amy.total)
        XCTAssertEqual(repository.submittedOrders.first?.billingAddress.street1, Seeds.Orders.amy.billingAddress.street1)
        repository.finishSave(with: viewModel.draft)
        await save?.value
        XCTAssertTrue(viewModel.didSave)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertEqual(feature.orders.first?.firstName, "Amelia")
    }

    @MainActor
    func testFailureRetainsDraftAndAllowsRetry() async throws {
        let repository = ControllableOrdersRepository()
        repository.failsNextSave = true
        let viewModel = CreateOrderViewModel(ordersFeature: OrdersFeature(repository: repository))
        viewModel.draft.email = "synthetic@example.com"
        await viewModel.save()?.value
        XCTAssertTrue(viewModel.showsSaveError)
        XCTAssertFalse(viewModel.didSave)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertEqual(viewModel.draft.email, "synthetic@example.com")
        XCTAssertEqual(viewModel.failureTitle, "Failed to create order")
        await viewModel.save()?.value
        XCTAssertTrue(viewModel.didSave)
        XCTAssertFalse(viewModel.showsSaveError)
        XCTAssertEqual(repository.submittedOrders.count, 2)
    }

    @MainActor
    func testRepeatedSaveDoesNotDuplicateTheDisabledFormsSubmission() async throws {
        let repository = ControllableOrdersRepository()
        repository.holdsSaves = true
        defer { repository.releasePendingRequests() }
        let started = expectation(description: "Save reached repository")
        repository.saveStarted = { started.fulfill() }
        let viewModel = CreateOrderViewModel(ordersFeature: OrdersFeature(repository: repository))
        let first = viewModel.save()
        let repeated = viewModel.save()
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(repository.submittedOrders.count, 1)
        repository.finishSave(with: Seeds.Orders.amy)
        await first?.value
        await repeated?.value
        await viewModel.save()?.value
        XCTAssertEqual(repository.submittedOrders.count, 1)
    }

    @MainActor
    func testCommitSurvivesEditorRelease() async throws {
        let repository = ControllableOrdersRepository()
        repository.holdsSaves = true
        defer { repository.releasePendingRequests() }
        let started = expectation(description: "Save reached repository")
        repository.saveStarted = { started.fulfill() }
        let feature = OrdersFeature(repository: repository)
        var viewModel: CreateOrderViewModel? = CreateOrderViewModel(ordersFeature: feature)
        let editorWasReleased = { [weak viewModel] in viewModel == nil }
        let save = viewModel?.save()
        await fulfillment(of: [started], timeout: 2)
        viewModel = nil
        XCTAssertTrue(editorWasReleased())
        repository.finishSave(with: Seeds.Orders.amy)
        await save?.value
        XCTAssertEqual(feature.orders.map(\.id), ["aaa111"])
    }

    @MainActor
    func testDraftsAreIndependentAndBackWithoutSavingHasNoSideEffect() async throws {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        await feature.refresh()
        feature.prepareEditingOrder(id: "aaa111")
        let editor = CreateOrderViewModel(ordersFeature: feature)
        editor.draft.firstName = "Discard me"
        feature.prepareNewOrder()
        let anotherEditor = CreateOrderViewModel(ordersFeature: feature)
        XCTAssertEqual(editor.draft.id, "aaa111")
        XCTAssertNil(anotherEditor.draft.id)
        XCTAssertEqual(feature.orders.first?.firstName, "Amy")
        XCTAssertTrue(repository.submittedOrders.isEmpty)
    }

    @MainActor
    func testTextFocusAdvancesAndEndsAtLastField() async throws {
        let viewModel = CreateOrderViewModel(ordersFeature: OrdersFeature(repository: ControllableOrdersRepository()))
        let fields: [CreateOrderViewModel.Field] = [
            .firstName, .lastName, .phone, .email,
            .shipmentStreet1, .shipmentStreet2, .shipmentCity, .shipmentState, .shipmentZIP,
            .creditCardNumber, .cvv,
            .billingStreet1, .billingStreet2, .billingCity, .billingState, .billingZIP
        ]
        for (current, next) in zip(fields, fields.dropFirst()) {
            XCTAssertEqual(viewModel.nextField(after: current), next)
        }
        XCTAssertNil(viewModel.nextField(after: .billingZIP))
    }
}
