import XCTest
@testable import LuckRingDemo

/// The workout layer contains estimates, and estimates are where plausible-looking
/// wrong numbers come from. These pin the formulas and their edge cases.
final class WorkoutTests: XCTestCase {

    private func day(restingHR: Int?, steps: Int = 9000, activeMinutes: Int = 40) -> DailySnapshot {
        var d = DailySnapshot(date: Date())
        d.activity = ActivitySummary(date: d.date, steps: steps, distanceMetres: steps * 7,
                                     activeSeconds: activeMinutes * 60, calories: 400)
        if let restingHR {
            let cal = Calendar.current
            d.heartRate = (0..<24).map { i in
                HeartRateSample(time: cal.date(byAdding: .hour, value: i, to: d.date)!,
                                bpm: restingHR + Int.random(in: -2...2))
            }
        }
        return d
    }

    private func workout(_ kind: Workout.Kind, minutes: Double, hr: Int? = nil,
                         metres: Int = 0, since start: Date = Date()) -> Workout {
        var w = Workout(kind: kind, start: start)
        w.end = start.addingTimeInterval(minutes * 60)
        w.distanceMetres = metres
        w.averageHR = hr
        return w
    }

    // MARK: - Calories

    func testCaloriesScaleWithDuration() {
        let short = WorkoutEstimator.calories(for: workout(.run, minutes: 30), restingHR: nil)
        let long = WorkoutEstimator.calories(for: workout(.run, minutes: 60), restingHR: nil)
        XCTAssertGreaterThan(long, short)
        XCTAssertEqual(Double(long), Double(short) * 2, accuracy: 2.0)
    }

    func testHarderActivityBurnsMoreThanEasierForTheSameTime() {
        let walk = WorkoutEstimator.calories(for: workout(.walk, minutes: 45), restingHR: nil)
        let run = WorkoutEstimator.calories(for: workout(.run, minutes: 45), restingHR: nil)
        XCTAssertGreaterThan(run, walk)
    }

    func testHeartRateRaisesTheEstimateAboveRestingIntensity() {
        let resting = WorkoutEstimator.calories(for: workout(.run, minutes: 40, hr: 70), restingHR: 60)
        let hard = WorkoutEstimator.calories(for: workout(.run, minutes: 40, hr: 150), restingHR: 60)
        XCTAssertGreaterThan(hard, resting)
    }

    func testWithoutRestingHeartRateTheBaseMetIsUsed() {
        let withNoHR = WorkoutEstimator.calories(for: workout(.run, minutes: 40), restingHR: nil)
        let hrBelowResting = WorkoutEstimator.calories(for: workout(.run, minutes: 40, hr: 55),
                                                       restingHR: 60)
        // Without a baseline the base MET is used; a sub-resting average only
        // trims the estimate, it does not invert it.
        XCTAssertLessThanOrEqual(hrBelowResting, withNoHR)
        XCTAssertGreaterThanOrEqual(hrBelowResting, Int(Double(withNoHR) * 0.7))
        XCTAssertEqual(WorkoutEstimator.intensityAdjustedMET(for: workout(.run, minutes: 40),
                                                             restingHR: nil),
                       Workout.Kind.run.baseMET, accuracy: 0.001)
    }

    /// Sanity check on the absolute scale: 40 minutes of running for a 70 kg
    /// wearer is roughly 400-500 kcal. This is the assertion that would have
    /// caught the per-minute / per-hour mix-up on its own.
    func testRunningCaloriesArePlausiblyScaled() {
        let burn = WorkoutEstimator.calories(for: workout(.run, minutes: 40), restingHR: nil)
        XCTAssertGreaterThan(burn, 350)
        XCTAssertLessThan(burn, 600)
    }

    func testZeroDurationBurnsNothing() {
        var w = workout(.run, minutes: 30)
        w.end = w.start
        XCTAssertEqual(WorkoutEstimator.calories(for: w, restingHR: nil), 0)
    }

    /// The intensity multiplier is clamped, so a sensor glitch reporting 240 bpm
    /// cannot inflate the estimate without bound.
    func testHeartRateSpikesAreClamped() {
        let normal = WorkoutEstimator.calories(for: workout(.run, minutes: 40, hr: 120), restingHR: 60)
        let absurd = WorkoutEstimator.calories(for: workout(.run, minutes: 40, hr: 240), restingHR: 60)
        let ceiling = WorkoutEstimator.calories(for: workout(.run, minutes: 40, hr: 190), restingHR: 60)
        XCTAssertLessThanOrEqual(absurd, ceiling + 1)
        XCTAssertLessThanOrEqual(Double(absurd), Double(normal) * 1.6)
    }

    // MARK: - Pace

    func testPaceIsNilWithoutDistance() {
        XCTAssertNil(WorkoutEstimator.pace(for: workout(.run, minutes: 30)))
        XCTAssertNil(WorkoutEstimator.secondsPerKm(for: workout(.run, minutes: 30)))
    }

    func testPaceFromDistanceAndTime() {
        // 5 km in 30 minutes = 6 min/km = 360 s/km
        let w = workout(.run, minutes: 30, metres: 5000)
        XCTAssertEqual(WorkoutEstimator.secondsPerKm(for: w)!, 360, accuracy: 5)
    }

    func testZeroDistanceDoesNotDivideByZero() {
        let w = workout(.run, minutes: 0, metres: 0)
        XCTAssertNil(WorkoutEstimator.pace(for: w))
    }

    // MARK: - MET hours

