import SwiftUI

// MARK: - Sparkline

/// Compact line for a day's heart-rate trace, with a dashed resting baseline.
struct Sparkline: View {
    let values: [Double]
    var tint: Color
    var baseline: Double?

    var body: some View {
        GeometryReader { geo in
            let lo = values.min() ?? 0
            let hi = values.max() ?? 1
            let span = max(1, hi - lo)

            ZStack {
                if let baseline {
                    let y = geo.size.height * (1 - (baseline - lo) / span)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Palette.textTertiary.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }

                if values.count > 1 {
                    Path { p in
                        let step = geo.size.width / CGFloat(values.count - 1)
                        for (i, v) in values.enumerated() {
                            let pt = CGPoint(x: CGFloat(i) * step,
                                             y: geo.size.height * (1 - (v - lo) / span))
                            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                        }
                    }
                    .stroke(
                        LinearGradient(colors: [tint.opacity(0.45), tint],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

// MARK: - Trend chart

/// Time-series chart with auto-scaling. Scores cluster in a narrow band, so a
/// fixed 0-100 axis renders every week as a flat line; we scale to the data but
/// never zoom inside a 25-point window, or noise looks like a trend.
struct TrendChart: View {
    let points: [Double]
    var tint: Color
    var showsGrid: Bool = true

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
            let grid = showsGrid
                ? Array(stride(from: ceil(s.low / 10) * 10, through: s.high, by: 10))
                : []

            ZStack {
                ForEach(grid, id: \.self) { g in
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y(g)))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y(g)))
                    }
                    .stroke(Palette.stroke, style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                }

                if !points.isEmpty {
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: geo.size.height))
                        for (i, v) in points.enumerated() {
                            p.addLine(to: CGPoint(x: CGFloat(i) * w, y: y(v)))
                        }
                        p.addLine(to: CGPoint(x: CGFloat(points.count - 1) * w, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [tint.opacity(0.26), tint.opacity(0.01)],
                                         startPoint: .top, endPoint: .bottom))
                }

                if points.count > 1 {
                    Path { p in
                        for (i, v) in points.enumerated() {
                            let pt = CGPoint(x: CGFloat(i) * w, y: y(v))
                            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
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

// MARK: - Date strip

/// Horizontal day picker. Swipeable in the Vitals tab, and the same control is
/// reused by Today so the two tabs never disagree about which day is shown.
struct DayStrip: View {
    @ObservedObject var store: HealthStore
    var onPick: ((Date?) -> Void)?

    private var days: [Date] { Array(store.orderedDays.prefix(14).map(\.date)) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { date in
                        let selected = isSelected(date)
                        Button {
                            onPick?(date)
                        } label: {
                            VStack(spacing: 3) {
                                Text(Fmt.dayTick(date))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(selected ? Palette.bg : Palette.textTertiary)
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.metric(16))
                                    .foregroundStyle(selected ? Palette.bg : Palette.textPrimary)
                            }
                            .frame(width: 42, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(selected ? Palette.textPrimary : Palette.surface))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(Palette.stroke, lineWidth: selected ? 0 : 1))
                        }
                        .buttonStyle(.plain)
                        .id(date)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                proxy.scrollTo(store.selectedDate ?? days.first, anchor: .center)
            }
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let selected = store.selectedDate else {
            return Calendar.current.isDateInToday(date)
        }
        return Calendar.current.isDate(selected, inSameDayAs: date)
    }
}

// MARK: - Section

/// Titled group container used across Vitals and Health.
struct Section<Content: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(Palette.textSecondary)
                if let caption {
                    Text(caption)
                        .font(.label(11))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            content
        }
    }
}