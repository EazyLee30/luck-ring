import Foundation

#if canImport(HealthKit)
import HealthKit

/// Writes the ring's readings into HealthKit so they appear in Apple Health and
/// interoperate with anything else reading the user's health data.
///
/// The guiding rule is that nothing is written that the ring did not actually
/// report. Where the app holds a number HealthKit has no honest home for — skin
/// temperature, a resting rate that fell back to a whole-day average — it is
/// skipped and the reason recorded, rather than being passed off as a
/// measurement of something else.
@MainActor
final class HealthKitExporter: HealthExportService {

    private(set) var status: HealthExportStatus = .notDetermined

    private let store = HKHealthStore()
    private var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// What the app is willing to write. Each entry needs permission, so the list
    /// is kept to types the ring genuinely fills.
    static let writeIdentifiers: [HKQuantityTypeIdentifier] = [
        .heartRate,
        .heartRateVariabilitySDNN,
        .stepCount,
        .distanceWalkingRunning,
        .activeEnergyBurned,
        .restingHeartRate,
        .oxygenSaturation,
    ]

    /// HealthKit's Swift names drop the "Identifier" suffix, so the type is
    /// `HKCategoryType(.sleepAnalysis)` and the value enum is
    /// `HKCategoryValueSleepAnalysis`.
    static var sleepType: HKCategoryType { HKCategoryType(.sleepAnalysis) }

    static func quantityType(_ id: HKQuantityTypeIdentifier) -> HKQuantityType {
        HKQuantityType(id)
    }

    /// Union of what is written and what is read. The app shows stored history as
    /// well as exporting, so both halves are requested.
    static var allTypes: Set<HKSampleType> {
        var set: Set<HKSampleType> = Set(writeIdentifiers.map { quantityType($0) })
        set.insert(sleepType)
        return set
    }

    func prepare() {
        guard isAvailable else {
            status = .unsupported("Apple Health is not available on this device.")
            return
        }
        switch store.authorizationStatus(for: Self.sleepType) {
        case .sharingAuthorized: status = .ready
        case .sharingDenied: status = .refused
        case .notDetermined: status = .notDetermined
        @unknown default: status = .notDetermined
        }
    }

