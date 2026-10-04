import Foundation
import SwiftUI

/// Central observable store. Owns the day history, goals, connection state, and
/// the derived scores. Views read from here and never talk to BLE directly.
@MainActor
final class HealthStore: ObservableObject {

    // Data
    @Published private(set) var days: [DailySnapshot] = []
    @Published var goals: Goals = Goals()
    /// Order the wearer arranged their metric shortcuts in.
    @Published var shortcutOrder: [String] = Shortcut.defaultOrder
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

    /// Which day the UI is showing. nil means "today"; Vitals and Trends set it
    /// so every score on screen follows the same selection.
    @Published private(set) var selectedDate: Date?

    var selectedDay: DailySnapshot? {
        guard let selectedDate else { return today }
        let cal = Calendar.current
        return orderedDays.first { cal.isDate($0.date, inSameDayAs: selectedDate) } ?? today
    }

    var isViewingToday: Bool {
        guard let selectedDate else { return true }
        return Calendar.current.isDateInToday(selectedDate)
    }

    func select(day date: Date?) { selectedDate = date }

    private(set) var baseline: Baseline?

    var sleepScore: ScoreEngine.SleepBreakdown? {
        guard let d = selectedDay else { return nil }
        return ScoreEngine.sleep(for: d, goals: goals, baseline: baseline)
    }

    var readinessScore: ScoreEngine.ReadinessBreakdown? {
        guard let d = selectedDay, let s = sleepScore else { return nil }
        return ScoreEngine.readiness(for: d, goals: goals, baseline: baseline, sleepScore: s.total)
    }

    var activityScore: ScoreEngine.ActivityBreakdown? {
        guard let d = selectedDay else { return nil }
        return ScoreEngine.activity(for: d, goals: goals)
    }

    /// 7-day average of a score, for the delta chips.
    func averageScore(_ metric: TrendMetric) -> Int? {
        let values: [Int] = orderedDays.prefix(7).compactMap { day in
            switch metric {
            case .sleep:
                return day.sleep == nil ? nil : ScoreEngine.sleep(for: day, goals: goals, baseline: baseline).total
            case .readiness:
                guard day.sleep != nil else { return nil }
                let s = ScoreEngine.sleep(for: day, goals: goals, baseline: baseline).total
                return ScoreEngine.readiness(for: day, goals: goals, baseline: baseline, sleepScore: s).total
            case .activity:
                return day.activity == nil ? nil : ScoreEngine.activity(for: day, goals: goals).total
            }
        }
        guard values.count >= 2 else { return nil }
        return values.reduce(0, +) / values.count
    }

    func scoreDelta(_ metric: TrendMetric, current: Int) -> Int? {
        guard let avg = averageScore(metric) else { return nil }
        return current - avg
    }

    var healthAreas: [HealthArea] { HealthAreaBuilder.build(days: days, goals: goals) }

    // MARK: - Workouts

    /// The session in progress, if any.
    @Published private(set) var activeWorkout: Workout?

    /// The last 7 days of training load, for the UI.
    func weeklyTrainingLoad() -> Double {
        let recent = Array(orderedDays.prefix(7))
        let met = recent.reduce(0.0) { $0 + $1.metHours }
        return min(1, met / 150)
    }

    var totalExerciseMinutes: Int {
        recentWeekDays.reduce(0) { $0 + $1.exerciseMinutes }
    }

    var recentWeekDays: [DailySnapshot] { Array(orderedDays.prefix(7)) }

    func startWorkout(_ kind: Workout.Kind) {
        guard activeWorkout == nil else { return }
        activeWorkout = Workout(kind: kind, start: Date())
    }

    func cancelWorkout() { activeWorkout = nil }

    /// Ends the session, folds in whatever heart-rate samples arrived while it
    /// ran, and estimates the burn.
    @discardableResult
    func finishWorkout(distanceMetres: Int? = nil) -> Workout? {
        guard var workout = activeWorkout else { return nil }
        workout.end = Date()
        workout.distanceMetres = distanceMetres ?? workout.distanceMetres

        let day = today ?? DailySnapshot(date: Date())
        let window = day.heartRate.filter {
            $0.time >= workout.start && $0.time <= (workout.end ?? Date())
        }
        if !window.isEmpty {
            workout.averageHR = window.map(\.bpm).reduce(0, +) / window.count
            workout.peakHR = window.map(\.bpm).max()
        }
        workout.calories = WorkoutEstimator.calories(for: workout,
                                                     restingHR: day.restingHeartRate)

        activeWorkout = nil
        append(workout: workout, to: day)
        return workout
    }

