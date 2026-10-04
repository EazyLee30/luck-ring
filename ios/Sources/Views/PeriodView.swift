import SwiftUI

/// Week and month overviews. Averages with the number of days behind them, the
/// spread around each average, and a calendar to see where the days actually fell.
struct PeriodView: View {
    @ObservedObject var store: HealthStore
    @Environment(\.dismiss) private var dismiss

    enum Window: String, CaseIterable, Identifiable {
        case week = "7 days"
        case month = "30 days"
        var id: String { rawValue }
        var days: Int { self == .week ? 7 : 30 }
    }

    @State private var window: Window = .week
    @State private var metric: CalendarHeatmap.Metric = .sleep
    /// Which month the calendar draws. Seeded from the data rather than from today,
    /// so the month view is not empty for the first half of every month.
    @State private var month: Date

    init(store: HealthStore) {
        self.store = store
        // @State cannot read another property here, so the default month is seeded
        // through the initial value.
        _month = State(initialValue: CalendarHeatmap.defaultMonth(for: store.orderedDays))
    }
    @State private var heatmapMonth = Date()

    private var summary: PeriodSummary {
        PeriodSummary.make(from: store.orderedDays, goals: store.goals,
                           baseline: store.baseline, window: window.days)
    }

    enum Anchor: String { case top, calendar, averages }

    private var anchor: Anchor {
        Anchor(rawValue: LaunchOption.value("-periodAnchor") ?? "top") ?? .top
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 16) {
                picker
                verdictCard
                scoreSpreads
                heatmapCard.id("calendar")
                averagesCard.id("averages")
                trainingCard
                footer
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .onAppear {
            guard anchor != .top else { return }
            // Two hops: the first runs before the scroll view has a content size.
            DispatchQueue.main.async {
                withAnimation(.none) { proxy.scrollTo(id(anchor), anchor: .top) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.none) { proxy.scrollTo(id(anchor), anchor: .top) }
                }
            }
        }
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(window == .week ? "This week" : "This month")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func id(_ anchor: Anchor) -> String {
        anchor == .calendar ? "calendar" : "averages"
    }

    // MARK: - Controls

