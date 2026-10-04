import XCTest
@testable import LuckRingDemo

/// Sleep sessions are rebuilt from a flat transition list. This is where the two
/// real bugs in the first version lived, so it gets exercised hard.
final class SleepSessionTests: XCTestCase {

    private let cal = Calendar.current

    private func t(_ offsetHours: Double, from base: Date) -> Date {
        base.addingTimeInterval(offsetHours * 3600)
    }

    private var tonight: Date { cal.startOfDay(for: Date()) }

    // MARK: - Assembly

    func testSimpleNightIsAssembled() {
        let b = tonight.addingTimeInterval(23 * 3600)
        let session = SleepSession.assemble(from: [
            SleepTransition(time: b, stage: .start),
            SleepTransition(time: t(1, from: b), stage: .deep),
            SleepTransition(time: t(2, from: b), stage: .light),
            SleepTransition(time: t(7, from: b), stage: .awake),
        ])

        XCTAssertNotNil(session)
        XCTAssertEqual(session!.start, b)
        XCTAssertEqual(session!.end, t(7, from: b))
        XCTAssertEqual(session!.duration, 7 * 3600, accuracy: 0.5)
        XCTAssertEqual(session!.time(.deep), 3600, accuracy: 0.5)
        XCTAssertEqual(session!.time(.light), 5 * 3600, accuracy: 0.5)
        XCTAssertEqual(session!.time(.awake), 0, accuracy: 0.5, "the final awake marker closes, it does not occupy time")
    }

    /// The regression: an early awakening must not be mistaken for the end of the
    /// night. The first implementation took the first SLEEP_WAKEUP and reported a
    /// 7h night as ~1h in bed.
    func testEarlyAwakeningDoesNotTruncateTheNight() {
        let b = tonight.addingTimeInterval(23 * 3600)
        let session = SleepSession.assemble(from: [
            SleepTransition(time: b, stage: .start),
            SleepTransition(time: t(0.4, from: b), stage: .light),
            SleepTransition(time: t(0.5, from: b), stage: .awake),   // brief arousal
            SleepTransition(time: t(0.9, from: b), stage: .deep),
            SleepTransition(time: t(6.5, from: b), stage: .light),
            SleepTransition(time: t(7.6, from: b), stage: .awake),   // real wake-up
        ])

        XCTAssertNotNil(session)
        XCTAssertEqual(session!.duration, 7.6 * 3600, accuracy: 0.5)
        XCTAssertGreaterThan(session!.asleep, session!.time(.awake))
        XCTAssertLessThanOrEqual(session!.asleep, session!.duration + 0.5,
                                 "asleep can never exceed time in bed")
    }

    func testCrossesMidnight() {
        let b = tonight.addingTimeInterval(23.5 * 3600)
        let end = cal.date(byAdding: .hour, value: 7, to: b)!
        XCTAssertNotEqual(cal.component(.day, from: b), cal.component(.day, from: end))

        let session = SleepSession.assemble(from: [
            SleepTransition(time: b, stage: .start),
            SleepTransition(time: end.addingTimeInterval(-3600), stage: .light),
            SleepTransition(time: end, stage: .awake),
        ])
        XCTAssertEqual(session!.duration, 7 * 3600, accuracy: 0.5)
    }

    /// Packets can arrive out of order; the assembler sorts them.
    func testOutOfOrderTransitionsAreSorted() {
        let b = tonight.addingTimeInterval(23 * 3600)
        let session = SleepSession.assemble(from: [
            SleepTransition(time: t(7, from: b), stage: .awake),
            SleepTransition(time: b, stage: .start),
            SleepTransition(time: t(2, from: b), stage: .deep),
            SleepTransition(time: t(6, from: b), stage: .light),
        ])
        XCTAssertEqual(session!.duration, 7 * 3600, accuracy: 0.5)
        XCTAssertEqual(session!.time(.deep), 4 * 3600, accuracy: 0.5)
    }

    func testDuplicateTimestampsAreIgnored() {
        let b = tonight.addingTimeInterval(23 * 3600)
        let session = SleepSession.assemble(from: [
            SleepTransition(time: b, stage: .start),
            SleepTransition(time: t(2, from: b), stage: .deep),
            SleepTransition(time: t(2, from: b), stage: .deep),   // duplicate
            SleepTransition(time: t(7, from: b), stage: .awake),
        ])
        XCTAssertEqual(session!.duration, 7 * 3600, accuracy: 0.5)
        XCTAssertEqual(session!.time(.deep), 5 * 3600, accuracy: 0.5, "zero-length interval must be dropped")
    }

