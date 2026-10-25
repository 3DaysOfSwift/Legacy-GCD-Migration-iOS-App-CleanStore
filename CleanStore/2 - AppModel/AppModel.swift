import Foundation

@MainActor
final class AppModel {
    static let shared = AppModel.live()

    let ordersFeature: OrdersFeature
    private var hasRequestedLaunchRefresh: Bool

    init(ordersFeature: OrdersFeature) {
        self.ordersFeature = ordersFeature
        self.hasRequestedLaunchRefresh = false
    }

    static func live() -> AppModel {
        let ordersWorker = OrdersWorker(ordersStore: OrdersMemStore())
        let repository = LegacyOrdersRepository(ordersWorker: ordersWorker)
        let ordersFeature = OrdersFeature(repository: repository)
        return AppModel(ordersFeature: ordersFeature)
    }

    // Callback-based until the separate concurrency checkpoint.
    func applicationDidFinishLaunching() {
        guard !hasRequestedLaunchRefresh else { return }
        hasRequestedLaunchRefresh = true
        ordersFeature.refresh()
    }
}
