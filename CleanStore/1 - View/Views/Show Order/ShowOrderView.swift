import SwiftUI

struct ShowOrderView: View {
    @State private var viewModel = ShowOrderViewModel()

    var body: some View {
        ScrollView {
            if let order = viewModel.order {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    detail("Order ID:", value: order.id ?? "")
                    detail("Order Date:", value: order.date)
                    detail("Email Address:", value: order.email)
                    detail("Your Name:", value: order.name)
                    detail("Order Total:", value: order.total)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Show Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit", action: viewModel.editOrder)
                    .accessibilityIdentifier("edit-order")
            }
        }
        .navigationDestination(isPresented: $viewModel.showsEditor) {
            CreateOrderView()
        }
    }

    private func detail(_ title: LocalizedStringKey, value: String) -> some View {
        GridRow {
            Text(title)
            Text(value)
                .accessibilityIdentifier("order-detail-value")
        }
    }
}
