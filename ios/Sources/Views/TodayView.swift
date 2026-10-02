import SwiftUI

struct TodayView: View {
    @ObservedObject var store: HealthStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                gaugeStrip
                if let day = store.selectedDay {
                    sleepCard(day)
                    readinessCard(day)
                    activityCard(day)
                    vitalsCard(day)
                    heartRateCard(day)
                    sleepStagesCard(day)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Palette.bg.ignoresSafeArea())
        .refreshable { store.refresh() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.metric(22))
                    .foregroundStyle(Palette.textPrimary)
                Text(store.selectedDay.map { Fmt.dayTitle($0.date) } ?? "No data yet")
                    .font(.label(13))
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            RingStatusPill(store: store)
        }
        .padding(.top, 6)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Gauges

    private var gaugeStrip: some View {
        HStack(spacing: 10) {
            ScoreGauge(score: store.sleepScore?.total ?? 0,
                       tint: Palette.sleep, size: 104, lineWidth: 8, label: "sleep")
            ScoreGauge(score: store.readinessScore?.total ?? 0,
                       tint: Palette.readiness, size: 104, lineWidth: 8, label: "ready")
            ScoreGauge(score: store.activityScore?.total ?? 0,
                       tint: Palette.activity, size: 104, lineWidth: 8, label: "active")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sleep

    private func sleepCard(_ day: DailySnapshot) -> some View {
        let score = store.sleepScore ?? ScoreEngine.SleepBreakdown(total: 0, durationPoints: 0, efficiencyPoints: 0, deepPoints: 0, timingPoints: 0)
        let verdict = ScoreVerdict.sleep(score.total)

        return Card(tint: Palette.sleep) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Sleep", icon: "bed.double.fill", tint: Palette.sleep)

                ScoreRow(score: score.total, tint: Palette.sleep,
                         title: "score", verdict: verdict.title, detail: verdict.detail)

                if let sleep = day.sleep {
                    StatRow(title: "Time asleep",
                            value: Fmt.duration(sleep.asleep),
                            tint: Palette.sleep,
                            progress: min(1, sleep.asleep / (Double(store.goals.sleepTargetMinutes) * 60)))
                    StatRow(title: "Time in bed", value: Fmt.duration(sleep.duration), tint: Palette.textPrimary)
                    StatRow(title: "Efficiency", value: Fmt.percent(sleep.efficiency),
                            tint: efficiencyTint(sleep.efficiency))
                    StatRow(title: "Deep sleep", value: Fmt.duration(sleep.time(.deep)),
                            tint: Palette.sleepDeep)
                    StatRow(title: "REM", value: Fmt.duration(sleep.time(.rem)), tint: Palette.hrv)
                    StatRow(title: "Awake", value: Fmt.duration(sleep.time(.awake)), tint: Palette.warn)

                    HStack(spacing: 8) {
                        Chip(text: "BED \(Fmt.clock(sleep.start))", tint: Palette.sleep)
                        Chip(text: "UP \(Fmt.clock(sleep.end))", tint: Palette.sleep)
                        Chip(text: sleep.sleepScoreBand.uppercased(), tint: efficiencyTint(sleep.efficiency))
                    }
                } else {
                    Text("No sleep data for this day.")
                        .font(.label(13))
                        .foregroundStyle(Palette.textTertiary)
                }

                contributionBar(title: "Score contributions",
                                parts: [
                                    (score.durationPoints, 40, Palette.sleep, "duration"),
                                    (score.efficiencyPoints, 25, Palette.readiness, "efficiency"),
                                    (score.deepPoints, 20, Palette.sleepDeep, "deep"),
                                    (score.timingPoints, 15, Palette.hrv, "timing"),
                                ])
            }
        }
    }

    // MARK: - Readiness

    private func readinessCard(_ day: DailySnapshot) -> some View {
        let score = store.readinessScore ?? ScoreEngine.ReadinessBreakdown(
            total: 0, sleepPoints: 0, hrvPoints: 0, restingHRPoints: 0, temperaturePoints: 0)
        let verdict = ScoreVerdict.readiness(score.total)

        return Card(tint: Palette.readiness) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Readiness", icon: "bolt.heart.fill", tint: Palette.readiness)

                ScoreRow(score: score.total, tint: Palette.readiness,
                         title: "score", verdict: verdict.title, detail: verdict.detail)

                StatRow(title: "Resting heart rate",
                        value: day.restingHeartRate.map(String.init) ?? "—",
                        unit: "bpm", tint: Palette.heart,
                        progress: day.restingHeartRate.map { min(1, Double($0) / 100) })
                StatRow(title: "HRV",
                        value: day.averageHRV.map(String.init) ?? "—",
                        unit: "ms", tint: Palette.hrv,
                        progress: day.averageHRV.map { min(1, Double($0) / 80) })

                if let delta = day.temperatureDelta(baseline: store.baseline?.averageSkinTemp) {
                    StatRow(title: "Temperature",
                            value: Fmt.signed(delta), unit: "°C vs baseline",
                            tint: abs(delta) > 0.5 ? Palette.warn : Palette.temp)
                }

                contributionBar(title: "Score contributions",
                                parts: [
                                    (score.sleepPoints, 50, Palette.sleep, "sleep"),
                                    (score.hrvPoints, 25, Palette.hrv, "HRV"),
                                    (score.restingHRPoints, 15, Palette.heart, "RHR"),
                                    (score.temperaturePoints, 10, Palette.temp, "temp"),
                                ])
            }
        }
    }

    // MARK: - Activity

    private func activityCard(_ day: DailySnapshot) -> some View {
        let score = store.activityScore ?? ScoreEngine.ActivityBreakdown(
            total: 0, stepsPoints: 0, caloriesPoints: 0, activeTimePoints: 0)
        let verdict = ScoreVerdict.activity(score.total)

        return Card(tint: Palette.activity) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Activity", icon: "figure.walk.motion", tint: Palette.activity)

                ScoreRow(score: score.total, tint: Palette.activity,
                         title: "score", verdict: verdict.title, detail: verdict.detail)

                if let a = day.activity {
                    StatRow(title: "Steps", value: "\(a.steps)",
                            tint: Palette.activity,
                            progress: min(1, Double(a.steps) / Double(store.goals.stepTarget)))
                    StatRow(title: "Distance",
                            value: Fmt.distance(a.distanceMetres),
                            unit: Fmt.distanceUnit(a.distanceMetres),
                            tint: Palette.activity)
                    StatRow(title: "Active time",
                            value: Fmt.duration(TimeInterval(a.activeSeconds)),
                            tint: Palette.activity,
                            progress: min(1, Double(a.activeSeconds) / Double(store.goals.activeMinutesTarget * 60)))
                    StatRow(title: "Active calories", value: "\(a.calories)",
                            unit: "kcal", tint: Palette.activity,
                            progress: min(1, Double(a.calories) / 500))

                    HStack(spacing: 8) {
                        Chip(text: "\(a.totalCalories) KCAL TOTAL", tint: Palette.activity)
                        Chip(text: "\(Int(Double(a.steps) / 1000.0 * 10) / 10)K STEPS", tint: Palette.activity)
                    }
                }

                contributionBar(title: "Score contributions",
                                parts: [
                                    (score.stepsPoints, 50, Palette.activity, "steps"),
                                    (score.caloriesPoints, 30, Palette.activity, "calories"),
                                    (score.activeTimePoints, 20, Palette.activity, "active time"),
                                ])
            }
        }
    }

    // MARK: - Vitals summary

    private func vitalsCard(_ day: DailySnapshot) -> some View {
        Card(tint: Palette.oxygen) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Vitals", icon: "waveform.path.ecg", tint: Palette.oxygen)

                if let bp = day.latestBloodPressure {
                    StatRow(title: "Blood pressure",
                            value: "\(bp.systolic)/\(bp.diastolic)",
                            unit: "mmHg", tint: Palette.pressure)
                }
                StatRow(title: "Blood oxygen",
                        value: day.averageOxygen.map { "\($0)" } ?? "—",
                        unit: "%", tint: Palette.oxygen,
                        progress: day.averageOxygen.map { min(1, Double($0) / 100) })
                StatRow(title: "HRV (avg)",
                        value: day.averageHRV.map { "\($0)" } ?? "—",
                        unit: "ms", tint: Palette.hrv)

                Text("Live readings are taken on demand from the ring tab.")
                    .font(.label(11))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }

    // MARK: - Heart rate

    private func heartRateCard(_ day: DailySnapshot) -> some View {
        Card(tint: Palette.heart) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Heart rate", icon: "heart.fill", tint: Palette.heart)

                HStack(spacing: 20) {
                    StatRow(title: "Resting", value: day.restingHeartRate.map(String.init) ?? "—", unit: "bpm", tint: Palette.heart)
                    StatRow(title: "Lowest", value: day.lowestHeartRate.map(String.init) ?? "—", unit: "bpm", tint: Palette.readiness)
                    StatRow(title: "Highest", value: day.highestHeartRate.map(String.init) ?? "—", unit: "bpm", tint: Palette.warn)
                }

                if day.heartRate.count > 2 {
                    Sparkline(values: day.heartRate.map { Double($0.bpm) },
                              tint: Palette.heart, baseline: day.restingHeartRate.map(Double.init))
                        .frame(height: 64)
                    HStack {
                        Text(Fmt.clock(day.heartRate.first!.time))
                        Spacer()
                        Text("\(day.heartRate.count) readings")
                        Spacer()
                        Text(Fmt.clock(day.heartRate.last!.time))
                    }
                    .font(.label(10))
                    .foregroundStyle(Palette.textTertiary)
                } else {
                    Text("Not enough heart-rate samples yet.")
                        .font(.label(13))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
    }

    // MARK: - Sleep stages

    private func sleepStagesCard(_ day: DailySnapshot) -> some View {
        Card(tint: Palette.sleep) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Sleep stages", icon: "chart.bar.fill", tint: Palette.sleep)

                if let sleep = day.sleep, !sleep.intervals.isEmpty {
                    StackedBar(segments: [
                        .init(value: sleep.time(.deep), tint: Palette.sleepDeep, label: "Deep"),
                        .init(value: sleep.time(.rem), tint: Palette.hrv, label: "REM"),
                        .init(value: sleep.time(.light), tint: Palette.sleep, label: "Light"),
                        .init(value: sleep.time(.awake), tint: Palette.warn, label: "Awake"),
                    ])

                    VStack(spacing: 6) {
                        LegendItem(label: "Deep", tint: Palette.sleepDeep, value: Fmt.duration(sleep.time(.deep)))
                        LegendItem(label: "REM", tint: Palette.hrv, value: Fmt.duration(sleep.time(.rem)))
                        LegendItem(label: "Light", tint: Palette.sleep, value: Fmt.duration(sleep.time(.light)))
                        LegendItem(label: "Awake", tint: Palette.warn, value: Fmt.duration(sleep.time(.awake)))
                    }
                } else {
                    Text("No stage data.")
                        .font(.label(13))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
    }

    // MARK: - Pieces

    private func contributionBar(title: String,
                                 parts: [(points: Int, max: Int, tint: Color, label: String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(Palette.textTertiary)

            StackedBar(segments: parts.map {
                .init(value: Double($0.points), tint: $0.tint, label: $0.label)
            }, height: 8)

            HStack(spacing: 10) {
                ForEach(parts, id: \.label) { part in
                    HStack(spacing: 4) {
                        Circle().fill(part.tint).frame(width: 6, height: 6)
                        Text("\(part.label) \(part.points)/\(part.max)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
            }
        }
    }

    private func efficiencyTint(_ v: Double) -> Color {
        v >= 0.9 ? Palette.good : v >= 0.8 ? Palette.warn : Palette.bad
    }

    private var emptyState: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "No data")
                Text("Pair your ring from the Ring tab, then pull to refresh. History that the ring already holds is streamed once the sensor switch is on.")
                    .font(.label(13))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Status pill

struct RingStatusPill: View {
    @ObservedObject var store: HealthStore

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(store.connection.isLive ? Palette.good : Palette.textTertiary)
                .frame(width: 7, height: 7)
            Text(store.connection.label)
                .font(.label(11))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Palette.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.stroke, lineWidth: 1))
    }
}

// MARK: - Sparkline

struct Sparkline: View {
    let values: [Double]
    var tint: Color
    var baseline: Double?

    var body: some View {
        GeometryReader { geo in
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let span = max(1, maxV - minV)

            ZStack {
                if let baseline {
                    let y = geo.size.height * (1 - (baseline - minV) / span)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Palette.textTertiary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }

                Path { path in
                    guard values.count > 1 else { return }
                    let step = geo.size.width / CGFloat(values.count - 1)
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * step
                        let y = geo.size.height * (1 - (v - minV) / span)
                        i == 0 ? path.move(to: CGPoint(x: x, y: y))
                               : path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(
                    LinearGradient(colors: [tint.opacity(0.4), tint], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}