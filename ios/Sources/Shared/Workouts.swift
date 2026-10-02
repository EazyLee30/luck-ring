import Foundation

/// A recorded bout of activity. The ring has no workout concept — it reports
/// ambient steps and heart rate — so these are reconstructed in the app from a
/// user-started session plus the samples that arrive while it runs.
struct Workout: Identifiable, Codable, Hashable {
    var id = UUID()

    enum Kind: String, Codable, CaseIterable, Identifiable {
        case walk, run, cycle, swim, strength, hiit, yoga, rowing, elliptical, other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .walk: return "Walk"
            case .run: return "Run"
            case .cycle: return "Cycle"
            case .swim: return "Swim"
            case .strength: return "Strength"
            case .hiit: return "HIIT"
            case .yoga: return "Yoga"
            case .rowing: return "Rowing"
            case .elliptical: return "Elliptical"
            case .other: return "Other"
            }
        }

        var symbol: String {
            switch self {
            case .walk: return "figure.walk"
            case .run: return "figure.run"
            case .cycle: return "bicycle"
            case .swim: return "figure.pool.swim"
            case .strength: return "dumbbell.fill"
            case .hiit: return "flame.fill"
            case .yoga: return "figure.mind.and.body"
            case .rowing: return "figure.rower"
            case .elliptical: return "figure.strengthtraining.functional"
            case .other: return "figure.mixed.cardio"
            }
        }

        /// Metabolic equivalent at moderate effort. 1 MET is resting metabolism;
        /// these are the conventional compendium figures for each activity.
        var baseMET: Double {
            switch self {
            case .walk: return 3.5
            case .run: return 9.8
            case .cycle: return 7.5
            case .swim: return 8.3
            case .strength: return 5.0
            case .hiit: return 8.0
            case .yoga: return 3.0
            case .rowing: return 7.0
            case .elliptical: return 5.5
            case .other: return 5.0
            }
        }

        /// Some activities cannot be tracked by a wrist or ring accelerometer.
        var needsManualTracking: Bool {
            switch self {
            case .swim, .strength, .yoga, .hiit, .other: return true
            default: return false
            }
        }
    }

    var kind: Kind = .walk
    var start: Date
    var end: Date?
    /// Set for manual entries where the ring cannot measure distance.
    var distanceMetres: Int = 0
    var calories: Int = 0
    var averageHR: Int?
    var peakHR: Int?
    var source: Source = .manual

    enum Source: String, Codable {
        case manual       // user-started and user-stopped
        case detected     // inferred from a heart-rate and step pattern
    }

    var isRunning: Bool { end == nil }

    var duration: TimeInterval {
        guard let end else { return Date().timeIntervalSince(start) }
        return end.timeIntervalSince(start)
    }

    var activeSeconds: Int { Int(duration) }
}

extension DailySnapshot {

    var workouts: [Workout] { workoutLog }

    /// Exercise minutes — the part of movement that counts as deliberate activity,
    /// as opposed to the background step accumulation in `activity`.
    var exerciseMinutes: Int {
        let fromWorkouts = workouts.reduce(0) { $0 + $1.activeSeconds } / 60
        return Swift.max(0, fromWorkouts)
    }

    /// MET-hours, the conventional way to express daily training load. Only
    /// workouts contribute; ambient steps are deliberately excluded because
    /// including them inflates every number.
    var metHours: Double {
        workouts.reduce(0.0) { total, w in
            let hours = w.duration / 3600
            return total + hours * w.kind.baseMET * intensityFactor(w)
        }
    }

    /// Heart-rate driven intensity multiplier, 0.8…1.25. With no heart-rate
    /// data the activity's baseline MET is taken at face value.
    private func intensityFactor(_ workout: Workout) -> Double {
        guard let avg = workout.averageHR, let resting = restingHeartRate, resting > 0 else { return 1.0 }
        // Rough linear zone map: at resting HR the factor is ~0.85, at 1.6x
        // resting it saturates at ~1.25.
        let ratio = Double(avg) / Double(resting)
        return Swift.min(1.25, Swift.max(0.8, 0.85 + (ratio - 1.0) * 0.5))
    }

    /// Training-load bar used by the UI: 0…1 against a 150 MET-hour week.
    func trainingLoad(days: Int = 7) -> Double {
        let window = Array(workoutLog.prefix(days * max(1, workouts.count)))
        let total = window.reduce(0.0) { $0 + $1.metHoursContribution }
        return Swift.min(1, total / 150)
    }
}

extension Workout {
    var metHoursContribution: Double {
        (duration / 3600) * kind.baseMET
    }
}