    func requestAuthorization() async {
        guard isAvailable else {
            status = .unsupported("Apple Health is not available on this device.")
            return
        }
        do {
            try await store.requestAuthorization(toShare: Self.allTypes,
                                                 read: Self.allTypes)
            prepare()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Writes every reading in the given days. Returns how many samples landed.
    @discardableResult
    func export(days: [DailySnapshot]) async -> Int {
        guard isAvailable else { return 0 }
        prepare()
        // Only an explicit "ready" means writing is permitted; a refusal returns 0
        // rather than attempting a save that would throw for every sample.
        guard case .ready = status else { return 0 }

        var written = 0
        for day in days.sorted(by: { $0.date < $1.date }) {
            written += await write(day)
        }
        status = .wrote(samples: written)
        return written
    }

    // MARK: - Per day

    private func write(_ day: DailySnapshot) async -> Int {
        let samples = samples(for: day)
        var written = 0
        if !samples.isEmpty {
            do {
                try await store.save(samples)
                written += samples.count
            } catch {
                // One rejected sample must not take the whole day with it.
                written += await saveIndividually(samples)
            }
        }
        // Workouts are written separately because their children go through a
        // builder rather than the day batch.
        written += await writeWorkouts(day)
        return written
    }

    /// Builds every sample for one day. Pure and synchronous so the mapping can be
    /// asserted without touching the store.
    func samples(for day: DailySnapshot) -> [HKSample] {
        var out: [HKSample] = []
        out += heartRateSamples(day)
        out += hrvSamples(day)
        out += oxygenSamples(day)
        out += bloodPressureSamples(day)
        out += activitySamples(day)
        out += restingHeartRateSample(day)
        out += sleepSamples(day)
        return out
    }

    /// One sample per reading, which is what the ring actually sent.
    private func heartRateSamples(_ day: DailySnapshot) -> [HKSample] {
        let type = Self.quantityType(.heartRate)
        return day.heartRate
            .sorted { $0.time < $1.time }
            .map { quantity(type, $0.time, Double($0.bpm), .count().unitDivided(by: .minute())) }
    }

    /// Every HRV reading is written, not a single daily average — the individual
    /// values are the measurement, the average is the summary.
    private func hrvSamples(_ day: DailySnapshot) -> [HKSample] {
        let type = Self.quantityType(.heartRateVariabilitySDNN)
        return day.hrv
            .sorted { $0.time < $1.time }
            .map { quantity(type, $0.time, Double($0.ms), .secondUnit(with: .milli)) }
    }

    /// HealthKit stores SpO2 as a fraction, the ring reports percent.
    private func oxygenSamples(_ day: DailySnapshot) -> [HKSample] {
        let type = Self.quantityType(.oxygenSaturation)
        return day.oxygen
            .sorted { $0.time < $1.time }
            .map { quantity(type, $0.time, Double($0.spo2) / 100, .percent()) }
    }

    /// Blood pressure is two quantity samples, systolic and diastolic.
    private func bloodPressureSamples(_ day: DailySnapshot) -> [HKSample] {
        let sys = Self.quantityType(.bloodPressureSystolic)
        let dia = Self.quantityType(.bloodPressureDiastolic)
        let unit = HKUnit.millimeterOfMercury()
        return day.bloodPressure.sorted { $0.time < $1.time }.flatMap { sample -> [HKSample] in
            [
                quantity(sys, sample.time, Double(sample.systolic), unit),
                quantity(dia, sample.time, Double(sample.diastolic), unit),
            ]
        }
    }

    /// Daily totals go in as cumulative samples stamped late in the day, which is
    /// how a day's step total is expected to be recorded.
    private func activitySamples(_ day: DailySnapshot) -> [HKSample] {
        guard let activity = day.activity else { return [] }
        let at = day.date.addingTimeInterval(20 * 3600)
        var out: [HKSample] = []

        if activity.steps > 0 {
            out.append(cumulative(Self.quantityType(.stepCount), at,
                                 Double(activity.steps), .count()))
        }
        if activity.distanceMetres > 0 {
            out.append(cumulative(Self.quantityType(.distanceWalkingRunning), at,
                                 Double(activity.distanceMetres), .meter()))
        }
        if activity.calories > 0 {
            out.append(cumulative(Self.quantityType(.activeEnergyBurned), at,
                                 Double(activity.calories), .kilocalorie()))
        }
        return out
    }

    /// Only exported when it really is a resting rate.
    ///
    /// `restingHeartRate` averages pre-noon readings, but falls back to the whole
    /// day when there are none — and a whole-day average is not a resting heart
    /// rate. Writing it as one would put a number in Health under a name the
    /// number does not deserve, so the fallback case is left out.
    private func restingHeartRateSample(_ day: DailySnapshot) -> [HKSample] {
        guard let overnight = overnightHeartRate(day) else { return [] }
        let type = Self.quantityType(.restingHeartRate)
        return [quantity(type, overnight.at, Double(overnight.bpm),
                         .count().unitDivided(by: .minute()))]
    }

    /// The overnight mean and the instant it describes, or `nil` when the day's
    /// resting rate was only a whole-day fallback.
    private func overnightHeartRate(_ day: DailySnapshot) -> (bpm: Int, at: Date)? {
        let night = day.heartRate.filter {
            Calendar.current.isDate($0.time, inSameDayAs: day.date)
                && day.hourOf($0.time) < 12
        }
        guard !night.isEmpty else { return nil }
        return (night.map(\.bpm).reduce(0, +) / night.count, night[0].time)
    }

    /// Skin temperature is deliberately not exported. HealthKit has no
    /// skin-temperature type, and the only honest-looking destination —
    /// `bodyTemperature` — would file a wrist reading as a core measurement. It
    /// stays in the app, where it is labelled as skin temperature.

    // MARK: - Sleep

    /// Written per stage interval, which is the granularity HealthKit models, with
    /// an overlapping "in bed" sample so Health can compute time-to-fall-asleep
    /// and in-bed efficiency itself.
    private func sleepSamples(_ day: DailySnapshot) -> [HKSample] {
        guard let sleep = day.sleep else { return [] }
        let type = Self.sleepType

        var stages: [HKCategorySample] = []
        for interval in sleep.intervals {
            guard let value = Self.sleepValue(for: interval.stage) else { continue }
            stages.append(category(type, value: value.rawValue,
                                   start: interval.start, end: interval.end))
        }
        // A night with no recognised stages still needs a record, or Health shows
        // an empty box rather than an unsleep night.
        if stages.isEmpty {
            stages.append(category(type, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                                   start: sleep.start, end: sleep.end))
        }

        let inBed = category(type, value: HKCategoryValueSleepAnalysis.inBed.rawValue,
                             start: sleep.start, end: sleep.end)
        return [inBed] + stages
    }

    /// The app's stage names are finer than HealthKit's. `.light` maps to "asleep,
    /// stage unspecified" because the device does not separate N1 from N2.
    static func sleepValue(for stage: SleepStage) -> HKCategoryValueSleepAnalysis? {
        switch stage {
        case .deep: return .asleepDeep
        case .rem: return .asleepREM
        case .light: return .asleepUnspecified
        case .awake: return .awake
        // Session boundaries, not stages.
        case .none, .start: return nil
        @unknown default: return nil
        }
    }

    // MARK: - Workouts

    /// Workouts are written through `HKWorkoutBuilder`, which documents support
    /// for "a workout that occurred in the past" — exactly this case.
    ///
    /// Children must go through `addSamples(_:)` rather than being saved in the
    /// day's batch: the builder is what associates them with the workout, and
    /// saving them separately would leave the session in Health with no energy,
    /// distance or heart rate in it.
    private func writeWorkouts(_ day: DailySnapshot) async -> Int {
        var written = 0
        for w in day.workouts {
            guard let end = w.end, end > w.start else { continue }
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = Self.workoutActivity(for: w.kind)
            configuration.locationType = .unknown

            let builder = HKWorkoutBuilder(healthStore: store,
                                           configuration: configuration,
                                           device: .local())
            do {
                try await builder.beginCollection(at: w.start)
                let children = workoutQuantitySamples(w, end: end)
                if !children.isEmpty {
                    _ = try await builder.addSamples(children)
                }
                try await builder.endCollection(at: end)
                if let finished = try await builder.finishWorkout() {
                    _ = finished
                    written += 1 + children.count
                }
            } catch {
                // A rejected workout must not abandon the rest of the day.
                continue
            }
        }
        return written
    }

    /// The samples that belong to one session. Timestamped inside its bounds: the
    /// midpoint for averages, the start for totals.
    private func workoutQuantitySamples(_ w: Workout, end: Date) -> [HKSample] {
        let energy = Self.quantityType(.activeEnergyBurned)
        let distance = Self.quantityType(.distanceWalkingRunning)
        let heartRate = Self.quantityType(.heartRate)
        var out: [HKSample] = []

        if w.calories > 0 {
            out.append(quantity(energy, w.start, Double(w.calories), .kilocalorie()))
        }
        if w.distanceMetres > 0 {
            out.append(quantity(distance, w.start, Double(w.distanceMetres), .meter()))
        }
        if let avg = w.averageHR {
            out.append(quantity(heartRate, w.start.addingTimeInterval(w.duration / 2),
                                Double(avg), .count().unitDivided(by: .minute())))
        }
        out.removeAll { $0.endDate > end }
        return out
    }

    static func workoutActivity(for kind: Workout.Kind) -> HKWorkoutActivityType {
        switch kind {
        case .walk: return .walking
        case .run: return .running
        case .cycle: return .cycling
        case .swim: return .swimming
        case .hiit: return .highIntensityIntervalTraining
        case .yoga: return .yoga
        case .rowing: return .rowing
        case .strength: return .traditionalStrengthTraining
        case .elliptical: return .elliptical
        case .other: return .other
        }
    }

    // MARK: - Helpers

    private func quantity(_ type: HKQuantityType, _ date: Date, _ value: Double,
                          _ unit: HKUnit, workout: HKWorkout? = nil) -> HKQuantitySample {
        // `metadata` is read-only on the sample, so it goes through the designated
        // initialiser rather than being assigned after the fact.
        var keys: [String: Any] = [HKMetadataKeyWasUserEntered: false]
        if workout != nil { keys[HKMetadataKeyHeartRateMotionContext] = false }
        return HKQuantitySample(type: type,
                                quantity: HKQuantity(unit: unit, doubleValue: value),
                                start: date, end: date, metadata: keys)
    }

    private func cumulative(_ type: HKQuantityType, _ date: Date, _ value: Double,
                            _ unit: HKUnit) -> HKQuantitySample {
        HKQuantitySample(type: type,
                         quantity: HKQuantity(unit: unit, doubleValue: value),
                         start: dayBounds(for: date), end: date)
    }

    /// Cumulative samples need a start, and the day's midnight is the only honest
    /// one available from a date alone.
    private func dayBounds(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func category(_ type: HKCategoryType, value: Int,
                          start: Date, end: Date) -> HKCategorySample {
        HKCategorySample(type: type, value: value, start: start, end: end,
                         metadata: [HKMetadataKeyWasUserEntered: false])
    }

    /// Falls back to one at a time so a single rejection does not discard the rest,
    /// counting only what actually landed.
    private func saveIndividually(_ samples: [HKSample]) async -> Int {
        var written = 0
        for sample in samples {
            do {
                try await store.save(sample)
                written += 1
            } catch {
                continue
            }
        }
        return written
    }
}
#endif

/// Installs the exporter so the shared UI can find it. Called once from the device
/// app's entry point.
@MainActor
enum HealthKitExportBootstrap {
    static func install() {
        HealthExportRegistry.install(HealthKitExporter())
    }
}
