import SwiftUI

/// A month grid of one metric per day.
///
/// The cells are square and unlabelled because the number is in the tap, not the
/// grid — a month of seven-point type is unreadable. Days with no record are drawn
/// as an empty outline rather than tinted: an absent reading is not a bad one.
struct CalendarHeatmap: View {
    enum Metric: String, CaseIterable, Identifiable {
        case sleep, readiness, activity

        var id: String { rawValue }

        var title: String {
            switch self {
            case .sleep: return "Sleep"
            case .readiness: return "Ready"
            case .activity: return "Active"
            }
        }

        var tint: Color {
            switch self {
            case .sleep: return Palette.sleep
            case .readiness: return Palette.readiness
            case .activity: return Palette.activity
            }
        }
    }

    let days: [DailySnapshot]
    let goals: Goals
    let baseline: Baseline?
    var metric: Metric = .sleep
    /// Highlighted outline, used to show the selected day.
    var selected: Date?
    /// Which month to draw. Owned by the caller so the arrows and the header label
    /// can move it. Declared last so `onSelect` can still be a trailing closure.
    @Binding var month: Date
    var onSelect: ((Date) -> Void)?

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 1 // Monday, matching the rest of the app's week
        return cal
    }

    /// The month worth opening by default.
    ///
    /// Anchoring on today leaves the grid nearly empty for the first half of every
    /// month, which makes a month view look broken rather than young. So the newest
    /// month holding a worthwhile amount of data wins, and the current month is used
    /// when nothing else qualifies.
    static func defaultMonth(for days: [DailySnapshot]) -> Date {
        let cal = Calendar.current
        let byMonth = Dictionary(grouping: days, by: {
            cal.date(from: cal.dateComponents([.year, .month], from: $0.date)) ?? $0.date
        })
        let today = Date()
        let qualifying = byMonth
            .filter { $0.value.count >= 14 }
            .keys
            .max()
        return qualifying ?? today
    }

    /// Every day of the drawn month, padded to whole weeks.
    private var grid: [Date?] {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let firstOfMonth = calendar.date(from: components) else { return [] }
        let range = calendar.range(of: .day, in: .month, for: firstOfMonth) ?? 1..<2

        let weekday = calendar.component(.weekday, from: firstOfMonth)
        // Convert Sunday=1…Saturday=7 into a Monday-first offset.
        let leading = (weekday + 5) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in range {
            cells.append(calendar.date(byAdding: .day, value: offset - 1,
                                      to: firstOfMonth))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private func day(at date: Date) -> DailySnapshot? {
        days.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func score(for day: DailySnapshot) -> Int? {
        switch metric {
        case .sleep:
            guard day.sleep != nil else { return nil }
            return ScoreEngine.sleep(for: day, goals: goals, baseline: baseline).total
        case .readiness:
            guard day.sleep != nil || day.activity != nil else { return nil }
            // Named binding: the inner closure has its own implicit argument, so
            // `$0` cannot be used while the outer one is explicit.
            let sleepScore = day.sleep.map { _ in
                ScoreEngine.sleep(for: day, goals: goals, baseline: baseline).total
            } ?? 0
            return ScoreEngine.readiness(for: day, goals: goals, baseline: baseline,
                                         sleepScore: sleepScore).total
        case .activity:
            guard day.activity != nil else { return nil }
            return ScoreEngine.activity(for: day, goals: goals).total
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(weekdayInitials, id: \.self) { Text($0) }
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Palette.textTertiary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4),
                                    count: 7),
                      spacing: 4) {
                ForEach(Array(grid.enumerated()), id: \.offset) { _, date in
                    if let date {
                        cell(date)
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }

            legend
        }
    }

    private var weekdayInitials: [String] {
        // Fixed locale: the app's own copy is English, so a device set to another
        // language should not end up with a Chinese or Arabic weekday row inside an
        // otherwise English screen.
        var cal = calendar
        cal.locale = Locale(identifier: "en_US_POSIX")
        let symbols = cal.shortStandaloneWeekdaySymbols
        // Rotate so Monday leads, matching the grid.
        return Array(symbols[1...]) + [symbols[0]]
    }

    /// True when a later month exists in the stored history.
    var canGoForward: Bool {
        guard let newest = days.map(\.date).max() else { return false }
        return month < startOfMonth(containing: newest)
    }

    var canGoBack: Bool {
        guard let oldest = days.map(\.date).min() else { return false }
        return month > startOfMonth(containing: oldest)
    }

    func shift(by months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: month) else { return }
        month = next
    }

    func startOfMonth(containing date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func cell(_ date: Date) -> some View {
        let snapshot = day(at: date)
        let value = snapshot.flatMap(score)
        let isSelected = selected.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)

        return Button {
            onSelect?(date)
            Haptics.select()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(value.map { metric.tint.opacity(intensity($0)) }
                          ?? Palette.surfaceHi.opacity(0.5))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(border(value: value, isSelected: isSelected,
                                         isToday: isToday),
                                  lineWidth: isSelected ? 1.6 : 1)
            }
            .frame(height: 30)
            .overlay {
                // Only the day number, only when there is something behind it.
                if value != nil || isToday {
                    Text(calendar.component(.day, from: date).description)
                        .font(.system(size: 9, weight: isToday ? .bold : .medium))
                        .foregroundStyle(value.map { $0 > 62 ? Palette.bg
                                                             : Palette.textPrimary }
                                         ?? Palette.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(onSelect == nil)
        .accessibilityLabel(accessibilityLabel(date: date, value: value))
    }

    /// Four bands rather than a continuous ramp: at this cell size the difference
    /// between 71 and 76 is invisible, and banding makes the boundaries readable.
    private func intensity(_ score: Int) -> Double {
        switch score {
        case 85...: return 0.92
        case 70..<85: return 0.68
        case 55..<70: return 0.42
        default: return 0.22
        }
    }

    private func border(value: Int?, isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return Palette.textPrimary }
        if value == nil { return Palette.stroke }
        return isToday ? metric.tint.opacity(0.9) : metric.tint.opacity(0.28)
    }

    private func accessibilityLabel(date: Date, value: Int?) -> String {
        let day = Fmt.dayTitle(date)
        guard let value else { return "\(day), no data" }
        return "\(day), \(metric.title) \(value)"
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("Lower").font(.system(size: 9)).foregroundStyle(Palette.textTertiary)
            ForEach([22, 42, 68, 92], id: \.self) { step in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(metric.tint.opacity(Double(step) / 100))
                    .frame(width: 16, height: 8)
            }
            Text("Higher").font(.system(size: 9)).foregroundStyle(Palette.textTertiary)
            Spacer()
            Text("Bands at 55 · 70 · 85")
                .font(.system(size: 9))
                .foregroundStyle(Palette.textTertiary)
        }
    }
}

extension CalendarHeatmap {
    /// Days of the displayed month that actually recorded `metric`. Exposed so a
    /// header can state the same number the grid is showing.
    static func daysInMonth(_ month: Date, of days: [DailySnapshot],
                            metric: Metric) -> Int {
        var cal = Calendar.current
        cal.firstWeekday = 1
        let components = cal.dateComponents([.year, .month], from: month)
        guard let first = cal.date(from: components) else { return 0 }
        return days.filter { day in
            guard cal.isDate(day.date, equalTo: first, toGranularity: .month) else {
                return false
            }
            switch metric {
            case .sleep: return day.sleep != nil
            case .readiness: return day.sleep != nil || day.activity != nil
            case .activity: return day.activity != nil
            }
        }.count
    }
}
