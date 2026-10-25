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
        let repository = MemoryOrdersRepository(orders: MemoryOrdersRepository.demoOrders(at: Date()))
        let ordersFeature = OrdersFeature(repository: repository)
        return AppModel(ordersFeature: ordersFeature)
    }

    func applicationDidFinishLaunching() async {
        guard !hasRequestedLaunchRefresh else { return }
        hasRequestedLaunchRefresh = true
        await ordersFeature.refresh()
    }
}
