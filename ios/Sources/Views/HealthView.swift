import SwiftUI

/// Long-term view. Rates each health area on four levels against a data
/// requirement, and shows the window that produced the rating.
struct HealthView: View {
    @ObservedObject var store: HealthStore

    private var areas: [HealthArea] { store.healthAreas }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                summary

                Section(title: "Health areas",
                        caption: "Rated from the last two weeks, not from today") {
                    VStack(spacing: 12) {
                        ForEach(areas) { area in
                            AreaCard(area: area)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                habitsSection
                disclaimer
            }
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(Palette.bg.ignoresSafeArea())
        .refreshable { store.refresh() }
        .navigationTitle("My Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary arc

    private var summary: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Overview", icon: "chart.pie.fill")

                // One arc segment per area, drawn on a shared 180° track.
                HStack(alignment: .top, spacing: 6) {
                    ForEach(areas) { area in
                        VStack(spacing: 5) {
                            RatingArc(rating: area.rating, tint: area.rating.tint)
                                .frame(maxWidth: .infinity)
                            Text(area.shortLabel)
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundStyle(Palette.textTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)

                HStack(spacing: 14) {
                    ForEach([HealthRating.thriving, .lookingGood, .worthWatching, .needsCare],
                            id: \.self) { r in
                        HStack(spacing: 4) {
                            Circle().fill(r.tint).frame(width: 6, height: 6)
                            Text(r.title)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Palette.textTertiary)
                        }
                    }
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Habits

    private var habitsSection: some View {
        Section(title: "Habits & routines",
                caption: "Rolling averages vs your targets") {
            Card {
                VStack(alignment: .leading, spacing: 13) {
                    let avgSteps = averageActivity?.steps
                    let avgSleep = averageSleepHours
                    MetricRow(title: "Daily step average",
                              value: avgSteps.map(String.init) ?? "—", unit: "steps",
                              tint: Palette.activity,
                              progress: avgSteps.map { min(1, Double($0) / Double(store.goals.stepTarget)) })
                    MetricRow(title: "Sleep regularity",
                              value: regularityLabel, unit: "",
                              tint: regularityTint)
                    MetricRow(title: "Average sleep",
                              value: avgSleep.map { String(format: "%.1f", $0) } ?? "—", unit: "h",
                              tint: Palette.sleep,
                              progress: avgSleep.map { min(1, $0 / Double(store.goals.sleepTargetMinutes) * (60.0 / 60.0)) })
                    MetricRow(title: "Active days (7d)",
                              value: "\(activeDaysLast7)", unit: "of 7", tint: Palette.readiness,
                              progress: Double(activeDaysLast7) / 7)
                }
                .padding(14)
            }
        }
        .padding(.horizontal, 16)
    }

    private var averageActivity: ActivitySummary? {
        let days = store.orderedDays.prefix(7).compactMap(\.activity)
        guard !days.isEmpty else { return nil }
        return ActivitySummary(
            date: Date(),
            steps: days.map(\.steps).reduce(0, +) / days.count,
            distanceMetres: days.map(\.distanceMetres).reduce(0, +) / days.count,
            activeSeconds: days.map(\.activeSeconds).reduce(0, +) / days.count,
            calories: days.map(\.calories).reduce(0, +) / days.count)
    }

    private var averageSleepHours: Double? {
        let hours = store.orderedDays.prefix(7).compactMap { $0.sleep?.asleep }
        guard !hours.isEmpty else { return nil }
        return (hours.reduce(0, +) / Double(hours.count)) / 3600
    }

    /// Bedtime spread across the last week: under an hour is regular.
    private var bedtimeSpreadMinutes: Int? {
        let times = store.orderedDays.prefix(7).compactMap { day -> Int? in
            guard let s = day.sleep else { return nil }
            let c = Calendar.current
            return c.component(.hour, from: s.start) * 60 + c.component(.minute, from: s.start)
        }
        guard times.count >= 3 else { return nil }
        // Circular spread, so 23:50 and 00:10 count as close together.
        var best = Double.greatestFiniteMagnitude
        for a in times {
            for b in times {
                var d = abs(a - b)
                if d > 720 { d = 1440 - d }
                best = min(best, Double(d))
            }
        }
        return Int(best)
    }

    private var regularityLabel: String {
        guard let spread = bedtimeSpreadMinutes else { return "—" }
        if spread <= 30 { return "Regular" }
        if spread <= 60 { return "Mostly regular" }
        return "Irregular"
    }

    private var regularityTint: Color {
        guard let spread = bedtimeSpreadMinutes else { return Palette.textTertiary }
        if spread <= 30 { return Palette.good }
        if spread <= 60 { return Palette.warn }
        return Palette.bad
    }

    private var activeDaysLast7: Int {
        store.orderedDays.prefix(7).filter { ($0.activity?.steps ?? 0) >= store.goals.stepTarget / 2 }.count
    }

    // MARK: - Disclaimer

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "About these ratings", icon: "info.circle")
            Text("Ratings are generated by this app's own heuristic model, not by a clinician and not by Oura. They compare your last two weeks against your own baseline. Treat them as a prompt to notice patterns, not as a diagnosis.")
                .font(.label(12))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Baselines need 2–4 weeks of consistent wear. Until then areas show “not enough data” instead of a guess.")
                .font(.label(12))
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Palette.stroke, lineWidth: 1))
        .padding(.horizontal, 16)
    }
}

// MARK: - Area card

struct AreaCard: View {
    let area: HealthArea

    var body: some View {
        Card(tint: area.rating.tint) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: area.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(area.rating.tint)
                        .frame(width: 34, height: 34)
                        .background(area.rating.tint.opacity(0.13),
                                    in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(area.title)
                            .font(.metric(16))
                            .foregroundStyle(Palette.textPrimary)
                        Text(area.subtitle)
                            .font(.label(11))
                            .foregroundStyle(Palette.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Text(area.rating.title.uppercased())
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(area.rating == .unknown ? Palette.textTertiary : Palette.bg)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(area.rating == .unknown
                                     ? Palette.surfaceHi : area.rating.tint, in: Capsule())
                }

                if area.trend.count > 1 {
                    TrendChart(points: area.trend.map(Double.init),
                               tint: area.rating.tint, showsGrid: false)
                        .frame(height: 58)
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(area.value)
                        .font(.score(26))
                        .foregroundStyle(area.rating == .unknown ? Palette.textTertiary : Palette.textPrimary)
                    if let unit = area.unit, area.value != "—" {
                        Text(unit)
                            .font(.label(11))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    Spacer()
                    if let avg = area.trendAverage {
                        Text("avg \(avg)")
                            .font(.label(11))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }

                Text(area.rationale)
                    .font(.label(12))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if area.isCalibrating {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("CALIBRATING")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.9)
                                .foregroundStyle(Palette.textTertiary)
                            Spacer()
                            Text(area.requirement)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Palette.textTertiary)
                        }
                        Bar(progress: area.progress, tint: area.tint, height: 4)
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Rating arc

/// Half-circle segment showing a rating level. Four nested arcs fill up as the
/// rating worsens, so the shape itself carries meaning.
struct RatingArc: View {
    let rating: HealthRating
    let tint: Color
    var size: CGFloat = 38

    /// 0.25 thriving -> 1.0 needs care; empty when unknown.
    private var fill: CGFloat {
        switch rating {
        case .thriving: return 0.25
        case .lookingGood: return 0.5
        case .worthWatching: return 0.75
        case .needsCare: return 1.0
        case .unknown: return 0
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(Palette.surfaceHi, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(180))
            Circle()
                .trim(from: 0, to: 0.5 * fill)
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(180))
                .animation(.easeOut(duration: 0.5), value: fill)
        }
        .frame(width: size, height: size / 2)
    }
}
