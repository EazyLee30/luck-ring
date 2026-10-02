import Foundation
import SwiftUI

/// Things the app wants to tell the wearer right now, derived from actual state
/// rather than hardcoded copy.
struct ActionItem: Identifiable {
    enum Kind { case warning, info, success }
    let id = UUID()
    let kind: Kind
    let title: String
    let detail: String
    let symbol: String

    var tint: Color {
        switch kind {
        case .warning: return Palette.warn
        case .info: return Palette.temp
        case .success: return Palette.good
        }
    }
}

/// A line in the day's history, built from records that actually arrived.
struct DayEvent: Identifiable {
    let id = UUID()
    let time: Date
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
}

enum Insights {

    /// Rule-based, in priority order. Each rule explains itself so nothing looks
    /// like a black box.
    static func actionItems(days: [DailySnapshot], connection: RingConnection,
                            battery: Int?, streaming: Bool, goals: Goals) -> [ActionItem] {
        var items: [ActionItem] = []
        let recent = days.sorted { $0.date > $1.date }

        if let battery, battery <= 20 {
            items.append(.init(kind: .warning,
                              title: "Ring battery \(battery)%",
                              detail: "Charge it soon — below 15% the ring stops streaming overnight data.",
                              symbol: "battery.25"))
        }

        switch connection {
        case .demo:
            items.append(.init(kind: .info,
                              title: "Showing demo data",
                              detail: "Tap the ring icon in the top-right to pair and replace this with your own readings.",
                              symbol: "wand.and.stars"))
        case .idle, .disconnected:
            items.append(.init(kind: .warning,
                              title: "Ring not connected",
                              detail: "Reconnect to upload today's steps, sleep and heart rate.",
                              symbol: "antenna.radiowaves.left.and.right.slash"))
        case .awaitingConfirm:
            items.append(.init(kind: .warning,
                              title: "Confirm pairing on the ring",
                              detail: "Tap the ring screen to finish pairing.",
                              symbol: "hand.tap"))
        default:
            break
        }

        if case .ready = connection, !streaming {
            items.append(.init(kind: .info,
                              title: "History upload is paused",
                              detail: "The ring only sends stored history while the sensor switch is on.",
                              symbol: "arrow.down.circle"))
        }

        if let yesterday = recent.dropFirst().first, yesterday.sleep == nil, recent.first != nil {
            items.append(.init(kind: .info,
                              title: "No sleep recorded",
                              detail: "Keep the ring on overnight — sleep stages are detected while you wear it.",
                              symbol: "bed.double"))
        }

        if let today = recent.first, let steps = today.activity?.steps,
           steps < goals.stepTarget / 2, Calendar.current.isDateInToday(today.date) {
            items.append(.init(kind: .info,
                              title: "Movement is light so far",
                              detail: "\(steps) of \(goals.stepTarget) steps. A short walk closes the gap.",
                              symbol: "figure.walk"))
        }

        return items
    }

