import SwiftUI

/// One trend line on the period cards.
private struct TrendRow: Identifiable {
    let id = UUID()
    let title: String
    let tint: Color
    let values: [Double]
    var average: Int? {
        guard !values.isEmpty else { return nil }
        return Int(values.reduce(0, +) / Double(values.count))
    }
}

/// One view that renders every `ShareTemplate`. Kept as a single switch rather
/// than five near-duplicate views so the shared chrome — header, wash, footer —
/// cannot drift between formats.
struct ShareTemplateView: View {
    let template: ShareTemplate
    let store: HealthStore

    private var day: DailySnapshot? { store.selectedDay ?? store.today }
    private var size: CGSize { template.size(for: store) }
    private var scale: CGFloat { size.width / 1080 }

    private var wash: Color {
        guard let d = day else { return Palette.sleep }
        switch template {
        case .day:
            switch (store.sleepScore?.total ?? 0,
                  store.readinessScore?.total ?? 0,
                  store.activityScore?.total ?? 0) {
            case let (s, r, a) where s <= r && s <= a: return Palette.sleep
            case let (s, r, _) where r <= s: return Palette.readiness
            default: return Palette.activity
            }
        case .scores: return Palette.readiness
        case .training: return Palette.activity
        case .week: return Palette.sleep
        case .month: return Palette.hrv
        }
    }

