import XCTest
@testable import LuckRingDemo

/// Period summaries are where averages get laundered into claims. The tests are
/// concentrated on the ways that goes wrong: averaging in days that recorded
/// nothing, presenting a mean over too few days, and letting one outlier define
/// the headline.
final class PeriodSummaryTests: XCTestCase {

    private var calendar: Calendar { Calendar.current }
    private let goals = Goals()

    /// Readiness awards up to 50 of its 100 points for HRV and resting rate being
    /// at or better than the wearer's own baseline. Without one it is capped near
    /// 70 by design, so any test about readiness strength needs a real baseline.
    private func baseline(hrv: Int = 60, restingHR: Int = 55,
                          skinTemp: Double = 33.8) -> Baseline {
        Baseline(averageBedtimeMinutes: 23 * 60, averageHRV: hrv,
                 averageRestingHR: restingHR, averageSkinTemp: skinTemp)
    }

    /// Day `offset` days before today, oldest first when offsets count up.
    private func day(_ offset: Int, sleepHours: Double? = nil,
                     steps: Int? = nil, restingHR: Int? = nil,
                     hrv: Int? = nil, exercise: Int = 0) -> DailySnapshot {
        var d = DailySnapshot(date: calendar.startOfDay(for: Date())
            .addingTimeInterval(Double(offset) * 86400))
        if let sleepHours {
            let start = d.date.addingTimeInterval(23 * 3600)
            d.sleep = SleepSession(start: start,
                                   end: start.addingTimeInterval(sleepHours * 3600),
                                   intervals: [])
        }
        if let steps {
            d.activity = ActivitySummary(date: d.date, steps: steps,
                                         distanceMetres: Int(Double(steps) * 0.7),
                                         activeSeconds: 3000, calories: 400)
        }
        if let restingHR {
            d.heartRate = [HeartRateSample(time: d.date.addingTimeInterval(4 * 3600),
                                          bpm: restingHR)]
        }
        if let hrv {
            d.hrv = [HRVSample(time: d.date.addingTimeInterval(4 * 3600), ms: hrv)]
        }
        // Exercise minutes are derived from the log, not stored on the day.
        if exercise > 0 {
            d.workoutLog = [Workout(kind: .run,
                                    start: d.date.addingTimeInterval(9 * 3600),
                                    end: d.date.addingTimeInterval(
                                        Double(9 * 3600 + exercise * 60)),
                                    calories: exercise * 8)]
        }
        return d
    }

    // MARK: - Windows

    func testWindowTakesTheMostRecentDays() {
        let days = (0..<10).map { day(-$0, sleepHours: 7) }
        let summary = PeriodSummary.make(from: days, goals: goals, baseline: nil,
                                         window: 3)
        XCTAssertEqual(summary.requestedDays, 3)
        XCTAssertEqual(summary.sleep.count, 3)
    }

    func testInputOrderDoesNotMatter() {
        let days = (0..<5).map { day(-$0, sleepHours: 7) }.reversed()
        let summary = PeriodSummary.make(from: Array(days), goals: goals,
                                         baseline: nil, window: 5)
        XCTAssertEqual(summary.sleep.count, 5)
        XCTAssertEqual(summary.sleep.best?.value, summary.sleep.worst?.value,
                       "identical days should produce an identical spread")
    }

    func testPointsAreOldestFirst() {
        let days = (0..<4).map { day(-$0, sleepHours: 7) }
        let summary = PeriodSummary.make(from: days, goals: goals, baseline: nil,
                                         window: 4)
        let dates = summary.sleep.points.map(\.day.date)
        XCTAssertEqual(dates, dates.sorted())
    }

    // MARK: - Absent days

    /// The core honesty rule: a day with no sleep record contributes nothing to the
    /// sleep average. Including it as zero would turn two good nights into a
    /// five-night average of a third of that.
    func testDaysWithoutSleepDoNotPullTheSleepAverageDown() {
        let withSleep = (0..<2).map { day(-$0, sleepHours: 8, steps: 9000) }
        let without = (2..<5).map { day(-$0, steps: 9000) }
        let summary = PeriodSummary.make(from: withSleep + without, goals: goals,
                                         baseline: nil, window: 5)

        XCTAssertEqual(summary.sleep.count, 2, "only two nights recorded")
        XCTAssertEqual(summary.averageSleepSeconds ?? 0, 8 * 3600, accuracy: 1,
                       "average must be over the recorded nights only")
        XCTAssertEqual(summary.coveredDays, 5)
        XCTAssertEqual(summary.coverageNote, "Based on 5 of 5 days")
    }

