import Foundation

/// Disk storage for everything the app would otherwise lose on relaunch.
///
/// Two files: one JSON document for history (days, goals), one for UI
/// preferences. History is the part that is genuinely painful to rebuild — the
/// ring only streams while the sensor switch is open — so it is written eagerly
/// rather than on a background timer.
final class HistoryStore {

    static let shared = HistoryStore()

    private let directory: URL
    private let historyURL: URL
    private let preferencesURL: URL
    private let queue = DispatchQueue(label: "com.luckring.history", qos: .utility)

    private struct Document: Codable {
        var version: Int = 1
        var days: [DailySnapshot] = []
        var goals: Goals = Goals()
    }

    struct Preferences: Codable {
        var shortcutOrder: [String] = Shortcut.defaultOrder
    }

    /// Bumped when the on-disk shape changes in a way that needs a migration.
    private static let currentVersion = 1

    /// `baseDirectory` exists so tests can point at a temporary directory. The
    /// earlier version always resolved under Application Support, which meant the
    /// tests exercised — and wrote to — the real app container.
    init(baseDirectory: URL? = nil, directoryName: String = "history") {
        let base = baseDirectory
            ?? FileManager.default.urls(for: .applicationSupportDirectory,
                                       in: .userDomainMask)[0]
            .appendingPathComponent(directoryName, isDirectory: true)
        directory = base
        historyURL = base.appendingPathComponent("history.json")
        preferencesURL = base.appendingPathComponent("preferences.json")
    }

    // MARK: - History

    func load() -> (days: [DailySnapshot], goals: Goals) {
        queue.sync {
            guard let data = try? Data(contentsOf: historyURL) else { return ([], Goals()) }
            guard let document = try? JSONDecoder.luckRing.decode(Document.self, from: data) else {
                // Corrupt or truncated: keep the bad file for diagnosis rather
                // than silently overwriting the wearer's history.
                try? data.write(to: directory.appendingPathComponent("history-corrupt.json"))
                return ([], Goals())
            }
            guard document.version <= Self.currentVersion else {
                // Written by a newer build. Refuse rather than downgrade the data.
                return ([], Goals())
            }
            return (document.days, document.goals)
        }
    }

    func save(days: [DailySnapshot], goals: Goals) {
        let document = Document(version: Self.currentVersion, days: days, goals: goals)
        queue.async {
            guard let data = try? JSONEncoder.luckRing.encode(document) else { return }
            self.writeAtomically(data, to: self.historyURL)
        }
    }

    // MARK: - Preferences

    func loadPreferences() -> Preferences {
        queue.sync {
            guard let data = try? Data(contentsOf: preferencesURL),
                  let prefs = try? JSONDecoder.luckRing.decode(Preferences.self, from: data)
            else { return Preferences() }
            return prefs
        }
    }

    func savePreferences(_ prefs: Preferences) {
        queue.async {
            guard let data = try? JSONEncoder.luckRing.encode(prefs) else { return }
            self.writeAtomically(data, to: self.preferencesURL)
        }
    }

    // MARK: - Maintenance

    /// Exposed for the ring sheet so a wearer can clear local history.
    func deleteAll() {
        queue.sync {
            try? FileManager.default.removeItem(at: historyURL)
            try? FileManager.default.removeItem(at: preferencesURL)
        }
    }

    var fileSizeBytes: Int64 {
        queue.sync {
            let attrs = try? FileManager.default.attributesOfItem(atPath: historyURL.path)
            return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        }
    }

    private func writeAtomically(_ data: Data, to url: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Atomic so a crash mid-write cannot truncate the existing file.
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Coders

extension JSONEncoder {
    static var luckRing: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var luckRing: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
