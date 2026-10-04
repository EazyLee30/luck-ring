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
                    DerivedMetricsCard(store: store)
                    trendSection()
                } else {
                    Text("No data for the selected day.")
                        .scaledFont(13, weight: .medium)
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
        VStack(spacing: 12) {
            scoreCard(title: "Readiness", symbol: "bolt.heart.fill", tint: Palette.readiness,
                      score: store.readinessScore?.total ?? 0, metric: .readiness,
                      status: ScoreVerdict.readiness(store.readinessScore?.total ?? 0).title)
            scoreCard(title: "Sleep", symbol: "bed.double.fill", tint: Palette.sleep,
                      score: store.sleepScore?.total ?? 0, metric: .sleep,
                      status: ScoreVerdict.sleep(store.sleepScore?.total ?? 0).title)
            scoreCard(title: "Activity goal", symbol: "flame.fill", tint: Palette.activity,
                      score: store.activityScore?.total ?? 0, metric: .activity,
                      status: ScoreVerdict.activity(store.activityScore?.total ?? 0).title)
        }
        .padding(.horizontal, 18)
    }

    /// One score, laid out the way the reference design does it: header row with a
    /// status word, a large serif score, and a dot placed on a min/max track.
    private func scoreCard(title: String, symbol: String, tint: Color,
                           score: Int, metric: TrendMetric, status: String) -> some View {
        let average = store.averageScore(metric)
        let band = average.map { score - $0 } ?? 0
        let spread = Swift.max(14, Swift.min(40, (average ?? 70) / 4))

        return GlowCard(tint: tint) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeaderRow(title: title, symbol: symbol,
                              status: status.uppercased(), tint: tint)

                HStack(alignment: .center, spacing: 16) {
                    ScoreWithMark(score: score, symbol: metric == .readiness ? "crown.fill" : nil,
                                  size: 42)
                        .frame(width: 92, alignment: .leading)
                    RangeScale(value: score,
                               min: Swift.max(0, score - band - spread),
                               max: Swift.min(100, score - band + spread),
                               tint: tint)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Grouped metric cards

    private func sleepSection(_ day: DailySnapshot) -> some View {
        Section(title: "Sleep", caption: "Composition and timing") {
            if let sleep = day.sleep {
                GlowCard(tint: Palette.sleep) {
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

    /// The readiness score already has a card above, so this one carries only
    /// what drives it.
    private func readinessSection(_ day: DailySnapshot) -> some View {
        let score = store.readinessScore
        let parts: [ContributorRow] = [
            ContributorRow(title: "Sleep", verdict: verdict(for: score?.sleepPoints, max: 50),
                           progress: ratio(score?.sleepPoints, max: 50), tint: Palette.sleep),
            ContributorRow(title: "Heart-rate variability",
                           verdict: verdict(for: score?.hrvPoints, max: 25),
                           progress: ratio(score?.hrvPoints, max: 25), tint: Palette.hrv),
            ContributorRow(title: "Resting heart rate",
                           verdict: verdict(for: score?.restingHRPoints, max: 15),
                           progress: ratio(score?.restingHRPoints, max: 15), tint: Palette.heart),
            ContributorRow(title: "Skin temperature",
                           verdict: verdict(for: score?.temperaturePoints, max: 10),
                           progress: ratio(score?.temperaturePoints, max: 10), tint: Palette.temp),
        ]

        return Section(title: "Readiness", caption: "What drove the score") {
            GlowCard(tint: Palette.readiness) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(ScoreVerdict.readiness(score?.total ?? 0).detail)
                        .scaledFont(13)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(Array(parts.enumerated()), id: \.offset) { index, row in
                        if index > 0 { Divider().overlay(Palette.stroke) }
                        row
                    }
                }
                .padding(16)
            }
        }
        .padding(.horizontal, 18)
    }

    private func ratio(_ points: Int?, max: Int) -> Double {
        guard let points, max > 0 else { return 0 }
        return Double(points) / Double(max)
    }

    private func verdict(for points: Int?, max: Int) -> String {
        let r = ratio(points, max: max)
        if r >= 0.85 { return "Optimal" }
        if r >= 0.6 { return "Good" }
        if r >= 0.3 { return "Fair" }
        return "Low"
    }

    private func activitySection(_ day: DailySnapshot) -> some View {
        Section(title: "Activity", caption: "Movement and burn") {
            if let a = day.activity {
                GlowCard(tint: Palette.activity) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            ProgressRing(progress: Double(a.steps) / Double(max(1, store.goals.stepTarget)),
                                         tint: Palette.activity, size: 70, lineWidth: 6,
                                         value: Fmt.count(a.steps), caption: "steps")
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
        .padding(.horizontal, 18)
    }

    private func coreMetricsSection(_ day: DailySnapshot) -> some View {
        Section(title: "Core metrics", caption: "Resting heart rate, HRV, temperature") {
            GlowCard(tint: Palette.heart) {
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
            GlowCard(tint: Palette.oxygen) {
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
                            .scaledFont(11, weight: .medium)
                            .foregroundStyle(Palette.textTertiary)
                    } else {
                        Text("No blood-pressure reading for this day.")
                            .scaledFont(12, weight: .medium)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                .padding(14)
            }
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Trend

    private func trendSection() -> some View {
        let metric = TrendMetric.allCases[abs(store.days.count) % TrendMetric.allCases.count]
        let points = store.trend(metric)

        return Section(title: "\(metric.title) trend",
                       caption: points.isEmpty ? nil : "Last \(points.count) days") {
            GlowCard(tint: metric.tint) {
                VStack(alignment: .leading, spacing: 12) {
                    if points.count > 1 {
                        TrendChart(points: points.map { Double($0.value) }, tint: metric.tint)
                            .frame(height: 88)
                        HStack {
                            Text(Fmt.dayTick(points.first!.day.date))
                            Spacer()
                            if let avg = store.averageScore(metric) { Text("avg \(avg)") }
                            Spacer()
                            Text(Fmt.dayTick(points.last!.day.date))
                        }
                        .scaledFont(10, weight: .medium)
                        .foregroundStyle(Palette.textTertiary)
                    } else {
                        Text("Need at least two days of data.")
                            .scaledFont(13)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                .padding(16)
            }
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Helpers

    private func missingCard(_ text: String) -> some View {
        GlowCard {
            Text(text)
                .scaledFont(13)
                .foregroundStyle(Palette.textTertiary)
                .padding(16)
        }
    }

    private func efficiencyTint(_ v: Double) -> Color {
        v >= 0.9 ? Palette.good : v >= 0.8 ? Palette.warn : Palette.bad
    }
}