    /// Stage intervals cover the classified part of the night, which is at most
    /// the whole session: the device never reports the moment of falling asleep.
    func testStageIntervalsNeverExceedSessionDuration() {
        let b = tonight.addingTimeInterval(22.8 * 3600)
        let session = SleepSession.assemble(from: [
            SleepTransition(time: b, stage: .start),
            SleepTransition(time: t(0.5, from: b), stage: .deep),
            SleepTransition(time: t(1.5, from: b), stage: .awake),
            SleepTransition(time: t(2.0, from: b), stage: .rem),
            SleepTransition(time: t(5.0, from: b), stage: .light),
            SleepTransition(time: t(7.2, from: b), stage: .awake),
        ])!
        let summed = session.intervals.reduce(0) { $0 + $1.duration }
        XCTAssertLessThanOrEqual(summed, session.duration + 0.5)
        // Whatever the stages do not cover is treated as asleep, never as awake.
        XCTAssertGreaterThan(session.asleep, 0)
        XCTAssertEqual(session.asleep + session.time(.awake), session.duration, accuracy: 0.5)
    }

    // MARK: - Degenerate input

    func testNoTransitionsIsNil() {
        XCTAssertNil(SleepSession.assemble(from: []))
    }

    func testSingleTransitionIsNil() {
        XCTAssertNil(SleepSession.assemble(from: [SleepTransition(time: Date(), stage: .start)]))
    }

    func testStartAfterWakeIsRejected() {
        let b = tonight.addingTimeInterval(23 * 3600)
        XCTAssertNil(SleepSession.assemble(from: [
            SleepTransition(time: b, stage: .start),
            SleepTransition(time: t(-1, from: b), stage: .awake),  // before the start
        ]))
    }

    /// A trailing SLEEP_WAKEUP is the session close marker and occupies no time,
    /// so a night with no mid-session arousal is legitimately 100% efficient.
    func testNightWithoutMidSessionAwakeIsFullyEfficient() {
        let b = tonight.addingTimeInterval(23 * 3600)
        let s = SleepSession.assemble(from: [
            SleepTransition(time: b, stage: .start),
            SleepTransition(time: t(2, from: b), stage: .deep),
            SleepTransition(time: t(8, from: b), stage: .light),
            SleepTransition(time: t(8, from: b), stage: .awake),
        ])!
        XCTAssertEqual(s.time(.awake), 0, accuracy: 0.5, "the close marker is not an awake period")
        XCTAssertEqual(s.efficiency, 1.0, accuracy: 0.01)
    }

    /// A stage transition holds until the *next* one, so a single arousal marker
    /// means "awake from here until we drop back into a stage".
    func testAwakeRunsUntilTheNextStageTransition() {
        let b = tonight.addingTimeInterval(23 * 3600)
        let s = SleepSession.assemble(from: [
            SleepTransition(time: b, stage: .start),
            SleepTransition(time: t(2, from: b), stage: .deep),
            SleepTransition(time: t(3, from: b), stage: .awake),
            SleepTransition(time: t(4, from: b), stage: .light),
            SleepTransition(time: t(8, from: b), stage: .awake),
        ])!
        XCTAssertEqual(s.time(.awake), 3600, accuracy: 0.5)
        XCTAssertEqual(s.time(.deep), 3600, accuracy: 0.5)
        XCTAssertEqual(s.time(.light), 4 * 3600, accuracy: 0.5)
        XCTAssertLessThan(s.efficiency, 1)
        XCTAssertEqual(s.asleep, 7 * 3600, accuracy: 0.5)
    }

    func testEfficiencyIsClampedToUnitRange() {
        let b = tonight.addingTimeInterval(23 * 3600)
        let s = SleepSession.assemble(from: [
            SleepTransition(time: b, stage: .start),
            SleepTransition(time: t(2, from: b), stage: .deep),
            SleepTransition(time: t(3, from: b), stage: .awake),
            SleepTransition(time: t(8, from: b), stage: .light),
            SleepTransition(time: t(8.01, from: b), stage: .awake),
        ])!
        XCTAssertTrue((0...1).contains(s.efficiency))
        XCTAssertGreaterThan(s.efficiency, 0)
        XCTAssertLessThan(s.efficiency, 1)
    }

