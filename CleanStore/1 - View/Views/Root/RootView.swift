import SwiftUI

// Structural navigation only; the feature screens own their ViewModels.
struct RootView: View {
    var body: some View {
        NavigationStack {
            ListOrdersView()
        }
        .tint(.primary)
    }
}
