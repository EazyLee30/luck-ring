import Foundation
import SwiftUI

/// Central observable store. Owns the day history, goals, connection state, and
/// the derived scores. Views read from here and never talk to BLE directly.
@MainActor
final class HealthStore: ObservableObject {

    // Data
    @Published private(set) var days: [DailySnapshot] = []
    @Published var goals: Goals = Goals()
    @Published private(set) var connection: RingConnection = .demo
    @Published private(set) var batteryPercent: Int?
    @Published private(set) var ringName: String = "Luck Ring"
    @Published private(set) var firmware: String?
    @Published private(set) var lastSync: Date?

    // BLE plumbing
    var onPeripherals: (([DiscoveredRing]) -> Void)?
    var onLog: ((String) -> Void)?

    private let bridge: RingBridge
    private var ingestQueue: [IngestedRecord] = []

    // MARK: - Init

    /// `bridge` is injected rather than defaulted so the demo and device targets
    /// can supply their own transport.
    init(bridge: RingBridge) {
        self.bridge = bridge
        bridge.onRecords = { [weak self] records in
            Task { @MainActor in self?.ingest(records) }
        }
        bridge.onConnection = { [weak self] state in
            Task { @MainActor in self?.connection = state }
        }
        bridge.onDiscovered = { [weak self] rings in
            Task { @MainActor in self?.onPeripherals?(rings) }
        }
        bridge.onLogLine = { [weak self] line in
            Task { @MainActor in self?.onLog?(line) }
        }
    }

    // MARK: - Derived

    /// Days sorted newest-first.
    var orderedDays: [DailySnapshot] { days.sorted { $0.date > $1.date } }

    var today: DailySnapshot? {
        orderedDays.first { Calendar.current.isDateInToday($0.date) } ?? orderedDays.first
    }

    var selectedDay: DailySnapshot? { today }

    private(set) var baseline: Baseline?

    var sleepScore: ScoreEngine.SleepBreakdown? {
        guard let d = today else { return nil }
        return ScoreEngine.sleep(for: d, goals: goals, baseline: baseline)
    }

    var readinessScore: ScoreEngine.ReadinessBreakdown? {
        guard let d = today, let s = sleepScore else { return nil }
        return ScoreEngine.readiness(for: d, goals: goals, baseline: baseline, sleepScore: s.total)
    }

    var activityScore: ScoreEngine.ActivityBreakdown? {
        guard let d = today else { return nil }
        return ScoreEngine.activity(for: d, goals: goals)
    }

    /// Seven-day trend of any scored metric.
    func trend(_ metric: TrendMetric) -> [(day: DailySnapshot, value: Int)] {
        orderedDays.prefix(7).reversed().compactMap { day in
            switch metric {
            case .sleep:
                return (day, ScoreEngine.sleep(for: day, goals: goals, baseline: baseline).total)
            case .readiness:
                let s = ScoreEngine.sleep(for: day, goals: goals, baseline: baseline).total
                return (day, ScoreEngine.readiness(for: day, goals: goals, baseline: baseline, sleepScore: s).total)
            case .activity:
                return (day, ScoreEngine.activity(for: day, goals: goals).total)
            }
        }
    }

    // MARK: - Actions

    func start() {
        bridge.start()
        if case .demo = bridge.connection {
            loadDemoData()
        }
    }

    func refresh() {
        bridge.refreshAll()
        lastSync = Date()
    }

    func setConnection(_ state: RingConnection) { connection = state }

    // MARK: - Ingestion

    func ingest(_ records: [IngestedRecord]) {
        guard !records.isEmpty else { return }
        ingestQueue.append(contentsOf: records)

        let calendar = Calendar.current
        var touched = Set<Date>()

        for record in records {
            guard let time = record.timestamp else { continue }
            let dayStart = calendar.startOfDay(for: time)

            if !days.contains(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) {
                days.append(DailySnapshot(date: dayStart))
                days.sort { $0.date < $1.date }
            }
            apply(record, to: dayStart)
            touched.insert(dayStart)
        }

        days = Array(days.suffix(120))
        baseline = Baseline.make(from: days)
        lastSync = Date()
    }

    private func apply(_ record: IngestedRecord, to dayStart: Date) {
        let idx = days.firstIndex { Calendar.current.isDate($0.date, inSameDayAs: dayStart) } ?? days.count - 1
        guard days.indices.contains(idx) else { return }

        switch record {
        case .sleepTransition(let time, let stage):
            var day = days[idx]
            // Rebuild the whole session from every transition seen for this night.
            var transitions = day.sleepTransitions
            transitions.append(SleepTransition(time: time, stage: stage))
            day.sleepTransitions = transitions
            day.sleep = SleepSession.assemble(from: transitions)
            days[idx] = day

        case .activity(let summary):
            var day = days[idx]
            day.activity = summary
            days[idx] = day

        case .heartRate(let sample):
            var day = days[idx]
            // Keep the list bounded; the ring streams every reading.
            day.heartRate.append(sample)
            day.heartRate = Array(day.heartRate.suffix(1500))
            days[idx] = day

        case .bloodPressure(let sample):
            var day = days[idx]
            day.bloodPressure.append(sample)
            days[idx] = day

        case .oxygen(let sample):
            var day = days[idx]
            day.oxygen.append(sample)
            days[idx] = day

        case .hrv(let sample):
            var day = days[idx]
            day.hrv.append(sample)
            days[idx] = day

        case .temperature(let sample):
            var day = days[idx]
            day.temperature.append(sample)
            days[idx] = day

        case .battery(let level):
            batteryPercent = level

        case .deviceInfo(let name, let fw):
            if !name.isEmpty { ringName = name }
            firmware = fw
        }
    }

    // MARK: - Demo

    /// Populates a week of plausible history so the UI is meaningful before the
    /// ring has synced anything.
    func loadDemoData() {
        var generator = SeededGenerator(seed: 0xC0FFEE)
        var built: [DailySnapshot] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for dayOffset in stride(from: 6, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            built.append(DemoDay.make(date: date, rng: &generator))
        }

        days = built
        baseline = Baseline.make(from: built)
        batteryPercent = 68
        ringName = "Luck Ring"
        firmware = "1.4.2"
        connection = .demo
    }
}

// MARK: - Records

enum IngestedRecord {
    /// Day bucket this record belongs to. Device-level records (battery, device
    /// info) have no natural timestamp.
    var timestamp: Date? {
        switch self {
        case .sleepTransition(let t, _): return t
        case .activity(let a): return a.date
        case .heartRate(let s): return s.time
        case .bloodPressure(let s): return s.time
        case .oxygen(let s): return s.time
        case .hrv(let s): return s.time
        case .temperature(let s): return s.time
        case .battery, .deviceInfo: return nil
        }
    }

    case sleepTransition(Date, SleepStage)
    case activity(ActivitySummary)
    case heartRate(HeartRateSample)
    case bloodPressure(BloodPressureSample)
    case oxygen(OxygenSample)
    case hrv(HRVSample)
    case temperature(TemperatureSample)
    case battery(Int)
    case deviceInfo(String, String)
}

// MARK: - Trend metrics

enum TrendMetric: String, CaseIterable, Identifiable {
    case sleep, readiness, activity
    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: return "Sleep"
        case .readiness: return "Readiness"
        case .activity: return "Activity"
        }
    }

    var tint: Color {
        switch self {
        case .sleep: return Palette.sleep
        case .readiness: return Palette.readiness
        case .activity: return Palette.activity
        }
    }
}
