import Foundation
import SwiftUI

/// Four rating levels, mirroring the vocabulary health apps use for long-term
/// areas. Ordered best → worst so a rating can be compared numerically.
enum HealthRating: Int, CaseIterable, Comparable {
    case thriving = 0      // looks great, keep going
    case lookingGood = 1   // solid balance
    case worthWatching = 2 // small shifts may help
    case needsCare = 3     // worth extra attention
    case unknown = 4       // not enough data yet

    static func < (lhs: HealthRating, rhs: HealthRating) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .thriving: return "Thriving"
        case .lookingGood: return "Looking good"
        case .worthWatching: return "Worth watching"
        case .needsCare: return "Needs care"
        case .unknown: return "Not enough data"
        }
    }

    var tint: Color {
        switch self {
        case .thriving: return Palette.ratingThriving
        case .lookingGood: return Palette.ratingGood
        case .worthWatching: return Palette.ratingWatch
        case .needsCare: return Palette.ratingCare
        case .unknown: return Palette.textTertiary
        }
    }

    var blurb: String {
        switch self {
        case .thriving: return "This area looks fantastic. Whatever you're doing to support it is working."
        case .lookingGood: return "A very nice place to be. You've found a solid balance."
        case .worthWatching: return "Worth keeping an eye on. Small shifts in your habits may help."
        case .needsCare: return "Could use some extra love. Consider small, positive shifts where possible."
        case .unknown: return "Wear the ring consistently and this will calibrate."
        }
    }
}

/// A long-term area of health, rated from a window of history rather than a
/// single day.
struct HealthArea: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    let rating: HealthRating
    /// Rolling trend, oldest → newest. Drives the 90-day arc.
    let trend: [Int]
    let value: String
    let unit: String?
    /// Plain-language reason the rating is what it is.
    let rationale: String

    /// What the rating needs before it can be produced.
    let requirement: String
    var progress: Double      // 0...1 toward the requirement
    var isCalibrating: Bool { rating == .unknown }

    var trendAverage: Int? {
        guard !trend.isEmpty else { return nil }
        return trend.reduce(0, +) / trend.count
    }
}

/// Builds the Health Areas view from stored history.
///
/// The data requirements are deliberate: a rating computed from two nights of
/// data is noise, and showing "Thriving" then is worse than showing nothing.
enum HealthAreaBuilder {

    /// Minimum evidence before a rating is produced at all.
    static let sleepScoresNeeded = 7
    static let sleepWindowDays = 14
    static let heartNightsNeeded = 14
    static let heartWindowDays = 30

    static func build(days: [DailySnapshot], goals: Goals) -> [HealthArea] {
        let recent = Array(days.suffix(sleepWindowDays).sorted { $0.date < $1.date })

        return [
            sleepHealth(recent),
            readinessHealth(recent),
            heartHealth(days),
            activityHealth(recent, goals: goals),
            recoveryHealth(days),
        ]
    }

    // MARK: - Sleep

    private static func sleepHealth(_ recent: [DailySnapshot]) -> HealthArea {
        let scores = recent.compactMap { d -> Int? in
            d.sleep == nil ? nil : ScoreEngine.sleep(for: d, goals: Goals(), baseline: nil).total
        }
        let needed = sleepScoresNeeded
        let have = scores.count

        let rating: HealthRating
        let rationale: String
        if have < needed {
            rating = .unknown
            rationale = "Needs \(needed) nights of sleep data in the last \(sleepWindowDays) days. You have \(have)."
        } else {
            // Median, so one bad night cannot tank a two-week picture.
            let sorted = scores.sorted()
            let median = sorted[sorted.count / 2]
            rating = rate(median, good: 80, great: 88)
            rationale = "Median sleep score \(median) across \(have) nights. "
                + "Your rating follows the median of the last \(sleepWindowDays) days, not last night alone."
        }

        return HealthArea(
            id: "sleep",
            title: "Sleep Health",
            subtitle: "Median sleep score, last \(sleepWindowDays) days",
            symbol: "bed.double.fill",
            tint: Palette.sleep,
            rating: rating,
            trend: scores,
            value: scores.isEmpty ? "—" : "\(sortedMedian(scores))",
            unit: "median",
            rationale: rationale,
            requirement: "\(needed) sleep scores in \(sleepWindowDays) days",
            progress: min(1, Double(have) / Double(needed))
        )
    }

    // MARK: - Readiness

    private static func readinessHealth(_ recent: [DailySnapshot]) -> HealthArea {
        let scores = recent.compactMap { d -> Int? in
            guard d.sleep != nil else { return nil }
            let s = ScoreEngine.sleep(for: d, goals: Goals(), baseline: nil).total
            return ScoreEngine.readiness(for: d, goals: Goals(), baseline: nil, sleepScore: s).total
        }
        let needed = sleepScoresNeeded
        let have = scores.count

        let rating: HealthRating
        if have < needed {
            rating = .unknown
        } else {
            rating = rate(sortedMedian(scores), good: 78, great: 86)
        }

        return HealthArea(
            id: "readiness",
            title: "Readiness",
            subtitle: "Recovery capacity, last \(sleepWindowDays) days",
            symbol: "bolt.heart.fill",
            tint: Palette.readiness,
            rating: rating,
            trend: scores,
            value: scores.isEmpty ? "—" : "\(sortedMedian(scores))",
            unit: "median",
            rationale: have < needed
                ? "Needs \(needed) nights of recovery data. You have \(have)."
                : "Recovery tracked from sleep, HRV, resting heart rate and skin temperature.",
            requirement: "\(needed) recovery scores in \(sleepWindowDays) days",
            progress: min(1, Double(have) / Double(needed))
        )
    }

