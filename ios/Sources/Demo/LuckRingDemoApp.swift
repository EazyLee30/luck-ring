import SwiftUI

/// Entry point for the simulator / demo build: always `DemoRingBridge`, so the
/// UI is fully navigable without a paired ring.
@main
struct LuckRingDemoApp: App {
    @StateObject private var store = HealthStore(bridge: DemoRingBridge())

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store)
        }
    }
}