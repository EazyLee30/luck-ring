import SwiftUI

/// Surfaces the derived metrics. Every row shows its caveat on tap, because a
/// number computed from other numbers should never look like a measurement.
struct DerivedMetricsCard: View {
    @ObservedObject var store: HealthStore
    @State private var expandedCaveat: String?

    private var day: DailySnapshot? { store.selectedDay ?? store.today }

    var body: some View {
        GlowCard(tint: Palette.temp) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeaderRow(title: "Derived metrics", symbol: "function",
                              status: "ESTIMATES", tint: Palette.temp)

                Text("Computed from readings above — not measured by the ring.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                rows

                if let debt = debt {
                    Divider().overlay(Palette.stroke)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Recovery debt")
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.textPrimary)
                            Spacer()
                            Text(debtLabel)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(debtTint)
                        }
                        Bar(progress: debt, tint: debtTint, height: 4)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private var rows: some View {
        if let day {
            let respiratory = DerivedMetrics.respiratoryRate(
                hrvMS: day.averageHRV,
                restingHR: day.restingHeartRate)
            row(symbol: "lungs.fill", tint: Palette.temp,
                title: "Respiratory rate",
                value: respiratory.map { String(format: "%.0f", $0) },
                unit: "brpm",
                caveat: DerivedMetrics.respiratoryCaveat)

            let stress = DerivedMetrics.stress(day: day, baseline: store.baseline)
            let band = DerivedMetrics.stressBand(stress)
            row(symbol: "waveform.path.ecg", tint: bandColor(band.tint),
                title: "Stress proxy",
                value: stress.map { String(format: "%.0f%%", $0 * 100) },
                unit: band.label,
                caveat: DerivedMetrics.stressCaveat)

            if let deviation = DerivedMetrics.cardiovascularDeviation(
                day: day, baseline: store.baseline) {
                row(symbol: "heart.text.square.fill",
                    tint: deviation > 5 ? Palette.bad : (deviation > 0 ? Palette.warn : Palette.good),
                    title: "Cardiovascular marker",
                    value: deviation > 0 ? "+\(deviation)" : "\(deviation)",
                    unit: "vs reference",
                    caveat: DerivedMetrics.cardiovascularCaveat)
            }

            if let regularity = DerivedMetrics.sleepRegularity(days: store.recentWeekDays) {
                row(symbol: "calendar.badge.clock", tint: Palette.sleep,
                    title: "Sleep regularity",
                    value: Fmt.percent(regularity),
                    unit: regularity > 0.85 ? "Regular"
                        : (regularity > 0.6 ? "Somewhat" : "Irregular"),
                    caveat: "Standard deviation of bedtime over the last "
                        + "\(store.recentWeekDays.count) nights, on a circular mean so "
                        + "23:50 and 00:10 count as the same bedtime.")
            }
        }
    }

    private func row(symbol: String, tint: Color, title: String,
                     value: String?, unit: String?, caveat: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                expandedCaveat = expandedCaveat == caveat ? nil : caveat
            }
            Haptics.tap()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    IconBadge(symbol: symbol, tint: tint, size: 28)
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    if let value {
                        Text(value)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(value == "—" ? Palette.textTertiary : tint)
                    }
                    if let unit {
                        Text(unit)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    Image(systemName: expandedCaveat == caveat ? "chevron.down" : "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textTertiary)
                }

                if expandedCaveat == caveat {
                    Text(caveat)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                } else if value == nil {
                    Text("Not enough data for this one.")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var debt: Double? {
        guard let day, day.sleep != nil || store.recentWeekDays.contains(where: { $0.sleep != nil })
        else { return nil }
        let value = DerivedMetrics.recoveryDebt(days: store.recentWeekDays, goals: store.goals)
        return value > 0.01 ? value : nil
    }

    private var debtLabel: String {
        guard let debt else { return "" }
        if debt > 0.6 { return "High" }
        if debt > 0.25 { return "Moderate" }
        return "Low"
    }

    private var debtTint: Color {
        guard let debt else { return Palette.good }
        if debt > 0.6 { return Palette.bad }
        if debt > 0.25 { return Palette.warn }
        return Palette.good
    }

    private func bandColor(_ tint: DerivedMetrics.Tint) -> Color {
        switch tint {
        case .good: return Palette.good
        case .watch: return Palette.warn
        case .care: return Palette.bad
        case .neutral: return Palette.textTertiary
        }
    }
}