    // MARK: - Heart

    private static func heartHealth(_ all: [DailySnapshot]) -> HealthArea {
        let window = Array(all.suffix(heartWindowDays))
        let nights = window.filter { !$0.heartRate.isEmpty }.count
        let needed = heartNightsNeeded

        let rhrs = window.compactMap(\.restingHeartRate)
        let avg = rhrs.isEmpty ? nil : rhrs.reduce(0, +) / rhrs.count

        let rating: HealthRating
        if nights < needed {
            rating = .unknown
        } else if let avg {
            rating = rate(100 - avg, good: 45, great: 55, invert: true)
        } else {
            rating = .unknown
        }

        return HealthArea(
            id: "heart",
            title: "Heart Health",
            subtitle: "Resting heart rate, last \(heartWindowDays) days",
            symbol: "heart.fill",
            tint: Palette.heart,
            rating: rating,
            trend: rhrs,
            value: avg.map(String.init) ?? "—",
            unit: "bpm",
            rationale: nights < needed
                ? "Needs \(needed) nights with heart-rate data in \(heartWindowDays) days. You have \(nights)."
                : "Average resting heart rate \(avg ?? 0) bpm across \(nights) nights.",
            requirement: "\(needed) nights in \(heartWindowDays) days",
            progress: min(1, Double(nights) / Double(needed))
        )
    }

    // MARK: - Activity

    private static func activityHealth(_ recent: [DailySnapshot], goals: Goals) -> HealthArea {
        let scores = recent.compactMap { d in
            d.activity == nil ? nil : ScoreEngine.activity(for: d, goals: goals).total
        }
        let needed = sleepScoresNeeded
        let have = scores.count

        let rating: HealthRating
        if have < needed {
            rating = .unknown
        } else {
            rating = rate(sortedMedian(scores), good: 75, great: 85)
        }

        return HealthArea(
            id: "activity",
            title: "Movement",
            subtitle: "Activity consistency, last \(sleepWindowDays) days",
            symbol: "figure.walk.motion",
            tint: Palette.activity,
            rating: rating,
            trend: scores,
            value: scores.isEmpty ? "—" : "\(sortedMedian(scores))",
            unit: "median",
            rationale: have < needed
                ? "Needs \(needed) days with movement data. You have \(have)."
                : "Consistency matters more than any single day. Median activity score \(sortedMedian(scores)).",
            requirement: "\(needed) active days in \(sleepWindowDays) days",
            progress: min(1, Double(have) / Double(needed))
        )
    }

    // MARK: - Recovery / balance

    private static func recoveryHealth(_ all: [DailySnapshot]) -> HealthArea {
        let window = Array(all.suffix(sleepWindowDays))
        let hrvs = window.compactMap(\.averageHRV)
        let needed = sleepScoresNeeded
        let have = hrvs.count

        let rating: HealthRating
        if have < needed {
            rating = .unknown
        } else {
            // Higher HRV is better, so rate it directly on its own scale.
            rating = rate(sortedMedian(hrvs), good: 40, great: 55)
        }

        return HealthArea(
            id: "hrv",
            title: "Recovery",
            subtitle: "Heart-rate variability, last \(sleepWindowDays) days",
            symbol: "waveform.path.ecg",
            tint: Palette.hrv,
            rating: rating,
            trend: hrvs,
            value: hrvs.isEmpty ? "—" : "\(sortedMedian(hrvs))",
            unit: "ms median",
            rationale: have < needed
                ? "Needs \(needed) nights of HRV data. You have \(have)."
                : "HRV is the single best daily signal for training readiness.",
            requirement: "\(needed) nights of HRV in \(sleepWindowDays) days",
            progress: min(1, Double(have) / Double(needed))
        )
    }

    // MARK: - Rating helpers

    private static func sortedMedian(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let s = values.sorted()
        return s[s.count / 2]
    }

    /// Two-threshold rating. `invert` flips it for metrics where lower is better
    /// (resting heart rate).
    private static func rate(_ value: Int, good: Int, great: Int, invert: Bool = false) -> HealthRating {
        let v = invert ? -value : value
        let g = invert ? -great : great
        let gd = invert ? -good : good
        if v >= g { return .thriving }
        if v >= gd { return .lookingGood }
        if v >= gd - 12 { return .worthWatching }
        return .needsCare
    }
}

extension Palette {
    /// Health-area rating ramp, deliberately distinct from the metric tints.
    static let ratingThriving = Color(hex: 0x3B82F6)   // blue
    static let ratingGood = Color(hex: 0x3ED598)      // green
    static let ratingWatch = Color(hex: 0xFFC24C)     // yellow
    static let ratingCare = Color(hex: 0xFF5C7A)      // red
}
extension HealthArea {
    /// Compact label for the overview strip.
    var shortLabel: String {
        switch id {
        case "sleep": return "Sleep"
        case "readiness": return "Recovery"
        case "heart": return "Heart"
        case "activity": return "Move"
        case "hrv": return "HRV"
        default: return title
        }
    }
}
