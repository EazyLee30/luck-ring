import Foundation

// MARK: - Sleep

/// Stage codes as they arrive from the device (`SleepType` in the vendor docs).
/// The ring does not report REM separately, so `rem` stays absent rather than
/// being faked from deep sleep.
enum SleepStage: Int, Codable, CaseIterable {
    case none = 0
    case start = 1      // session boundary, not a stage
    case deep = 2
    case light = 3
    case awake = 4      // session boundary, not a stage
    /// Local-only: used when we synthesise a REM estimate for the demo dataset.
    case rem = 5

    var isStage: Bool { self == .deep || self == .light || self == .awake || self == .rem }

    var title: String {
        switch self {
        case .deep: return "Deep"
        case .light: return "Light"
        case .rem: return "REM"
        case .awake: return "Awake"
        default: return "—"
        }
    }
}

/// One `(timestamp, stage)` pair straight off the wire.
struct SleepTransition: Identifiable, Codable, Hashable {
    var id = UUID()
    var time: Date
    var stage: SleepStage
}

struct SleepInterval: Identifiable, Codable, Hashable {
    var id = UUID()
    var stage: SleepStage
    var start: Date
    var end: Date
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// One sleep bout, assembled from the device's flat transition list.
struct SleepSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var start: Date
    var end: Date
    var intervals: [SleepInterval] = []

    var duration: TimeInterval { end.timeIntervalSince(start) }

    func time(_ stage: SleepStage) -> TimeInterval {
        intervals.filter { $0.stage == stage }.reduce(0) { $0 + $1.duration }
    }

    /// The ring only ever reports *awake*, never "asleep". Everything in the
    /// session that was not explicitly marked awake therefore counts as sleep,
    /// which also covers the unclassified gap before the first stage transition.
    var asleep: TimeInterval {
        max(0, duration - time(.awake))
    }

    /// Asleep ÷ time in bed.
    var efficiency: Double {
        duration > 0 ? min(1, max(0, asleep / duration)) : 0
    }

    var deepRatio: Double { duration > 0 ? time(.deep) / duration : 0 }
    var remRatio: Double { duration > 0 ? time(.rem) / duration : 0 }
    var awakeRatio: Double { duration > 0 ? time(.awake) / duration : 0 }

    /// Stable-ish cutoff used by the scorer and the summary line.
    var sleepScoreBand: String {
        if efficiency < 0.7 { return "Restless" }
        if efficiency < 0.85 { return "OK" }
        return "Efficient"
    }

    /// Assemble from the device's `(timestamp, stage)` transitions.
    /// Each transition opens a stage; the next one closes it.
    static func assemble(from transitions: [SleepTransition]) -> SleepSession? {
        let ordered = transitions.sorted { $0.time < $1.time }

        // Anchor on an explicit SLEEP_START. Without it we cannot tell a session
        // from a stray stage change, and previously an awake-first sequence
        // produced a bogus session.
        guard let startMarker = ordered.first(where: { $0.stage == .start }) else { return nil }
        let start = startMarker.time

        // A stage transition can share the start timestamp exactly — the device is not
        // obliged to delay it — so keep those. Only the session end needs to be
        // strictly later.
        let after = ordered.filter { $0.time >= start && $0.stage != .start }
        // The session ends on the LAST awake transition, not the first — there is
        // typically an early awakening minutes after falling asleep.
        let end = after.last { $0.stage == .awake && $0.time > start }?.time
            ?? after.last(where: { $0.time > start })?.time
            ?? start
        guard end > start else { return nil }

        // Each stage transition opens a stage that runs until the next one. The
        // device does not emit a transition at the instant of falling asleep, so
        // these intervals deliberately cover less than the whole session — the
        // remainder is unclassified rather than invented. `asleep` is derived
        // from the session length, not from this list.
        var intervals: [SleepInterval] = []
        for (i, transition) in after.enumerated() {
            guard transition.stage.isStage else { continue }
            let nextTime = after.dropFirst(i + 1).first?.time ?? end
            guard nextTime > transition.time else { continue }
            intervals.append(SleepInterval(stage: transition.stage,
                                          start: transition.time, end: nextTime))
        }

        return SleepSession(start: start, end: end, intervals: intervals)
    }
}

