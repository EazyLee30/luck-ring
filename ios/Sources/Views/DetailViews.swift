import SwiftUI

/// Where a tapped card can lead. Today is now inside a `NavigationStack` so a
/// score card pushes a real screen instead of expanding inline — long inline
/// detail was the main reason the scroll became unwieldy.
enum DetailRoute: Hashable {
    case sleep(Date)
    case activity(Date)
    case readiness(Date)
    case vitals(Date)
    case training

    var title: String {
        switch self {
        case .sleep: return "Sleep"
        case .activity: return "Activity"
        case .readiness: return "Readiness"
        case .vitals: return "Vitals"
        case .training: return "Training"
        }
    }

    var symbol: String {
        switch self {
        case .sleep: return "bed.double.fill"
        case .activity: return "figure.walk.motion"
        case .readiness: return "bolt.heart.fill"
        case .vitals: return "waveform.path.ecg"
        case .training: return "figure.run"
        }
    }
}

// MARK: - Sleep detail

struct SleepDetailView: View {
    let date: Date
    @ObservedObject var store: HealthStore

    private var day: DailySnapshot? {
        store.orderedDays.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let sleep = day?.sleep {
                    header(sleep)
                    scoreCard(sleep)
                    StageBreakdown(sleep: sleep)
                    timeline(sleep)
                    regularity
                } else {
                    missing
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 110)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ sleep: SleepSession) -> some View {
        GlowCard(tint: Palette.sleep) {
            VStack(spacing: 16) {
                ArcGauge(score: score, tint: Palette.sleep, caption: "sleep", size: 150)
                HStack(spacing: 20) {
                    MiniStat(title: "Asleep", value: Fmt.duration(sleep.asleep), tint: Palette.sleep)
                    MiniStat(title: "In bed", value: Fmt.duration(sleep.duration), tint: Palette.textPrimary)
                    MiniStat(title: "Efficiency", value: Fmt.percent(sleep.efficiency),
                             tint: efficiencyTint(sleep.efficiency))
                }
                HStack(spacing: 8) {
                    Chip(text: "BED \(Fmt.clock(sleep.start))", tint: Palette.sleep)
                    Chip(text: "UP \(Fmt.clock(sleep.end))", tint: Palette.sleep)
                    Chip(text: sleep.sleepScoreBand.uppercased(),
                         tint: efficiencyTint(sleep.efficiency))
                }
            }
            .padding(18)
        }
    }

    private var score: Int {
        guard let day else { return 0 }
        return ScoreEngine.sleep(for: day, goals: store.goals, baseline: store.baseline).total
    }