    var body: some View {
        ZStack {
            Palette.bg

            RadialGradient(colors: [wash.opacity(0.28), .clear],
                           center: .topTrailing, startRadius: 20, endRadius: 820)
            RadialGradient(colors: [Palette.sleep.opacity(0.14), .clear],
                           center: .bottomLeading, startRadius: 20, endRadius: 660)

            content
                .padding(84 * scale)
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private var content: some View {
        switch template {
        case .day: dayBody
        case .scores: scoresBody
        case .training: trainingBody
        case .week: periodBody(days: 7, noun: "week")
        case .month: periodBody(days: 30, noun: "month")
        }
    }

    // MARK: - Shared chrome

    private var header: some View {
        HStack {
            Text("LUCK RING".uppercased())
                .font(.system(size: 26 * scale, weight: .semibold))
                .tracking(6)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Text(dayTitle)
                .font(.system(size: 26 * scale, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Rectangle().fill(Palette.stroke).frame(height: 1)
            Text("Scores are this app's own model, not a clinical measure")
                .font(.system(size: 20))
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private var dayTitle: String {
        guard let day else { return "—" }
        switch template {
        case .day, .scores, .training: return Fmt.dayTitle(day.date)
        case .week: return "Last 7 days"
        case .month: return "Last 30 days"
        }
    }

    // MARK: - Templates

    private var dayBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 22) {
                Text(headline)
                    .font(.system(size: 66 * scale, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
                HStack(spacing: 10) {
                    Capsule().fill(wash).frame(width: 54 * scale, height: 5)
                    Text(subheadline)
                        .font(.system(size: 30 * scale, weight: .medium))
                        .foregroundStyle(wash)
                }
            }
            Spacer(minLength: 0)
            scoreStrip
            Spacer(minLength: 0)
            detailRows
            Spacer(minLength: 0)
            footer
        }
    }

    private var scoresBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 0)
            Text(headline)
                .font(.system(size: 72 * scale, weight: .regular, design: .serif))
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 0)
            // Stacked, large, one per row — the bare-number format.
            VStack(spacing: 26) {
                scoreLine("Sleep", store.sleepScore?.total ?? 0, Palette.sleep)
                scoreLine("Readiness", store.readinessScore?.total ?? 0, Palette.readiness)
                scoreLine("Activity", store.activityScore?.total ?? 0, Palette.activity)
            }
            Spacer(minLength: 0)
            footer
        }
    }

    private func scoreLine(_ title: String, _ value: Int, _ tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 22 * scale, weight: .bold))
                .tracking(3)
                .foregroundStyle(Palette.textTertiary)
            Spacer()
            Text("\(value)")
                .font(.system(size: 76 * scale, weight: .regular, design: .serif))
                .foregroundStyle(tint)
            Rectangle().fill(tint.opacity(0.3)).frame(width: 90 * scale, height: 1)
        }
    }

    private var trainingBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 0)
            Text(trainingHeadline)
                .font(.system(size: 58 * scale, weight: .regular, design: .serif))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
            Spacer(minLength: 0)

            VStack(spacing: 22) {
                HStack(spacing: 18) {
                    bigStat("\(store.totalExerciseMinutes)", "min exercise", Palette.activity)
                    bigStat(String(format: "%.1f", day?.metHours ?? 0), "MET-hours", Palette.sleep)
                }
                HStack(spacing: 18) {
                    bigStat(Fmt.percent(store.weeklyTrainingLoad()), "week load", Palette.readiness)
                    bigStat("\(day?.workouts.count ?? 0)", "sessions", Palette.hrv)
                }
            }
            Spacer(minLength: 0)

            if let log = day?.workouts, !log.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(log.prefix(4)) { w in
                        HStack(spacing: 16) {
                            Image(systemName: w.kind.symbol)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Palette.activity)
                                .frame(width: 30)
                            Text(w.kind.title)
                                .font(.system(size: 24))
                                .foregroundStyle(Palette.textSecondary)
                            Spacer()
                            Text("\(Fmt.duration(w.duration)) · \(w.calories) kcal")
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.textPrimary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            footer
        }
    }

    private func bigStat(_ value: String, _ caption: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 54 * scale, weight: .regular, design: .serif))
                .foregroundStyle(tint)
            Text(caption)
                .font(.system(size: 22))
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18,
                                                          style: .continuous))
    }

    /// Shared by the week and month templates: averages plus a trend strip.
    private func periodBody(days: Int, noun: String) -> some View {
        let window = Array(store.recentWeekDays.prefix(days))
        let sleep: [Double] = store.trend(.sleep).map { Double($0.value) }
        let readiness: [Double] = store.trend(.readiness).map { Double($0.value) }
        let activity: [Double] = store.trend(.activity).map { Double($0.value) }
        let trends: [TrendRow] = [
            TrendRow(title: "Sleep", tint: Palette.sleep, values: sleep),
            TrendRow(title: "Readiness", tint: Palette.readiness, values: readiness),
            TrendRow(title: "Activity", tint: Palette.activity, values: activity),
        ]

        return VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 0)
            Text(periodHeadline(window: window, noun: noun))
                .font(.system(size: 58 * scale, weight: .regular, design: .serif))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
            Spacer(minLength: 0)

            VStack(spacing: 20) {
                ForEach(trends) { row in
                    HStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title.uppercased())
                                .font(.system(size: 20, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(Palette.textTertiary)
                            if !row.values.isEmpty {
                                Sparkline(values: row.values, tint: row.tint)
                                    .frame(width: 300 * scale, height: 44 * scale)
                            }
                        }
                        Spacer()
                        Text(row.average.map(String.init) ?? "—")
                            .font(.system(size: 56 * scale, weight: .regular, design: .serif))
                            .foregroundStyle(row.tint)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 18) {
                averageStat("Steps/day", window.compactMap { $0.activity?.steps },
                            unit: "", grouped: true)
                averageStat("Sleep/night",
                            window.compactMap { $0.sleep.map { Int($0.asleep / 3600) } },
                            unit: "h")
            }
            Spacer(minLength: 0)
            footer
        }
    }

    private func averageStat(_ caption: String, _ values: [Int], unit: String,
                             grouped: Bool = false) -> some View {
        let mean = values.isEmpty ? nil : values.reduce(0, +) / values.count
        let value: String
        if let mean {
            value = grouped ? Fmt.count(mean) : "\(mean)"
        } else {
            value = "—"
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text(value + unit)
                .font(.system(size: 44 * scale, weight: .regular, design: .serif))
                .foregroundStyle(Palette.textPrimary)
            Text(caption)
                .font(.system(size: 20))
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18,
                                                          style: .continuous))
    }

    // MARK: - Pieces

    private var scoreStrip: some View {
        HStack(spacing: 0) {
            scoreBlock("Sleep", store.sleepScore?.total ?? 0, Palette.sleep)
            blockDivider
            scoreBlock("Readiness", store.readinessScore?.total ?? 0, Palette.readiness)
            blockDivider
            scoreBlock("Activity", store.activityScore?.total ?? 0, Palette.activity)
        }
        .padding(.vertical, 34)
        .overlay(alignment: .top) { rule }
        .overlay(alignment: .bottom) { rule }
    }

    private var rule: some View {
        Rectangle().fill(Palette.stroke).frame(height: 1)
    }

    private var blockDivider: some View {
        Rectangle().fill(Palette.stroke).frame(width: 1, height: 104)
    }

    private func scoreBlock(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 8) {
            Text("\(value)")
                .font(.system(size: 70 * scale, weight: .regular, design: .serif))
                .foregroundStyle(tint)
            Text(title.uppercased())
                .font(.system(size: 20, weight: .bold))
                .tracking(3)
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var detailRows: some View {
        VStack(spacing: 20) {
            detail("bed.double.fill", Palette.sleep, "Time asleep",
                   day?.sleep.map { Fmt.duration($0.asleep) } ?? "—")
            detail("figure.walk.motion", Palette.activity, "Steps",
                   day?.activity.map { Fmt.count($0.steps) } ?? "—")
            detail("heart.fill", Palette.heart, "Resting HR",
                   day?.restingHeartRate.map { "\($0) bpm" } ?? "—")
            detail("waveform.path.ecg", Palette.hrv, "HRV",
                   day?.averageHRV.map { "\($0) ms" } ?? "—")
        }
    }

    private func detail(_ symbol: String, _ tint: Color, _ title: String,
                        _ value: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34)
            Text(title)
                .font(.system(size: 26))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
        }
    }

    // MARK: - Copy

    private var headline: String {
        let lowest = min(store.sleepScore?.total ?? 0,
                         store.readinessScore?.total ?? 0,
                         store.activityScore?.total ?? 0)
        switch lowest {
        case 85...: return "A strong day"
        case 70..<85: return "A decent day"
        case 55..<70: return "A mixed day"
        default: return "A hard day"
        }
    }

    private var subheadline: String {
        switch min(store.sleepScore?.total ?? 0, store.readinessScore?.total ?? 0,
                   store.activityScore?.total ?? 0) {
        case 85...: return "All three scores in good shape"
        case 70..<85: return "Room to improve"
        case 55..<70: return "Take it easy today"
        default: return "Prioritise recovery"
        }
    }

    private var trainingHeadline: String {
        let minutes = store.totalExerciseMinutes
        if minutes == 0 { return "No sessions logged yet" }
        if minutes >= 180 { return "A big training week" }
        if minutes >= 90 { return "A solid training week" }
        return "Light training this week"
    }

    private func periodHeadline(window: [DailySnapshot], noun: String) -> String {
        let scored = window.compactMap { d -> Int? in
            d.sleep == nil ? nil : ScoreEngine.sleep(for: d, goals: store.goals,
                                                     baseline: store.baseline).total
        }
        guard !scored.isEmpty else { return "Building your \(noun)" }
        let avg = scored.reduce(0, +) / scored.count
        switch avg {
        case 85...: return "A strong \(noun)"
        case 70..<85: return "A steady \(noun)"
        case 55..<70: return "An uneven \(noun)"
        default: return "A difficult \(noun)"
        }
    }
}