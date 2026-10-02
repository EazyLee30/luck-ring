import SwiftUI

// Components modelled on the reference screenshots: editorial serif headlines,
// floating pill navigation, circular shortcut badges, an arc gauge with tick
// marks, and the range scale that places a dot on a min/max track.

// MARK: - Typography

extension Font {
    /// New York, via the system serif design. Used for the big editorial
    /// headline that sits under each score, which is the strongest visual
    /// signature in the reference design.
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func label2(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
}

/// Small caps run used above headlines and card values.
struct CapsLabel: View {
    let text: String
    var tint: Color = Palette.textTertiary
    var size: CGFloat = 10

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(tint)
    }
}

// MARK: - Icon badge

/// Rounded-square tinted icon container used at the head of every card.
struct IconBadge: View {
    let symbol: String
    var tint: Color = Palette.textSecondary
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.3,
                                                               style: .continuous))
    }
}

// MARK: - Arc gauge

/// The large hero gauge: a partial ring with tick marks around the outside and a
/// dot riding the progress end.
struct ArcGauge: View {
    let score: Int
    let tint: Color
    var caption: String?
    var size: CGFloat = 190
    /// Fraction of the circle the arc covers.
    var sweep: Double = 0.78

    private var progress: Double { max(0, min(1, Double(score) / 100)) }

    /// Angle the arc starts at, so the gap sits at the bottom.
    /// trim() begins at 3 o'clock and runs clockwise, so an arc covering `sweep`
    /// of the circle starts at `(1 - sweep) / 2` turns past the top-left gap.
    private var startAngle: Double { (1 - sweep) / 2 * 360 + 90 }

    var body: some View {
        let lineWidth = size * 0.052
        let radius = (size - lineWidth) / 2 - size * 0.05

        ZStack {
            ticks(radius: radius, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: sweep)
                .stroke(tint.opacity(0.14),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(startAngle))

            Circle()
                .trim(from: 0, to: sweep * progress)
                .stroke(
                    LinearGradient(colors: [tint.opacity(0.5), tint],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(startAngle))
                .animation(.easeOut(duration: 0.8), value: progress)

            // Marker riding the leading edge of the arc.
            Circle()
                .fill(Palette.textPrimary)
                .frame(width: lineWidth * 1.05, height: lineWidth * 1.05)
                .offset(y: -radius)
                .rotationEffect(.degrees(startAngle + 360 * sweep * progress))
                .opacity(progress > 0.015 ? 1 : 0)
                .animation(.easeOut(duration: 0.8), value: progress)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: size * 0.29, weight: .regular, design: .serif))
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())
                if let caption {
                    CapsLabel(text: caption, tint: tint, size: size * 0.058)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption ?? "score")
        .accessibilityValue("\(score) out of 100")
    }

    /// Tick marks along the arc, every sixth one longer.
    private func ticks(radius: CGFloat, lineWidth: CGFloat) -> some View {
        let count = 33
        let span = 360 * sweep
        return ForEach(0..<count, id: \.self) { i in
            let major = i % 6 == 0
            Rectangle()
                .fill(major ? tint.opacity(0.5) : Palette.textTertiary.opacity(0.26))
                .frame(width: major ? 1.8 : 1.1,
                       height: major ? lineWidth * 0.40 : lineWidth * 0.22)
                .offset(y: -radius - lineWidth * 0.40)
                .rotationEffect(.degrees(startAngle + span * (Double(i) / Double(count - 1))))
        }
    }
}

// MARK: - Range scale

/// A dot placed on a min…max track. This is the element that carries "where does
/// today's value sit relative to the usual band" without needing an axis.
struct RangeScale: View {
    let value: Int
    let min: Int
    let max: Int
    var tint: Color = Palette.textPrimary
    var trackHeight: CGFloat = 3

    private var fraction: Double {
        let low = self.min, high = self.max
        guard high > low else { return 0.5 }
        return Swift.max(0, Swift.min(1, Double(value - low) / Double(high - low)))
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let x = Swift.max(7, Swift.min(geo.size.width - 7, geo.size.width * fraction))
                ZStack(alignment: .center) {
                    Capsule()
                        .fill(Palette.surfaceHi)
                        .frame(height: trackHeight)
                    Capsule()
                        .fill(tint)
                        .frame(width: x, height: trackHeight)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Circle()
                        .fill(Palette.textPrimary)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().strokeBorder(tint, lineWidth: 2))
                        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                        .position(x: x, y: geo.size.height / 2)
                }
            }
            .frame(height: 14)

            HStack {
                Text("\(min)")
                Spacer()
                Text("\(max)")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Palette.textTertiary)
        }
    }
}

// MARK: - Segmented scale

/// Discrete state indicator, e.g. None / Moderate / Strong. Inactive segments
/// stay visible so the position reads as a place on a scale.
struct SegmentedScale: View {
    let labels: [String]
    let active: Int
    var tint: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.system(size: 11, weight: index == active ? .bold : .medium))
                    .foregroundStyle(index == active ? Palette.textPrimary : Palette.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(index == active ? tint : Palette.surfaceHi))
            }
        }
    }
}

// MARK: - Contributor row