    private var picker: some View {
        SegmentedScale(labels: Window.allCases.map(\.rawValue),
                       active: Window.allCases.firstIndex(of: window) ?? 0,
                       tint: Palette.sleep)
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.18)) {
                    window = Window.allCases[Window.allCases.firstIndex(of: window) == 0
                                             ? 1 : 0]
                }
                Haptics.select()
            }
    }

    // MARK: - Verdict

    private var verdictCard: some View {
        GlowCard(tint: Palette.sleep) {
            VStack(alignment: .leading, spacing: 12) {
                CapsLabel(text: summary.coverageNote)
                Text(summary.verdict)
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !summary.hasEnoughData {
                    Text("At least \(PeriodSummary.minimumDays) days are needed before an average says anything. Showing what exists so far.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let weak = summary.weakest {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.warn)
                        Text("\(weak.title) is the weak spot, averaging \(weak.value).")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
    }

    // MARK: - Spreads

    private var scoreSpreads: some View {
        GlowCard(tint: Palette.sleep) {
            VStack(alignment: .leading, spacing: 16) {
                CardHeaderRow(title: "How the days went", symbol: "chart.bar.fill",
                              tint: Palette.sleep)

                spreadRow("Sleep", summary.sleep, Palette.sleep)
                Divider().overlay(Palette.stroke)
                spreadRow("Readiness", summary.readiness, Palette.readiness)
                Divider().overlay(Palette.stroke)
                spreadRow("Activity", summary.activity, Palette.activity)
            }
            .padding(16)
        }
    }

    /// Mean with the spread beside it. A mean without a spread is a number that
    /// hides whether the period was steady or saw-toothed.
    private func spreadRow(_ title: String, _ spread: PeriodSummary.Spread,
                           _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                if let mean = spread.mean {
                    Text("\(mean)")
                        .font(.system(size: 26, weight: .medium, design: .serif))
                        .foregroundStyle(tint)
                } else {
                    Text("—")
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .foregroundStyle(Palette.textTertiary)
                }
            }

            if spread.count > 1 {
                Sparkline(values: spread.points.map { Double($0.value) }, tint: tint)
                    .frame(height: 26)
            }

            HStack(spacing: 12) {
                if let deviation = spread.deviation {
                    label("±\(Int(deviation.rounded()))", "spread")
                }
                if let share = spread.goodShare {
                    label("\(Int((share * 100).rounded()))%", "days ≥ 70")
                }
                if let range = spread.range {
                    label("\(range)", "range")
                }
                Spacer()
            }
        }
    }

    private func label(_ value: String, _ caption: String) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(Palette.textTertiary)
        }
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        GlowCard(tint: metric.tint) {
            VStack(alignment: .leading, spacing: 14) {
                monthHeader

                SegmentedScale(labels: CalendarHeatmap.Metric.allCases.map(\.title),
                               active: CalendarHeatmap.Metric.allCases
                                   .firstIndex(of: metric) ?? 0,
                               tint: metric.tint)
                    .onTapGesture {
                        let all = CalendarHeatmap.Metric.allCases
                        let index = all.firstIndex(of: metric) ?? 0
                        withAnimation(.easeOut(duration: 0.18)) {
                            metric = all[(index + 1) % all.count]
                        }
                        Haptics.select()
                    }

                CalendarHeatmap(days: store.orderedDays, goals: store.goals,
                                baseline: store.baseline, metric: metric,
                                selected: store.selectedDate, month: $month) { date in
                    store.select(day: date)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Averages

    /// Days of the month actually drawn, so the header cannot claim more than the
    /// grid shows.
    private var heatmapDayCount: Int {
        CalendarHeatmap.daysInMonth(month, of: store.orderedDays, metric: metric)
    }

    /// Month and year with a fixed locale, for the same reason the weekday row is
    /// fixed: the app's copy is English.
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: month)
    }

    private var monthHeader: some View {
        HStack(spacing: 10) {
            IconBadge(symbol: "calendar", tint: metric.tint, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(monthName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                CapsLabel(text: heatmapDayCount > 0
                          ? "\(heatmapDayCount) \(metric.title.uppercased()) DAYS"
                          : "NO \(metric.title.uppercased()) DATA", tint: metric.tint,
                          size: 9)
            }
            Spacer(minLength: 4)
            pagerButton("chevron.left", enabled: canGoBack) { shift(-1) }
            pagerButton("chevron.right", enabled: canGoForward) { shift(1) }
        }
    }

    private var canGoBack: Bool {
        CalendarHeatmap.daysInMonth(month.addingTimeInterval(-31 * 86400),
                                    of: store.orderedDays, metric: metric) > 0
            || canStepFurtherBack
    }

    private var canGoForward: Bool {
        guard let newest = store.orderedDays.first?.date else { return false }
        return month < monthStart(containing: newest)
    }

    /// Anything older than the drawn month that still has data.
    private var canStepFurtherBack: Bool {
        store.orderedDays.contains { $0.date < monthStart(containing: month) }
    }

    private func monthStart(containing date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    private func pagerButton(_ symbol: String, enabled: Bool,
                             action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { action() }
            Haptics.select()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(enabled ? Palette.textSecondary : Palette.stroke)
                .frame(width: 30, height: 26)
                .background(Palette.surfaceHi, in: RoundedRectangle(cornerRadius: 8,
                                                                    style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func shift(_ months: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: months,
                                               to: month) else { return }
        month = next
    }

    private var averagesCard: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: 14) {
                CardHeaderRow(title: "Averages", symbol: "sum", tint: Palette.textSecondary)
                if summary.hasEnoughData {
                    averageRow("Time asleep", summary.averageSleepSeconds
                               .map { Fmt.duration($0) }, "per night")
                    Divider().overlay(Palette.stroke)
                    averageRow("Sleep efficiency", summary.averageEfficiency
                               .map { Fmt.percent($0) }, nil)
                    Divider().overlay(Palette.stroke)
                    averageRow("Steps", summary.averageSteps
                               .map { Fmt.count($0) }, "per day")
                    Divider().overlay(Palette.stroke)
                    averageRow("Resting heart rate", summary.averageRestingHR
                               .map { "\($0) bpm" }, nil)
                    Divider().overlay(Palette.stroke)
                    averageRow("HRV", summary.averageHRV.map { "\($0) ms" }, nil)
                    if let consistency = summary.bedtimeConsistency {
                        Divider().overlay(Palette.stroke)
                        averageRow("Bedtime consistency", Fmt.percent(consistency),
                                   "higher is steadier")
                    }
                } else {
                    Text("Not enough days yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .padding(16)
        }
    }

    private func averageRow(_ title: String, _ value: String?,
                            _ caption: String?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Text(value ?? "—")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(value == nil ? Palette.textTertiary : Palette.textPrimary)
            if let caption {
                Text(caption)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textTertiary)
                    .frame(width: 92, alignment: .trailing)
            }
        }
    }

    // MARK: - Training

    private var trainingCard: some View {
        GlowCard(tint: Palette.activity) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeaderRow(title: "Training", symbol: "figure.run", tint: Palette.activity)
                HStack(spacing: 14) {
                    bigStat("\(summary.trainingMinutes)", "min exercise")
                    bigStat(String(format: "%.1f", summary.metHours), "MET-hours")
                    bigStat("\(summary.workoutCount)", "sessions")
                }
            }
            .padding(16)
        }
    }

    private func bigStat(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .medium, design: .serif))
                .foregroundStyle(Palette.textPrimary)
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14,
                                                          style: .continuous))
    }

    private var footer: some View {
        Text("Averages cover only the days that recorded each metric, so a missing night never counts as zero. Scores are this app's own model.")
            .font(.system(size: 11))
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
