import SwiftUI
import UIKit

/// Renders a shareable card for a day. Deliberately composed at a fixed aspect
/// ratio and rendered through `ImageRenderer`, so the exported PNG is pixel
/// identical to what the preview shows — the two have shared a bug before.
struct ShareCard: View {
    let day: DailySnapshot
    let sleepScore: Int
    let readinessScore: Int
    let activityScore: Int
    let ringName: String

    private static let size = CGSize(width: 1080, height: 1350)

    /// Score-coloured wash behind the headline, matched to the metric that is
    /// weakest so the card's mood reflects the day.
    private var dominant: Color {
        switch (sleepScore, readinessScore, activityScore) {
        case let (s, r, a) where s <= r && s <= a: return Palette.sleep
        case let (s, r, _) where r <= s: return Palette.readiness
        default: return Palette.activity
        }
    }

    var body: some View {
        ZStack {
            Palette.bg

            // Background wash
            RadialGradient(colors: [dominant.opacity(0.30), .clear],
                           center: .topTrailing, startRadius: 20, endRadius: 780)
            RadialGradient(colors: [Palette.sleep.opacity(0.16), .clear],
                           center: .bottomLeading, startRadius: 20, endRadius: 640)

            VStack(alignment: .leading, spacing: 0) {
                header

                Spacer(minLength: 0)

                headline

                Spacer(minLength: 0)

                scoreRow

                Spacer(minLength: 0)

                detailRows

                Spacer(minLength: 0)

                footer
            }
            .padding(84)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Text("LUCK RING".uppercased())
                .font(.system(size: 26, weight: .semibold))
                .tracking(6)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Text(Fmt.dayTitle(day.date))
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(headlineText)
                .font(.system(size: 66, weight: .regular, design: .serif))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)

            HStack(spacing: 10) {
                Capsule()
                    .fill(dominant)
                    .frame(width: 54, height: 5)
                Text(verdictText)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(dominant)
            }
        }
    }

    private var scoreRow: some View {
        HStack(spacing: 0) {
            scoreBlock("Sleep", sleepScore, Palette.sleep)
            divider
            scoreBlock("Readiness", readinessScore, Palette.readiness)
            divider
            scoreBlock("Activity", activityScore, Palette.activity)
        }
        .padding(.vertical, 36)
        .overlay(alignment: .top) { hairline }
        .overlay(alignment: .bottom) { hairline }
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.stroke)
            .frame(width: 1, height: 108)
    }

    private var hairline: some View {
        Rectangle().fill(Palette.stroke).frame(height: 1)
    }

    private func scoreBlock(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 8) {
            Text("\(value)")
                .font(.system(size: 72, weight: .regular, design: .serif))
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
            detailRow(symbol: "bed.double.fill", tint: Palette.sleep,
                       title: "Time asleep",
                       value: day.sleep.map { Fmt.duration($0.asleep) } ?? "—")
            detailRow(symbol: "figure.walk.motion", tint: Palette.activity,
                       title: "Steps",
                       value: day.activity.map { Fmt.count($0.steps) } ?? "—")
            detailRow(symbol: "heart.fill", tint: Palette.heart,
                       title: "Resting HR",
                       value: day.restingHeartRate.map { "\($0) bpm" } ?? "—")
            detailRow(symbol: "waveform.path.ecg", tint: Palette.hrv,
                       title: "HRV",
                       value: day.averageHRV.map { "\($0) ms" } ?? "—")
        }
    }

    private func detailRow(symbol: String, tint: Color, title: String, value: String) -> some View {
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

    private var footer: some View {
        VStack(spacing: 14) {
            hairline
            Text(footerText)
                .font(.system(size: 22))
                .foregroundStyle(Palette.textTertiary)
        }
    }

    // MARK: - Copy

    /// Lead with the weakest score — that is the honest summary of the day.
    private var headlineText: String {
        let lowest = min(sleepScore, readinessScore, activityScore)
        switch lowest {
        case 85...:
            return "A strong day"
        case 70..<85:
            return "A decent day"
        case 55..<70:
            return "A mixed day"
        default:
            return "A hard day"
        }
    }

    private var verdictText: String {
        let lowest = min(sleepScore, readinessScore, activityScore)
        switch lowest {
        case 85...: return "All three scores in good shape"
        case 70..<85: return "Room to improve"
        case 55..<70: return "Take it easy today"
        default: return "Prioritise recovery"
        }
    }

    private var footerText: String {
        var bits = ["Scores are this app's own model, not a clinical measure"]
        if !day.workouts.isEmpty {
            bits.append("\(day.exerciseMinutes) min of logged training")
        }
        return bits.joined(separator: " · ")
    }
}

/// Owns the render + share flow so views only ask for "share today".
@MainActor
final class ShareCardRenderer: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isRendering = false

    func render(day: DailySnapshot, sleep: Int, readiness: Int, activity: Int,
                ringName: String) {
        isRendering = true
        let card = ShareCard(day: day, sleepScore: sleep, readinessScore: readiness,
                             activityScore: activity, ringName: ringName)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1        // the card is already laid out at export size

        DispatchQueue.main.async {
            if let cgImage = renderer.cgImage {
                self.image = UIImage(cgImage: cgImage)
            } else if let uiImage = renderer.uiImage {
                self.image = uiImage
            }
            self.isRendering = false
        }
    }

    /// Writes a PNG to a temporary file so the share sheet can offer "Save image"
    /// rather than only posting the bitmap to social apps.
    func writePNG() -> URL? {
        guard let image, let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("luckring-\(Int(Date().timeIntervalSince1970)).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    func shareItems() -> [Any] {
        var items: [Any] = []
        if let url = writePNG() { items.append(url) }
        if let image { items.append(image) }
        return items
    }
}