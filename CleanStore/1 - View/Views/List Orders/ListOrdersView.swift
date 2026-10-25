import SwiftUI

struct ListOrdersView: View {
    @State private var viewModel = ListOrdersViewModel()

    var body: some View {
        List(viewModel.rows) { row in
            Button {
                viewModel.showOrder(id: row.id)
            } label: {
                HStack {
                    Text(row.date)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(row.total)
                        .foregroundStyle(.primary)
                }
                .frame(minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("order-row-\(row.id ?? "unidentified")")
        }
        .listStyle(.plain)
        .navigationTitle("List Orders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus", action: viewModel.createOrder)
                    .accessibilityIdentifier("add-order")
            }
        }
        .navigationDestination(isPresented: $viewModel.showsOrder) {
            ShowOrderView()
        }
        .navigationDestination(isPresented: $viewModel.showsEditor) {
            CreateOrderView()
        }
        .onAppear(perform: viewModel.refresh)
    }
}
