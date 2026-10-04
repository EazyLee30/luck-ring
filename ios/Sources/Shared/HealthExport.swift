import Foundation

/// How far along an export to Apple Health is.
///
/// HealthKit deliberately does not reveal whether access was granted for any
/// individual type — it reports only whether *asking* is allowed. So there is no
/// per-type "denied" reading here; a refusal shows up as a low written count
/// rather than a specific error.
enum HealthExportStatus: Equatable {
    case unsupported(String)
    case notDetermined
    case ready
    case refused
    case wrote(samples: Int)
    case failed(String)

    var label: String {
        switch self {
        case .unsupported: return "Unavailable"
        case .notDetermined: return "Not connected"
        case .ready: return "Ready"
        case .refused: return "Not permitted"
        case .wrote(let n): return "\(n) written"
        case .failed: return "Failed"
        }
    }

    var detail: String {
        switch self {
        case .unsupported(let why):
            return why
        case .notDetermined:
            return "Apple Health will ask which types Luck Ring may write. You can decline any of them."
        case .ready:
            return "Connected. Exporting writes this app's readings into Apple Health."
        case .refused:
            return "Writing is turned off for at least one type. Check Settings › Health › Data Access & Devices."
        case .wrote(let n):
            return n == 0
                ? "Nothing written — either there is nothing to write, or every sample was declined. Heart rate, HRV, steps, distance, energy, oxygen and blood pressure are written when present."
                : "Wrote \(n) samples. Your ring's own copy is untouched, and exporting again will add a second set."
        case .failed(let why):
            return why
        }
    }

    /// Whether the primary button should offer to connect.
    var wantsAuthorization: Bool {
        switch self {
        case .notDetermined, .refused: return true
        default: return false
        }
    }
}

/// The shared view layer talks to this rather than to HealthKit directly, because
/// the framework only exists in the device target — the demo builds without it.
///
/// The protocol is not `ObservableObject` on purpose: status only ever changes as a
/// result of an action the caller just performed, so the view model re-reads it
/// afterwards instead of subscribing across an existential.
protocol HealthExportService: AnyObject {
    var status: HealthExportStatus { get }
    func prepare()
    func requestAuthorization() async
    func export(days: [DailySnapshot]) async -> Int
}

/// The device app installs its HealthKit-backed implementation at launch; the demo
/// leaves it `nil` and the UI says so rather than offering a button that does
/// nothing.
enum HealthExportRegistry {
    private static let lock = NSLock()
    private static var storage: (any HealthExportService)?

    static var service: (any HealthExportService)? {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    static func install(_ service: any HealthExportService) {
        lock.lock()
        defer { lock.unlock() }
        storage = service
    }
}

@MainActor
final class HealthExportViewModel: ObservableObject {
    @Published private(set) var status: HealthExportStatus = .notDetermined
    @Published private(set) var isWorking = false

    var isAvailable: Bool { HealthExportRegistry.service != nil }

    func refresh() {
        guard let service = HealthExportRegistry.service else {
            status = .unsupported("This build has no Apple Health support.")
            return
        }
        service.prepare()
        status = service.status
    }

    func connect() async {
        guard let service = HealthExportRegistry.service else { return }
        isWorking = true
        defer { isWorking = false }
        await service.requestAuthorization()
        status = service.status
    }

    @discardableResult
    func export(days: [DailySnapshot]) async -> Int {
        guard let service = HealthExportRegistry.service else { return 0 }
        isWorking = true
        defer { isWorking = false }
        let written = await service.export(days: days)
        status = service.status
        return written
    }
}

/// Storage figures come straight from the filesystem, so these are exact byte
/// counts rather than anything inferred.
enum Bytes {
    /// `ByteCountFormatter` renders zero as "Zero KB", which reads like a bug on a
    /// storage row, so the empty case is stated instead.
    static func human(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "Nothing stored" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        return formatter.string(fromByteCount: bytes)
    }
}