// Sanity harness for the score engine and demo generator. Compiles the pure
// Foundation sources so score distributions can be checked without a device.
//
//   swiftc -O Sources/Shared/Models.swift Sources/Shared/Scores.swift \
//          Sources/Shared/DemoData.swift Sources/Shared/SeededRNG.swift \
//          Tools/ScoreReport/main.swift -o /tmp/score-report
//   /tmp/score-report

import Foundation

let goals = Goals()

print("=== demo week (seed 0xC0FFEE) ===")
var rng = SeededGenerator(seed: 0xC0FFEE)
let calendar = Calendar.current
let today = calendar.startOfDay(for: Date())
var days: [DailySnapshot] = []
for offset in stride(from: 6, through: 0, by: -1) {
    guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
    days.append(DemoDay.make(date: d, rng: &rng))
}
let baseline = Baseline.make(from: days)

print(String(format: "%-10s %5s %5s %5s  %-9s %-9s %-8s %-7s %-7s",
             ("day" as NSString).utf8String!,
             ("sleep" as NSString).utf8String!,
             ("ready" as NSString).utf8String!,
             ("active" as NSString).utf8String!,
             ("asleep" as NSString).utf8String!,
             ("inBed" as NSString).utf8String!,
             ("eff" as NSString).utf8String!,
             ("deep" as NSString).utf8String!,
             ("rem" as NSString).utf8String!))

var sleepScores: [Int] = []
for day in days.sorted(by: { $0.date < $1.date }) {
    let s = ScoreEngine.sleep(for: day, goals: goals, baseline: baseline)
    let r = ScoreEngine.readiness(for: day, goals: goals, baseline: baseline, sleepScore: s.total)
    let a = ScoreEngine.activity(for: day, goals: goals)
    sleepScores.append(s.total)
    let f = DateFormatter()
    f.dateFormat = "EEE"
    let asleepMin = day.sleep.map { Int($0.asleep / 60) }
    let inBedMin = day.sleep.map { Int($0.duration / 60) }
    let deepMin = day.sleep.map { Int($0.time(.deep) / 60) }
    let remMin = day.sleep.map { Int($0.time(.rem) / 60) }

    func pad(_ s: String, _ n: Int) -> String {
        s.count >= n ? s : s + String(repeating: " ", count: n - s.count)
    }

    var line = pad(f.string(from: day.date), 10)
    line += pad("\(s.total)", 7)
    line += pad("\(r.total)", 7)
    line += pad("\(a.total)", 8)
    line += pad(asleepMin.map { "\($0)m" } ?? "-", 9)
    line += pad(inBedMin.map { "\($0)m" } ?? "-", 9)
    line += pad(day.sleep.map { String(format: "%.0f%%", $0.efficiency * 100) } ?? "-", 7)
    line += pad(deepMin.map { "\($0)m" } ?? "-", 7)
    line += remMin.map { "\($0)m" } ?? "-"
    print(line)
}

func stats(_ label: String, _ v: [Int]) {
    guard !v.isEmpty else { return }
    let avg = v.reduce(0, +) / v.count
    print("\(label): avg \(avg)  min \(v.min()!)  max \(v.max()!)")
}
print("")
stats("sleep scores", sleepScores)

print("\n=== distribution over 2000 generated days ===")
var rng2 = SeededGenerator(seed: 99)
var buckets = [Int](repeating: 0, count: 11)   // 0-9,10-19,...100
var many: [DailySnapshot] = []
for i in 0..<2000 {
    guard let d = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
    many.append(DemoDay.make(date: d, rng: &rng2))
}
let bigBaseline = Baseline.make(from: many)
var all: [Int] = []
for day in many {
    let score = ScoreEngine.sleep(for: day, goals: goals, baseline: bigBaseline).total
    all.append(score)
    buckets[min(10, score / 10)] += 1
}
for (i, b) in buckets.enumerated() {
    let pct = Double(b) / Double(max(1, all.count)) * 100
    let bar = String(repeating: "#", count: Int(pct / 1.5))
    let lo = i * 10
    let hi = i == 10 ? 100 : i * 10 + 9
    print("\(lo)-\(hi)".padding(toLength: 9, withPad: " ", startingAt: 0)
          + "\(b)".padding(toLength: 7, withPad: " ", startingAt: 0)
          + String(format: "(%5.1f%%) ", pct) + bar)
}
stats("sleep scores", all)

var readyAll: [Int] = []
var actAll: [Int] = []
for day in many {
    let s = ScoreEngine.sleep(for: day, goals: goals, baseline: bigBaseline).total
    readyAll.append(ScoreEngine.readiness(for: day, goals: goals, baseline: bigBaseline, sleepScore: s).total)
    actAll.append(ScoreEngine.activity(for: day, goals: goals).total)
}
stats("readiness", readyAll)
stats("activity", actAll)

// Invariant checks on session assembly.
print("\n=== invariants ===")
var bad = 0
for day in many {
    guard let s = day.sleep else { continue }
    if s.asleep > s.duration + 1 { bad += 1; print("asleep > inBed on \(day.date)") }
    if s.efficiency < 0 || s.efficiency > 1 { bad += 1; print("efficiency out of range") }
    let summed = s.intervals.reduce(0) { $0 + $1.duration }
    if summed > s.duration + 2 { bad += 1; print("stage intervals \(summed) exceed session \(s.duration)") }
    if abs((s.asleep + s.time(.awake)) - s.duration) > 1 { bad += 1; print("asleep+awake != duration") }
}
print(bad == 0 ? "all sessions consistent ✓" : "\(bad) violations ✗")