import SwiftUI

struct ListOrdersView: View {
    @State private var viewModel = ListOrdersViewModel()

    var body: some View {
        List {
            if viewModel.isRefreshing && viewModel.rows.isEmpty {
                ProgressView("Loading orders…")
            }
            if let message = viewModel.refreshErrorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(message)
                    Button("Retry") { viewModel.refresh() }
                        .disabled(viewModel.isRefreshing)
                }
            }
            ForEach(viewModel.rows) { row in
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
        .task { await viewModel.refresh().value }
    }
}
