import SwiftUI

/// Simulator / demo entry point. Always uses `DemoRingBridge`, so the whole UI
/// is navigable without a paired ring.
@main
struct LuckRingDemoApp: App {
    @StateObject private var store = HealthStore(bridge: DemoRingBridge())

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store)
        }
    }
}