    func testZeroDurationSessionIsRejected() {
        let now = Date()
        XCTAssertNil(SleepSession.assemble(from: [
            SleepTransition(time: now, stage: .start),
            SleepTransition(time: now, stage: .awake),
        ]))
    }
}

// MARK: - Ingestion

@MainActor
final class HealthStoreIngestionTests: XCTestCase {

    private func makeStore() -> HealthStore {
        HealthStore(bridge: DemoRingBridge())
    }

    func testHeartRatesLandInTheRightDayBucket() {
        let store = makeStore()
        // Anchored to local noon, not `Date()`. Sampling relative to the current
        // instant made this test time-of-day dependent: run near midnight and the
        // two readings straddle a day boundary and it fails.
        let noon = Calendar.current.date(
            bySettingHour: 12, minute: 0, second: 0, of: Date())!
        store.ingest([
            .heartRate(HeartRateSample(time: noon, bpm: 61)),
            .heartRate(HeartRateSample(time: noon.addingTimeInterval(3600), bpm: 58)),
        ])
        XCTAssertEqual(store.days.count, 1)
        XCTAssertEqual(store.days[0].heartRate.count, 2)
    }

    func testReadingsEitherSideOfMidnightSplitIntoTwoBuckets() {
        let store = makeStore()
        let midnight = Calendar.current.startOfDay(for: Date())
        store.ingest([
            .heartRate(HeartRateSample(time: midnight.addingTimeInterval(-60), bpm: 55)),
            .heartRate(HeartRateSample(time: midnight.addingTimeInterval(60), bpm: 62)),
        ])
        XCTAssertEqual(store.days.count, 2)
        XCTAssertEqual(store.days.first?.heartRate.first?.bpm, 55)
        XCTAssertEqual(store.days.last?.heartRate.first?.bpm, 62)
    }

    func testRecordsOnDifferentDaysCreateSeparateBuckets() {
        let store = makeStore()
        let now = Date()
        let yesterday = cal_day(now, -1)
        store.ingest([
            .heartRate(HeartRateSample(time: now, bpm: 61)),
            .heartRate(HeartRateSample(time: yesterday, bpm: 55)),
        ])
        XCTAssertEqual(store.days.count, 2)
        // `days` is ascending, so yesterday is first and today is last.
        XCTAssertEqual(store.days.first?.heartRate.first?.bpm, 55)
        XCTAssertEqual(store.days.last?.heartRate.first?.bpm, 61)
    }

    func testDeviceRecordsWithoutTimestampsStillApply() {
        let store = makeStore()
        store.ingest([.battery(42), .deviceInfo("Ring A1B2", "1.9.9")])
        XCTAssertEqual(store.batteryPercent, 42)
        XCTAssertEqual(store.ringName, "Ring A1B2")
        XCTAssertEqual(store.firmware, "1.9.9")
        XCTAssertTrue(store.days.isEmpty, "device-level records must not create a day bucket")
    }

    func testBaselineIsRecomputedAfterIngestion() {
        let store = makeStore()
        for offset in 0..<3 {
            let day = cal_day(Date(), -offset)
            store.ingest([
                .hrv(HRVSample(time: day.addingTimeInterval(3 * 3600), ms: 50)),
                .heartRate(HeartRateSample(time: day.addingTimeInterval(3 * 3600), bpm: 55)),
            ])
        }
        XCTAssertNotNil(store.baseline)
        XCTAssertEqual(store.baseline?.averageHRV, 50)
    }

    func testDuplicateIngestionDoesNotDuplicateDays() {
        let store = makeStore()
        let now = Date()
        for _ in 0..<5 {
            store.ingest([.heartRate(HeartRateSample(time: now, bpm: 60))])
        }
        XCTAssertEqual(store.days.count, 1)
        XCTAssertEqual(store.days[0].heartRate.count, 5)
    }