    private func scoreCard(_ sleep: SleepSession) -> some View {
        let breakdown = store.sleepScore ?? ScoreEngine.SleepBreakdown(
            total: 0, durationPoints: 0, efficiencyPoints: 0, deepPoints: 0, timingPoints: 0)

        return GlowCard(tint: Palette.sleep) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeaderRow(title: "What drove it", symbol: "slider.horizontal.3",
                              tint: Palette.sleep)
                ForEach(Array(contributors(breakdown).enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider().overlay(Palette.stroke) }
                    row
                }
            }
            .padding(16)
        }
    }

    private func contributors(_ b: ScoreEngine.SleepBreakdown) -> [ContributorRow] {
        [
            ContributorRow(title: "Duration", verdict: verdict(b.durationPoints, 40),
                           progress: Double(b.durationPoints) / 40, tint: Palette.sleep),
            ContributorRow(title: "Efficiency", verdict: verdict(b.efficiencyPoints, 25),
                           progress: Double(b.efficiencyPoints) / 25, tint: Palette.readiness),
            ContributorRow(title: "Deep sleep", verdict: verdict(b.deepPoints, 20),
                           progress: Double(b.deepPoints) / 20, tint: Palette.sleepDeep),
            ContributorRow(title: "Bedtime consistency", verdict: verdict(b.timingPoints, 15),
                           progress: Double(b.timingPoints) / 15, tint: Palette.hrv),
        ]
    }

    private func verdict(_ points: Int, _ max: Int) -> String {
        let r = Double(points) / Double(max)
        if r >= 0.85 { return "Strong" }
        if r >= 0.6 { return "Good" }
        if r >= 0.3 { return "Weak" }
        return "Poor"
    }

    /// Stage-by-stage timeline, the clearest way to show where the night went.
    private func timeline(_ sleep: SleepSession) -> some View {
        GlowCard(tint: Palette.sleep) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderRow(title: "Night timeline", symbol: "clock", tint: Palette.sleep)

                GeometryReader { geo in
                    let total = max(1, sleep.duration)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.surfaceHi).frame(height: 10)
                        ForEach(sleep.intervals) { interval in
                            let offset = interval.start.timeIntervalSince(sleep.start) / total
                            let width = interval.duration / total
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tint(for: interval.stage))
                                .frame(width: max(2, geo.size.width * width),
                                       height: 10)
                                .offset(x: geo.size.width * offset)
                        }
                    }
                }
                .frame(height: 12)

                HStack {
                    Text(Fmt.clock(sleep.start))
                    Spacer()
                    Text("\(Int(sleep.duration / 3600))h in bed")
                    Spacer()
                    Text(Fmt.clock(sleep.end))
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.textTertiary)
            }
            .padding(16)
        }
    }

    private func tint(for stage: SleepStage) -> Color {
        switch stage {
        case .deep: return Palette.sleepDeep
        case .rem: return Palette.hrv
        case .awake: return Palette.warn
        default: return Palette.sleep
        }
    }

    private var regularity: some View {
        let value = DerivedMetrics.sleepRegularity(days: store.recentWeekDays)
        let band = value.map { $0 > 0.85 ? "Regular" : ($0 > 0.6 ? "Somewhat regular" : "Irregular") }
        return GlowCard(tint: Palette.sleep) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderRow(title: "Sleep regularity",
                              status: band?.uppercased(), tint: Palette.sleep)
                MetricRow(title: "Bedtime scatter",
                          value: value.map { Fmt.percent($0) } ?? "—",
                          tint: Palette.sleep, progress: value)
                Text("How consistent your bedtime has been over the last \(store.recentWeekDays.count) nights. Needs at least three.")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }

    private var missing: some View {
        GlowCard {
            Text("No sleep recorded for \(Fmt.dayTitle(date)). Keep the ring on overnight — stages are detected while you wear it.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
                .padding(18)
        }
    }

    private func efficiencyTint(_ v: Double) -> Color {
        v >= 0.9 ? Palette.good : v >= 0.8 ? Palette.warn : Palette.bad
    }
}

// MARK: - Activity detail

struct ActivityDetailView: View {
    let date: Date
    @ObservedObject var store: HealthStore

    private var day: DailySnapshot? {
        store.orderedDays.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let day, let activity = day.activity {
                    header(activity)
                    rings(activity)
                    contributors
                    workouts
                    weekTrend
                } else {
                    GlowCard {
                        Text("No movement data for \(Fmt.dayTitle(date)).")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary)
                            .padding(18)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 110)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ a: ActivitySummary) -> some View {
        GlowCard(tint: Palette.activity) {
            VStack(spacing: 16) {
                ArcGauge(score: score, tint: Palette.activity, caption: "activity", size: 150)
                HStack(spacing: 20) {
                    MiniStat(title: "Steps", value: Fmt.count(a.steps), tint: Palette.activity)
                    MiniStat(title: "Distance",
                             value: Fmt.distance(a.distanceMetres),
                             unit: Fmt.distanceUnit(a.distanceMetres), tint: Palette.textPrimary)
                    MiniStat(title: "Burn", value: "\(a.calories)", unit: "kcal",
                             tint: Palette.activity)
                }
            }
            .padding(18)
        }
    }

    private var score: Int {
        guard let day else { return 0 }
        return ScoreEngine.activity(for: day, goals: store.goals).total
    }

