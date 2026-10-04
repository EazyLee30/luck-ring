import Foundation

/// Shared container plumbing.
///
/// The widget is a separate process, so it cannot read `HistoryStore`'s file
/// directly — both sides need the same App Group. Everything here degrades to a
/// no-op when the group is unavailable, which is the normal case in the
/// simulator and on an unsigned build.
enum AppGroup {
    static let identifier = "group.com.luckring.reader"

    /// The group directory, or `nil` when the entitlement is not present.
    static var containerURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// True when history is reachable from a second process.
    static var isAvailable: Bool { containerURL != nil }

    static func describeAvailability() -> String {
        if let url = containerURL {
            return "Shared container: \(url.path)"
        }
        return """
        No App Group entitlement (\(identifier)). History stays in this process \
        only, so the widget will show placeholder data. Add the App Groups \
        capability to both targets to enable it.
        """
    }

    /// A tiny snapshot the widget can read without decoding the whole history.
    static let snapshotFilename = "widget-snapshot.json"

    static func writeSnapshot(_ snapshot: WidgetSnapshot) {
        guard let container = containerURL else { return }
        let url = container.appendingPathComponent(snapshotFilename)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func readSnapshot() -> WidgetSnapshot? {
        guard let container = containerURL else { return nil }
        let url = container.appendingPathComponent(snapshotFilename)
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }
}

/// What the widget shows. Deliberately small: one day, three scores, a couple of
/// headline numbers. Decoding a fortnight of history in a widget extension to
/// render a 160pt-wide view would be wasteful and slow.
struct WidgetSnapshot: Codable, Hashable {
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
    /// True when the numbers came from the demo generator rather than a ring.
    var isDemo: Bool

    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(date: Date(), sleepScore: 0, readinessScore: 0, activityScore: 0,
                       sleepDurationSeconds: 0, steps: 0, restingHR: nil, hrvMS: nil,
                       batteryPercent: nil, ringName: "Luck Ring", isDemo: true)
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
}

extension HealthStore {

    /// Publishes the current day for the widget. Cheap enough to call after any
    /// ingest, and a no-op when there is no shared container.
    func publishWidgetSnapshot() {
        guard let day = today else { return }
        AppGroup.writeSnapshot(
            WidgetSnapshot(
                date: day.date,
                sleepScore: sleepScore?.total ?? 0,
                readinessScore: readinessScore?.total ?? 0,
                activityScore: activityScore?.total ?? 0,
                sleepDurationSeconds: Int(day.sleep?.asleep ?? 0),
                steps: day.activity?.steps ?? 0,
                restingHR: day.restingHeartRate,
                hrvMS: day.averageHRV,
                batteryPercent: batteryPercent,
                ringName: ringName,
                isDemo: connection == .demo))
    }
}

// MARK: - CSV export

/// Flat CSV of every reading, for anyone who wants to analyse it elsewhere.
/// One row per sample rather than one row per day, because that is the shape
/// every analysis tool actually wants.
enum CSVExport {

    struct Column {
        let header: String
        let value: (DailySnapshot, Any?) -> String
    }

    static var columns: [Column] {
        [
            Column(header: "date") { d, _ in isoDay(d.date) },
            Column(header: "sleep_score") { day, _ in
                day.sleep == nil ? "" : "\(ScoreEngine.sleep(for: day, goals: Goals(), baseline: nil).total)"
            },
            Column(header: "sleep_seconds") { day, _ in
                day.sleep.map { "\(Int($0.asleep))" } ?? ""
            },
            Column(header: "time_in_bed_seconds") { day, _ in
                day.sleep.map { "\(Int($0.duration))" } ?? ""
            },
            Column(header: "sleep_efficiency") { day, _ in
                day.sleep.map { String(format: "%.4f", $0.efficiency) } ?? ""
            },
            Column(header: "deep_seconds") { day, _ in
                day.sleep.map { "\(Int($0.time(.deep)))" } ?? ""
            },
            Column(header: "rem_seconds") { day, _ in
                day.sleep.map { "\(Int($0.time(.rem)))" } ?? ""
            },
            Column(header: "awake_seconds") { day, _ in
                day.sleep.map { "\(Int($0.time(.awake)))" } ?? ""
            },
            Column(header: "steps") { day, _ in day.activity.map { "\($0.steps)" } ?? "" },
            Column(header: "distance_m") { day, _ in day.activity.map { "\($0.distanceMetres)" } ?? "" },
            Column(header: "active_seconds") { day, _ in day.activity.map { "\($0.activeSeconds)" } ?? "" },
            Column(header: "active_calories") { day, _ in day.activity.map { "\($0.calories)" } ?? "" },
            Column(header: "exercise_minutes") { day, _ in "\(day.exerciseMinutes)" },
            Column(header: "met_hours") { day, _ in String(format: "%.3f", day.metHours) },
            Column(header: "resting_hr") { day, _ in day.restingHeartRate.map { "\($0)" } ?? "" },
            Column(header: "hrv_ms") { day, _ in day.averageHRV.map { "\($0)" } ?? "" },
            Column(header: "spo2") { day, _ in day.averageOxygen.map { "\($0)" } ?? "" },
            Column(header: "blood_pressure") { day, _ in
                day.latestBloodPressure.map { "\($0.systolic)/\($0.diastolic)" } ?? ""
            },
            Column(header: "skin_temp_c") { day, _ in
                day.temperature.sorted { $0.time < $1.time }.last
                    .map { String(format: "%.2f", $0.celsius) } ?? ""
            },
            Column(header: "heart_rate_samples") { day, _ in "\(day.heartRate.count)" },
            Column(header: "workouts") { day, _ in "\(day.workouts.count)" },
        ]
    }

