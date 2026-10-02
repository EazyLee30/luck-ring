import SwiftUI

// Palette and reusable chrome for the app. Colours, type ramp and icon choices
// here are our own; the layout follows the usual "one gauge per score, cards
// below" pattern that most health apps use.
enum Palette {
    static let bg = Color(hex: 0x0B0B0F)
    static let surface = Color(hex: 0x16161C)
    static let surfaceHi = Color(hex: 0x1E1E26)
    static let stroke = Color(hex: 0x2A2A34)
    static let textPrimary = Color(hex: 0xF2F2F5)
    static let textSecondary = Color(hex: 0x9A9AA6)
    static let textTertiary = Color(hex: 0x6B6B78)

    static let sleep = Color(hex: 0x6C7BFF)
    static let sleepDeep = Color(hex: 0x3D4BD8)
    static let readiness = Color(hex: 0x2ED3B7)
    static let activity = Color(hex: 0xFF8A4C)
    static let heart = Color(hex: 0xFF5C7A)
    static let hrv = Color(hex: 0x9B7BFF)
    static let temp = Color(hex: 0x4CC9FF)
    static let oxygen = Color(hex: 0x52D9A0)
    static let pressure = Color(hex: 0xFFC24C)

    static let good = Color(hex: 0x3ED598)
    static let warn = Color(hex: 0xFFC24C)
    static let bad = Color(hex: 0xFF5C7A)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Typography

extension Font {
    static func score(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func metric(_ size: CGFloat = 20, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func label(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium)
    }
}

// MARK: - Score gauge

/// The signature circular gauge. Three of these sit at the top of Today.
struct ScoreGauge: View {
    let score: Int
    let tint: Color
    var size: CGFloat = 108
    var lineWidth: CGFloat = 9
    var label: String?
    var caption: String?

    private var progress: Double { max(0, min(1, Double(score) / 100)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.55), tint, tint.opacity(0.95)],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.7), value: progress)

            VStack(spacing: -2) {
                Text("\(score)")
                    .font(.score(size * 0.34))
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())
                if let label {
                    Text(label.uppercased())
                        .font(.system(size: size * 0.085, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(tint)
                }
                if let caption {
                    Text(caption)
                        .font(.system(size: size * 0.085, weight: .medium))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "score")
        .accessibilityValue("\(score) out of 100")
    }
}

// MARK: - Cards

struct Card<Content: View>: View {
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1)
            )
            .overlay(alignment: .top) {
                if let tint {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                        .mask(
                            LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                                .frame(height: 90)
                        )
                }
            }
    }
}

struct SectionHeader: View {
    let title: String
    var icon: String?
    var tint: Color = Palette.textSecondary

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.system(size: 12, weight: .bold))
            }
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity, alignment: .leading)
        }
}

// MARK: - Rows & chips

/// Compact three-across stat. `StatRow` splits a title from a right-aligned value,
/// which wraps badly when three of them share a narrow card — this centres the
/// pair and keeps both lines to a single line.
struct MiniStat: View {
    let title: String
    let value: String
    var unit: String?
    var tint: Color = Palette.textPrimary

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.metric(18))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct StatRow: View {
    let title: String
    let value: String
    var unit: String?
    var tint: Color = Palette.textPrimary
    var progress: Double?

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(title)
                    .font(.label(13))
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 8)
                Text(value)
                    .font(.metric(17))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(.label(11))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            if let progress {
                Bar(progress: progress, tint: tint, height: 4)
            }
        }
    }
}

struct Bar: View {
    let progress: Double
    var tint: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surfaceHi)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.5), value: progress)
    }
}

struct Chip: View {
    let text: String
    var tint: Color
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(filled ? Palette.bg : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(filled ? tint : tint.opacity(0.14), in: Capsule())
    }
}

/// Horizontal stacked bar used for sleep-stage composition and activity mix.
struct StackedBar: View {
    struct Segment: Identifiable {
        let id = UUID()
        let value: Double
        let tint: Color
        let label: String
    }

    let segments: [Segment]
    var height: CGFloat = 12

    private var total: Double { max(0.0001, segments.reduce(0) { $0 + $1.value }) }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(segments) { seg in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(seg.tint)
                        .frame(width: max(2, seg.value / total * (geo.size.width - 2 * CGFloat(max(0, segments.count - 1)))))
                }
            }
        }
        .frame(height: height)
    }
}

struct LegendItem: View {
    let label: String
    let tint: Color
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(label)
                .font(.label(12))
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: 4)
            Text(value)
                .font(.metric(13))
                .foregroundStyle(Palette.textPrimary)
        }
    }
}

// MARK: - Score summary strip

struct ScoreRow: View {
    let score: Int
    let tint: Color
    let title: String
    let verdict: String
    let detail: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ScoreGauge(score: score, tint: tint, size: 86, lineWidth: 7)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(verdict)
                        .font(.metric(18))
                        .foregroundStyle(Palette.textPrimary)
                    Chip(text: title.uppercased(), tint: tint)
                }
                Text(detail)
                    .font(.label(12))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Formatting helpers

