import XCTest
@testable import LuckRingDemo

/// Persistence is the layer that fails silently: a dropped write or a lossy
/// round-trip looks fine in the simulator and loses a fortnight of history on
/// device. These assert the bytes actually survive.
final class PersistenceTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("luckring-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func store() -> HistoryStore {
        HistoryStore(baseDirectory: directory)
    }

    // MARK: - Helpers

    private func sampleDay(offsetDays: Int) -> DailySnapshot {
        let cal = Calendar.current
        let date = cal.startOfDay(for: Date())
            .addingTimeInterval(Double(offsetDays) * 86400)

        var day = DailySnapshot(date: date)
        let start = date.addingTimeInterval(23 * 3600)
        day.sleepTransitions = [
            SleepTransition(time: start, stage: .start),
            SleepTransition(time: start.addingTimeInterval(3600), stage: .deep),
            SleepTransition(time: start.addingTimeInterval(3 * 3600), stage: .light),
            SleepTransition(time: start.addingTimeInterval(7 * 3600), stage: .awake),
        ]
        day.sleep = SleepSession.assemble(from: day.sleepTransitions)
        day.activity = ActivitySummary(date: date, steps: 8123, distanceMetres: 5900,
                                        activeSeconds: 2400, calories: 410)
        day.heartRate = [
            HeartRateSample(time: date.addingTimeInterval(4 * 3600), bpm: 54),
            HeartRateSample(time: date.addingTimeInterval(9 * 3600), bpm: 71),
        ]
        day.hrv = [HRVSample(time: date.addingTimeInterval(4 * 3600), ms: 52)]
        day.oxygen = [OxygenSample(time: date.addingTimeInterval(8 * 3600), spo2: 97)]
        day.temperature = [TemperatureSample(time: date.addingTimeInterval(4 * 3600), celsius: 33.4)]
        day.bloodPressure = [BloodPressureSample(time: date.addingTimeInterval(8 * 3600),
                                                  systolic: 118, diastolic: 76)]

        var workout = Workout(kind: .run, start: date.addingTimeInterval(6 * 3600))
        workout.end = date.addingTimeInterval(6.5 * 3600)
        workout.distanceMetres = 5200
        workout.calories = 420
        workout.averageHR = 138
        workout.peakHR = 161
        day.workoutLog = [workout]
        return day
    }

    // MARK: - Round trip

    func testDaysSurviveARoundTrip() throws {
        let history = store()
        let days = [sampleDay(offsetDays: -1), sampleDay(offsetDays: 0)]
        history.save(days: days, goals: Goals())

        // The save is dispatched async; wait for the file rather than sleeping.
        let loaded = waitForLoad(history)
        XCTAssertEqual(loaded.days.count, 2)
        XCTAssertEqual(loaded.days.map(\.stepsOnDay), days.map(\.stepsOnDay))
    }

    func testSleepSessionSurvivesARoundTrip() throws {
        let history = store()
        history.save(days: [sampleDay(offsetDays: 0)], goals: Goals())
        let loaded = waitForLoad(history)

        let sleep = try XCTUnwrap(loaded.days.first?.sleep)
        XCTAssertEqual(sleep.duration, 7 * 3600, accuracy: 1)
        XCTAssertEqual(sleep.time(.deep), 2 * 3600, accuracy: 1)
        XCTAssertEqual(sleep.efficiency, 1.0, accuracy: 0.02)
    }

    func testWorkoutsSurviveARoundTrip() throws {
        let history = store()
        history.save(days: [sampleDay(offsetDays: 0)], goals: Goals())
        let loaded = waitForLoad(history)

        let workouts = try XCTUnwrap(loaded.days.first?.workoutLog)
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts[0].kind, .run)
        XCTAssertEqual(workouts[0].distanceMetres, 5200)
        XCTAssertEqual(workouts[0].calories, 420)
        XCTAssertEqual(workouts[0].averageHR, 138)
        XCTAssertEqual(workouts[0].activeSeconds, 1800)
    }

    func testGoalsSurviveARoundTrip() throws {
        let history = store()
        let goals = Goals(stepTarget: 11000, sleepTargetMinutes: 480, activeMinutesTarget: 45)
        history.save(days: [sampleDay(offsetDays: 0)], goals: goals)
        let loaded = waitForLoad(history)

        XCTAssertEqual(loaded.goals.stepTarget, 11000)
        XCTAssertEqual(loaded.goals.sleepTargetMinutes, 480)
        XCTAssertEqual(loaded.goals.activeMinutesTarget, 45)
    }

    func testVitalsSurviveARoundTrip() throws {
        let history = store()
        history.save(days: [sampleDay(offsetDays: 0)], goals: Goals())
        let day = try XCTUnwrap(waitForLoad(history).days.first)

        XCTAssertEqual(day.restingHeartRate, 62, "integer average of 54 and 71")
        XCTAssertEqual(day.averageHRV, 52)
        XCTAssertEqual(day.averageOxygen, 97)
        XCTAssertEqual(day.latestBloodPressure?.systolic, 118)
        XCTAssertEqual(day.lowestHeartRate, 54)
        XCTAssertEqual(day.highestHeartRate, 71)
    }

    // MARK: - Failure handling

    func testMissingFileYieldsEmptyHistoryRatherThanCrashing() {
        let fresh = store()
        let loaded = fresh.load()
        XCTAssertTrue(loaded.days.isEmpty)
        XCTAssertEqual(loaded.goals.stepTarget, Goals().stepTarget)
    }

    /// A truncated file must not throw, and must not silently replace the good
    /// copy with an empty one.
    func testCorruptFileIsQuarantinedNotOverwritten() throws {
        let history = store()
        let days = [sampleDay(offsetDays: 0)]
        history.save(days: days, goals: Goals())
        _ = waitForLoad(history)

        let url = directory.appendingPathComponent("history.json")
        try Data("{ this is not json".utf8).write(to: url)

        let loaded = history.load()
        XCTAssertTrue(loaded.days.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("history-corrupt.json").path),
                      "the unreadable file should be kept for diagnosis")
    }

    func testEmptyHistoryRoundTrips() {
        let history = store()
        history.save(days: [], goals: Goals())
        let loaded = waitForLoad(history)
        XCTAssertTrue(loaded.days.isEmpty)
    }

    // MARK: - Preferences

    func testShortcutOrderSurvivesARoundTrip() {
        let history = store()
        let order = ["hrv", "heart", "temperature", "oxygen", "activity"]
        history.savePreferences(.init(shortcutOrder: order))

        var loaded = HistoryStore.Preferences()
        for _ in 0..<50 where loaded.shortcutOrder != order {
            loaded = history.loadPreferences()
        }
        XCTAssertEqual(loaded.shortcutOrder, order)
    }

    func testDeleteAllClearsBothFiles() {
        let history = store()
        history.save(days: [sampleDay(offsetDays: 0)], goals: Goals())
        _ = waitForLoad(history)
        history.savePreferences(.init(shortcutOrder: ["heart"]))

        history.deleteAll()
        XCTAssertTrue(history.load().days.isEmpty)
        XCTAssertEqual(history.loadPreferences().shortcutOrder, Shortcut.defaultOrder)
    }

    // MARK: - Store integration

    @MainActor
    func testStoreRestoresWhatItPersisted() {
        let history = HistoryStore(baseDirectory: directory)
        let original = HealthStore(bridge: DemoRingBridge())
        original.ingest([.heartRate(HeartRateSample(time: Date(), bpm: 70)),
                         .battery(55)])
        original.goals.stepTarget = 9500
        original.shortcutOrder = ["hrv", "heart"]
        history.save(days: original.days, goals: original.goals)
        history.savePreferences(.init(shortcutOrder: original.shortcutOrder))

        var loaded: HistoryStore.Preferences = .init()
        for _ in 0..<50 { loaded = history.loadPreferences() }
        XCTAssertEqual(loaded.shortcutOrder, ["hrv", "heart"])
        XCTAssertEqual(history.load().goals.stepTarget, 9500)
    }

    // MARK: - Waiting

    /// Saves are dispatched to a utility queue, so a test cannot read the file
    /// the instant it calls save(). Poll the directory instead of sleeping.
    private func waitForLoad(_ history: HistoryStore,
                             timeout: TimeInterval = 5) -> (days: [DailySnapshot], goals: Goals) {
        let deadline = Date().addingTimeInterval(timeout)
        let url = directory.appendingPathComponent("history.json")
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               let document = try? JSONDecoder.luckRing.decode(
                    HistoryStore.DocumentForTesting.self, from: data) {
                return (document.days, document.goals)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return history.load()
    }
}

private extension DailySnapshot {
    var stepsOnDay: Int { activity?.steps ?? 0 }
}

extension HistoryStore {
    /// Mirror of the private on-disk shape, so tests can read the file without
    /// widening the production type's access level.
    struct DocumentForTesting: Codable {
        var version = 1
        var days: [DailySnapshot] = []
        var goals = Goals()
    }
}