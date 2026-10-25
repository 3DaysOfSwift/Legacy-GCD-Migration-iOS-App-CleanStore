import Foundation
import Observation

@MainActor
@Observable
final class CreateOrderViewModel {
    private let ordersFeature: OrdersFeature
    var draft: Order
    private(set) var isSaving = false
    private(set) var didSave = false
    var showsSaveError = false
    var hasSelectedShippingSpeed: Bool
    var hasSelectedExpirationDate: Bool

    // The original storyboard switch has no action or outlet. Preserve its
    // presentation without silently adding address-copying product behaviour.
    var sameAsShippingAddress = true

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

    func save() {
        // The form is disabled while saving, so another tap has no distinct draft.
        guard !isSaving, !didSave else { return }
        isSaving = true
        showsSaveError = false
        ordersFeature.save(draft) { [weak self] savedOrder in
            guard let self else { return }
            isSaving = false
            if let savedOrder {
                draft = savedOrder
                didSave = true
            } else {
                showsSaveError = true
            }
        }
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
