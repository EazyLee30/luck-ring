import Foundation

/// Aggregates a run of days into the numbers a week or month card needs.
///
/// Two rules run through all of it. An average only counts days that actually
/// recorded the thing being averaged — a night with no sleep record contributes
/// nothing rather than dragging the mean toward zero. And every summary says how
/// many days it is standing on, because "average sleep 7h 20m" over two nights is
/// a different claim from the same number over thirty.
struct PeriodSummary {

    /// The spread of one metric across the window.
    struct Spread {
        /// `(day, value)` pairs, oldest first. Empty when nothing was recorded.
        var points: [(day: DailySnapshot, value: Int)] = []

        var count: Int { points.count }
        var isEmpty: Bool { points.isEmpty }

        var mean: Int? {
            guard !points.isEmpty else { return nil }
            return points.reduce(0) { $0 + $1.value } / points.count
        }

        /// Median, which resists the single bad night that a mean would follow.
        var median: Int? {
            guard !points.isEmpty else { return nil }
            let sorted = points.map(\.value).sorted()
            let mid = sorted.count / 2
            return sorted.count % 2 == 0
                ? (sorted[mid - 1] + sorted[mid]) / 2
                : sorted[mid]
        }

        var best: (day: DailySnapshot, value: Int)? {
            points.max { $0.value < $1.value }
        }

        var worst: (day: DailySnapshot, value: Int)? {
            points.min { $0.value < $1.value }
        }

        var range: Int? {
            guard let high = best?.value, let low = worst?.value else { return nil }
            return high - low
        }

        /// Population standard deviation of the scores. Reported next to the mean as
        /// the honest companion to it: the same average with a spread of 4 and a
        /// spread of 25 are not the same week.
        var deviation: Double? {
            guard points.count > 1, let mean else { return nil }
            let m = Double(mean)
            let variance = points.reduce(0.0) { sum, point in
                sum + pow(Double(point.value) - m, 2)
            } / Double(points.count)
            return sqrt(variance)
        }

        /// Share of days scoring 70 or better. 70 is where the app's own verdicts
        /// stop calling a day weak, so it is the line that matters here.
        var goodShare: Double? {
            guard !points.isEmpty else { return nil }
            let good = points.filter { $0.value >= 70 }.count
            return Double(good) / Double(points.count)
        }
    }

    /// Window size the caller asked for, and how much of it exists.
    var requestedDays: Int = 0
    var coveredDays: Int = 0

    var sleep: Spread = Spread()
    var readiness: Spread = Spread()
    var activity: Spread = Spread()

    var averageSleepSeconds: Double?
    var averageEfficiency: Double?
    var averageSteps: Int?
    var averageRestingHR: Int?
    var averageHRV: Int?

    var trainingMinutes: Int = 0
    var metHours: Double = 0
    var workoutCount: Int = 0

    /// Bedtime scatter as a 0…1 score, reusing the same circular-mean definition
    /// the sleep detail screen uses so the two never disagree.
    var bedtimeConsistency: Double?

    /// Below this the summary says so rather than presenting a number built from a
    /// handful of days.
    static let minimumDays = 3

    var hasEnoughData: Bool { coveredDays >= Self.minimumDays }

    /// What the summary can honestly claim, in words.
    var coverageNote: String {
        if coveredDays == 0 { return "No days recorded" }
        if coveredDays == 1 { return "Based on 1 day" }
        return "Based on \(coveredDays) of \(requestedDays) days"
    }

    // MARK: - Build

    /// `days` may arrive in any order; the window is the most recent `window` of
    /// them, and a nil window means "use all of them".
    static func make(from days: [DailySnapshot], goals: Goals,
                     baseline: Baseline?, window: Int? = nil) -> PeriodSummary {
        let sorted = days.sorted { $0.date < $1.date }
        let slice = window.map { Array(sorted.suffix($0)) } ?? sorted
        // Most recent first for "covered"; the spreads keep chronological order.
        let covered = slice.filter { $0.sleep != nil || $0.activity != nil }.count

        var summary = PeriodSummary()
        summary.requestedDays = window ?? slice.count
        summary.coveredDays = covered

        // Explicit result types: the closures return tuples, which the type
        // checker will not infer from compactMap on their own.
        summary.sleep.points = slice.compactMap { day -> (DailySnapshot, Int)? in
            guard day.sleep != nil else { return nil }
            return (day, ScoreEngine.sleep(for: day, goals: goals,
                                          baseline: baseline).total)
        }
        // Readiness is half sleep score, so it has to be computed from the same
        // sleep score the sleep spread uses rather than recomputed independently.
        summary.readiness.points = slice.compactMap { day -> (DailySnapshot, Int)? in
            guard day.sleep != nil || day.activity != nil else { return nil }
            let sleepScore: Int
            if day.sleep != nil {
                sleepScore = ScoreEngine.sleep(for: day, goals: goals,
                                               baseline: baseline).total
            } else {
                sleepScore = 0
            }
            return (day, ScoreEngine.readiness(for: day, goals: goals,
                                               baseline: baseline,
                                               sleepScore: sleepScore).total)
        }
        summary.activity.points = slice.compactMap { day -> (DailySnapshot, Int)? in
            guard day.activity != nil else { return nil }
            return (day, ScoreEngine.activity(for: day, goals: goals).total)
        }

        summary.averageSleepSeconds = mean(slice.compactMap { $0.sleep?.asleep })
        summary.averageEfficiency = mean(slice.compactMap { $0.sleep?.efficiency })
        summary.averageSteps = slice.compactMap { $0.activity?.steps }.average
        summary.averageRestingHR = slice.compactMap { $0.restingHeartRate }.average
        summary.averageHRV = slice.compactMap { $0.averageHRV }.average

        summary.trainingMinutes = slice.reduce(0) { $0 + $1.exerciseMinutes }
        summary.metHours = slice.reduce(0.0) { $0 + $1.metHours }
        summary.workoutCount = slice.reduce(0) { $0 + $1.workouts.count }
        summary.bedtimeConsistency = DerivedMetrics.sleepRegularity(days: slice)
        return summary
    }

    // MARK: - Headline

    /// One sentence naming the period's character. Deliberately bland about cause:
    /// the app can describe a week, not explain it.
    var verdict: String {
        guard hasEnoughData, let mean = sleep.mean else { return "Building your picture" }
        if sleep.goodShare ?? 0 >= 0.85 { return "A strong period" }
        if (sleep.goodShare ?? 0) >= 0.6 { return "A steady period" }
        if mean >= 55 { return "An uneven period" }
        return "A difficult period"
    }

    /// What to tell the reader about the weakest metric, or `nil` when there is
    /// nothing clearly weak.
    var weakest: (title: String, value: Int)? {
        let candidates: [(String, Int)] = [
            ("Sleep", sleep.mean), ("Readiness", readiness.mean),
            ("Activity", activity.mean),
        ].compactMap { title, value in value.map { (title, $0) } }
        guard let lowest = candidates.min(by: { $0.1 < $1.1 }), lowest.1 < 70 else { return nil }
        return lowest
    }
}

// MARK: - Helpers

private func mean(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
}

extension Array where Element == Int {
    /// Rounded, and `nil` when empty so an absent metric never renders as zero.
    var average: Int? {
        guard !isEmpty else { return nil }
        return Int((Double(reduce(0, +)) / Double(count)).rounded())
    }
}
