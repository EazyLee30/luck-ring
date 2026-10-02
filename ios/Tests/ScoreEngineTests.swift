import XCTest
@testable import LuckRingDemo

/// Score engine contract. These are the numbers the whole UI hangs off, so they
/// get asserted rather than eyeballed.
final class ScoreEngineTests: XCTestCase {

    private let goals = Goals(stepTarget: 8000, sleepTargetMinutes: 450, activeMinutesTarget: 30)

    // MARK: - Helpers

    private func day(
        sleepHours: Double? = nil,
        efficiency: Double? = nil,
        deepRatio: Double? = nil,
        steps: Int = 0,
        distance: Int = 0,
        activeMinutes: Int = 0,
        calories: Int = 0,
        rhr: Int? = nil,
        hrv: Int? = nil,
        tempC: Double? = nil,
        offsetDays: Int = 0
    ) -> DailySnapshot {
        var d = DailySnapshot(date: Date().addingTimeInterval(Double(offsetDays) * 86400))
        if let sleepHours {
            let start = d.date.addingTimeInterval(23 * 3600)
            d.sleep = SleepSession(start: start, end: start.addingTimeInterval(sleepHours * 3600), intervals: [])
        }
        if let efficiency, let sleepHours {
            // Backfill intervals so the session's derived ratios match the intent.
            let asleep = sleepHours * 3600 * efficiency
            let awake = sleepHours * 3600 - asleep
            d.sleep?.intervals = [
                SleepInterval(stage: .deep, start: d.date.addingTimeInterval(23 * 3600),
                              end: d.date.addingTimeInterval(23 * 3600 + asleep * 0.25)),
                SleepInterval(stage: .light, start: d.date.addingTimeInterval(23 * 3600 + asleep * 0.25),
                              end: d.date.addingTimeInterval(23 * 3600 + asleep * 0.75)),
                SleepInterval(stage: .awake, start: d.date.addingTimeInterval(23 * 3600 + asleep * 0.75),
                              end: d.date.addingTimeInterval(23 * 3600 + asleep * 0.75 + awake)),
            ]
        }
        if let deepRatio, let sleepHours {
            let total = sleepHours * 3600
            let asleep = total * (efficiency ?? 0.9)
            d.sleep?.intervals = [
                SleepInterval(stage: .deep, start: d.date.addingTimeInterval(23 * 3600),
                              end: d.date.addingTimeInterval(23 * 3600 + total * deepRatio)),
                SleepInterval(stage: .light, start: d.date.addingTimeInterval(23 * 3600 + total * deepRatio),
                              end: d.date.addingTimeInterval(23 * 3600 + asleep)),
                SleepInterval(stage: .awake, start: d.date.addingTimeInterval(23 * 3600 + asleep),
                              end: d.date.addingTimeInterval(23 * 3600 + total)),
            ]
        }
        d.activity = ActivitySummary(date: d.date, steps: steps, distanceMetres: distance,
                                     activeSeconds: activeMinutes * 60, calories: calories)
        if let rhr { d.heartRate = [HeartRateSample(time: d.date.addingTimeInterval(4 * 3600), bpm: rhr)] }
        if let hrv { d.hrv = [HRVSample(time: d.date.addingTimeInterval(4 * 3600), ms: hrv)] }
        if let tempC { d.temperature = [TemperatureSample(time: d.date.addingTimeInterval(4 * 3600), celsius: tempC)] }
        return d
    }

    // MARK: - Bounds

    func testSleepScoreAlwaysWithinZeroToHundred() {
        // Sweep the input space rather than spot-check, since a weight bug can
        // push the sum past 100 without breaking a single example.
        for hours in stride(from: 0.0, through: 14.0, by: 0.25) {
            for eff in [0.0, 0.4, 0.7, 0.85, 0.95, 1.0, 1.4] {
                for deep in [0.0, 0.05, 0.13, 0.2, 0.35, 0.9] {
                    let d = day(sleepHours: hours, efficiency: eff, deepRatio: deep)
                    let s = ScoreEngine.sleep(for: d, goals: goals, baseline: nil)
                    XCTAssertTrue((0...100).contains(s.total), "sleep \(s.total) out of range")
                    XCTAssertEqual(s.total,
                                   s.durationPoints + s.efficiencyPoints + s.deepPoints + s.timingPoints,
                                   "components must sum to total")
                }
            }
        }
    }

