import SwiftUI

/// Every metric in one place, grouped by health area, with date navigation at the
/// top. This is the "find any number fast" screen.
struct VitalsView: View {
    @ObservedObject var store: HealthStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                DayStrip(store: store) { store.select(day: $0) }

                if let day = store.selectedDay {
                    scoreSection(day)
                    sleepSection(day)
                    readinessSection(day)
                    activitySection(day)
                    coreMetricsSection(day)
                    cardiovascularSection(day)
                } else {
                    Text("No data for the selected day.")
                        .font(.label(13))
                        .foregroundStyle(Palette.textTertiary)
                        .padding(.top, 40)
                }
            }
            .padding(.bottom, 28)
        }
        .background(Palette.bg.ignoresSafeArea())
        .refreshable { store.refresh() }
        .navigationTitle("Vitals")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Scores

    private func scoreSection(_ day: DailySnapshot) -> some View {
        Section(title: "Scores", caption: store.isViewingToday ? nil : "Viewing \(Fmt.dayTitle(day.date))") {
            Card {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        scorePill("Sleep", store.sleepScore?.total ?? 0, Palette.sleep, .sleep)
                        scorePill("Readiness", store.readinessScore?.total ?? 0, Palette.readiness, .readiness)
                        scorePill("Activity", store.activityScore?.total ?? 0, Palette.activity, .activity)
                    }

                    Divider().overlay(Palette.stroke)

                    let points = store.trend(.sleep)
                    if points.count > 1 {
                        TrendChart(points: points.map { Double($0.value) }, tint: Palette.sleep)
                            .frame(height: 96)
                        HStack {
                            Text("\(points.count)-day sleep trend")
                            Spacer()
                            if let avg = store.averageScore(.sleep) {
                                Text("avg \(avg)")
                            }
                        }
                        .font(.label(11))
                        .foregroundStyle(Palette.textTertiary)
                    }
                }
                .padding(14)
            }
        }
        .padding(.horizontal, 16)
    }

    private func scorePill(_ title: String, _ score: Int, _ tint: Color, _ metric: TrendMetric) -> some View {
        VStack(spacing: 7) {
            ScoreGauge(score: score, tint: tint, size: 68, lineWidth: 6)
            Text(title)
                .font(.label(11))
                .foregroundStyle(Palette.textSecondary)
            if let d = store.scoreDelta(metric, current: score) {
                DeltaChip(delta: d)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Grouped metric cards

    private func sleepSection(_ day: DailySnapshot) -> some View {
        Section(title: "Sleep", caption: "Composition and timing") {
            if let sleep = day.sleep {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        StageBreakdown(sleep: sleep)
                        Divider().overlay(Palette.stroke)
                        MetricRow(title: "Time asleep", value: Fmt.duration(sleep.asleep),
                                  tint: Palette.sleep,
                                  progress: min(1, sleep.asleep
                                                / Double(store.goals.sleepTargetMinutes * 60)))
                        MetricRow(title: "Time in bed", value: Fmt.duration(sleep.duration))
                        MetricRow(title: "Efficiency", value: Fmt.percent(sleep.efficiency),
                                  tint: efficiencyTint(sleep.efficiency))
                        HStack(spacing: 8) {
                            Chip(text: "BED \(Fmt.clock(sleep.start))", tint: Palette.sleep)
                            Chip(text: "UP \(Fmt.clock(sleep.end))", tint: Palette.sleep)
                        }
                    }
                    .padding(14)
                }
            } else {
                missingCard("No sleep data for this day.")
            }
        }
        .padding(.horizontal, 16)
    }

    private func readinessSection(_ day: DailySnapshot) -> some View {
        Section(title: "Readiness", caption: "Recovery inputs") {
            let score = store.readinessScore
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    ScoreHero(score: score?.total ?? 0,
                              verdict: ScoreVerdict.readiness(score?.total ?? 0).title,
                              detail: ScoreVerdict.readiness(score?.total ?? 0).detail,
                              tint: Palette.readiness,
                              delta: score.map { store.scoreDelta(.readiness, current: $0.total) } ?? nil)

                    if let score {
                        ContributionStrip(parts: [
                            .init(points: score.sleepPoints, max: 50, tint: Palette.sleep, label: "sleep"),
                            .init(points: score.hrvPoints, max: 25, tint: Palette.hrv, label: "HRV"),
                            .init(points: score.restingHRPoints, max: 15, tint: Palette.heart, label: "RHR"),
                            .init(points: score.temperaturePoints, max: 10, tint: Palette.temp, label: "temp"),
                        ])
                    }
                }
                .padding(14)
            }
        }
        .padding(.horizontal, 16)
    }

    private func activitySection(_ day: DailySnapshot) -> some View {
        Section(title: "Activity", caption: "Movement and burn") {
            if let a = day.activity {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            ProgressRing(progress: Double(a.steps) / Double(max(1, store.goals.stepTarget)),
                                         tint: Palette.activity, size: 70, lineWidth: 6,
                                         value: "\(a.steps)", caption: "steps")
                            ProgressRing(progress: Double(a.calories) / 500,
                                         tint: Palette.activity, size: 70, lineWidth: 6,
                                         value: "\(a.calories)", caption: "kcal")
                            ProgressRing(progress: Double(a.activeSeconds)
                                            / Double(max(1, store.goals.activeMinutesTarget * 60)),
                                         tint: Palette.activity, size: 70, lineWidth: 6,
                                         value: Fmt.duration(TimeInterval(a.activeSeconds)),
                                         caption: "active")
                        }
                        .frame(maxWidth: .infinity)
                        Divider().overlay(Palette.stroke)
                        MetricRow(title: "Distance", value: Fmt.distance(a.distanceMetres),
                                  unit: Fmt.distanceUnit(a.distanceMetres))
                        MetricRow(title: "Total calories", value: "\(a.totalCalories)", unit: "kcal")
                    }
                    .padding(14)
                }
            } else {
                missingCard("No movement data for this day.")
            }
        }
        .padding(.horizontal, 16)
    }

    private func coreMetricsSection(_ day: DailySnapshot) -> some View {
        Section(title: "Core metrics", caption: "Resting heart rate, HRV, temperature") {
            Card {
                VStack(alignment: .leading, spacing: 13) {
                    MetricRow(title: "Resting heart rate",
                              value: day.restingHeartRate.map(String.init) ?? "—", unit: "bpm",
                              tint: Palette.heart,
                              progress: day.restingHeartRate.map { min(1, Double($0) / 100) },
                              delta: day.restingHeartRate.flatMap { r in
                                  store.baseline?.averageRestingHR.map { r - $0 } },
                              deltaUnit: " bpm", higherIsBetter: false)
                    MetricRow(title: "Heart-rate variability",
                              value: day.averageHRV.map(String.init) ?? "—", unit: "ms",
                              tint: Palette.hrv,
                              progress: day.averageHRV.map { min(1, Double($0) / 80) },
                              delta: day.averageHRV.flatMap { v in
                                  store.baseline?.averageHRV.map { v - $0 } },
                              deltaUnit: " ms")
                    MetricRow(title: "Skin temperature",
                              value: day.temperatureDelta(baseline: store.baseline?.averageSkinTemp)
                                  .map { Fmt.signed($0) } ?? "—",
                              unit: "°C vs baseline",
                              tint: Palette.temp)

                    if day.heartRate.count > 2 {
                        Divider().overlay(Palette.stroke)
                        Sparkline(values: day.heartRate.map { Double($0.bpm) },
                                  tint: Palette.heart,
                                  baseline: day.restingHeartRate.map(Double.init))
                            .frame(height: 56)
                    }
                }
                .padding(14)
            }
        }
        .padding(.horizontal, 16)
    }

    private func cardiovascularSection(_ day: DailySnapshot) -> some View {
        Section(title: "Cardiovascular", caption: "Oxygen and pressure") {
            Card {
                VStack(alignment: .leading, spacing: 13) {
                    MetricRow(title: "Blood oxygen",
                              value: day.averageOxygen.map { "\($0)" } ?? "—", unit: "%",
                              tint: Palette.oxygen,
                              progress: day.averageOxygen.map { min(1, Double($0) / 100) })
                    if let bp = day.latestBloodPressure {
                        MetricRow(title: "Blood pressure",
                                  value: "\(bp.systolic)/\(bp.diastolic)", unit: "mmHg",
                                  tint: Palette.pressure)
                        MetricRow(title: "Pulse pressure",
                                  value: "\(bp.systolic - bp.diastolic)", unit: "mmHg")
                        Text("Measured \(Fmt.dayTitle(bp.time)) at \(Fmt.clock(bp.time))")
                            .font(.label(11))
                            .foregroundStyle(Palette.textTertiary)
                    } else {
                        Text("No blood-pressure reading for this day.")
                            .font(.label(12))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                .padding(14)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func missingCard(_ text: String) -> some View {
        Card {
            Text(text)
                .font(.label(13))
                .foregroundStyle(Palette.textTertiary)
                .padding(14)
        }
    }

    private func efficiencyTint(_ v: Double) -> Color {
        v >= 0.9 ? Palette.good : v >= 0.8 ? Palette.warn : Palette.bad
    }
}