    func testSleepTransitionsRebuildTheSessionOnEachPacket() {
        let store = makeStore()
        let base = Calendar.current.startOfDay(for: Date()).addingTimeInterval(23 * 3600)
        store.ingest([.sleepTransition(base, .start)])
        // A lone start marker is not a session yet: there is no stage and no end.
        XCTAssertNil(store.days.first?.sleep)

        store.ingest([.sleepTransition(base.addingTimeInterval(3600), .deep)])
        store.ingest([.sleepTransition(base.addingTimeInterval(7 * 3600), .awake)])
        let sleep = store.days.first?.sleep
        XCTAssertNotNil(sleep)
        XCTAssertEqual(sleep!.duration, 7 * 3600, accuracy: 1)
    }

    /// Regression: a night starting before midnight used to be split across two
    /// day buckets, so no session ever assembled and every night read as missing.
    func testNightCrossingMidnightStaysInOneBucket() {
        let store = makeStore()
        let base = Calendar.current.startOfDay(for: Date()).addingTimeInterval(23.5 * 3600)
        let afterMidnight = base.addingTimeInterval(3600)      // 00:30 next day

        store.ingest([.sleepTransition(base, .start)])
        store.ingest([.sleepTransition(afterMidnight, .deep)])
        store.ingest([.sleepTransition(afterMidnight.addingTimeInterval(6 * 3600), .awake)])

        XCTAssertEqual(store.days.count, 1, "one night must produce exactly one bucket")
        let sleep = store.days.first?.sleep
        XCTAssertNotNil(sleep)
        XCTAssertEqual(sleep!.duration, 7 * 3600, accuracy: 1)
        XCTAssertEqual(sleep!.time(.deep), 6 * 3600, accuracy: 1)
    }

    func testTwoNightsProduceTwoBuckets() {
        let store = makeStore()
        let cal = Calendar.current
        let night1 = cal.startOfDay(for: Date()).addingTimeInterval(23 * 3600)
        let night2 = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
            .addingTimeInterval(23 * 3600)

        store.ingest([.sleepTransition(night1, .start)])
        store.ingest([.sleepTransition(night1.addingTimeInterval(7 * 3600), .awake)])
        store.ingest([.sleepTransition(night2, .start)])
        store.ingest([.sleepTransition(night2.addingTimeInterval(7 * 3600), .awake)])

        XCTAssertEqual(store.days.count, 2)
        for day in store.days {
            XCTAssertEqual(day.sleep?.duration ?? 0, 7 * 3600, accuracy: 1)
        }
    }

    func testDemoDataSatisfiesInvariants() {
        let store = makeStore()
        store.loadDemoData()
        // The count is a named constant now; asserting against it keeps this test
        // about the invariants rather than about how much demo data exists.
        XCTAssertEqual(store.days.count, DemoDay.historyDays)
        XCTAssertNotNil(store.baseline)

        for d in store.days {
            if let s = d.sleep {
                XCTAssertLessThanOrEqual(s.asleep, s.duration + 1, "asleep exceeded time in bed")
                XCTAssertTrue((0...1).contains(s.efficiency))
                let summed = s.intervals.reduce(0) { $0 + $1.duration }
                XCTAssertLessThanOrEqual(summed, s.duration + 2,
                                         "stage intervals cannot exceed the session")
                XCTAssertEqual(s.asleep + s.time(.awake), s.duration, accuracy: 1,
                               "asleep plus awake must account for the whole session")
                XCTAssertGreaterThan(s.time(.deep), 0, "every generated night has deep sleep")
                XCTAssertGreaterThan(s.time(.light), 0, "every generated night has light sleep")
            }
            let scores = ScoreEngine.activity(for: d, goals: store.goals).total
            XCTAssertTrue((0...100).contains(scores))
        }
    }

    func testDemoScoresSpanARealisticRange() {
        // Guards against the first version, where every generated night scored
        // 72-78 and the trend chart was a flat line.
        let store = makeStore()
        store.loadDemoData()
        var scores: [Int] = []
        for offset in 0..<400 {
            var rng = SeededGenerator(seed: UInt64(offset) &+ 1)
            let d = DemoDay.make(date: Date().addingTimeInterval(Double(-offset) * 86400), rng: &rng)
            scores.append(ScoreEngine.sleep(for: d, goals: store.goals, baseline: nil).total)
        }
        XCTAssertLessThan(scores.min()!, 65, "demo data needs genuinely bad nights")
        XCTAssertGreaterThan(scores.max()! - scores.min()!, 15, "demo data needs visible variation")
    }

    // MARK: - Helpers

    private func cal_day(_ base: Date, _ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: base)!
    }
}