import SwiftUI

/// Headline screen. Mirrors the structure health apps converge on: pinned
/// metric shortcuts, the three scores, things needing attention, and a timeline
/// of what actually happened today.
struct TodayView: View {
    @ObservedObject var store: HealthStore
    @State private var pinned: [String] = Shortcut.defaultOrder
    @State private var showDevice = false

    private var day: DailySnapshot? { store.selectedDay }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if store.orderedDays.isEmpty {
                    emptyState
                } else {
                    shortcutRow
                    if let day {
                        scoreStrip
                        actionItems
                        if let sleep = day.sleep { sleepCard(day, sleep) }
                        readinessCard(day)
                        activityCard(day)
                        vitalsCard(day)
                        heartRateCard(day)
                        timelineCard(day)
                    }
                }
            }
            .padding(.bottom, 28)
        }
        .background(Palette.bg.ignoresSafeArea())
        .refreshable { store.refresh() }
        .sheet(isPresented: $showDevice) { DeviceSheet(store: store) }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.metric(24))
                    .foregroundStyle(Palette.textPrimary)
                Text(day.map { Fmt.dayTitle($0.date) } ?? "No data")
                    .font(.label(13))
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Button { showDevice = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "circle.dotted.circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                    if let b = store.batteryPercent {
                        Text("\(b)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Palette.bg)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(batteryTint(b), in: Capsule())
                            .offset(x: 8, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ring and device settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Shortcuts

    private var shortcutRow: some View {
        let catalogue = Shortcut.catalogue(days: store.days, goals: store.goals)
        let shown = pinned.compactMap { id in catalogue.first { $0.id == id } }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(shown) { s in
                    Button { store.select(day: nil) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: s.symbol)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(s.tint)
                                Spacer()
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                Text(s.value)
                                    .font(.score(23))
                                    .foregroundStyle(Palette.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Text(s.caption)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Palette.textTertiary)
                            }
                            Text(s.title)
                                .font(.label(12))
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(width: 108, height: 106, alignment: .topLeading)
                        .padding(12)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Palette.stroke, lineWidth: 1))
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(s.tint.opacity(0.4), lineWidth: 1)
                                .mask(LinearGradient(colors: [.black, .clear],
                                                     startPoint: .top, endPoint: .bottom)
                                    .frame(height: 64))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Score strip

    private var scoreStrip: some View {
        HStack(spacing: 10) {
            ScoreGauge(score: store.sleepScore?.total ?? 0, tint: Palette.sleep,
                       size: 100, lineWidth: 8, label: "sleep")
            ScoreGauge(score: store.readinessScore?.total ?? 0, tint: Palette.readiness,
                       size: 100, lineWidth: 8, label: "ready")
            ScoreGauge(score: store.activityScore?.total ?? 0, tint: Palette.activity,
                       size: 100, lineWidth: 8, label: "active")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    // MARK: - Action items

    private var actionItems: some View {
        let items = Insights.actionItems(days: store.days, connection: store.connection,
                                         battery: store.batteryPercent, streaming: store.isStreaming, goals: store.goals)
        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NEEDS ATTENTION")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Palette.textTertiary)
                        .padding(.horizontal, 16)
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(item.tint)
                                .frame(width: 26, height: 26)
                                .background(item.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.metric(14))
                                    .foregroundStyle(Palette.textPrimary)
                                Text(item.detail)
                                    .font(.label(11))
                                    .foregroundStyle(Palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(item.tint.opacity(0.28), lineWidth: 1))
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    // MARK: - Sleep

    private func sleepCard(_ day: DailySnapshot, _ sleep: SleepSession) -> some View {
        let score = store.sleepScore ?? ScoreEngine.SleepBreakdown(
            total: 0, durationPoints: 0, efficiencyPoints: 0, deepPoints: 0, timingPoints: 0)
        let verdict = ScoreVerdict.sleep(score.total)

        return Card(tint: Palette.sleep) {
            VStack(alignment: .leading, spacing: 15) {
                SectionHeader(title: "Sleep", icon: "bed.double.fill", tint: Palette.sleep)

                ScoreHero(score: score.total, verdict: verdict.title, detail: verdict.detail,
                          tint: Palette.sleep,
                          delta: store.scoreDelta(.sleep, current: score.total))

                MetricRow(title: "Time asleep", value: Fmt.duration(sleep.asleep),
                          tint: Palette.sleep,
                          progress: min(1, sleep.asleep / Double(store.goals.sleepTargetMinutes * 60)))
                MetricRow(title: "Time in bed", value: Fmt.duration(sleep.duration))
                MetricRow(title: "Efficiency", value: Fmt.percent(sleep.efficiency),
                          tint: efficiencyTint(sleep.efficiency))
                MetricRow(title: "Deep sleep", value: Fmt.duration(sleep.time(.deep)),
                          tint: Palette.sleepDeep)
                MetricRow(title: "REM", value: Fmt.duration(sleep.time(.rem)), tint: Palette.hrv)
                MetricRow(title: "Awake", value: Fmt.duration(sleep.time(.awake)), tint: Palette.warn)

                HStack(spacing: 8) {
                    Chip(text: "BED \(Fmt.clock(sleep.start))", tint: Palette.sleep)
                    Chip(text: "UP \(Fmt.clock(sleep.end))", tint: Palette.sleep)
                    Chip(text: sleep.sleepScoreBand.uppercased(),
                         tint: efficiencyTint(sleep.efficiency))
                }

                Divider().overlay(Palette.stroke)
                StageBreakdown(sleep: sleep)

                Divider().overlay(Palette.stroke)
                ContributionStrip(parts: [
                    .init(points: score.durationPoints, max: 40, tint: Palette.sleep, label: "duration"),
                    .init(points: score.efficiencyPoints, max: 25, tint: Palette.readiness, label: "efficiency"),
                    .init(points: score.deepPoints, max: 20, tint: Palette.sleepDeep, label: "deep"),
                    .init(points: score.timingPoints, max: 15, tint: Palette.hrv, label: "timing"),
                ])
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Readiness

    private func readinessCard(_ day: DailySnapshot) -> some View {
        let score = store.readinessScore ?? ScoreEngine.ReadinessBreakdown(
            total: 0, sleepPoints: 0, hrvPoints: 0, restingHRPoints: 0, temperaturePoints: 0)
        let verdict = ScoreVerdict.readiness(score.total)
        let base = store.baseline

        return Card(tint: Palette.readiness) {
            VStack(alignment: .leading, spacing: 15) {
                SectionHeader(title: "Readiness", icon: "bolt.heart.fill", tint: Palette.readiness)

                ScoreHero(score: score.total, verdict: verdict.title, detail: verdict.detail,
                          tint: Palette.readiness,
                          delta: store.scoreDelta(.readiness, current: score.total))

                MetricRow(title: "Resting heart rate",
                          value: day.restingHeartRate.map(String.init) ?? "—", unit: "bpm",
                          tint: Palette.heart,
                          progress: day.restingHeartRate.map { min(1, Double($0) / 100) },
                          delta: day.restingHeartRate.flatMap { r in
                              base?.averageRestingHR.map { r - $0 } })

                MetricRow(title: "HRV",
                          value: day.averageHRV.map(String.init) ?? "—", unit: "ms",
                          tint: Palette.hrv,
                          progress: day.averageHRV.map { min(1, Double($0) / 80) },
                          delta: day.averageHRV.flatMap { v in
                              base?.averageHRV.map { v - $0 } })

                if let delta = day.temperatureDelta(baseline: base?.averageSkinTemp) {
                    MetricRow(title: "Skin temperature",
                              value: Fmt.signed(delta), unit: "°C vs baseline",
                              tint: abs(delta) > 0.5 ? Palette.warn : Palette.temp)
                }

                Divider().overlay(Palette.stroke)
                ContributionStrip(parts: [
                    .init(points: score.sleepPoints, max: 50, tint: Palette.sleep, label: "sleep"),
                    .init(points: score.hrvPoints, max: 25, tint: Palette.hrv, label: "HRV"),
                    .init(points: score.restingHRPoints, max: 15, tint: Palette.heart, label: "RHR"),
                    .init(points: score.temperaturePoints, max: 10, tint: Palette.temp, label: "temp"),
                ])
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Activity

    private func activityCard(_ day: DailySnapshot) -> some View {
        let score = store.activityScore ?? ScoreEngine.ActivityBreakdown(
            total: 0, stepsPoints: 0, caloriesPoints: 0, activeTimePoints: 0)
        let verdict = ScoreVerdict.activity(score.total)
        let a = day.activity

        return Card(tint: Palette.activity) {
            VStack(alignment: .leading, spacing: 15) {
                SectionHeader(title: "Activity", icon: "figure.walk.motion", tint: Palette.activity)

                ScoreHero(score: score.total, verdict: verdict.title, detail: verdict.detail,
                          tint: Palette.activity,
                          delta: store.scoreDelta(.activity, current: score.total))

                if let a {
                    HStack(spacing: 14) {
                        ProgressRing(progress: Double(a.steps) / Double(max(1, store.goals.stepTarget)),
                                     tint: Palette.activity, size: 66, lineWidth: 6,
                                     value: "\(a.steps)", caption: "steps")
                        ProgressRing(progress: Double(a.calories) / 500,
                                     tint: Palette.activity, size: 66, lineWidth: 6,
                                     value: "\(a.calories)", caption: "kcal")
                        ProgressRing(progress: Double(a.activeSeconds)
                                        / Double(max(1, store.goals.activeMinutesTarget * 60)),
                                     tint: Palette.activity, size: 66, lineWidth: 6,
                                     value: Fmt.duration(TimeInterval(a.activeSeconds)),
                                     caption: "active")
                    }
                    .frame(maxWidth: .infinity)

                    MetricRow(title: "Distance",
                              value: Fmt.distance(a.distanceMetres),
                              unit: Fmt.distanceUnit(a.distanceMetres))
                    MetricRow(title: "Total calories", value: "\(a.totalCalories)", unit: "kcal")

                    Divider().overlay(Palette.stroke)
                    ContributionStrip(parts: [
                        .init(points: score.stepsPoints, max: 50, tint: Palette.activity, label: "steps"),
                        .init(points: score.caloriesPoints, max: 30, tint: Palette.activity, label: "calories"),
                        .init(points: score.activeTimePoints, max: 20, tint: Palette.activity, label: "active time"),
                    ])
                } else {
                    Text("No movement data yet for this day.")
                        .font(.label(13))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Vitals

    private func vitalsCard(_ day: DailySnapshot) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Vitals", icon: "waveform.path.ecg", tint: Palette.oxygen)

                if let bp = day.latestBloodPressure {
                    MetricRow(title: "Blood pressure",
                              value: "\(bp.systolic)/\(bp.diastolic)", unit: "mmHg",
                              tint: Palette.pressure)
                }
                MetricRow(title: "Blood oxygen",
                          value: day.averageOxygen.map { "\($0)" } ?? "—", unit: "%",
                          tint: Palette.oxygen,
                          progress: day.averageOxygen.map { min(1, Double($0) / 100) })
                MetricRow(title: "Heart-rate readings", value: "\(day.heartRate.count)",
                          unit: "samples", tint: Palette.textSecondary)

                Text("On-demand measurements live in the ring sheet.")
                    .font(.label(11))
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Heart rate

    private func heartRateCard(_ day: DailySnapshot) -> some View {
        Card(tint: Palette.heart) {
            VStack(alignment: .leading, spacing: 13) {
                SectionHeader(title: "Heart rate", icon: "heart.fill", tint: Palette.heart)

                HStack(spacing: 10) {
                    MiniStat(title: "Resting", value: day.restingHeartRate.map(String.init) ?? "—",
                             unit: "bpm", tint: Palette.heart)
                    MiniStat(title: "Lowest", value: day.lowestHeartRate.map(String.init) ?? "—",
                             unit: "bpm", tint: Palette.readiness)
                    MiniStat(title: "Highest", value: day.highestHeartRate.map(String.init) ?? "—",
                             unit: "bpm", tint: Palette.warn)
                }

                if day.heartRate.count > 2, let first = day.heartRate.first,
                   let last = day.heartRate.last {
                    Sparkline(values: day.heartRate.map { Double($0.bpm) },
                              tint: Palette.heart,
                              baseline: day.restingHeartRate.map(Double.init))
                        .frame(height: 64)
                    HStack {
                        Text(Fmt.clock(first.time))
                        Spacer()
                        Text("\(day.heartRate.count) readings")
                        Spacer()
                        Text(Fmt.clock(last.time))
                    }
                    .font(.label(10))
                    .foregroundStyle(Palette.textTertiary)
                } else {
                    Text("Not enough heart-rate samples yet.")
                        .font(.label(13))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Timeline

    private func timelineCard(_ day: DailySnapshot) -> some View {
        let events = Insights.events(for: day)

        return Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Recent events", icon: "clock.arrow.circlepath")

                if events.isEmpty {
                    Text("Nothing recorded for this day yet.")
                        .font(.label(13))
                        .foregroundStyle(Palette.textTertiary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            HStack(alignment: .top, spacing: 11) {
                                VStack(spacing: 0) {
                                    Circle()
                                        .fill(event.tint)
                                        .frame(width: 9, height: 9)
                                    if index < events.count - 1 {
                                        Rectangle()
                                            .fill(Palette.stroke)
                                            .frame(width: 1.5)
                                            .frame(maxHeight: .infinity)
                                    }
                                }
                                .frame(width: 9)

                                VStack(alignment: .leading, spacing: 1) {
                                    HStack {
                                        Text(event.title)
                                            .font(.metric(14))
                                            .foregroundStyle(Palette.textPrimary)
                                        Spacer()
                                        Text(Fmt.clock(event.time))
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Palette.textTertiary)
                                    }
                                    Text(event.detail)
                                        .font(.label(11))
                                        .foregroundStyle(Palette.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.bottom, 14)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func efficiencyTint(_ v: Double) -> Color {
        v >= 0.9 ? Palette.good : v >= 0.8 ? Palette.warn : Palette.bad
    }

    private func batteryTint(_ level: Int) -> Color {
        level > 40 ? Palette.good : level > 15 ? Palette.warn : Palette.bad
    }

    private var emptyState: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "No data yet")
                Text("Tap the ring icon to pair your ring, then pull down to refresh. History the ring already holds is uploaded once the sensor switch is on.")
                    .font(.label(13))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open ring sheet") { showDevice = true }
                    .font(.label(14))
                    .buttonStyle(.bordered)
                    .tint(Palette.sleep)
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, 16)
    }
}