    func append(workout: Workout, to day: DailySnapshot) {
        let idx = days.firstIndex { Calendar.current.isDate($0.date, inSameDayAs: day.date) }
            ?? days.count
        if idx >= days.count { days.append(day) }
        days.sort { $0.date < $1.date }
        let target = days.firstIndex { Calendar.current.isDate($0.date, inSameDayAs: day.date) }!
        days[target].workoutLog.append(workout)
        days[target].workoutLog.sort { $0.start < $1.start }
        baseline = Baseline.make(from: days)
        persist()
    }

    /// Folds inferred sessions into the day, skipping anything overlapping one
    /// the wearer already logged.
    func ingestDetected(_ detections: [WorkoutDetector.Detection]) {
        guard let day = today else { return }
        for detection in detections {
            let overlaps = day.workoutLog.contains {
                $0.start < detection.end && detection.end > detection.start
            }
            guard !overlaps else { continue }

            var workout = Workout(kind: detection.kind, start: detection.start, end: detection.end)
            workout.averageHR = detection.averageHR
            workout.peakHR = detection.peakHR
            workout.calories = WorkoutEstimator.calories(for: workout,
                                                         restingHR: day.restingHeartRate)
            append(workout: workout, to: day)
        }
    }

    /// Whether the ring is currently uploading stored history. Set by the device
    /// sheet; Today reads it to decide whether to nag about a paused upload.
    @Published private(set) var isStreaming = false

    func setSensorStreaming(_ on: Bool) {
        isStreaming = on
        bridge.setSensorStreaming(on)
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
        restore()
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

    /// Wipe locally stored history. Does not touch the ring.
    func deleteLocalHistory() {
        HistoryStore.shared.deleteAll()
        days = []
        baseline = nil
        if case .demo = connection { loadDemoData() }
    }

    var localStorageBytes: Int64 { HistoryStore.shared.fileSizeBytes }

    // MARK: - Persistence

    /// Loads persisted history, falling back to generated data on a fresh install
    /// so the UI is never empty.
    func restore() {
        shortcutOrder = HistoryStore.shared.loadPreferences().shortcutOrder

        if case .demo = bridge.connection {
            shortcutOrder = Shortcut.defaultOrder
            return
        }
        let saved = HistoryStore.shared.load()
        if saved.days.isEmpty {
            loadDemoData()
        } else {
            days = saved.days.sorted { $0.date < $1.date }
            goals = saved.goals
            baseline = Baseline.make(from: days)
        }
    }

    /// Called after every mutation. Writes are coalesced onto a utility queue and
    /// are atomic, so a crash mid-write cannot truncate the existing file.
    func persist() {
        HistoryStore.shared.save(days: days, goals: goals)
        HistoryStore.shared.savePreferences(
            HistoryStore.Preferences(shortcutOrder: shortcutOrder))
    }

    // MARK: - Ingestion

    func ingest(_ records: [IngestedRecord]) {
        guard !records.isEmpty else { return }
        ingestQueue.append(contentsOf: records)

        let calendar = Calendar.current
        var touched = Set<Date>()

        for record in records {
            // Device-level records (battery, firmware) carry no timestamp and so
            // belong to no day. They must still be applied — skipping them here
            // silently discarded the ring's battery reading.
            guard let time = record.timestamp else {
                applyDeviceLevel(record)
                continue
            }
            let dayStart = bucket(for: record, at: time)

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
        persist()
    }

    /// Which midnight a record belongs to.
    ///
    /// Everything is bucketed by local midnight except sleep: a night that begins
    /// at 23:30 has most of its stages after midnight, and bucketing those by
    /// their own timestamp splits one session across two days — which means the
    /// night never assembles at all. Sleep transitions therefore stay with the
    /// day that owns the SLEEP_START.
    private func bucket(for record: IngestedRecord, at time: Date) -> Date {
        let calendar = Calendar.current

        guard case .sleepTransition = record else {
            return calendar.startOfDay(for: time)
        }

        let ownsNight = days.first { day in
            guard let start = day.sleepTransitions.first(where: { $0.stage == .start })?.time
            else { return false }
            return time >= start && time.timeIntervalSince(start) < 24 * 3600
        }
        if let ownsNight { return ownsNight.date }

        // No open session owns this timestamp, so this transition starts a night.
        return calendar.startOfDay(for: time)
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

        case .battery, .deviceInfo:
            // Handled by `applyDeviceLevel`; they have no day bucket.
            break
        }
    }

    /// Records that describe the ring rather than the wearer on a given day.
    private func applyDeviceLevel(_ record: IngestedRecord) {
        switch record {
        case .battery(let level):
            batteryPercent = level
        case .deviceInfo(let name, let fw):
            if !name.isEmpty { ringName = name }
            if !fw.isEmpty, fw != "—" { firmware = fw }
        default:
            break
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

        // 42 days, not 7: the week and month screens are only reviewable against a
        // window that actually spans two calendar months.
        for dayOffset in stride(from: DemoDay.historyDays - 1, through: 0, by: -1) {
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