// MARK: - Activity

struct ActivitySummary: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var steps: Int = 0
    var distanceMetres: Int = 0
    var activeSeconds: Int = 0
    var calories: Int = 0

    var distanceKm: Double { Double(distanceMetres) / 1000 }

    /// Rough kcal/day floor for an adult; activity adds on top.
    var basalCalories: Int { 1550 }

    var totalCalories: Int { basalCalories + calories }
}

// MARK: - Vitals

struct HeartRateSample: Identifiable, Codable, Hashable {
    var id = UUID()
    var time: Date
    var bpm: Int
}

struct BloodPressureSample: Identifiable, Codable, Hashable {
    var id = UUID()
    var time: Date
    var systolic: Int
    var diastolic: Int
}

struct OxygenSample: Identifiable, Codable, Hashable {
    var id = UUID()
    var time: Date
    var spo2: Int
}

struct HRVSample: Identifiable, Codable, Hashable {
    var id = UUID()
    var time: Date
    var ms: Int
}

struct TemperatureSample: Identifiable, Codable, Hashable {
    var id = UUID()
    var time: Date
    /// Device reports skin temperature; we only ever use the delta vs baseline.
    var celsius: Double
}

// MARK: - Daily rollup

struct DailySnapshot: Identifiable, Codable, Hashable {
    var id = UUID()
    /// Local midnight.
    var date: Date
    var sleep: SleepSession?
    /// Raw stage transitions as received; kept so a session can be re-assembled
    /// when a late packet arrives out of order.
    var sleepTransitions: [SleepTransition] = []
    var activity: ActivitySummary?
    var heartRate: [HeartRateSample] = []
    var bloodPressure: [BloodPressureSample] = []
    var oxygen: [OxygenSample] = []
    var hrv: [HRVSample] = []
    var temperature: [TemperatureSample] = []
    /// Sessions the wearer started, plus anything the app inferred.
    var workoutLog: [Workout] = []

    var restingHeartRate: Int? {
        guard !heartRate.isEmpty else { return nil }
        // Overnight readings are the resting baseline.
        let night = heartRate.filter { Calendar.current.isDate($0.time, inSameDayAs: date) && hourOf($0.time) < 12 }
        let pool = night.isEmpty ? heartRate : night
        return pool.map(\.bpm).reduce(0, +) / pool.count
    }

    var lowestHeartRate: Int? { heartRate.map(\.bpm).min() }
    var highestHeartRate: Int? { heartRate.map(\.bpm).max() }
    var averageHRV: Int? {
        guard !hrv.isEmpty else { return nil }
        return hrv.map(\.ms).reduce(0, +) / hrv.count
    }
    var averageOxygen: Int? {
        guard !oxygen.isEmpty else { return nil }
        return oxygen.map(\.spo2).reduce(0, +) / oxygen.count
    }
    var latestBloodPressure: BloodPressureSample? { bloodPressure.sorted { $0.time < $1.time }.last }

    /// Deviation from the 7-day skin-temperature baseline, in °C.
    func temperatureDelta(baseline: Double?) -> Double? {
        guard let baseline, let last = temperature.sorted(by: { $0.time < $1.time }).last else { return nil }
        return last.celsius - baseline
    }

    func hourOf(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }
}

// MARK: - Goals & connection

struct Goals: Codable, Hashable {
    var stepTarget: Int = 8000
    var sleepTargetMinutes: Int = 450      // 7h30
    var activeMinutesTarget: Int = 30
}

enum RingConnection: Equatable {
    case demo
    case idle
    case scanning
    case connecting
    case awaitingConfirm
    case ready
    case disconnected(String)

    var label: String {
        switch self {
        case .demo: return "Demo data"
        case .idle: return "Not connected"
        case .scanning: return "Scanning…"
        case .connecting: return "Connecting…"
        case .awaitingConfirm: return "Tap the ring to confirm"
        case .ready: return "Connected"
        case .disconnected(let why): return why
        }
    }

    var isLive: Bool {
        switch self {
        case .ready, .awaitingConfirm, .connecting, .scanning: return true
        default: return false
        }
    }
}