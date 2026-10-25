import Foundation
import Observation

@MainActor
@Observable
final class CreateOrderViewModel {
    private let ordersFeature: OrdersFeature
    var draft: Order {
        didSet {
            if !draft.hasSameSnapshot(as: oldValue) { draftRevision += 1 }
        }
    }
    private(set) var isSaving = false
    private(set) var didSave = false
    var showsSaveError = false
    var hasSelectedShippingSpeed: Bool
    var hasSelectedExpirationDate: Bool

    // The original storyboard switch has no action or outlet. Preserve its
    // presentation without silently adding address-copying product behaviour.
    var sameAsShippingAddress = true
    @ObservationIgnored private var draftRevision = 0
    @ObservationIgnored private var submittedRevision: Int?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(ordersFeature: OrdersFeature = AppModel.shared.ordersFeature) {
        let draft = ordersFeature.makeOrderDraft()
        self.ordersFeature = ordersFeature
        self.draft = draft
        self.hasSelectedShippingSpeed = draft.id != nil
        self.hasSelectedExpirationDate = draft.id != nil
    }

    struct ShippingOption {
        let speed: ShipmentMethod.ShippingSpeed
        let title: String
    }

    var shippingOptions: [ShippingOption] {
        ordersFeature.shippingSpeeds.map {
            ShippingOption(speed: $0, title: ShipmentMethod(speed: $0).toString())
        }
    }

    var shippingSpeedText: String {
        hasSelectedShippingSpeed ? draft.shipmentMethod.toString() : ""
    }

    var expirationDateText: String {
        hasSelectedExpirationDate ? OrderPresentation.shortDate(draft.paymentMethod.expirationDate) : ""
    }

    var failureTitle: String {
        draft.id == nil ? "Failed to create order" : "Failed to update order"
    }

    func selectShippingSpeed(_ speed: ShipmentMethod.ShippingSpeed) {
        draft.shipmentMethod.speed = speed
        hasSelectedShippingSpeed = true
    }

    func selectExpirationDate(_ date: Date) {
        draft.paymentMethod.expirationDate = date
        hasSelectedExpirationDate = true
    }

    @discardableResult
    func save() -> Task<Void, Never>? {
        if let saveTask, submittedRevision == draftRevision { return saveTask }
        guard !didSave else { return nil }
        let predecessor = saveTask
        let revision = draftRevision
        let draftToSave = draft
        submittedRevision = revision
        isSaving = true
        showsSaveError = false
        // The form prevents changes while saving; still queue a distinct programmatic
        // draft rather than returning the first draft's result. Do not retain the screen.
        let task = Task { [weak self, ordersFeature] in
            if let predecessor { await predecessor.value }
            defer {
                if self?.submittedRevision == revision {
                    self?.isSaving = false
                    self?.saveTask = nil
                }
            }
            do {
                let savedOrder = try await ordersFeature.save(draftToSave)
                guard let self, submittedRevision == revision, draftRevision == revision else { return }
                draft = savedOrder
                didSave = true
            } catch {
                if self?.submittedRevision == revision { self?.showsSaveError = true }
            }
        }
        saveTask = task
        return task
    }

    enum Field: Int, CaseIterable {
        case firstName, lastName, phone, email
        case shipmentStreet1, shipmentStreet2, shipmentCity, shipmentState, shipmentZIP
        case creditCardNumber, cvv
        case billingStreet1, billingStreet2, billingCity, billingState, billingZIP
    }

    func nextField(after field: Field) -> Field? {
        Field(rawValue: field.rawValue + 1)
    }
}
