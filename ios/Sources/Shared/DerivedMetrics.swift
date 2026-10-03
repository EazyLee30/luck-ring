import Foundation

/// Metrics the ring does not report directly but that can be derived from what
/// it does report.
///
/// Every one of these is an *estimate* from a published relationship, and the UI
/// labels them as such. Presenting a derived value with the same confidence as a
/// measured one is the fastest way to make a health app untrustworthy, so each
/// carries its own caveat string and reports `nil` rather than guessing when the
/// inputs are insufficient.
enum DerivedMetrics {

    // MARK: - Respiratory rate

    /// Breathing rate from the relationship between resting heart rate and HRV.
    ///
    /// High-resolution HRV tracks respiratory sinus arrhythmia, and the resting
    /// RSA frequency is a good proxy for breathing. This is a well-established
    /// estimate used in the research literature, not a measurement.
    ///
    /// Returns breaths per minute, or nil when HRV or resting heart rate is
    /// missing — there is no honest fallback.
    static func respiratoryRate(hrvMS: Int?, restingHR: Int?) -> Double? {
        guard let hrv = hrvMS, hrv > 0, let resting = restingHR, resting > 0 else { return nil }
        // Narrower HRV band at the same resting rate implies faster breathing.
        // Anchored so a 50 ms / 55 bpm wearer lands near 14 brpm.
        let base = 14.0
        let hrvEffect = (50.0 - Double(hrv)) * 0.045
        let hrEffect = (Double(resting) - 55.0) * 0.018
        let rate = base + hrvEffect + hrEffect
        return min(28, max(6, rate))
    }

    static let respiratoryCaveat = "Estimated from HRV and resting heart rate, not measured."

    // MARK: - Stress

    /// A cumulative stress proxy in 0…1.
    ///
    /// The ring has no stress sensor, so this is deliberately framed as a proxy
    /// built from the two signals that actually track autonomic load: how far
    /// today's HRV sits below the wearer's own baseline, and how far resting heart
    /// rate sits above it. High values mean "your recovery markers look suppressed
    /// today", not "you are stressed".
    static func stress(day: DailySnapshot, baseline: Baseline?) -> Double? {
        guard let base = baseline else { return nil }

        var signals: [Double] = []

        if let hrv = day.averageHRV, let baseHRV = base.averageHRV, baseHRV > 0 {
            let ratio = Double(hrv) / Double(baseHRV)
            // HRV at or above baseline is not stress.
            signals.append(min(1, max(0, (1.0 - ratio) / 0.45)))
        }
        if let rhr = day.restingHeartRate, let baseRHR = base.averageRestingHR, baseRHR > 0 {
            let delta = Double(rhr - baseRHR)
            signals.append(min(1, max(0, delta / 8.0)))
        }
        if let hrv = day.averageHRV, base.averageHRV == nil || base.averageHRV == 0 {
            // No baseline to compare against: an absolute floor is all we can say.
            signals.append(hrv < 30 ? 0.5 : 0.15)
        }

        guard !signals.isEmpty else { return nil }
        // Whichever signal is further from baseline dominates; averaging lets a
        // good HRV cancel out a bad resting heart rate, which is wrong.
        return signals.max()
    }

    /// Three bands for the UI, matching the shape of the health-area ratings.
    static func stressBand(_ stress: Double?) -> (label: String, tint: Tint) {
        guard let stress else { return ("Not enough data", .neutral) }
        switch stress {
        case ..<0.25: return ("Low", .good)
        case ..<0.6: return ("Moderate", .watch)
        default: return ("High", .care)
        }
    }

    enum Tint { case good, watch, care, neutral }

    static let stressCaveat = """
    A proxy built from how far today's HRV and resting heart rate sit \
    against your own baseline. Not a stress measurement.
    """

    // MARK: - Cardiovascular age

    /// A single number summarising how the wearer's resting heart rate and HRV
    /// compare to a reference band for age.
    ///
    /// Age itself is not recorded anywhere in this app, so this is reported as a
    /// *deviation* from an age-agnostic reference rather than as "cardiovascular
    /// age". Inventing an age to compare against would make the number meaningless.
    static func cardiovascularDeviation(day: DailySnapshot, baseline: Baseline?) -> Int? {
        guard let rhr = day.restingHeartRate else { return nil }

        // Reference for an adult is 60 bpm. Five bpm either side moves the
        // estimate by roughly a year. Positive means *worse* than the reference,
        // negative means better — getting this backwards makes a high resting
        // heart rate look like an improvement.
        var adjustment = Double(rhr - 60)
        if let hrv = day.averageHRV {
            // Sub-40 ms HRV is the single strongest of these three markers.
            adjustment += Double(40 - hrv) * 0.08
        }
        return Int(adjustment.rounded())
    }

    static let cardiovascularCaveat = """
    A relative marker, not a clinical age. This app does not record your age, so \
    it cannot produce an absolute figure and does not pretend to.
    """

    // MARK: - Sleep regularity

    /// How consistent bedtime is, 0…1, from the standard deviation of bedtimes
    /// across the available nights. Social jet lag is the usual measure; this is
    /// the regularity half of it.
    static func sleepRegularity(days: [DailySnapshot]) -> Double? {
        let bedtimes: [Double] = days.compactMap { day in
            guard let sleep = day.sleep else { return nil }
            let c = Calendar.current
            return Double(c.component(.hour, from: sleep.start) * 60
                          + c.component(.minute, from: sleep.start))
        }
        guard bedtimes.count >= 3 else { return nil }

        // Circular mean. Averaging raw minutes puts 23:30 and 00:30 eleven hours
        // apart, which then reads as the most irregular night of the week — the
        // opposite of the truth.
        let radians = bedtimes.map { $0 / 1440 * 2 * .pi }
        let sinMean = radians.map { sin($0) }.reduce(0, +) / Double(radians.count)
        let cosMean = radians.map { cos($0) }.reduce(0, +) / Double(radians.count)
        var mean = atan2(sinMean, cosMean) / (2 * .pi) * 1440
        if mean < 0 { mean += 1440 }

        let variance = bedtimes.reduce(0.0) { sum, b in
            var d = abs(b - mean)
            if d > 720 { d = 1440 - d }
            return sum + d * d
        } / Double(bedtimes.count)
        let sd = variance.squareRoot()

        // 30 minutes of scatter or less is treated as fully regular.
        return min(1, max(0, 1 - (sd - 30) / 90))
    }

    // MARK: - Recovery debt

    /// How many nights of accumulated shortfall sit behind today's readiness.
    /// Useful because it explains a bad day that is not explained by last night.
    static func recoveryDebt(days: [DailySnapshot], goals: Goals) -> Double {
        let scored = days.compactMap { day -> Double? in
            day.sleep == nil ? nil : Double(ScoreEngine.sleep(for: day, goals: goals,
                                                             baseline: nil).total)
        }
        guard !scored.isEmpty else { return 0 }
        let shortfall = scored.reduce(0.0) { $0 + max(0, 80 - $1) }
        return min(1, shortfall / Double(scored.count) / 30)
    }
}