/// Label, verdict and a bar — the repeated unit of a "what drove this" list.
struct ContributorRow: View {
    let title: String
    let verdict: String
    let progress: Double
    var tint: Color = Palette.textSecondary
    var showsChevron: Bool = false

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 8)
                Text(verdict)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(tint)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            Bar(progress: progress, tint: tint, height: 3)
        }
    }
}

// MARK: - Rating ends

/// Two-ended caption above a health-area rating.
struct RatingEnds: View {
    let left: String
    let right: String
    var leftTint: Color = Palette.ratingCare
    var rightTint: Color = Palette.ratingThriving

    var body: some View {
        HStack {
            CapsLabel(text: left, tint: leftTint)
            Spacer()
            CapsLabel(text: right, tint: rightTint)
        }
    }
}

// MARK: - Editorial card

/// Serif headline, body copy and a pill call to action. The layout that gives
/// the reference design its editorial feel.
struct EditorialCard<Content: View>: View {
    let eyebrow: String?
    let headline: String
    var eyebrowTint: Color = Palette.textSecondary
    var cta: String?
    var ctaSymbol: String?
    var content: Content

    init(eyebrow: String? = nil,
         headline: String,
         eyebrowTint: Color = Palette.textSecondary,
         cta: String? = nil,
         ctaSymbol: String? = nil,
         @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.headline = headline
        self.eyebrowTint = eyebrowTint
        self.cta = cta
        self.ctaSymbol = ctaSymbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let eyebrow {
                CapsLabel(text: eyebrow, tint: eyebrowTint)
            }
            Text(headline)
                .font(.display(26))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            content
            if let cta {
                PillButton(title: cta, symbol: ctaSymbol)
            }
        }
    }
}

/// Filled pill button, used for every call to action in the app.
struct PillButton: View {
    let title: String
    var symbol: String?
    var tint: Color = Palette.textPrimary
    var filled: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(filled ? Palette.bg : Palette.textPrimary)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .frame(maxWidth: filled ? .infinity : nil)
        .background(
            Capsule().fill(filled ? tint : Color.white.opacity(0.07)))
        .contentShape(Capsule())
    }
}

// MARK: - Score with crown

/// Large score with an optional superscript marker, matching how the reference
/// design annotates a score with a small crown.
struct ScoreWithMark: View {
    let score: Int
    var symbol: String?
    var tint: Color = Palette.textPrimary
    var size: CGFloat = 46

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(score)")
                .font(.system(size: size, weight: .regular, design: .serif))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.24, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}

// MARK: - Shortcut badge

/// Circular shortcut: icon, value and label, arranged as a column. A horizontal
/// row of these replaces the rectangular shortcut cards.
struct ShortcutBadge: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color
    var diameter: CGFloat = 68

    var body: some View {
        VStack(spacing: 6) {
            // Icon sits above the value inside the circle, both stacked — an
            // offset overlay collided at small diameters.
            ZStack {
                Circle()
                    .fill(tint.opacity(0.13))
                    .frame(width: diameter, height: diameter)
                VStack(spacing: -2) {
                    Image(systemName: symbol)
                        .font(.system(size: diameter * 0.24, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(value)
                        .font(.system(size: diameter * 0.28, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                }
                .padding(.horizontal, diameter * 0.12)
            }
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: diameter + 14)
    }
}

// MARK: - Hatched bar

/// Diagonally hatched fill, used for a target line rather than a measurement.
struct HatchedBar: View {
    var tint: Color = Palette.textTertiary
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.surfaceHi)
                Capsule()
                    .fill(tint.opacity(0.28))
                    .overlay(
                        Canvas { context, size in
                            var path = Path()
                            var x: CGFloat = -size.height
                            while x < size.width + size.height {
                                path.move(to: CGPoint(x: x, y: size.height))
                                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                                x += 5
                            }
                            context.stroke(path, with: .color(tint.opacity(0.85)),
                                           lineWidth: 1.1)
                        }
                    )
                    .frame(width: geo.size.width, alignment: .leading)
                    .clipShape(Capsule())
            }
        }
        .frame(height: height)
    }
}

// MARK: - Card with glow

/// Card surface with a soft accent-coloured bleed from the top edge, matching the
/// way each metric card picks up its own hue.
struct GlowCard<Content: View>: View {
    var tint: Color?
    var radius: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Palette.stroke, lineWidth: 1))
            .overlay(alignment: .top) {
                if let tint {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            RadialGradient(colors: [tint.opacity(0.22), .clear],
                                           center: .topLeading, startRadius: 4, endRadius: 190))
                        .frame(height: 150)
                        .allowsHitTesting(false)
                        .blendMode(.plusLighter)
                }
            }
    }
}

/// Card header row: badge, title, status word, chevron.
struct CardHeaderRow: View {
    let title: String
    var symbol: String?
    var status: String?
    var tint: Color = Palette.textSecondary

    var body: some View {
        HStack(spacing: 10) {
            if let symbol {
                IconBadge(symbol: symbol, tint: tint, size: 30)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                if let status {
                    CapsLabel(text: status, tint: tint, size: 9)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textTertiary)
        }
    }
}