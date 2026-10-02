import Foundation

/// Builds one plausible day of history. Deterministic given a seed so the demo
/// looks the same every launch, and shaped so the score engine has something
/// interesting to chew on.
enum DemoDay {

    static func make(date: Date, rng: inout SeededGenerator) -> DailySnapshot {
        var day = DailySnapshot(date: Calendar.current.startOfDay(for: date))
        day.sleep = makeSleep(date: date, rng: &rng)
        day.activity = makeActivity(date: date, rng: &rng)
        day.heartRate = makeHeart(date: date, rng: &rng)
        day.hrv = makeHRV(date: date, rng: &rng)
        day.oxygen = makeOxygen(date: date, rng: &rng)
        day.bloodPressure = makeBloodPressure(date: date, rng: &rng)
        day.temperature = makeTemperature(date: date, rng: &rng)
        return day
    }

    // MARK: - Sleep

    private static func makeSleep(date: Date, rng: inout SeededGenerator) -> SleepSession? {
        let calendar = Calendar.current

        // Bedtime drifts around 23:00, with a fair share of genuinely bad nights so
        // the trend chart has something to show.
        let roll = Double.random(in: 0...1, using: &rng)
        let isPoorNight = roll < 0.30
        let bedtimeOffset = isPoorNight
            ? Double.random(in: 80...190, using: &rng)     // stayed up late
            : Double.random(in: -60...45, using: &rng)

        let baseBed = calendar.date(bySettingHour: 23, minute: 10, second: 0, of: date) ?? date
        let start = baseBed.addingTimeInterval(bedtimeOffset * 60)

        // Asleep hours span a wide realistic band, deliberately straddling the
        // 7h30 goal so the duration term in the score actually bites.
        let asleepMinutes = isPoorNight
            ? Double.random(in: 235...355, using: &rng)
            : Double.random(in: 375...575, using: &rng)

        // Wasted-in-bed gap drives efficiency: restless nights are short on sleep
        // relative to time in bed.
        let gapMinutes = isPoorNight
            ? Double.random(in: 70...175, using: &rng)
            : Double.random(in: 5...60, using: &rng)
        let end = start.addingTimeInterval((asleepMinutes + gapMinutes) * 60)

        // Composition: mostly light, deep early, REM across later cycles.
        // Shares must sum to exactly 1.0 or the stages won't fill the session.
        let deepShare = isPoorNight ? Double.random(in: 0.07...0.11, using: &rng)
                                    : Double.random(in: 0.14...0.21, using: &rng)
        let remShare = isPoorNight ? Double.random(in: 0.08...0.12, using: &rng)
                                   : Double.random(in: 0.16...0.22, using: &rng)
        let awakeShare = Double.random(in: 0.04...0.09, using: &rng)
        let lightShare = max(0, 1.0 - deepShare - remShare - awakeShare)

        // ~90 min cycles: deep → light → REM, with short arousals between.
        let plan: [SleepStage] = [.deep, .light, .rem, .light, .rem, .light, .rem, .light]

        // Each stage's share is split across the slots that stage occupies, so
        // the totals land on deepShare / remShare / lightShare respectively.
        func slots(_ stage: SleepStage) -> Double {
            Double(max(1, plan.filter { $0 == stage }.count))
        }

        var transitions: [SleepTransition] = [SleepTransition(time: start, stage: .start)]
        var cursor = start
        let total = end.timeIntervalSince(start)

        for (i, stage) in plan.enumerated() {
            let share: Double = switch stage {
            case .deep: deepShare
            case .rem: remShare
            default: lightShare
            }
            let seconds = total * share / slots(stage)
            guard seconds > 60 else { continue }

            transitions.append(SleepTransition(time: cursor, stage: stage))
            cursor = cursor.addingTimeInterval(seconds)

            // Short arousal between cycles, never after the final stage.
            if i < plan.count - 1 {
                let awakeFor = total * awakeShare / Double(max(1, plan.count - 1))
                if awakeFor > 30 {
                    transitions.append(SleepTransition(time: cursor, stage: .awake))
                    cursor = cursor.addingTimeInterval(awakeFor)
                }
            }
        }

        transitions.append(SleepTransition(time: end, stage: .awake))
        return SleepSession.assemble(from: transitions)
    }

    // MARK: - Activity

