import Foundation

/// Shared presentation formatting, not a shared screen ViewModel.
struct OrderPresentation: Identifiable {
    let id: String?
    let date: String
    let email: String
    let name: String
    let total: String

    init(order: Order) {
        id = order.id
        date = Self.shortDate(order.date)
        email = order.email
        name = "\(order.firstName) \(order.lastName)"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        total = formatter.string(from: order.total) ?? order.total.stringValue
    }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
