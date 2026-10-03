import XCTest
@testable import LuckRingDemo

/// Derived metrics are the easiest thing in the app to get subtly wrong, because
/// nothing cross-checks them. These assert the guards: the real requirement is
/// that each one returns nil rather than inventing a value.
final class DerivedMetricsTests: XCTestCase {

    private func day(hrv: Int? = nil, rhr: Int? = nil, sleepHours: Double? = nil,
                     at offsetDays: Int = 0) -> DailySnapshot {
        let cal = Calendar.current
        var d = DailySnapshot(date: cal.startOfDay(for: Date())
            .addingTimeInterval(Double(offsetDays) * 86400))
        if let sleepHours {
            let start = d.date.addingTimeInterval(23 * 3600)
            d.sleep = SleepSession(start: start,
                                   end: start.addingTimeInterval(sleepHours * 3600),
                                   intervals: [])
        }
        if let rhr {
            d.heartRate = [HeartRateSample(time: d.date.addingTimeInterval(4 * 3600), bpm: rhr)]
        }
        if let hrv {
            d.hrv = [HRVSample(time: d.date.addingTimeInterval(4 * 3600), ms: hrv)]
        }
        return d
    }

    // MARK: - Respiratory rate

    func testRespiratoryRateNeedsBothInputs() {
        XCTAssertNil(DerivedMetrics.respiratoryRate(hrvMS: nil, restingHR: 55))
        XCTAssertNil(DerivedMetrics.respiratoryRate(hrvMS: 50, restingHR: nil))
        XCTAssertNil(DerivedMetrics.respiratoryRate(hrvMS: 0, restingHR: 55))
        XCTAssertNil(DerivedMetrics.respiratoryRate(hrvMS: 50, restingHR: 0))
    }

    func testRespiratoryRateIsPlausible() {
        let rate = DerivedMetrics.respiratoryRate(hrvMS: 50, restingHR: 55)
        XCTAssertNotNil(rate)
        XCTAssertGreaterThan(rate!, 10)
        XCTAssertLessThan(rate!, 22)
    }

    func testLowerHrvMeansFasterBreathing() {
        let suppressed = DerivedMetrics.respiratoryRate(hrvMS: 25, restingHR: 55)!
        let typical = DerivedMetrics.respiratoryRate(hrvMS: 60, restingHR: 55)!
        XCTAssertGreaterThan(suppressed, typical)
    }

    func testRespiratoryRateStaysInsideClinicalBounds() {
        // Absurd inputs must clamp, not produce 60 brpm.
        for hrv in [1, 5, 20, 40, 80, 200] {
            for hr in [35, 45, 55, 70, 95] {
                let rate = DerivedMetrics.respiratoryRate(hrvMS: hrv, restingHR: hr)!
                XCTAssertTrue((6...28).contains(rate), "\(hrv)/\(hr) gave \(rate)")
            }
        }
    }

    // MARK: - Stress

    func testStressNeedsABaseline() {
        XCTAssertNil(DerivedMetrics.stress(day: day(hrv: 40, rhr: 60), baseline: nil))
    }

    func testBaselineAtYourOwnNumbersIsNoStress() {
        let base = Baseline(averageBedtimeMinutes: nil, averageHRV: 50,
                            averageRestingHR: 55, averageSkinTemp: nil)
        let stress = DerivedMetrics.stress(day: day(hrv: 50, rhr: 55), baseline: base)!
        XCTAssertLessThan(stress, 0.05)
    }

    func testSuppressedMarkersAreHighStress() {
        let base = Baseline(averageBedtimeMinutes: nil, averageHRV: 60,
                            averageRestingHR: 50, averageSkinTemp: nil)
        let stress = DerivedMetrics.stress(day: day(hrv: 28, rhr: 64), baseline: base)!
        XCTAssertGreaterThan(stress, 0.8)
    }

    func testStressStaysInRangeAcrossExtremeInput() {
        let base = Baseline(averageBedtimeMinutes: nil, averageHRV: 50,
                            averageRestingHR: 55, averageSkinTemp: nil)
        for hrv in [5, 25, 50, 120] {
            for hr in [35, 55, 90, 150] {
                let s = DerivedMetrics.stress(day: day(hrv: hrv, rhr: hr), baseline: base)!
                XCTAssertTrue((0...1).contains(s), "\(hrv)/\(hr) gave \(s)")
            }
        }
    }

    /// The dominant signal must not be averaged away: a terrible HRV should still
    /// register even when resting heart rate is perfect.
    func testStressIsNotAveragedAway() {
        let base = Baseline(averageBedtimeMinutes: nil, averageHRV: 60,
                            averageRestingHR: 55, averageSkinTemp: nil)
        let badHRVGoodRHR = DerivedMetrics.stress(day: day(hrv: 25, rhr: 55), baseline: base)!
        XCTAssertGreaterThan(badHRVGoodRHR, 0.7)
    }