    func testAverageIsNilRatherThanZeroWhenNothingRecorded() {
        let summary = PeriodSummary.make(from: [day(0, steps: 5000)], goals: goals,
                                         baseline: nil, window: 7)
        XCTAssertNil(summary.averageSleepSeconds)
        XCTAssertNil(summary.averageEfficiency)
        XCTAssertNil(summary.averageRestingHR)
        XCTAssertNil(summary.averageHRV)
        XCTAssertEqual(summary.averageSteps, 5000, "steps did exist")
    }

    func testActivitySpreadIgnoresDaysWithoutActivity() {
        let days = [
            day(0, steps: 4000),
            day(-1, steps: 6000),
            day(-2),                 // sleep only, no activity
            day(-3),
        ]
        let summary = PeriodSummary.make(from: days, goals: goals, baseline: nil,
                                         window: 4)
        XCTAssertEqual(summary.activity.count, 2)
        XCTAssertEqual(summary.activity.mean, expectedActivityMean(summarising: [4000, 6000]))
    }

    private func expectedActivityMean(summarising steps: [Int]) -> Int {
        // Delegates to the engine so the expectation cannot drift from the
        // implementation it is checking.
        let scores = steps.map { value -> Int in
            var d = DailySnapshot(date: Date())
            d.activity = ActivitySummary(date: d.date, steps: value,
                                         distanceMetres: Int(Double(value) * 0.7),
                                         activeSeconds: 3000, calories: 400)
            return ScoreEngine.activity(for: d, goals: goals).total
        }
        return scores.reduce(0, +) / scores.count
    }

    // MARK: - Spread

    func testMedianResistsASingleBadNight() {
        var spread = PeriodSummary.Spread()
        spread.points = [
            (day(0, sleepHours: 8), 90), (day(-1, sleepHours: 8), 90),
            (day(-2, sleepHours: 8), 88), (day(-3, sleepHours: 1), 5),
        ]
        // A mean would be dragged to ~68; the median should hold near the good nights.
        XCTAssertEqual(spread.median, 89)
        XCTAssertEqual(spread.worst?.value, 5)
        XCTAssertEqual(spread.best?.value, 90)
        XCTAssertEqual(spread.range, 85)
    }

    func testEvenCountMedianAveragesTheMiddlePair() {
        var spread = PeriodSummary.Spread()
        spread.points = [(day(0), 80), (day(-1), 60)]
        XCTAssertEqual(spread.median, 70)
    }

    func testDeviationNeedsMoreThanOnePoint() {
        var single = PeriodSummary.Spread()
        single.points = [(day(0), 80)]
        XCTAssertNil(single.deviation, "a spread of one value is not zero, it is unknown")

        var pair = PeriodSummary.Spread()
        pair.points = [(day(0), 80), (day(-1), 60)]
        XCTAssertEqual(pair.deviation ?? 0, 10, accuracy: 0.001)
    }

    func testIdenticalDaysHaveZeroDeviation() {
        var spread = PeriodSummary.Spread()
        spread.points = [(day(0), 77), (day(-1), 77), (day(-2), 77)]
        XCTAssertEqual(spread.deviation ?? 1, 0, accuracy: 0.0001)
    }

    func testGoodShareCountsFromSeventyUp() {
        var spread = PeriodSummary.Spread()
        spread.points = [(day(0), 70), (day(-1), 69), (day(-2), 85), (day(-3), 95)]
        XCTAssertEqual(spread.goodShare ?? 0, 0.75, accuracy: 0.0001,
                       "70 counts as good, 69 does not")
    }

    func testEmptySpreadReportsNothingRatherThanZero() {
        let spread = PeriodSummary.Spread()
        XCTAssertNil(spread.mean)
        XCTAssertNil(spread.median)
        XCTAssertNil(spread.range)
        XCTAssertNil(spread.deviation)
        XCTAssertNil(spread.goodShare)
        XCTAssertTrue(spread.isEmpty)
    }

    // MARK: - Honesty about thin data

    func testTooFewDaysIsNotEnough() {
        let summary = PeriodSummary.make(from: [day(0, sleepHours: 8),
                                                day(-1, sleepHours: 7)],
                                         goals: goals, baseline: nil, window: 7)
        XCTAssertFalse(summary.hasEnoughData)
        XCTAssertEqual(summary.verdict, "Building your picture")
    }

    func testThreeDaysIsEnough() {
        let summary = PeriodSummary.make(from: (0..<3).map { day(-$0, sleepHours: 8) },
                                         goals: goals, baseline: nil, window: 7)
        XCTAssertTrue(summary.hasEnoughData)
        XCTAssertNotEqual(summary.verdict, "Building your picture")
    }

