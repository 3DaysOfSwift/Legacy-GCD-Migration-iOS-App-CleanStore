import Foundation
import XCTest
@testable import CleanStore

final class CreateOrderViewModelTests: XCTestCase {
    @MainActor
    func testNewFormStartsBlankWithLegacyPickerDefaults() {
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
    func testEditingDraftPreservesUnchangedFieldsAndOnlyPublishesOnSave() {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        repository.holdsSaves = true
        let feature = OrdersFeature(repository: repository)
        feature.refresh()
        feature.prepareEditingOrder(id: "aaa111")
        let viewModel = CreateOrderViewModel(ordersFeature: feature)
        viewModel.draft.firstName = "Amelia"
        XCTAssertEqual(feature.orders.first?.firstName, "Amy")
        viewModel.save()
        XCTAssertTrue(viewModel.isSaving)
        XCTAssertFalse(viewModel.didSave)
        XCTAssertEqual(repository.submittedOrders.first?.date, Seeds.Orders.amy.date)
        XCTAssertEqual(repository.submittedOrders.first?.total, Seeds.Orders.amy.total)
        XCTAssertEqual(repository.submittedOrders.first?.billingAddress.street1, Seeds.Orders.amy.billingAddress.street1)
        repository.finishSave(with: viewModel.draft)
        XCTAssertTrue(viewModel.didSave)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertEqual(feature.orders.first?.firstName, "Amelia")
    }

    @MainActor
    func testFailureRetainsDraftAndAllowsRetry() {
        let repository = ControllableOrdersRepository()
        repository.failsNextSave = true
        let viewModel = CreateOrderViewModel(ordersFeature: OrdersFeature(repository: repository))
        viewModel.draft.email = "synthetic@example.com"
        viewModel.save()
        XCTAssertTrue(viewModel.showsSaveError)
        XCTAssertFalse(viewModel.didSave)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertEqual(viewModel.draft.email, "synthetic@example.com")
        XCTAssertEqual(viewModel.failureTitle, "Failed to create order")
        viewModel.save()
        XCTAssertTrue(viewModel.didSave)
        XCTAssertFalse(viewModel.showsSaveError)
        XCTAssertEqual(repository.submittedOrders.count, 2)
    }

    @MainActor
    func testRepeatedSaveDoesNotDuplicateTheDisabledFormsSubmission() {
        let repository = ControllableOrdersRepository()
        repository.holdsSaves = true
        let viewModel = CreateOrderViewModel(ordersFeature: OrdersFeature(repository: repository))
        viewModel.save()
        viewModel.save()
        XCTAssertEqual(repository.submittedOrders.count, 1)
        repository.finishSave(with: Seeds.Orders.amy)
        viewModel.save()
        XCTAssertEqual(repository.submittedOrders.count, 1)
    }

    @MainActor
    func testCommitSurvivesEditorRelease() {
        let repository = ControllableOrdersRepository()
        repository.holdsSaves = true
        let feature = OrdersFeature(repository: repository)
        var viewModel: CreateOrderViewModel? = CreateOrderViewModel(ordersFeature: feature)
        let editorWasReleased = { [weak viewModel] in viewModel == nil }
        viewModel?.save()
        viewModel = nil
        XCTAssertTrue(editorWasReleased())
        repository.finishSave(with: Seeds.Orders.amy)
        XCTAssertEqual(feature.orders.map(\.id), ["aaa111"])
    }

    @MainActor
    func testDraftsAreIndependentAndBackWithoutSavingHasNoSideEffect() {
        let repository = ControllableOrdersRepository(orders: [Seeds.Orders.amy])
        let feature = OrdersFeature(repository: repository)
        feature.refresh()
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
    func testTextFocusAdvancesAndEndsAtLastField() {
        let viewModel = CreateOrderViewModel(ordersFeature: OrdersFeature(repository: ControllableOrdersRepository()))
        XCTAssertEqual(viewModel.nextField(after: .firstName), .lastName)
        XCTAssertEqual(viewModel.nextField(after: .billingState), .billingZIP)
        XCTAssertNil(viewModel.nextField(after: .billingZIP))
    }
}