    func testStressBandsAreMonotonic() {
        let ranks = ["Low", "Moderate", "High", "Not enough data"]
        let steps = 100
        for i in 0..<steps {
            let low = Double(i) / Double(steps)
            let high = Double(i + 1) / Double(steps)
            let a = ranks.firstIndex(of: DerivedMetrics.stressBand(low).label) ?? 0
            let b = ranks.firstIndex(of: DerivedMetrics.stressBand(high).label) ?? 0
            XCTAssertLessThanOrEqual(a, b)
        }
        XCTAssertEqual(DerivedMetrics.stressBand(nil).label, "Not enough data")
    }

    // MARK: - Cardiovascular

    func testCardiovascularNeedsRestingHeartRate() {
        XCTAssertNil(DerivedMetrics.cardiovascularDeviation(day: day(hrv: 50), baseline: nil))
    }

    func testCardiovascularIsRelativeNotAbsolute() {
        // Documented behaviour: no age is stored, so no absolute figure is given.
        XCTAssertFalse(DerivedMetrics.cardiovascularCaveat.isEmpty)
        let relaxed = DerivedMetrics.cardiovascularDeviation(day: day(hrv: 70, rhr: 52), baseline: nil)
        let strained = DerivedMetrics.cardiovascularDeviation(day: day(hrv: 30, rhr: 68), baseline: nil)
        XCTAssertNotNil(relaxed)
        XCTAssertNotNil(strained)
        XCTAssertGreaterThan(strained!, relaxed!)
    }

    // MARK: - Sleep regularity

    func testRegularityNeedsAtLeastThreeNights() {
        let two = [day(sleepHours: 8, at: -1), day(sleepHours: 8, at: 0)]
        XCTAssertNil(DerivedMetrics.sleepRegularity(days: two))
        XCTAssertNil(DerivedMetrics.sleepRegularity(days: []))
    }

    func testConsistentBedtimesAreFullyRegular() {
        // Same 23:00 every night.
        let days = (0..<5).map { day(sleepHours: 8, at: -$0) }
        let regularity = DerivedMetrics.sleepRegularity(days: days)!
        XCTAssertGreaterThan(regularity, 0.95)
    }

    func testScatteredBedtimesAreIrregular() {
        var days: [DailySnapshot] = []
        for (i, hour) in [23.0, 1.0, 0.5, 2.0, 22.5].enumerated() {
            var d = day(at: -i)
            let start = d.date.addingTimeInterval(hour * 3600)
            d.sleep = SleepSession(start: start,
                                   end: start.addingTimeInterval(7 * 3600), intervals: [])
            days.append(d)
        }
        let regularity = DerivedMetrics.sleepRegularity(days: days)!
        XCTAssertLessThan(regularity, 0.6)
    }

    /// Bedtimes either side of midnight are close together, not twelve hours apart.
    func testBedtimesWrappingMidnightCountAsClose() {
        var days: [DailySnapshot] = []
        for (i, hour) in [23.5, 0.5, 23.75, 0.25].enumerated() {
            var d = day(at: -i)
            let start = d.date.addingTimeComponent(hour)
            d.sleep = SleepSession(start: start,
                                   end: start.addingTimeInterval(7 * 3600), intervals: [])
            days.append(d)
        }
        let regularity = DerivedMetrics.sleepRegularity(days: days)!
        XCTAssertGreaterThan(regularity, 0.9, "23:30 and 00:30 are the same bedtime")
    }

    // MARK: - Recovery debt

    func testRecoveryDebtGrowsWithShortNights() {
        let good = (0..<7).map { day(sleepHours: 8, at: -$0) }
        let poor = (0..<7).map { day(sleepHours: 5, at: -$0) }
        XCTAssertGreaterThan(DerivedMetrics.recoveryDebt(days: poor, goals: Goals()),
                             DerivedMetrics.recoveryDebt(days: good, goals: Goals()))
    }

    func testRecoveryDebtIsBoundedAndZeroWithoutData() {
        let poor = (0..<7).map { day(sleepHours: 2, at: -$0) }
        XCTAssertTrue((0...1).contains(DerivedMetrics.recoveryDebt(days: poor, goals: Goals())))
        XCTAssertEqual(DerivedMetrics.recoveryDebt(days: [], goals: Goals()), 0)
    }
}

private extension Date {
    /// Absolute time-of-day helper that survives a date that is not midnight.
    func addingTimeComponent(_ hours: Double) -> Date {
        Calendar.current.date(bySettingHour: Int(hours),
                              minute: Int((hours - floor(hours)) * 60),
                              second: 0, of: self)!
    }
}