    private func rings(_ a: ActivitySummary) -> some View {
        GlowCard(tint: Palette.activity) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeaderRow(title: "Against your goals", symbol: "target", tint: Palette.activity)
                HStack(spacing: 14) {
                    ProgressRing(progress: Double(a.steps) / Double(max(1, store.goals.stepTarget)),
                                 tint: Palette.activity, size: 76, lineWidth: 7,
                                 value: Fmt.count(a.steps), caption: "steps")
                    ProgressRing(progress: Double(a.activeSeconds)
                                    / Double(max(1, store.goals.activeMinutesTarget * 60)),
                                 tint: Palette.sleep, size: 76, lineWidth: 7,
                                 value: Fmt.duration(TimeInterval(a.activeSeconds)),
                                 caption: "active")
                    ProgressRing(progress: Double(a.calories) / 500,
                                 tint: Palette.activity, size: 76, lineWidth: 7,
                                 value: "\(a.calories)", caption: "kcal")
                }
                .frame(maxWidth: .infinity)
                MetricRow(title: "Target", value: Fmt.count(store.goals.stepTarget),
                          unit: "steps", tint: Palette.textSecondary)
            }
            .padding(16)
        }
    }

    private var contributors: some View {
        let b = store.activityScore ?? ScoreEngine.ActivityBreakdown(
            total: 0, stepsPoints: 0, caloriesPoints: 0, activeTimePoints: 0)
        return GlowCard(tint: Palette.activity) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeaderRow(title: "What drove it", symbol: "slider.horizontal.3",
                              tint: Palette.activity)
                ContributorRow(title: "Steps", verdict: text(Double(b.stepsPoints) / 50),
                               progress: Double(b.stepsPoints) / 50, tint: Palette.activity)
                Divider().overlay(Palette.stroke)
                ContributorRow(title: "Calories", verdict: text(Double(b.caloriesPoints) / 30),
                               progress: Double(b.caloriesPoints) / 30, tint: Palette.activity)
                Divider().overlay(Palette.stroke)
                ContributorRow(title: "Active time", verdict: text(Double(b.activeTimePoints) / 20),
                               progress: Double(b.activeTimePoints) / 20, tint: Palette.activity)
            }
            .padding(16)
        }
    }

    private func text(_ r: Double) -> String {
        if r >= 0.85 { return "Maxed" }
        if r >= 0.6 { return "On track" }
        if r >= 0.3 { return "Partial" }
        return "Low"
    }

    private var workouts: some View {
        let log = day?.workouts ?? []
        return GlowCard(tint: Palette.activity) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeaderRow(title: "Training",
                              status: log.isEmpty ? "NONE"
                                  : "\(day?.exerciseMinutes ?? 0) MIN · \(String(format: "%.1f", day?.metHours ?? 0)) MET-h",
                              tint: Palette.activity)

                if log.isEmpty {
                    Text("No sessions logged. Ambient steps still count toward your step goal, but not toward training load.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(log) { w in
                        HStack(spacing: 12) {
                            IconBadge(symbol: w.kind.symbol, tint: Palette.activity, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(w.kind.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Palette.textPrimary)
                                Text("\(Fmt.clock(w.start)) · \(Fmt.duration(w.duration))"
                                     + (w.distanceMetres > 0
                                        ? " · \(Fmt.distance(w.distanceMetres))\(Fmt.distanceUnit(w.distanceMetres))"
                                        : "")
                                     + (w.averageHR.map { " · \($0) bpm" } ?? ""))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Palette.textTertiary)
                            }
                            Spacer()
                            Text("\(w.calories)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.textPrimary)
                        }
                    }
                }

                Divider().overlay(Palette.stroke)
                MetricRow(title: "7-day training load",
                          value: Fmt.percent(store.weeklyTrainingLoad()),
                          tint: Palette.activity, progress: store.weeklyTrainingLoad())
            }
            .padding(16)
        }
    }

    private var weekTrend: some View {
        let points = store.trend(.activity)
        return GlowCard(tint: Palette.activity) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderRow(title: "Activity trend", symbol: "chart.xyaxis.line",
                              tint: Palette.activity)
                if points.count > 1 {
                    TrendChart(points: points.map { Double($0.value) }, tint: Palette.activity)
                        .frame(height: 96)
                    HStack {
                        Text(Fmt.dayTick(points.first!.day.date))
                        Spacer()
                        Text(Fmt.dayTick(points.last!.day.date))
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.textTertiary)
                } else {
                    Text("Need at least two days of data.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .padding(16)
        }
    }
}