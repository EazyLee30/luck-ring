import SwiftUI

struct TrendsView: View {
    @ObservedObject var store: HealthStore
    @State private var metric: TrendMetric = .sleep

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("", selection: $metric) {
                    ForEach(TrendMetric.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                trendCard
                if let day = store.selectedDay { detailCard(day) }
                weekGrid
            }
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Trend card

    private var trendCard: some View {
        let points = store.trend(metric)
        let average = points.isEmpty ? 0 : points.reduce(0) { $0 + $1.value } / points.count

        return Card(tint: metric.tint) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("7-DAY AVERAGE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Palette.textTertiary)
                        Text("\(average)")
                            .font(.score(32))
                            .foregroundStyle(metric.tint)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("RANGE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Palette.textTertiary)
                        Text(points.map { $0.value }.min().map(String.init) ?? "—")
                            .font(.metric(15))
                            .foregroundStyle(Palette.textSecondary)
                        Text("– " + (points.map { $0.value }.max().map(String.init) ?? "—"))
                            .font(.metric(15))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }

                if points.count > 1 {
                    TrendChart(points: points.map { Double($0.value) }, tint: metric.tint)
                        .frame(height: 120)
                    HStack {
                        ForEach(points, id: \.day.id) { p in
                            Text(Fmt.dayTick(p.day.date))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Palette.textTertiary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    Text("Need at least two days of data.")
                        .font(.label(13))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Metric detail

    private func detailCard(_ day: DailySnapshot) -> some View {
        Card(tint: metric.tint) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: metric.title + " detail", icon: "chart.line.uptrend.xyaxis",
                              tint: metric.tint)

                switch metric {
                case .sleep:
                    if let s = day.sleep {
                        StatRow(title: "Time asleep", value: Fmt.duration(s.asleep), tint: metric.tint)
                        StatRow(title: "Efficiency", value: Fmt.percent(s.efficiency), tint: metric.tint)
                        StatRow(title: "Deep", value: Fmt.duration(s.time(.deep)), tint: Palette.sleepDeep)
                        StatRow(title: "REM", value: Fmt.duration(s.time(.rem)), tint: Palette.hrv)
                    }
                case .readiness:
                    StatRow(title: "RHR", value: day.restingHeartRate.map(String.init) ?? "—",
                            unit: "bpm", tint: Palette.heart)
                    StatRow(title: "HRV", value: day.averageHRV.map(String.init) ?? "—",
                            unit: "ms", tint: Palette.hrv)
                    StatRow(title: "SpO2", value: day.averageOxygen.map(String.init) ?? "—",
                            unit: "%", tint: Palette.oxygen)
                case .activity:
                    StatRow(title: "Steps", value: day.activity.map { "\($0.steps)" } ?? "—", tint: metric.tint)
                    StatRow(title: "Distance", value: day.activity.map { Fmt.distance($0.distanceMetres) } ?? "—",
                            unit: day.activity.map { Fmt.distanceUnit($0.distanceMetres) } ?? "", tint: metric.tint)
                    StatRow(title: "Active kcal", value: day.activity.map { "\($0.calories)" } ?? "—",
                            unit: "kcal", tint: metric.tint)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Week grid

    private var weekGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "History")
            ForEach(store.orderedDays) { day in
                DayRow(day: day, store: store)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct DayRow: View {
    let day: DailySnapshot
    @ObservedObject var store: HealthStore

    private var sleep: Int { ScoreEngine.sleep(for: day, goals: store.goals, baseline: store.baseline).total }
    private var ready: Int {
        let s = sleep
        return ScoreEngine.readiness(for: day, goals: store.goals, baseline: store.baseline, sleepScore: s).total
    }
    private var active: Int { ScoreEngine.activity(for: day, goals: store.goals).total }

    var body: some View {
        Card {
            VStack(spacing: 10) {
                HStack {
                    Text(Fmt.dayTitle(day.date))
                        .font(.metric(15))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text(Fmt.duration(day.sleep?.asleep ?? 0))
                        .font(.label(12))
                        .foregroundStyle(Palette.textTertiary)
                }
                HStack(spacing: 8) {
                    miniGauge("Sleep", sleep, Palette.sleep)
                    miniGauge("Ready", ready, Palette.readiness)
                    miniGauge("Active", active, Palette.activity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func miniGauge(_ label: String, _ score: Int, _ tint: Color) -> some View {
        VStack(spacing: 5) {
            ScoreGauge(score: score, tint: tint, size: 52, lineWidth: 5)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Trend chart

struct TrendChart: View {
    let points: [Double]
    var tint: Color

    /// Scores cluster in a narrow band (typically 70-90), so a fixed 0-100 axis
    /// renders every week as a flat line. Scale to the data with padding, but
    /// never zoom in past a 25-point window or noise looks like a trend.
    private var scale: (low: Double, high: Double) {
        guard let lo = points.min(), let hi = points.max() else { return (0, 100) }
        var low = lo, high = hi
        if high - low < 25 {
            let mid = (high + low) / 2
            low = mid - 12.5
            high = mid + 12.5
        } else {
            let pad = (high - low) * 0.15
            low -= pad
            high += pad
        }
        return (max(0, low), min(100, high))
    }

    var body: some View {
        GeometryReader { geo in
            let s = scale
            let span = max(1, s.high - s.low)
            let w = geo.size.width / CGFloat(max(1, points.count - 1))
            let y = { (v: Double) in geo.size.height * (1 - (v - s.low) / span) }
            let gridlines = stride(from: ceil(s.low / 10) * 10, through: s.high, by: 10).map { $0 }

            ZStack {
                ForEach(Array(gridlines), id: \.self) { g in
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y(g)))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y(g)))
                    }
                    .stroke(Palette.stroke, style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                }

                // Filled area, anchored to the axis floor.
                Path { p in
                    guard !points.isEmpty else { return }
                    p.move(to: CGPoint(x: 0, y: geo.size.height))
                    for (i, v) in points.enumerated() {
                        p.addLine(to: CGPoint(x: CGFloat(i) * w, y: y(v)))
                    }
                    p.addLine(to: CGPoint(x: CGFloat(points.count - 1) * w, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.01)],
                                     startPoint: .top, endPoint: .bottom))

                Path { p in
                    guard points.count > 1 else { return }
                    for (i, v) in points.enumerated() {
                        i == 0 ? p.move(to: CGPoint(x: 0, y: y(v)))
                               : p.addLine(to: CGPoint(x: CGFloat(i) * w, y: y(v)))
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.offset) { i, v in
                    Circle()
                        .fill(Palette.bg)
                        .overlay(Circle().strokeBorder(tint, lineWidth: 2))
                        .frame(width: 7, height: 7)
                        .position(x: CGFloat(i) * w, y: y(v))
                }
            }
        }
    }
}