import Foundation

/// Scores are ours, not Oura's. Their proprietary algorithms are not public, so
/// these are plausible, documented heuristics over the metrics the ring reports.
/// Everything is 0...100.
enum ScoreEngine {

    struct SleepBreakdown {
        var total: Int
        var durationPoints: Int
        var efficiencyPoints: Int
        var deepPoints: Int
        var timingPoints: Int
    }

    struct ReadinessBreakdown {
        var total: Int
        var sleepPoints: Int
        var hrvPoints: Int
        var restingHRPoints: Int
        var temperaturePoints: Int
    }

    struct ActivityBreakdown {
        var total: Int
        var stepsPoints: Int
        var caloriesPoints: Int
        var activeTimePoints: Int
    }

    // MARK: - Sleep

    /// Duration is the dominant term, efficiency gates it, deep sleep and
    /// consistency round it out.
    static func sleep(for day: DailySnapshot, goals: Goals,
                      baseline: Baseline?) -> SleepBreakdown {
        let target = Double(goals.sleepTargetMinutes) * 60

        // Duration: full marks at target, tapering to 0 at 4h. Oversleeping past
        // target+2h gives nothing extra.
        var durationPoints = 0
        if let s = day.sleep {
            let t = s.duration
            if t >= target {
                durationPoints = 40
            } else if t > 4 * 3600 {
                let ratio = (t - 4 * 3600) / (target - 4 * 3600)
                durationPoints = Int(40 * max(0, ratio))
            }
        }

        var efficiencyPoints = 0
        if let s = day.sleep, s.duration > 0 {
            let eff = s.efficiency
            efficiencyPoints = eff >= 0.95 ? 25 : Int(25 * max(0, min(1, (eff - 0.60) / 0.35)))
        }

        // Deep sleep: 13–23% of the night is the healthy band.
        var deepPoints = 0
        if let s = day.sleep, s.duration > 0 {
            let r = s.deepRatio
            if r >= 0.13 && r <= 0.23 {
                deepPoints = 20
            } else if r < 0.13 {
                deepPoints = Int(20 * (r / 0.13))
            } else {
                deepPoints = Int(20 * max(0, 1 - (r - 0.23) / 0.12))
            }
        }

        // Timing: how close bedtime is to the same time on previous nights.
        var timingPoints = 0
        if let s = day.sleep {
            let bedtime = Calendar.current.component(.hour, from: s.start) * 60
                + Calendar.current.component(.minute, from: s.start)
            if let prev = baseline?.averageBedtimeMinutes {
                var delta = abs(bedtime - prev)
                if delta > 720 { delta = 1440 - delta }   // wrap midnight
                timingPoints = delta <= 30 ? 15 : Int(15 * max(0, 1 - Double(delta - 30) / 180))
            } else {
                timingPoints = 10
            }
        }

        let total = max(0, min(100, durationPoints + efficiencyPoints + deepPoints + timingPoints))
        return SleepBreakdown(total: total, durationPoints: durationPoints,
                              efficiencyPoints: efficiencyPoints,
                              deepPoints: deepPoints, timingPoints: timingPoints)
    }

    // MARK: - Readiness

    /// Sleep carries the most weight, then HRV and resting HR; temperature
    /// deviation is a small modifier because skin temp is noisy.
    static func readiness(for day: DailySnapshot, goals: Goals,
                          baseline: Baseline?, sleepScore: Int) -> ReadinessBreakdown {
        let sleepPoints = Int(Double(sleepScore) * 0.50)

        var hrvPoints = 0
        if let today = day.averageHRV, let base = baseline?.averageHRV, base > 0 {
            let ratio = Double(today) / Double(base)
            hrvPoints = ratio >= 1.0 ? 25 : Int(25 * max(0, min(1, (ratio - 0.70) / 0.30)))
        } else if day.averageHRV != nil {
            hrvPoints = 12
        }

        var hrPoints = 0
        if let rhr = day.restingHeartRate, let base = baseline?.averageRestingHR, base > 0 {
            let delta = Double(rhr - base)
            hrPoints = delta <= 0 ? 15 : Int(15 * max(0, 1 - delta / 8.0))
        } else if day.restingHeartRate != nil {
            hrPoints = 8
        }

        var tempPoints = 0
        if let delta = day.temperatureDelta(baseline: baseline?.averageSkinTemp) {
            tempPoints = abs(delta) <= 0.3 ? 10 : Int(10 * max(0, 1 - (abs(delta) - 0.3) / 0.9))
        } else {
            tempPoints = 5
        }

        let total = max(0, min(100, sleepPoints + hrvPoints + hrPoints + tempPoints))
        return ReadinessBreakdown(total: total, sleepPoints: sleepPoints,
                                  hrvPoints: hrvPoints, restingHRPoints: hrPoints,
                                  temperaturePoints: tempPoints)
    }