    func testCoverageNoteDistinguishesEmptyFromPartial() {
        XCTAssertEqual(PeriodSummary().coverageNote, "No days recorded")

        let partial = PeriodSummary.make(from: [day(0, sleepHours: 7)], goals: goals,
                                         baseline: nil, window: 7)
        XCTAssertEqual(partial.coverageNote, "Based on 1 day")

        let full = PeriodSummary.make(from: (0..<7).map { day(-$0, sleepHours: 7) },
                                      goals: goals, baseline: nil, window: 7)
        XCTAssertEqual(full.coverageNote, "Based on 7 of 7 days")
    }

    func testNoDataAtAllProducesAnEmptySummary() {
        let summary = PeriodSummary.make(from: [], goals: goals, baseline: nil,
                                         window: 30)
        XCTAssertEqual(summary.coveredDays, 0)
        XCTAssertNil(summary.averageSteps)
        XCTAssertEqual(summary.trainingMinutes, 0)
        XCTAssertEqual(summary.workoutCount, 0)
        XCTAssertFalse(summary.hasEnoughData)
        XCTAssertEqual(summary.verdict, "Building your picture")
    }

    // MARK: - Headline

    func testWeakestNamesOnlyMetricsBelowSeventy() {
        // Strong sleep and a real baseline, but almost no movement: the summary
        // should point at activity rather than at whichever number came lowest.
        let days = (0..<4).map { day(-$0, sleepHours: 8, steps: 300,
                                     restingHR: 55, hrv: 60) }
        let summary = PeriodSummary.make(from: days, goals: goals,
                                         baseline: baseline(), window: 4)
        XCTAssertGreaterThan(summary.sleep.mean ?? 0, 70)
        XCTAssertGreaterThan(summary.readiness.mean ?? 0, 70)
        XCTAssertEqual(summary.weakest?.title, "Activity")
    }

    func testWeakestIsSilentWhenNothingIsWeak() {
        let days = (0..<4).map { day(-$0, sleepHours: 8, steps: 12000,
                                     restingHR: 54, hrv: 62) }
        let summary = PeriodSummary.make(from: days, goals: goals,
                                         baseline: baseline(), window: 4)
        XCTAssertNil(summary.weakest, "nothing below 70, so nothing to warn about")
    }

    /// Readiness genuinely is capped low without a baseline — it cannot call HRV
    /// "down" without knowing what normal is. That is the honest behaviour, and it
    /// is why the summary must not treat a missing baseline as a good period.
    func testReadinessStaysLowWithoutABaseline() {
        let days = (0..<7).map { day(-$0, sleepHours: 8, steps: 12000,
                                     restingHR: 50, hrv: 80) }
        let withBaseline = PeriodSummary.make(from: days, goals: goals,
                                              baseline: baseline(), window: 7)
        let without = PeriodSummary.make(from: days, goals: goals,
                                         baseline: nil, window: 7)
        XCTAssertGreaterThan(withBaseline.readiness.mean ?? 0,
                             without.readiness.mean ?? 0)
        XCTAssertLessThan(without.readiness.mean ?? 100, 75)
    }

    // MARK: - Training

    func testTrainingTotalsSumTheWindow() {
        let days = (0..<4).map { day(-$0, sleepHours: 7, exercise: 30) }
        let summary = PeriodSummary.make(from: days, goals: goals, baseline: nil,
                                         window: 4)
        XCTAssertEqual(summary.trainingMinutes, 120)
    }

    // MARK: - Bedtime consistency

    func testBedtimeConsistencyReusesTheCircularDefinition() {
        // Two nearly identical bedtimes should score as consistent.
        var a = DailySnapshot(date: calendar.startOfDay(for: Date()))
        a.sleep = SleepSession(start: Date().addingTimeInterval(-23 * 3600),
                               end: Date(), intervals: [])
        var b = DailySnapshot(date: calendar.startOfDay(for: Date()).addingTimeInterval(-86400))
        b.sleep = SleepSession(start: Date().addingTimeInterval(-47 * 3600),
                               end: Date().addingTimeInterval(-86400), intervals: [])

        let summary = PeriodSummary.make(from: [a, b], goals: goals, baseline: nil,
                                         window: 2)
        guard let value = summary.bedtimeConsistency else { return }
        // Cross-midnight bedtimes must not be scored as 23 hours apart.
        XCTAssertGreaterThan(value, 0.9)
    }
}