    func testActivityScoreAlwaysWithinZeroToHundred() {
        for steps in [0, 1, 500, 8000, 8001, 40000] {
            for calories in [0, 100, 500, 5000] {
                for minutes in [0, 1, 30, 600] {
                    let d = day(steps: steps, activeMinutes: minutes, calories: calories)
                    let a = ScoreEngine.activity(for: d, goals: goals)
                    XCTAssertTrue((0...100).contains(a.total), "activity \(a.total) out of range")
                    XCTAssertEqual(a.total, a.stepsPoints + a.caloriesPoints + a.activeTimePoints)
                }
            }
        }
    }

    func testReadinessNeverNegativeWhenSignalsAreGood() {
        let baseline = Baseline(averageBedtimeMinutes: 1380, averageHRV: 50,
                                averageRestingHR: 55, averageSkinTemp: 33.2)
        let d = day(sleepHours: 8, efficiency: 0.95, deepRatio: 0.18, rhr: 52, hrv: 58, tempC: 33.2)
        let s = ScoreEngine.sleep(for: d, goals: goals, baseline: baseline).total
        let r = ScoreEngine.readiness(for: d, goals: goals, baseline: baseline, sleepScore: s)
        XCTAssertGreaterThanOrEqual(r.total, 0)
        XCTAssertLessThanOrEqual(r.total, 100)
        XCTAssertEqual(r.total, r.sleepPoints + r.hrvPoints + r.restingHRPoints + r.temperaturePoints)
    }

    // MARK: - Monotonicity

    /// More sleep must never score worse. This is the single most user-visible
    /// property, so assert it across the duration axis.
    func testSleepScoreIsMonotonicInDuration() {
        var previous = -1
        for hours in stride(from: 3.0, through: 11.0, by: 0.5) {
            let d = day(sleepHours: hours, efficiency: 0.92, deepRatio: 0.17)
            let score = ScoreEngine.sleep(for: d, goals: goals, baseline: nil).total
            XCTAssertGreaterThanOrEqual(score, previous, "score dropped at \(hours)h")
            previous = score
        }
    }

    func testSleepScoreIsMonotonicInEfficiency() {
        var previous = -1
        for eff in stride(from: 0.5, through: 1.0, by: 0.05) {
            let d = day(sleepHours: 8, efficiency: eff, deepRatio: 0.17)
            let score = ScoreEngine.sleep(for: d, goals: goals, baseline: nil).total
            XCTAssertGreaterThanOrEqual(score, previous, "score dropped at efficiency \(eff)")
            previous = score
        }
    }

    func testActivityScoreIsMonotonicInSteps() {
        var previous = -1
        for steps in stride(from: 0, through: 20000, by: 500) {
            let d = day(steps: steps, distance: steps * 7, activeMinutes: steps / 130, calories: steps / 30)
            let score = ScoreEngine.activity(for: d, goals: goals).total
            XCTAssertGreaterThanOrEqual(score, previous, "score dropped at \(steps) steps")
            previous = score
        }
    }

    /// Above goal, extra steps must not push past 100 or change the score at all.
    func testActivityScoreSaturatesAtGoal() {
        let atGoal = ScoreEngine.activity(for: day(steps: 8000, distance: 5600, activeMinutes: 30, calories: 500),
                                          goals: goals)
        let wayOver = ScoreEngine.activity(for: day(steps: 60000, distance: 42000, activeMinutes: 400, calories: 4000),
                                           goals: goals)
        XCTAssertEqual(atGoal.total, 100)
        XCTAssertEqual(wayOver.total, 100)
    }

    // MARK: - Missing data

    func testEmptyDayScoresZeroNotCrash() {
        let empty = DailySnapshot(date: Date())
        XCTAssertEqual(ScoreEngine.sleep(for: empty, goals: goals, baseline: nil).total, 0)
        XCTAssertEqual(ScoreEngine.activity(for: empty, goals: goals).total, 0)
    }

