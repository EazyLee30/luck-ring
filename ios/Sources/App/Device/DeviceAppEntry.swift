import SwiftUI
import BluetoothLibrary

/// Device entry point. The vendor framework is only importable on device, which
/// is why this file lives outside LuckRingKit.
@main
struct LuckRingDeviceApp: App {
    @StateObject private var store = HealthStore(bridge: DeviceRingBridge())

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store)
        }
    }
}