    /// One row per day, newest last, for the given range.
    static func dailyCSV(days: [DailySnapshot]) -> String {
        var out = columns.map(\.header).joined(separator: ",") + "\n"
        for day in days.sorted(by: { $0.date < $1.date }) {
            let row = columns.map { escape($0.value(day, nil)) }.joined(separator: ",")
            out += row + "\n"
        }
        return out
    }

    /// Long-form export: one row per heart-rate sample. This is the shape a
    /// pandas notebook wants.
    static func samplesCSV(days: [DailySnapshot]) -> String {
        var out = "date,time,metric,value,unit\n"
        for day in days.sorted(by: { $0.date < $1.date }) {
            for sample in day.heartRate.sorted(by: { $0.time < $1.time }) {
                out += "\(isoDay(day.date)),\(isoTime(sample.time)),heart_rate,\(sample.bpm),bpm\n"
            }
            for sample in day.hrv {
                out += "\(isoDay(day.date)),\(isoTime(sample.time)),hrv,\(sample.ms),ms\n"
            }
            for sample in day.oxygen {
                out += "\(isoDay(day.date)),\(isoTime(sample.time)),spo2,\(sample.spo2),%\n"
            }
            for sample in day.temperature {
                out += "\(isoDay(day.date)),\(isoTime(sample.time)),skin_temperature,"
                    + String(format: "%.2f", sample.celsius) + ",celsius\n"
            }
            for sample in day.bloodPressure {
                out += "\(isoDay(day.date)),\(isoTime(sample.time)),blood_pressure,"
                    + "\(sample.systolic),\(sample.diastolic),mmHg\n"
            }
        }
        return out
    }

    /// Workouts as their own file, so training history is not buried in samples.
    static func workoutsCSV(days: [DailySnapshot]) -> String {
        var out = "date,start,kind,duration_seconds,distance_m,calories,avg_hr,peak_hr,source\n"
        for day in days.sorted(by: { $0.date < $1.date }) {
            for w in day.workouts.sorted(by: { $0.start < $1.start }) {
                let fields: [String] = [
                    isoDay(day.date),
                    isoTime(w.start),
                    w.kind.rawValue,
                    "\(Int(w.duration))",
                    "\(w.distanceMetres)",
                    "\(w.calories)",
                    w.averageHR.map { "\($0)" } ?? "",
                    w.peakHR.map { "\($0)" } ?? "",
                    w.source.rawValue,
                ]
                out += fields.map(escape).joined(separator: ",") + "\n"
            }
        }
        return out
    }

    static func write(_ contents: String, named name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Formatting

    /// Quotes only when needed, and doubles embedded quotes, so a value with a
    /// comma cannot shift every later column.
    static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Number of comma-separated fields, ignoring commas inside quotes. Used to
    /// assert that escaping kept every row the same width as the header.
    ///
    /// Doubled quotes inside a quoted field are an escaped quote, not a toggle, so
    /// they are consumed as a pair. The scan works over an array rather than an
    /// iterator because a peek must not swallow the character it looked at.
    static func countFields(_ line: String) -> Int {
        let chars = Array(line)
        var fields = 1
        var inQuotes = false
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if char == "\"" {
                if inQuotes, index + 1 < chars.count, chars[index + 1] == "\"" {
                    index += 2
                    continue
                }
                inQuotes.toggle()
            } else if char == ",", !inQuotes {
                fields += 1
            }
            index += 1
        }
        return fields
    }

    private static func isoDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private static func isoTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}