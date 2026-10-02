import SwiftUI

/// Headline screen. Follows the reference layout: circular shortcut badges, a
/// large arc gauge, then an editorial serif headline with body copy, and the
/// score cards below.
struct TodayView: View {
    @ObservedObject var store: HealthStore
    @Binding var showDevice: Bool

    private var day: DailySnapshot? { store.selectedDay }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header

                if store.orderedDays.isEmpty {
                    emptyState
                } else {
                    shortcutBadges
                    heroCard
                    actionItems
                    if let day {
                        if let sleep = day.sleep { sleepCard(day, sleep) }
                        readinessCard(day)
                        activityCard(day)
                        vitalsCard(day)
                        timelineCard(day)
                    }
                }
            }
            // Leave room for the floating bar.
            .padding(.bottom, 96)
        }
        .background(Palette.bg.ignoresSafeArea())
        .refreshable { store.refresh() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Button { showDevice = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ring settings")

            Spacer()

            Text("LUCK RING")
                .font(.system(size: 15, weight: .medium))
                .tracking(2.4)
                .foregroundStyle(Palette.textPrimary)

            Spacer()

            Button { showDevice = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "circle.dotted.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                    if let b = store.batteryPercent {
                        Text("\(b)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Palette.bg)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(batteryTint(b), in: Capsule())
                            .offset(x: 7, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ring and device settings")
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    // MARK: - Shortcuts

    private var shortcutBadges: some View {
        let catalogue = Shortcut.catalogue(days: store.days, goals: store.goals)
        let shown = Shortcut.defaultOrder.compactMap { id in catalogue.first { $0.id == id } }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(shown) { s in
                    ShortcutBadge(title: s.title, value: s.value,
                                  symbol: s.symbol, tint: s.tint)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        let score = store.readinessScore?.total ?? 0
        let verdict = ScoreVerdict.readiness(score)

        return VStack(spacing: 18) {
            ArcGauge(score: score, tint: Palette.readiness, caption: "readiness")

            VStack(spacing: 10) {
                Text(verdict.title)
                    .font(.display(30))
                    .foregroundStyle(Palette.textPrimary)

                Text(heroCopy(for: verdict))
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320)

                PillButton(title: "See what's driving it", symbol: "sparkles")
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.surface)
                .overlay(
                    RadialGradient(colors: [Palette.readiness.opacity(0.16), .clear],
                                   center: .top, startRadius: 10, endRadius: 260))
        }
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(Palette.stroke, lineWidth: 1))
        .padding(.horizontal, 18)
    }

    /// Editorial standfirst under the headline — the reference design uses this
    /// slot for advice, so we derive it from today's numbers.
    private func heroCopy(for verdict: (title: String, detail: String)) -> String {
        guard let day else { return "Pair a ring to see your readiness here." }
        var parts: [String] = []

        if let sleep = day.sleep {
            parts.append("You slept \(Fmt.duration(sleep.asleep)) at \(Fmt.percent(sleep.efficiency)) efficiency")
        }
        if let hrv = day.averageHRV {
            let delta = store.baseline?.averageHRV.map { hrv - $0 }
            if let delta, delta != 0 {
                parts.append("HRV \(delta > 0 ? "up" : "down") \(abs(delta)) ms")
            }
        }
        if let steps = day.activity?.steps {
            parts.append("\(Fmt.count(steps)) steps so far")
        }

        return parts.isEmpty
            ? verdict.detail
            : parts.joined(separator: " · ") + "."
    }

    // MARK: - Action items

    private var actionItems: some View {
        let items = Insights.actionItems(days: store.days, connection: store.connection,
                                         battery: store.batteryPercent,
                                         streaming: store.isStreaming, goals: store.goals)
        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    CapsLabel(text: "Needs attention")
                        .padding(.horizontal, 18)
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 11) {
                            IconBadge(symbol: item.symbol, tint: item.tint, size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Palette.textPrimary)
                                Text(item.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(13)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16,
                                                                         style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(item.tint.opacity(0.3), lineWidth: 1))
                        .padding(.horizontal, 18)
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
        let band = store.averageScore(.sleep).map { score.total - $0 } ?? 0
        let spread = store.averageScore(.sleep).map { max(14, Int(Double($0) * 0.35)) } ?? 20

        return GlowCard(tint: Palette.sleep) {
            VStack(alignment: .leading, spacing: 15) {
                CardHeaderRow(title: "Sleep", symbol: "bed.double.fill",
                              status: verdict.title.uppercased(), tint: Palette.sleep)

                HStack(alignment: .center, spacing: 14) {
                    ScoreWithMark(score: score.total, symbol: "crown.fill", size: 44)
                        .frame(width: 96, alignment: .leading)
                    RangeScale(value: score.total,
                               min: max(40, score.total - band - spread),
                               max: min(100, score.total - band + spread),
                               tint: Palette.sleep)
                }

                MetricRow(title: "Time asleep", value: Fmt.duration(sleep.asleep),
                          tint: Palette.sleep,
                          progress: min(1, sleep.asleep
                                        / Double(store.goals.sleepTargetMinutes * 60)))
                MetricRow(title: "Time in bed", value: Fmt.duration(sleep.duration))
                MetricRow(title: "Efficiency", value: Fmt.percent(sleep.efficiency),
                          tint: efficiencyTint(sleep.efficiency))

                StageBreakdown(sleep: sleep)

                HStack(spacing: 8) {
                    Chip(text: "BED \(Fmt.clock(sleep.start))", tint: Palette.sleep)
                    Chip(text: "UP \(Fmt.clock(sleep.end))", tint: Palette.sleep)
                }

                ContributionStrip(parts: [
                    .init(points: score.durationPoints, max: 40, tint: Palette.sleep, label: "duration"),
                    .init(points: score.efficiencyPoints, max: 25, tint: Palette.readiness, label: "efficiency"),
                    .init(points: score.deepPoints, max: 20, tint: Palette.sleepDeep, label: "deep"),
                    .init(points: score.timingPoints, max: 15, tint: Palette.hrv, label: "timing"),
                ])
            }
            .padding(16)
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Readiness

    private func readinessCard(_ day: DailySnapshot) -> some View {
        let score = store.readinessScore ?? ScoreEngine.ReadinessBreakdown(
            total: 0, sleepPoints: 0, hrvPoints: 0, restingHRPoints: 0, temperaturePoints: 0)
        let verdict = ScoreVerdict.readiness(score.total)
        let band = store.averageScore(.readiness).map { score.total - $0 } ?? 0
        let spread = store.averageScore(.readiness).map { max(14, Int(Double($0) * 0.3)) } ?? 18
        let base = store.baseline

        return GlowCard(tint: Palette.readiness) {
            VStack(alignment: .leading, spacing: 15) {
                CardHeaderRow(title: "Readiness", symbol: "bolt.heart.fill",
                              status: verdict.title.uppercased(), tint: Palette.readiness)

                HStack(alignment: .center, spacing: 14) {
                    ScoreWithMark(score: score.total, symbol: "crown.fill", size: 44)
                        .frame(width: 96, alignment: .leading)
                    RangeScale(value: score.total,
                               min: max(40, score.total - band - spread),
                               max: min(100, score.total - band + spread),
                               tint: Palette.readiness)
                }

                Text(verdict.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                MetricRow(title: "Resting heart rate",
                          value: day.restingHeartRate.map(String.init) ?? "—", unit: "bpm",
                          tint: Palette.heart,
                          delta: day.restingHeartRate.flatMap { r in
                              base?.averageRestingHR.map { r - $0 } },
                          deltaUnit: " bpm", higherIsBetter: false)
                MetricRow(title: "HRV",
                          value: day.averageHRV.map(String.init) ?? "—", unit: "ms",
                          tint: Palette.hrv,
                          delta: day.averageHRV.flatMap { v in
                              base?.averageHRV.map { v - $0 } },
                          deltaUnit: " ms")

                Divider().overlay(Palette.stroke)
                ContributionStrip(parts: [
                    .init(points: score.sleepPoints, max: 50, tint: Palette.sleep, label: "sleep"),
                    .init(points: score.hrvPoints, max: 25, tint: Palette.hrv, label: "HRV"),
                    .init(points: score.restingHRPoints, max: 15, tint: Palette.heart, label: "RHR"),
                    .init(points: score.temperaturePoints, max: 10, tint: Palette.temp, label: "temp"),
                ])
            }
            .padding(16)
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Activity

    private func activityCard(_ day: DailySnapshot) -> some View {
        let score = store.activityScore ?? ScoreEngine.ActivityBreakdown(
            total: 0, stepsPoints: 0, caloriesPoints: 0, activeTimePoints: 0)
        let verdict = ScoreVerdict.activity(score.total)
        let band = store.averageScore(.activity).map { score.total - $0 } ?? 0
        let spread = store.averageScore(.activity).map { max(14, Int(Double($0) * 0.4)) } ?? 25
        let a = day.activity

        return GlowCard(tint: Palette.activity) {
            VStack(alignment: .leading, spacing: 15) {
                CardHeaderRow(title: "Activity goal", symbol: "flame.fill",
                              status: verdict.title.uppercased(), tint: Palette.activity)

                HStack(alignment: .center, spacing: 14) {
                    ScoreWithMark(score: score.total, size: 44)
                        .frame(width: 96, alignment: .leading)
                    RangeScale(value: score.total,
                               min: max(0, score.total - band - spread),
                               max: min(100, score.total - band + spread),
                               tint: Palette.activity)
                }

                if let a {
                    HStack(spacing: 14) {
                        ProgressRing(progress: Double(a.steps) / Double(max(1, store.goals.stepTarget)),
                                     tint: Palette.activity, size: 62, lineWidth: 6,
                                     value: Fmt.count(a.steps), caption: "steps")
                        ProgressRing(progress: Double(a.calories) / 500,
                                     tint: Palette.activity, size: 62, lineWidth: 6,
                                     value: "\(a.calories)", caption: "kcal")
                        ProgressRing(progress: Double(a.activeSeconds)
                                        / Double(max(1, store.goals.activeMinutesTarget * 60)),
                                     tint: Palette.activity, size: 62, lineWidth: 6,
                                     value: Fmt.duration(TimeInterval(a.activeSeconds)),
                                     caption: "active")
                    }
                    .frame(maxWidth: .infinity)

                    MetricRow(title: "Distance", value: Fmt.distance(a.distanceMetres),
                              unit: Fmt.distanceUnit(a.distanceMetres))
                } else {
                    Text("No movement data yet for this day.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Vitals

    private func vitalsCard(_ day: DailySnapshot) -> some View {
        GlowCard {
            VStack(alignment: .leading, spacing: 13) {
                CardHeaderRow(title: "Vitals", symbol: "waveform.path.ecg",
                              tint: Palette.oxygen)

                if let bp = day.latestBloodPressure {
                    MetricRow(title: "Blood pressure",
                              value: "\(bp.systolic)/\(bp.diastolic)", unit: "mmHg",
                              tint: Palette.pressure)
                }
                MetricRow(title: "Blood oxygen",
                          value: day.averageOxygen.map { "\($0)" } ?? "—", unit: "%",
                          tint: Palette.oxygen,
                          progress: day.averageOxygen.map { min(1, Double($0) / 100) })

                HStack(spacing: 10) {
                    MiniStat(title: "Resting", value: day.restingHeartRate.map(String.init) ?? "—",
                             unit: "bpm", tint: Palette.heart)
                    MiniStat(title: "Low", value: day.lowestHeartRate.map(String.init) ?? "—",
                             unit: "bpm", tint: Palette.readiness)
                    MiniStat(title: "High", value: day.highestHeartRate.map(String.init) ?? "—",
                             unit: "bpm", tint: Palette.warn)
                }

                if day.heartRate.count > 2 {
                    Sparkline(values: day.heartRate.map { Double($0.bpm) }, tint: Palette.heart,
                              baseline: day.restingHeartRate.map(Double.init))
                        .frame(height: 56)
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Timeline

    private func timelineCard(_ day: DailySnapshot) -> some View {
        let events = Insights.events(for: day)
        return GlowCard {
            VStack(alignment: .leading, spacing: 14) {
                CardHeaderRow(title: "Recent events", symbol: "clock.arrow.circlepath")

                if events.isEmpty {
                    Text("Nothing recorded for this day yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textTertiary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            HStack(alignment: .top, spacing: 11) {
                                VStack(spacing: 0) {
                                    Circle().fill(event.tint).frame(width: 8, height: 8)
                                    if index < events.count - 1 {
                                        Rectangle().fill(Palette.stroke)
                                            .frame(width: 1.5)
                                            .frame(maxHeight: .infinity)
                                    }
                                }
                                .frame(width: 8)

                                VStack(alignment: .leading, spacing: 1) {
                                    HStack {
                                        Text(event.title)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Palette.textPrimary)
                                        Spacer()
                                        Text(Fmt.clock(event.time))
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Palette.textTertiary)
                                    }
                                    Text(event.detail)
                                        .font(.system(size: 11))
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
            .padding(16)
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Helpers

    private func efficiencyTint(_ v: Double) -> Color {
        v >= 0.9 ? Palette.good : v >= 0.8 ? Palette.warn : Palette.bad
    }

    private func batteryTint(_ level: Int) -> Color {
        level > 40 ? Palette.good : level > 15 ? Palette.warn : Palette.bad
    }

    private var emptyState: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderRow(title: "No data yet", symbol: "circle.dotted.circle")
                Text("Open the ring settings to pair your ring, then pull down to refresh. History the ring already holds is uploaded once the sensor switch is on.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                PillButton(title: "Pair a ring", symbol: "circle.dotted.circle", tint: Palette.sleep)
                    .onTapGesture { showDevice = true }
            }
            .padding(16)
        }
        .padding(.horizontal, 18)
    }
}