/// Reconstructs workouts from the ambient stream when the user did not start one.
///
/// The ring gives us step bursts and heart rate, so the only honest signal is a
/// sustained elevation in both. Anything cleverer would be inventing activity the
/// wearer did not do, and that is worse than missing a workout.
enum WorkoutDetector {

    struct Detection {
        var kind: Workout.Kind
        var start: Date
        var end: Date
        var averageHR: Int?
        var peakHR: Int?
    }

    /// A window counts as a workout when steps and heart rate are both above
    /// baseline for long enough to be deliberate rather than incidental.
    static func detect(in day: DailySnapshot, restingHR: Int?, baselineStepsPerHour: Int) -> [Detection] {
        let samples = day.heartRate
        guard samples.count >= 20, let restingHR else { return [] }

        let stepSeries = day.stepSeries()
        guard stepSeries.count == samples.count, stepSeries.count >= 20 else { return [] }

        let elevatedHR = samples.filter { $0.bpm >= restingHR + 15 }
        guard elevatedHR.count >= samples.count / 5 else { return [] }

        // Longest run of consecutive elevated readings, allowing small gaps.
        let gapTolerance = 4
        var best: (start: Date, end: Date, count: Int)?
        var runStart: Date?
        var runCount = 0
        var gap = 0
        var peak = 0
        var runPeak = 0

        for (index, sample) in samples.enumerated() {
            let steps = stepSeries[index]
            let active = sample.bpm >= restingHR + 15 && steps >= baselineStepsPerHour / 2

            if active {
                if runStart == nil { runStart = sample.time }
                runCount += 1
                runPeak = Swift.max(runPeak, sample.bpm)
                gap = 0
                if best == nil || runCount > best!.count {
                    peak = runPeak
                    best = (runStart!, sample.time, runCount)
                }
            } else {
                gap += 1
                if gap > gapTolerance {
                    runStart = nil
                    runCount = 0
                    runPeak = 0
                }
            }
        }

        // Fifteen minutes is the shortest thing worth calling a workout.
        guard let best, best.count >= 15 else { return [] }
        let duration = best.end.timeIntervalSince(best.start)
        guard duration >= 15 * 60 else { return [] }

        let windowHR = samples.filter { $0.time >= best.start && $0.time <= best.end }
        let avg = windowHR.isEmpty ? nil : windowHR.map(\.bpm).reduce(0, +) / windowHR.count
        let observedPeak = windowHR.map(\.bpm).max() ?? peak

        return [Detection(kind: .walk, start: best.start, end: best.end,
                          averageHR: avg, peakHR: observedPeak)]
    }
}

extension DailySnapshot {
    /// Evenly sampled step-per-tick series, used by the detector.
    func stepSeries() -> [Int] {
        guard let activity = activity else { return [] }
        // The device reports one cumulative figure per activity record; expand it
        // into a coarse hourly series so detection has something to threshold.
        let hours = Swift.max(1, Int(activity.activeSeconds / 3600))
        let per = activity.steps / Swift.max(1, hours)
        return [Int](repeating: per, count: Swift.max(20, hours * 6))
    }
}

/// Calorie and distance estimates for a finished workout.
enum WorkoutEstimator {

    /// kcal/min = MET x 3.5 x bodyWeightKg / 200, scaled by heart-rate intensity.
    ///
    /// The 3.5 / 200 constant is **per minute** — the original version multiplied
    /// by hours instead and produced estimates 60x too small, which is exactly the
    /// kind of plausible-looking wrong number these tests exist to catch.
    static func calories(for workout: Workout, bodyWeightKg: Double = 70,
                         restingHR: Int?) -> Int {
        let minutes = workout.duration / 60
        var met = intensityAdjustedMET(for: workout, restingHR: restingHR)
        met = Swift.max(0, met)
        return Int((met * 3.5 * bodyWeightKg / 200 * minutes).rounded())
    }

    /// Heart-rate adjusted MET, clamped to a plausible band around the base MET.
    static func intensityAdjustedMET(for workout: Workout, restingHR: Int?) -> Double {
        let base = workout.kind.baseMET
        guard let avg = workout.averageHR, let resting = restingHR, resting > 0 else {
            return base
        }
        let ratio = Double(avg) / Double(resting)
        return Swift.min(base * 1.5,
                         Swift.max(base * 0.75, base * (0.75 + (ratio - 1.0) * 0.35)))
    }

    /// Average pace-based speed, metres per second.
    static func pace(for workout: Workout) -> Double? {
        guard workout.duration > 0, workout.distanceMetres > 0 else { return nil }
        return Double(workout.distanceMetres) / workout.duration
    }

    /// Pace in seconds per kilometre, for running and walking.
    static func secondsPerKm(for workout: Workout) -> Int? {
        guard let speed = pace(for: workout), speed > 0 else { return nil }
        return Int((1000 / speed).rounded())
    }
}