enum Fmt {
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: date)
    }

    /// Single-token day label for chart axes — always a weekday symbol so the
    /// axis doesn't mix scripts with "Today"/"Yesterday".
    static func dayTick(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    static func percent(_ v: Double) -> String {
        "\(Int((v * 100).rounded()))%"
    }

    static func distance(_ metres: Int) -> String {
        metres >= 1000
            ? String(format: "%.1f", Double(metres) / 1000)
            : "\(metres)"
    }

    static func distanceUnit(_ metres: Int) -> String {
        metres >= 1000 ? "km" : "m"
    }

    static func signed(_ v: Double, digits: Int = 1) -> String {
        String(format: "%+.1f", v)
    }
}
// MARK: - Delta

/// Change against the wearer's own baseline. Direction is coloured, not just the
/// value — an HRV that fell 8 ms reads differently from one that rose 8 ms.
struct DeltaChip: View {
    let delta: Int
    var unit: String = ""
    var higherIsBetter: Bool = true

    private var isFlat: Bool { delta == 0 }
    private var tint: Color {
        if isFlat { return Palette.textTertiary }
        return (higherIsBetter ? delta > 0 : delta < 0) ? Palette.good : Palette.bad
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isFlat ? "minus" : (delta > 0 ? "arrow.up.right" : "arrow.down.right"))
                .font(.system(size: 9, weight: .bold))
            Text(isFlat ? "avg" : "\(abs(delta))\(unit)")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.13), in: Capsule())
        .accessibilityLabel(isFlat ? "at baseline"
                                  : "\(abs(delta)) \(unit) \(delta > 0 ? "above" : "below") baseline")
    }
}

// MARK: - Progress ring

/// Small gauge for sub-metrics (steps, calories, active time).
struct ProgressRing: View {
    let progress: Double
    let tint: Color
    var size: CGFloat = 54
    var lineWidth: CGFloat = 5
    var value: String?
    var caption: String?

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            VStack(spacing: 0) {
                if let value {
                    Text(value)
                        .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                }
                if let caption {
                    Text(caption)
                        .font(.system(size: size * 0.14, weight: .medium))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Score hero

/// Heads each score card: oversized score, verdict word, optional delta vs the
/// wearer's 7-day average.
struct ScoreHero: View {
    let score: Int
    let verdict: String
    let detail: String
    let tint: Color
    var delta: Int?

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(score)")
                        .font(.score(46))
                        .foregroundStyle(
                            LinearGradient(colors: [Palette.textPrimary, tint.opacity(0.8)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                        .contentTransition(.numericText())
                    if let delta { DeltaChip(delta: delta) }
                }
                Text(verdict)
                    .font(.metric(21))
                    .foregroundStyle(tint)
                Text(detail)
                    .font(.label(12))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Metric row

/// Label / value / unit with an optional bar and baseline delta.
struct MetricRow: View {
    let title: String
    let value: String
    var unit: String?
    var tint: Color = Palette.textPrimary
    var progress: Double?
    var delta: Int?
    var deltaUnit: String = ""
    var higherIsBetter: Bool = true

    var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.label(13))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(value)
                    .font(.metric(17))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit)
                        .font(.label(11))
                        .foregroundStyle(Palette.textTertiary)
                }
                if let delta {
                    DeltaChip(delta: delta, unit: deltaUnit, higherIsBetter: higherIsBetter)
                }
            }
            if let progress {
                Bar(progress: progress, tint: tint, height: 4)
            }
        }
    }
}

// MARK: - Contribution strip

/// How the score was assembled: one labelled slice per term.
struct ContributionStrip: View {
    struct Part: Identifiable {
        let id = UUID()
        let points: Int
        let max: Int
        let tint: Color
        let label: String
    }

    let parts: [Part]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("SCORE CONTRIBUTIONS")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(Palette.textTertiary)

            StackedBar(segments: parts.map {
                .init(value: Double($0.points), tint: $0.tint, label: $0.label)
            }, height: 8)

            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading)],
                      alignment: .leading, spacing: 6) {
                ForEach(parts) { part in
                    HStack(spacing: 5) {
                        Circle().fill(part.tint).frame(width: 6, height: 6)
                        Text(part.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Palette.textTertiary)
                            .lineLimit(1)
                        Text("\(part.points)/\(part.max)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

// MARK: - Stage breakdown

/// Sleep-stage composition with a proportional bar and a percentage legend.
struct StageBreakdown: View {
    let sleep: SleepSession

    private var segments: [(stage: SleepStage, seconds: TimeInterval, color: Color)] {
        [(.deep, sleep.time(.deep), Palette.sleepDeep),
         (.rem, sleep.time(.rem), Palette.hrv),
         (.light, sleep.time(.light), Palette.sleep),
         (.awake, sleep.time(.awake), Palette.warn)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StackedBar(segments: segments.filter { $0.seconds > 0 }
                .map { StackedBar.Segment(value: $0.seconds, tint: $0.color, label: $0.stage.title) })

            VStack(spacing: 7) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, entry in
                    let pct = sleep.duration > 0 ? Int(entry.seconds / sleep.duration * 100) : 0
                    LegendItem(label: entry.stage.title, tint: entry.color,
                               value: "\(Fmt.duration(entry.seconds))  ·  \(pct)%")
                }
            }
        }
    }
}