    // MARK: - Activity

    static func activity(for day: DailySnapshot, goals: Goals) -> ActivityBreakdown {
        guard let a = day.activity else {
            return ActivityBreakdown(total: 0, stepsPoints: 0, caloriesPoints: 0, activeTimePoints: 0)
        }

        let stepsPoints = Int(50 * min(1, Double(a.steps) / Double(max(1, goals.stepTarget))))

        // 500 active kcal is a full day.
        let caloriesPoints = Int(30 * min(1, Double(a.calories) / 500.0))

        let activePoints = Int(20 * min(1, Double(a.activeSeconds) / Double(goals.activeMinutesTarget * 60)))

        let total = max(0, min(100, stepsPoints + caloriesPoints + activePoints))
        return ActivityBreakdown(total: total, stepsPoints: stepsPoints,
                                caloriesPoints: caloriesPoints, activeTimePoints: activePoints)
    }
}

/// Rolling averages computed over the days we have, so scores can be compared
/// against the wearer rather than a population.
struct Baseline {
    var averageBedtimeMinutes: Int?
    var averageHRV: Int?
    var averageRestingHR: Int?
    var averageSkinTemp: Double?

    static func make(from days: [DailySnapshot]) -> Baseline? {
        // Two days of *any* wearable data is the floor. Gating on sleep
        // records alone meant a wearer with HRV and heart rate but no sleep
        // session yet never got a baseline at all.
        guard days.count >= 2 else { return nil }
        let withSleep = days.filter { $0.sleep != nil }

        let calendar = Calendar.current
        let bedtimes: [Int] = withSleep.compactMap { d in
            guard let s = d.sleep else { return nil }
            return calendar.component(.hour, from: s.start) * 60 + calendar.component(.minute, from: s.start)
        }
        let hrvs: [Int] = days.compactMap(\.averageHRV)
        let rhrs: [Int] = days.compactMap(\.restingHeartRate)
        let temps: [Double] = days.compactMap { $0.temperature.sorted { $0.time < $1.time }.last?.celsius }

        return Baseline(
            averageBedtimeMinutes: bedtimes.isEmpty ? nil : bedtimes.reduce(0, +) / bedtimes.count,
            averageHRV: hrvs.isEmpty ? nil : hrvs.reduce(0, +) / hrvs.count,
            averageRestingHR: rhrs.isEmpty ? nil : rhrs.reduce(0, +) / rhrs.count,
            averageSkinTemp: temps.isEmpty ? nil : temps.reduce(0, +) / Double(temps.count)
        )
    }
}

// MARK: - Copy

enum ScoreVerdict {
    static func sleep(_ score: Int) -> (title: String, detail: String) {
        switch score {
        case 90...: return ("Optimal", "You're well recovered and ready for anything.")
        case 80..<90: return ("Good", "Solid night. Nothing stands out as a problem.")
        case 70..<80: return ("Fair", "A bit short or restless — an easy night would help.")
        case 60..<70: return ("Poor", "Under-recovered. Consider an early night.")
        default: return ("Bad", "Very little recovery. Prioritise sleep tonight.")
        }
    }

    static func readiness(_ score: Int) -> (title: String, detail: String) {
        switch score {
        case 90...: return ("Ready", "Your body is primed. Good day for a hard session.")
        case 80..<90: return ("Good", "Normal capacity. Train as planned.")
        case 70..<80: return ("Fair", "Slightly depleted. Keep intensity moderate.")
        case 60..<70: return ("Low", "Body needs recovery. Skip the hard session.")
        default: return ("Rest", "Strong signals to rest today.")
        }
    }

    static func activity(_ score: Int) -> (title: String, detail: String) {
        switch score {
        case 90...: return ("Active", "You hit everything and pushed hard.")
        case 80..<90: return ("Balanced", "Good day of movement.")
        case 70..<80: return ("Light", "Under target — a walk would close the gap.")
        case 60..<70: return ("Sedentary", "Mostly still today.")
        default: return ("Rest day", "Very little movement recorded.")
        }
    }
}