    private static func makeActivity(date: Date, rng: inout SeededGenerator) -> ActivitySummary {
        // Skewed so there are genuine rest days, not a uniform mid-range band that
        // pins the activity score to its ceiling.
        let roll = Double.random(in: 0...1, using: &rng)
        let steps: Int
        switch roll {
        case ..<0.18: steps = Int.random(in: 900...3200, using: &rng)      // rest day
        case ..<0.55: steps = Int.random(in: 3200...7200, using: &rng)
        default: steps = Int.random(in: 7200...17500, using: &rng)
        }
        let distance = Int(Double(steps) * Double.random(in: 0.62...0.82, using: &rng))
        let activeMinutes = Int(Double(steps) / Double.random(in: 130...210, using: &rng))
        let calories = Int(Double(steps) * Double.random(in: 0.03...0.05, using: &rng)) + activeMinutes * 4
        return ActivitySummary(date: date, steps: steps, distanceMetres: distance,
                               activeSeconds: activeMinutes * 60, calories: calories)
    }

    // MARK: - Vitals

    private static func makeHeart(date: Date, rng: inout SeededGenerator) -> [HeartRateSample] {
        let base = Double.random(in: 48...62, using: &rng)
        var samples: [HeartRateSample] = []
        let calendar = Calendar.current

        // Night: slow decline toward the early-morning trough, sampled every 10 min.
        for minute in stride(from: 0, to: 360, by: 10) {
            let t = calendar.date(byAdding: .minute, value: minute, to: date) ?? date
            let drift = sin(Double(minute) / 120.0) * 3
            let jitter = Double.random(in: -1.6...1.6, using: &rng)
            samples.append(HeartRateSample(time: t, bpm: Int(base + drift + jitter)))
        }

        // Day: three activity bumps over waking hours.
        for (startHour, peak) in [(8.0, 22.0), (13.0, 34.0), (19.0, 28.0)] {
            let centre = calendar.date(bySettingHour: Int(startHour), minute: 0, second: 0, of: date) ?? date
            for step in 0..<40 {
                let offset = Double(step) * 5
                let shape = exp(-pow((offset - 25) / 18, 2))
                let t = centre.addingTimeInterval(offset * 60)
                let bpm = base + peak * shape + Double.random(in: -4...4, using: &rng)
                samples.append(HeartRateSample(time: t, bpm: Int(bpm)))
            }
        }

        return samples.sorted { $0.time < $1.time }
    }

    private static func makeHRV(date: Date, rng: inout SeededGenerator) -> [HRVSample] {
        let base = Double.random(in: 28...58, using: &rng)
        let calendar = Calendar.current
        return (0..<24).map { i in
            let t = calendar.date(byAdding: .hour, value: i * 2, to: date) ?? date
            // HRV climbs through the night, dips in the evening.
            let shape = sin(Double(i) / 24 * .pi) * 10
            return HRVSample(time: t, ms: Int(base + shape + Double.random(in: -4...4, using: &rng)))
        }
    }

    private static func makeOxygen(date: Date, rng: inout SeededGenerator) -> [OxygenSample] {
        let base = Double.random(in: 95...99, using: &rng)
        let calendar = Calendar.current
        return (0..<8).map { i in
            let t = calendar.date(byAdding: .hour, value: i * 3, to: date) ?? date
            return OxygenSample(time: t, spo2: Int(base + Double.random(in: -1...1, using: &rng)))
        }
    }

    private static func makeBloodPressure(date: Date, rng: inout SeededGenerator) -> [BloodPressureSample] {
        (0..<2).map { i in
            let sys = Int.random(in: 108...128, using: &rng)
            let dia = Int.random(in: 66...84, using: &rng)
            let t = Calendar.current.date(byAdding: .hour, value: i == 0 ? 8 : 20, to: date) ?? date
            return BloodPressureSample(time: t, systolic: sys, diastolic: dia)
        }
    }

    private static func makeTemperature(date: Date, rng: inout SeededGenerator) -> [TemperatureSample] {
        let calendar = Calendar.current
        let base = 33.1 + Double.random(in: -0.3...0.3, using: &rng)
        return (0..<4).map { i in
            let t = calendar.date(byAdding: .hour, value: i * 6, to: date) ?? date
            // Skin temp runs cooler in the early hours.
            let circadian = i < 2 ? -0.25 : 0.15
            return TemperatureSample(time: t, celsius: base + circadian + Double.random(in: -0.08...0.08, using: &rng))
        }
    }
}