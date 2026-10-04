import WidgetKit
import SwiftUI

/// Reads the snapshot the app publishes and renders the three scores. A widget
/// extension is a separate process, so it cannot touch the app's history file —
/// it only sees `WidgetSnapshot` in the shared container.
struct LuckRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LuckRingWidget",
                            provider: Provider()) { entry in
            WidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetPalette.bg }
        }
        .configurationDisplayName("Luck Ring")
        .description("Sleep, readiness and activity for the day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }

    struct Provider: TimelineProvider {
        func placeholder(in context: Context) -> Entry {
            Entry(date: Date(), snapshot: .placeholder)
        }

        func getSnapshot(in context: Context,
                         completion: @escaping (Entry) -> Void) {
            completion(Entry(date: Date(),
                             snapshot: AppGroupBridge.read() ?? .placeholder))
        }

        func getTimeline(in context: Context,
                         completion: @escaping (Timeline<Entry>) -> Void) {
            let snapshot = AppGroupBridge.read() ?? .placeholder
            // Refresh on the hour: the underlying data only changes when the ring
            // syncs, so anything more frequent is wasted wake-ups.
            let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
            completion(Timeline(entries: [Entry(date: Date(), snapshot: snapshot)],
                                policy: .after(next)))
        }
    }

    struct Entry: TimelineEntry {
        let date: Date
        let snapshot: WidgetSnapshot
    }
}

/// The widget cannot link against the app's source, so the two symbols it needs
/// are declared here and must be kept in step with `AppGroup` in the app target.
enum AppGroupBridge {
    static let identifier = "group.com.luckring.reader"
    static let snapshotFilename = "widget-snapshot.json"

    static func read() -> WidgetSnapshot? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier) else { return nil }
        let url = container.appendingPathComponent(snapshotFilename)
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }
}

/// Mirrors of the app's palette. A widget extension compiles separately and cannot
/// link the app's sources, so these values are repeated deliberately and must be
/// kept in step with `Palette` in `Editorial.swift`.
enum WidgetPalette {
    static let bg = Color(red: 0.043, green: 0.043, blue: 0.059)
    static let sleep = Color(red: 0.424, green: 0.482, blue: 1.0)
    static let readiness = Color(red: 0.180, green: 0.827, blue: 0.718)
    static let activity = Color(red: 1.0, green: 0.541, blue: 0.298)
    static let heart = Color(red: 1.0, green: 0.361, blue: 0.482)
    static let hrv = Color(red: 0.608, green: 0.482, blue: 1.0)
    static let text = Color(red: 0.949, green: 0.949, blue: 0.961)
    static let dim = Color(red: 0.604, green: 0.604, blue: 0.651)
}

/// Mirror of the app's snapshot type.
struct WidgetSnapshot: Codable {
    var date: Date
    var sleepScore: Int
    var readinessScore: Int
    var activityScore: Int
    var sleepDurationSeconds: Int
    var steps: Int
    var restingHR: Int?
    var hrvMS: Int?
    var batteryPercent: Int?
    var ringName: String
    var isDemo: Bool

    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(date: Date(), sleepScore: 83, readinessScore: 91,
                       activityScore: 93, sleepDurationSeconds: 25200, steps: 7091,
                       restingHR: 53, hrvMS: 62, batteryPercent: 68,
                       ringName: "Luck Ring", isDemo: true)
    }

    init(date: Date, sleepScore: Int, readinessScore: Int, activityScore: Int,
         sleepDurationSeconds: Int, steps: Int, restingHR: Int?, hrvMS: Int?,
         batteryPercent: Int?, ringName: String, isDemo: Bool) {
        self.date = date
        self.sleepScore = sleepScore
        self.readinessScore = readinessScore
        self.activityScore = activityScore
        self.sleepDurationSeconds = sleepDurationSeconds
        self.steps = steps
        self.restingHR = restingHR
        self.hrvMS = hrvMS
        self.batteryPercent = batteryPercent
        self.ringName = ringName
        self.isDemo = isDemo
    }

    enum CodingKeys: String, CodingKey {
        case date, sleepScore, readinessScore, activityScore, sleepDurationSeconds
        case steps, restingHR, hrvMS, batteryPercent, ringName, isDemo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(Date.self, forKey: .date)
        sleepScore = try c.decode(Int.self, forKey: .sleepScore)
        readinessScore = try c.decode(Int.self, forKey: .readinessScore)
        activityScore = try c.decode(Int.self, forKey: .activityScore)
        sleepDurationSeconds = try c.decode(Int.self, forKey: .sleepDurationSeconds)
        steps = try c.decode(Int.self, forKey: .steps)
        restingHR = try c.decodeIfPresent(Int.self, forKey: .restingHR)
        hrvMS = try c.decodeIfPresent(Int.self, forKey: .hrvMS)
        batteryPercent = try c.decodeIfPresent(Int.self, forKey: .batteryPercent)
        ringName = try c.decodeIfPresent(String.self, forKey: .ringName) ?? "Luck Ring"
        isDemo = try c.decodeIfPresent(Bool.self, forKey: .isDemo) ?? false
    }
}