    /// Reverse-chronological timeline of what the ring reported.
    static func events(for day: DailySnapshot, limit: Int = 8) -> [DayEvent] {
        var out: [DayEvent] = []

        if let sleep = day.sleep {
            out.append(.init(time: sleep.start,
                             title: "Fell asleep",
                             detail: "Bedtime — \(Fmt.duration(sleep.duration)) in bed, "
                                + "\(Fmt.duration(sleep.asleep)) asleep",
                             symbol: "bed.double.fill",
                             tint: Palette.sleep))

            let wake = sleep.intervals.last { $0.stage == .awake }?.end
            if let wake {
                out.append(.init(time: wake,
                                 title: "Woke up",
                                 detail: "\(Int(sleep.efficiency * 100))% efficiency, "
                                    + "\(Fmt.duration(sleep.time(.deep))) deep",
                                 symbol: "sun.horizon.fill",
                                 tint: Palette.sleepDeep))
            }
        }

        if let hrv = day.averageHRV {
            out.append(.init(time: day.date.addingTimeInterval(7 * 3600),
                             title: "HRV measured",
                             detail: "\(hrv) ms average",
                             symbol: "waveform.path.ecg",
                             tint: Palette.hrv))
        }

        if let bp = day.latestBloodPressure {
            out.append(.init(time: bp.time,
                             title: "Blood pressure",
                             detail: "\(bp.systolic)/\(bp.diastolic) mmHg",
                             symbol: "heart.text.square.fill",
                             tint: Palette.pressure))
        }

        if let spo2 = day.averageOxygen {
            out.append(.init(time: day.date.addingTimeInterval(8 * 3600),
                             title: "Blood oxygen",
                             detail: "\(spo2)% average",
                             symbol: "lungs.fill",
                             tint: Palette.oxygen))
        }

        if let resting = day.restingHeartRate {
            out.append(.init(time: day.date.addingTimeInterval(4 * 3600),
                             title: "Resting heart rate",
                             detail: "\(resting) bpm · range \(day.lowestHeartRate ?? 0)–\(day.highestHeartRate ?? 0)",
                             symbol: "heart.fill",
                             tint: Palette.heart))
        }

        if let activity = day.activity {
            out.append(.init(time: day.date.addingTimeInterval(20 * 3600),
                             title: "Movement logged",
                             detail: "\(activity.steps) steps · \(Fmt.distance(activity.distanceMetres)) "
                                + Fmt.distanceUnit(activity.distanceMetres)
                                + " · \(activity.calories) kcal",
                             symbol: "figure.walk.motion",
                             tint: Palette.activity))
        }

        return Array(out.sorted { $0.time > $1.time }.prefix(limit))
    }
}

/// Reorderable shortcut row. At least three are always shown, matching the
/// constraint health apps put on this affordance.
struct Shortcut: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let tint: Color
    /// Short value shown under the title, e.g. "83".
    var value: String
    var caption: String
}

extension Shortcut {
    /// Which shortcuts a wearer has pinned, in display order.
    static func catalogue(days: [DailySnapshot], goals: Goals) -> [Shortcut] {
        guard let day = days.sorted(by: { $0.date > $1.date }).first else { return [] }
        let baseline = Baseline.make(from: days)

        let sleep = ScoreEngine.sleep(for: day, goals: goals, baseline: baseline).total
        let ready = ScoreEngine.readiness(for: day, goals: goals, baseline: baseline,
                                          sleepScore: sleep).total
        let active = ScoreEngine.activity(for: day, goals: goals).total

        return [
            .init(id: "sleep", title: "Sleep", symbol: "bed.double.fill", tint: Palette.sleep,
                  value: "\(sleep)", caption: "score"),
            .init(id: "readiness", title: "Readiness", symbol: "bolt.heart.fill", tint: Palette.readiness,
                  value: "\(ready)", caption: "score"),
            .init(id: "activity", title: "Activity", symbol: "figure.walk.motion", tint: Palette.activity,
                  value: "\(active)", caption: "score"),
            .init(id: "heart", title: "Heart rate", symbol: "heart.fill", tint: Palette.heart,
                  value: day.restingHeartRate.map(String.init) ?? "—", caption: "resting bpm"),
            .init(id: "hrv", title: "HRV", symbol: "waveform.path.ecg", tint: Palette.hrv,
                  value: day.averageHRV.map(String.init) ?? "—", caption: "ms"),
            .init(id: "temperature", title: "Temperature", symbol: "thermometer.medium", tint: Palette.temp,
                  value: day.temperatureDelta(baseline: baseline?.averageSkinTemp)
                        .map { Fmt.signed($0) } ?? "—", caption: "°C vs baseline"),
            .init(id: "oxygen", title: "Blood oxygen", symbol: "lungs.fill", tint: Palette.oxygen,
                  value: day.averageOxygen.map(String.init) ?? "—", caption: "%"),
            .init(id: "pressure", title: "Blood pressure", symbol: "waveform.path.ecg.rectangle.fill",
                  tint: Palette.pressure,
                  value: day.latestBloodPressure.map { "\($0.systolic)/\($0.diastolic)" } ?? "—",
                  caption: "mmHg"),
        ]
    }

    /// Default pin order. Deliberately leads with the raw vitals: the three
    /// scores already have their own gauges directly below, so pinning them here
    /// too just duplicated the same two numbers twice on one screen.
    static let defaultOrder = ["heart", "hrv", "temperature", "oxygen", "activity"]
}