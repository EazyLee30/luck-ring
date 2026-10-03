import Foundation

/// Research notes and tooling for the ring's motion capability.
///
/// ## What the SDK actually exposes
///
/// Investigated directly against `BluetoothLibrary.framework`:
///
/// * `CE_GestureCmd` is **app → device**. It sets which wrist-raise actions the
///   ring should perform (TikTok, music, reader, photo, phone). The ring does the
///   gesture recognition itself and the SDK never tells us what it detected.
/// * `DATA_TYPE_MOTION_GAME` (143) and `DATA_TYPE_MOTION_DATA` (144) are declared
///   in `FuncType.h`, but the framework ships **no decoder** for either. There is
///   no method in the Obj-C metadata that handles them, and no accelerometer or
///   gyroscope keys anywhere in the binary — a sweep for `accel`, `gyro`, `imu`,
///   `pitch`, `roll`, `axis` and axis-tuple payload keys comes back empty.
/// * `CEDataParser` exposes exactly one decoder, `handleSleepData:`.
///
/// ## Conclusion
///
/// There is **no raw IMU stream** in this SDK. If the device does emit a 144
/// packet, `DeviceRingBridge.parse` currently discards it in its `default:` arm.
///
/// So gesture recognition on our side has one prerequisite: find out what a 144
/// packet actually contains. `MotionPacketInspector` below exists for exactly
/// that — it captures and decodes the payload so one real capture can be added to
/// `Tests/` as a fixture.
enum MotionResearch {

    /// funcTypes the SDK declares but does not decode.
    static let undecodedFuncTypes: [Int] = [143, 144]

    static let summary = """
    No raw IMU stream in the SDK. CE_GestureCmd is outbound configuration only.
    DATA_TYPE_MOTION_DATA (144) is declared but undecoded - capture one packet to
    find out whether it carries axes at all.
    """
}

/// A decoded-but-unknown packet, kept verbatim so nothing is lost on the way to
/// a human decision.
struct UnknownPacket: Identifiable, Codable, Hashable {
    var id = UUID()
    var timestamp: Date
    var funcType: Int
    var raw: Data

    var hex: String {
        raw.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    /// Bytes after the 10-byte framing header, if the frame is long enough.
    var body: [UInt8] {
        Array(raw.dropFirst(10))
    }

    /// Best-guess field widths, offered as a starting point rather than a claim.
    /// A 3-axis packet at 2 bytes per axis plus a status byte would be 7 bytes.
    var likelyStructures: [String] {
        guard !body.isEmpty else { return [] }
        var out = ["\(body.count) payload bytes"]
        if body.count == 7 {
            out.append("3 × int16 axes + 1 status byte")
            out.append("6 × int8 axes + 1 status byte")
        }
        if body.count >= 6 {
            out.append("\(body.count / 2) × int16 fields")
        }
        if body.count >= 3 {
            out.append("\(body.count) × int8 fields")
        }
        return out
    }
}

/// Collects packets the SDK does not decode so they can be exported for analysis.
@MainActor
final class MotionPacketInspector: ObservableObject {
    @Published private(set) var packets: [UnknownPacket] = []
    private let limit = 200

    func record(funcType: Int, raw: Data) {
        guard MotionResearch.undecodedFuncTypes.contains(funcType) else { return }
        packets.insert(UnknownPacket(timestamp: Date(), funcType: funcType, raw: raw), at: 0)
        if packets.count > limit { packets.removeLast(packets.count - limit) }
    }

    var isEmpty: Bool { packets.isEmpty }

    func export() -> URL? {
        guard !packets.isEmpty else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(packets) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("motion-packets-\(Int(Date().timeIntervalSince1970)).json")
        try? data.write(to: url)
        return url
    }

    /// Ready-made report for pasting into an issue.
    func report() -> String {
        guard !packets.isEmpty else {
            return "No DATA_TYPE_MOTION_* packets seen. Either the ring does not stream them, "
                + "or the sensor switch was off while connected."
        }
        var lines = ["Captured \(packets.count) undecoded motion packets:", ""]
        for packet in packets.prefix(8) {
            lines.append("funcType \(packet.funcType) · \(packet.body.count) payload bytes")
            lines.append("  \(packet.hex)")
            lines.append("  candidates: \(packet.likelyStructures.joined(separator: " / "))")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}