// MARK: - Rendering

struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LuckRingWidget.Entry

    var body: some View {
        switch family {
        case .accessoryRectangular: accessory
        case .systemMedium: medium
        case .systemLarge: large
        default: small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LUCK RING")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(WidgetPalette.dim)
            Spacer(minLength: 0)
            scoreRow("S", entry.snapshot.sleepScore, WidgetPalette.sleep)
            scoreRow("R", entry.snapshot.readinessScore, WidgetPalette.readiness)
            scoreRow("A", entry.snapshot.activityScore, WidgetPalette.activity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func scoreRow(_ label: String, _ value: Int, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 10)
            Text("\(value)")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetPalette.text)
            Spacer(minLength: 0)
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            small
            VStack(alignment: .leading, spacing: 5) {
                metric("Sleep", hours(entry.snapshot.sleepDurationSeconds), WidgetPalette.sleep)
                metric("Steps", "\(entry.snapshot.steps)", WidgetPalette.activity)
                metric("Resting HR",
                       entry.snapshot.restingHR.map { "\($0) bpm" } ?? "—",
                       WidgetPalette.heart)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func metric(_ label: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WidgetPalette.dim)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetPalette.text)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("LUCK RING")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(WidgetPalette.dim)
                Spacer()
                if let b = entry.snapshot.batteryPercent {
                    Text("\(b)%")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(b > 20 ? WidgetPalette.readiness : WidgetPalette.heart)
                }
            }

            HStack(spacing: 10) {
                gauge(entry.snapshot.sleepScore, WidgetPalette.sleep, "Sleep")
                gauge(entry.snapshot.readinessScore, WidgetPalette.readiness, "Ready")
                gauge(entry.snapshot.activityScore, WidgetPalette.activity, "Active")
            }

            Divider().overlay(WidgetPalette.dim.opacity(0.4))

            VStack(alignment: .leading, spacing: 7) {
                metric("Time asleep", hours(entry.snapshot.sleepDurationSeconds), WidgetPalette.sleep)
                metric("Steps", "\(entry.snapshot.steps)", WidgetPalette.activity)
                metric("Resting heart rate",
                       entry.snapshot.restingHR.map { "\($0) bpm" } ?? "—",
                       WidgetPalette.heart)
                metric("HRV", entry.snapshot.hrvMS.map { "\($0) ms" } ?? "—",
                       WidgetPalette.hrv)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func gauge(_ value: Int, _ tint: Color, _ label: String) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(tint.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: max(0, min(1, Double(value) / 100)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(value)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetPalette.text)
            }
            .frame(width: 58, height: 58)
            Text(label)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(WidgetPalette.dim)
        }
    }

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("LUCK RING").font(.system(size: 10, weight: .bold))
            HStack(spacing: 8) {
                Text("\(entry.snapshot.sleepScore)").foregroundStyle(WidgetPalette.sleep)
                Text("\(entry.snapshot.readinessScore)").foregroundStyle(WidgetPalette.readiness)
                Text("\(entry.snapshot.activityScore)").foregroundStyle(WidgetPalette.activity)
                Spacer()
                Text("\(entry.snapshot.steps) steps")
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
    }

    private func hours(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)h \(m)m"
    }
}

@main
struct LuckRingWidgetBundle: WidgetBundle {
    var body: some Widget { LuckRingWidget() }
}