    func testNoBaselineIsTreatedNotCrashed() {
        // A brand-new wearer has one day and therefore no Baseline. Readiness must
        // still produce a number rather than dividing by a nil average.
        let d = day(sleepHours: 7.5, efficiency: 0.9, rhr: 58, hrv: 40)
        let s = ScoreEngine.sleep(for: d, goals: goals, baseline: nil).total
        let r = ScoreEngine.readiness(for: d, goals: goals, baseline: nil, sleepScore: s)
        XCTAssertTrue((0...100).contains(r.total))
        XCTAssertGreaterThan(r.total, 0)
    }

    // MARK: - Baseline

    func testBaselineAveragesOnlyDaysThatHaveData() {
        let withSleep = [day(sleepHours: 8, offsetDays: -2), day(sleepHours: 8, offsetDays: -1)]
        let b = Baseline.make(from: withSleep)
        XCTAssertNotNil(b)
        XCTAssertNotNil(b?.averageBedtimeMinutes)
        XCTAssertNil(b?.averageHRV, "must not invent an HRV average from absent samples")
        XCTAssertNil(b?.averageRestingHR)
        XCTAssertNil(b?.averageSkinTemp)
    }

    func testBaselineIsNilForASingleDay() {
        XCTAssertNil(Baseline.make(from: [day(sleepHours: 8)]))
        XCTAssertNil(Baseline.make(from: []))
    }

    /// A resting HR below baseline is the good direction and must score at least
    // as well as being exactly at baseline.
    func testLowerRestingHeartRateScoresNoWorse() {
        let baseline = Baseline(averageBedtimeMinutes: 1380, averageHRV: 50,
                                averageRestingHR: 60, averageSkinTemp: 33.2)
        func rhrScore(_ rhr: Int) -> Int {
            let d = day(sleepHours: 8, efficiency: 0.93, rhr: rhr, hrv: 50, tempC: 33.2)
            let s = ScoreEngine.sleep(for: d, goals: goals, baseline: baseline).total
            return ScoreEngine.readiness(for: d, goals: goals, baseline: baseline, sleepScore: s).restingHRPoints
        }
        XCTAssertGreaterThanOrEqual(rhrScore(52), rhrScore(60))
        XCTAssertGreaterThanOrEqual(rhrScore(60), rhrScore(70))
        XCTAssertEqual(rhrScore(50), 15, "well below baseline should max the term")
    }

    /// HRV above baseline must not be punished, and a floor value must not divide
    /// by zero.
    func testHRVBaselineGuardsAgainstZero() {
        let zero = Baseline(averageBedtimeMinutes: nil, averageHRV: 0,
                            averageRestingHR: nil, averageSkinTemp: nil)
        let d = day(sleepHours: 8, efficiency: 0.93, rhr: 55, hrv: 45)
        let s = ScoreEngine.sleep(for: d, goals: goals, baseline: nil).total
        let r = ScoreEngine.readiness(for: d, goals: goals, baseline: zero, sleepScore: s)
        XCTAssertTrue((0...100).contains(r.total))
    }

    // MARK: - Verdict bands

    func testEveryScoreHasAVerdict() {
        for score in stride(from: 0, through: 100, by: 1) {
            XCTAssertFalse(ScoreVerdict.sleep(score).title.isEmpty)
            XCTAssertFalse(ScoreVerdict.readiness(score).detail.isEmpty)
            XCTAssertFalse(ScoreVerdict.activity(score).title.isEmpty)
        }
    }

    /// Band boundaries must not regress: a higher score must never produce a
    /// worse-sounding verdict.
    func testVerdictsImproveWithScore() {
        let ranks = ["Bad", "Poor", "Fair", "Good", "Optimal"]
        for (low, high) in zip(0..<100, 1...100) {
            let a = ranks.firstIndex(of: ScoreVerdict.sleep(low).title) ?? -1
            let b = ranks.firstIndex(of: ScoreVerdict.sleep(high).title) ?? -1
            XCTAssertGreaterThanOrEqual(b, a, "verdict regressed between \(low) and \(high)")
        }
    }
}