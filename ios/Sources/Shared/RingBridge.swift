import Foundation
import SwiftUI

/// Abstracted ring transport so the UI can run on demo data (simulator, or
/// before the ring has ever been paired) and swap to real BLE on device.
protocol RingBridge: AnyObject {
    var connection: RingConnection { get }
    var onRecords: (([IngestedRecord]) -> Void)? { get set }
    var onConnection: ((RingConnection) -> Void)? { get set }
    var onDiscovered: (([DiscoveredRing]) -> Void)? { get set }
    var onLogLine: ((String) -> Void)? { get set }

    func start()
    func refreshAll()
    func scan()
    func connect(_ ring: DiscoveredRing)
    func disconnect()
    func setSensorStreaming(_ on: Bool)
    func measure(kind: VitalKind)
}

/// What the device can actually measure. Mirrors the SDK's capability flags.
enum VitalKind: String, CaseIterable, Identifiable {
    case heart, bloodPressure, oxygen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heart: return "Heart rate"
        case .bloodPressure: return "Blood pressure"
        case .oxygen: return "Blood oxygen"
        }
    }

    var symbol: String {
        switch self {
        case .heart: return "heart.fill"
        case .bloodPressure: return "waveform.path.ecg"
        case .oxygen: return "lungs.fill"
        }
    }

    var tint: Color {
        switch self {
        case .heart: return Palette.heart
        case .bloodPressure: return Palette.pressure
        case .oxygen: return Palette.oxygen
        }
    }

    /// The command class the vendor SDK uses for this measurement.
    var sdkCommand: String {
        switch self {
        case .heart: return "CE_SyncHeartRateCmd"
        case .bloodPressure: return "CE_SyncBloodPressureCmd"
        case .oxygen: return "CE_SyncHeartO2Cmd"
        }
    }
}

/// A ring seen during a scan, flattened out of the SDK's `SearchPeripheral`
/// so the SwiftUI layer doesn't need the framework.
struct DiscoveredRing: Identifiable, Hashable {
    let id: String
    let name: String
    let deviceID: String?
    let mac: String?
    let rssi: Int
    let protocolVersion: Int
    let systemPaired: Bool

    var subtitle: String {
        var parts = ["id \(deviceID ?? "?")", "ver \(protocolVersion)", "rssi \(rssi)"]
        if let mac { parts.insert("mac \(mac)", at: 0) }
        if systemPaired { parts.append("system-paired") }
        return parts.joined(separator: " · ")
    }
}

/// Used when the app runs without a paired ring: keeps the bridge contract
/// satisfied while the UI shows generated data.
final class DemoRingBridge: RingBridge {
    var connection: RingConnection { .demo }
    var onRecords: (([IngestedRecord]) -> Void)?
    var onConnection: ((RingConnection) -> Void)?
    var onDiscovered: (([DiscoveredRing]) -> Void)?
    var onLogLine: ((String) -> Void)?

    func start() { onConnection?(.demo) }
    func refreshAll() { onLogLine?("Demo bridge: nothing to sync") }
    func scan() { onLogLine?("Demo bridge: scan disabled") }
    func connect(_ ring: DiscoveredRing) {}
    func disconnect() {}
    func setSensorStreaming(_ on: Bool) {}
    func measure(kind: VitalKind) { onLogLine?("Demo bridge: cannot run \(kind.title)") }
}