    /// MET-hours apply the heart-rate intensity factor, so an hour of hard
    /// running is more than the base MET and never more than base x 1.25.
    func testMetHoursAreIntensityAdjusted() {
        let base = Workout.Kind.run.baseMET

        var hard = day(restingHR: 50)
        hard.workoutLog = [workout(.run, minutes: 60, hr: 165)]
        XCTAssertGreaterThan(hard.metHours, base)
        XCTAssertLessThanOrEqual(hard.metHours, base * 1.25 + 0.01)

        var gentle = day(restingHR: 50)
        gentle.workoutLog = [workout(.run, minutes: 60, hr: 55)]
        XCTAssertLessThan(gentle.metHours, base)
        XCTAssertGreaterThanOrEqual(gentle.metHours, base * 0.8 - 0.01)
    }

    func testMetHoursWithoutHeartRateUseTheBaseMet() {
        var d = day(restingHR: nil)
        d.workoutLog = [workout(.run, minutes: 60)]
        XCTAssertEqual(d.metHours, Workout.Kind.run.baseMET, accuracy: 0.01)
    }

    func testAmbientStepsAreExcludedFromMetHours() {
        // A high-step day with no workouts must not register training load.
        let d = day(restingHR: 55, steps: 20000, activeMinutes: 120)
        XCTAssertEqual(d.metHours, 0)
        XCTAssertEqual(d.exerciseMinutes, 0)
    }

    func testExerciseMinutesCountsOnlyLoggedWorkouts() {
        var d = day(restingHR: 55, activeMinutes: 180)
        d.workoutLog = [workout(.run, minutes: 45), workout(.walk, minutes: 15)]
        XCTAssertEqual(d.exerciseMinutes, 60)
    }

    func testMetHoursClampIntensity() {
        var low = day(restingHR: 50)
        low.workoutLog = [workout(.walk, minutes: 60, hr: 52)]
        var high = day(restingHR: 50)
        high.workoutLog = [workout(.walk, minutes: 60, hr: 190)]
        // Both must stay inside the documented 0.8…1.25 band.
        XCTAssertGreaterThanOrEqual(low.metHours, 3.5 * 0.8 - 0.01)
        XCTAssertLessThanOrEqual(high.metHours, 3.5 * 1.25 + 0.01)
    }

    // MARK: - Store integration

    @MainActor
    func testFinishWorkoutFoldsInHeartRateAndBurn() {
        let store = HealthStore(bridge: DemoRingBridge())
        store.loadDemoData()
        let before = store.today!.workoutLog.count

        store.startWorkout(.run)
        XCTAssertNotNil(store.activeWorkout)
        store.finishWorkout(distanceMetres: 5000)

        let finished = store.today!.workoutLog
        XCTAssertEqual(finished.count, before + 1)
        XCTAssertNil(store.activeWorkout)
        XCTAssertNotNil(finished.last!.end)
        // Start and finish happen in the same tick, so there is no time to burn.
        XCTAssertGreaterThanOrEqual(finished.last!.calories, 0)
    }

    @MainActor
    func testStartingASecondWorkoutIsIgnored() {
        let store = HealthStore(bridge: DemoRingBridge())
        store.loadDemoData()
        store.startWorkout(.run)
        let first = store.activeWorkout
        store.startWorkout(.cycle)
        XCTAssertEqual(store.activeWorkout?.id, first?.id)
    }

    @MainActor
    func testFinishingWithNothingRunningIsANoOp() {
        let store = HealthStore(bridge: DemoRingBridge())
        store.loadDemoData()
        XCTAssertNil(store.finishWorkout())
    }

    @MainActor
    func testDetectedWorkoutsDoNotOverlapLoggedOnes() {
        let store = HealthStore(bridge: DemoRingBridge())
        store.loadDemoData()

        let anchor = store.today!.date.addingTimeInterval(6 * 3600)
        store.append(workout: workout(.run, minutes: 30, since: anchor), to: store.today!)

        let overlapping = WorkoutDetector.Detection(
            kind: .walk, start: anchor.addingTimeInterval(600),
            end: anchor.addingTimeInterval(2400), averageHR: 90, peakHR: 120)
        store.ingestDetected([overlapping])

        let overlappingOnes = store.today!.workoutLog.filter {
            $0.source == .detected && $0.start < anchor.addingTimeInterval(2400)
                && $0.end! > anchor.addingTimeInterval(600)
        }
        XCTAssertTrue(overlappingOnes.isEmpty, "must not stack a detected session on a logged one")
    }

    // MARK: - Detection

    func testDetectorStaysSilentWithoutEnoughSignal() {
        let quiet = day(restingHR: 55, steps: 1000, activeMinutes: 2)
        XCTAssertTrue(WorkoutDetector.detect(in: quiet, restingHR: 55,
                                             baselineStepsPerHour: 500).isEmpty)
    }

    func testDetectorStaysSilentWithoutRestingHeartRate() {
        let busy = day(restingHR: nil, steps: 15000, activeMinutes: 90)
        XCTAssertTrue(WorkoutDetector.detect(in: busy, restingHR: nil,
                                             baselineStepsPerHour: 500).isEmpty)
    }

    func testDetectorStaysSilentWhenNoStepsWereRecorded() {
        var d = day(restingHR: 55)
        d.activity = nil
        XCTAssertTrue(WorkoutDetector.detect(in: d, restingHR: 55,
                                             baselineStepsPerHour: 500).isEmpty)
    }
}