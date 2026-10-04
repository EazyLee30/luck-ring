import SwiftUI

/// The shareable formats. Different stories need different cards: a single day
/// is a status update, a week is a claim you can defend, training is a log, and
/// a bare score card is for when you do not want the detail.
enum ShareTemplate: String, CaseIterable, Identifiable {
    case day
    case scores
    case training
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "Today"
        case .scores: return "Scores only"
        case .training: return "Training"
        case .week: return "This week"
        case .month: return "This month"
        }
    }

    var symbol: String {
        switch self {
        case .day: return "sun.max.fill"
        case .scores: return "circle.grid.3x3.fill"
        case .training: return "figure.run"
        case .week: return "calendar"
        case .month: return "calendar.badge.clock"
        }
    }

    var blurb: String {
        switch self {
        case .day: return "Headline, three scores and the day's detail"
        case .scores: return "Just the numbers, no detail rows"
        case .training: return "Sessions, volume and MET-hours"
        case .week: return "Seven-day averages against your goals"
        case .month: return "30-day trend and consistency"
        }
    }

    /// Month and week need history, so they can report "not enough data" while
    /// today never does.
    var requiresHistoryDays: Int {
        switch self {
        case .day, .scores, .training: return 1
        case .week: return 4
        case .month: return 14
        }
    }

    func size(for store: HealthStore) -> CGSize {
        switch self {
        case .day, .scores: return CGSize(width: 1080, height: 1350)
        case .training: return CGSize(width: 1080, height: 1080)
        case .week: return CGSize(width: 1080, height: 1350)
        case .month: return CGSize(width: 1080, height: 1350)
        }
    }
}

/// Renders any template into a bitmap and hands it to the share sheet.
@MainActor
final class ShareComposer: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isRendering = false
    @Published private(set) var template: ShareTemplate = .day
    @Published private(set) var shortfall = false

    func render(_ template: ShareTemplate, store: HealthStore) {
        let available = store.recentWeekDays.count
        guard available >= template.requiresHistoryDays else {
            shortfall = true
            image = nil
            return
        }
        shortfall = false
        isRendering = true
        self.template = template

        let view = ShareTemplateView(template: template, store: store)
            .frame(width: template.size(for: store).width,
                   height: template.size(for: store).height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1

        DispatchQueue.main.async {
            if let cg = renderer.cgImage {
                self.image = UIImage(cgImage: cg)
            } else if let ui = renderer.uiImage {
                self.image = ui
            }
            self.isRendering = false
        }
    }

    /// PNG file plus bitmap, so "Save image" works and image-only apps still get
    /// something they understand.
    func shareItems(caption: String) -> [Any] {
        var items: [Any] = [caption]
        if let image, let data = image.pngData() {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("luckring-\(template.rawValue)-\(Int(Date().timeIntervalSince1970)).png")
            try? data.write(to: url)
            items.append(url)
            items.append(image)
        }
        return items
    }
}

/// Template chooser plus the live preview and the share button.
struct ShareTemplateSheet: View {
    @ObservedObject var store: HealthStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var composer = ShareComposer()
    @State private var shareAnchor: UIView?
    @State private var host: UIViewController?

    private var day: DailySnapshot? { store.selectedDay ?? store.today }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    picker
                    preview
                    actions
                }
                .padding(18)
                .padding(.bottom, 24)
            }
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                host = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                    .first { $0.isKeyWindow }?.rootViewController
                composer.render(.day, store: store)
            }
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 8) {
            CapsLabel(text: "Format")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ShareTemplate.allCases) { t in
                        Button {
                            composer.render(t, store: store)
                            Haptics.select()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(systemName: t.symbol)
                                    .scaledFont(15, weight: .semibold)
                                Text(t.title)
                                    .scaledFont(12, weight: .semibold)
                                Text(t.blurb)
                                    .scaledFont(10)
                                    .foregroundStyle(Palette.textTertiary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(composer.template == t ? Palette.bg : Palette.textPrimary)
                            .frame(width: 138, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(composer.template == t ? Palette.sleep : Palette.surface))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Palette.stroke, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 10) {
            if composer.shortfall {
                GlowCard(tint: Palette.warn) {
                    VStack(alignment: .leading, spacing: 8) {
                        CardHeaderRow(title: "Not enough history",
                                      symbol: "exclamationmark.triangle.fill", tint: Palette.warn)
                        Text("\(composer.template.title) needs at least \(composer.template.requiresHistoryDays) days of data and you have \(store.recentWeekDays.count).")
                            .scaledFont(12)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                }
            } else if composer.isRendering {
                ProgressView("Rendering…")
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
            } else if let image = composer.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
                    .frame(maxHeight: 420)
            }

            Text("Scores are this app's own model. Not a medical record.")
                .scaledFont(11)
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if composer.image != nil {
                Button { presentShare() } label: {
                    PillButton(title: "Share", symbol: "square.and.arrow.up", tint: Palette.sleep)
                }
                .buttonStyle(.plain)
            }
            if let url = exportURL {
                ShareLink(item: url) {
                    PillButton(title: "Export PNG", symbol: "square.and.arrow.down",
                               filled: false)
                }
            }
        }
    }

    private var exportURL: URL? {
        guard let image = composer.image, let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("luckring-\(composer.template.rawValue).png")
        try? data.write(to: url)
        return url
    }

    private func presentShare() {
        let sheet = UIActivityViewController(
            activityItems: composer.shareItems(caption: caption), applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = shareAnchor
        host?.present(sheet, animated: true)
    }

    private var caption: String {
        let d = store.selectedDay ?? store.today
        guard let d else { return "Tracked with Luck Ring." }
        let s = store.sleepScore?.total ?? 0
        let r = store.readinessScore?.total ?? 0
        let a = store.activityScore?.total ?? 0
        return "\(Fmt.dayTitle(d.date)): sleep \(s), readiness \(r), activity \(a). Tracked with Luck Ring."
    }
}