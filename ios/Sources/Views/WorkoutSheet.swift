import SwiftUI

/// Workout tracking plus the share sheet. Both live here because they are the
/// two things a wearer reaches for after the data lands: "log what I just did"
/// and "send this to someone".
struct WorkoutSheet: View {
    @ObservedObject var store: HealthStore
    @Environment(\.dismiss) private var dismiss

    @State private var kind: Workout.Kind = .run
    @State private var distanceText = ""
    @State private var kindPickerVisible = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let active = store.activeWorkout {
                        activeSession(active)
                    } else {
                        picker
                    }

                    if !store.today!.workouts.isEmpty {
                        log
                    }

                    shareSection
                }
                .padding(18)
                .padding(.bottom, 20)
            }
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Picker

    private var picker: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: 14) {
                CardHeaderRow(title: "Start a session", symbol: "figure.run",
                              tint: Palette.activity)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)],
                          spacing: 10) {
                    ForEach(Workout.Kind.allCases) { k in
                        Button {
                            kind = k
                            store.startWorkout(k)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            VStack(spacing: 7) {
                                Image(systemName: k.symbol)
                                    .font(.system(size: 19, weight: .semibold))
                                Text(k.title)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(Palette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Palette.surfaceHi,
                                        in: RoundedRectangle(cornerRadius: 12,
                                                              style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if kind.needsManualTracking {
                    Text("\(kind.title) can't be measured by a ring — you'll enter the distance yourself when you finish.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Active session

    private func activeSession(_ active: Workout) -> some View {
        GlowCard(tint: Palette.activity) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    IconBadge(symbol: active.kind.symbol, tint: Palette.activity, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(active.kind.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                        Text("In progress")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    Spacer()
                }

                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(Fmt.duration(active.duration))
                        .font(.system(size: 44, weight: .regular, design: .serif))
                        .foregroundStyle(Palette.textPrimary)
                        .contentTransition(.numericText())
                }

                if let hr = store.today?.restingHeartRate {
                    MetricRow(title: "Resting heart rate", value: "\(hr)", unit: "bpm", tint: Palette.heart)
                }
                MetricRow(title: "Samples recorded",
                          value: "\(samplesDuring(active))", unit: "this session", tint: Palette.textSecondary)

                HStack(spacing: 10) {
                    Button { finish(active) } label: {
                        PillButton(title: "Finish", symbol: "stop.fill", tint: Palette.activity)
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.cancelWorkout()
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    } label: {
                        PillButton(title: "Discard", symbol: "xmark", filled: false)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private func samplesDuring(_ workout: Workout) -> Int {
        (store.today?.heartRate ?? []).filter { $0.time >= workout.start }.count
    }

    private func finish(_ workout: Workout) {
        let text = distanceText.trimmingCharacters(in: .whitespaces)
        if text.isEmpty {
            _ = store.finishWorkout()
        } else {
            _ = store.finishWorkout(distanceMetres: Int(text))
        }
        distanceText = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Log

    private var log: some View {
        GlowCard(tint: Palette.activity) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeaderRow(title: "Today's sessions",
                              status: "\(store.today!.exerciseMinutes) MIN",
                              tint: Palette.activity)

                ForEach(store.today!.workouts) { w in
                    HStack(spacing: 12) {
                        IconBadge(symbol: w.kind.symbol, tint: Palette.activity, size: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(w.kind.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Palette.textPrimary)
                            Text("\(Fmt.clock(w.start)) · \(Fmt.duration(w.duration))"
                                 + (w.distanceMetres > 0
                                    ? " · \(Fmt.distance(w.distanceMetres))\(Fmt.distanceUnit(w.distanceMetres))"
                                    : ""))
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.textTertiary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(w.calories)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.textPrimary)
                            Text("kcal")
                                .font(.system(size: 9))
                                .foregroundStyle(Palette.textTertiary)
                        }
                    }
                }

                Divider().overlay(Palette.stroke)
                MetricRow(title: "Training load (MET-hours)",
                          value: String(format: "%.1f", store.today!.metHours),
                          tint: Palette.activity,
                          progress: store.weeklyTrainingLoad())
            }
            .padding(16)
        }
    }

    // MARK: - Share

    private var shareSection: some View {
        ShareRow(store: store)
    }
}

// MARK: - Share

struct ShareRow: View {
    @ObservedObject var store: HealthStore
    @StateObject private var renderer = ShareCardRenderer()
    @State private var preview: ShareCard?

    private var day: DailySnapshot? { store.selectedDay }

    var body: some View {
        GlowCard(tint: Palette.sleep) {
            VStack(alignment: .leading, spacing: 14) {
                CardHeaderRow(title: "Share this day", symbol: "square.and.arrow.up",
                              tint: Palette.sleep)
                    .onAppear { shareHost = resolveHost() }

                if let day {
                    ShareCardPreview(day: day,
                                     sleep: store.sleepScore?.total ?? 0,
                                     readiness: store.readinessScore?.total ?? 0,
                                     activity: store.activityScore?.total ?? 0,
                                     ringName: store.ringName)
                        .frame(height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if renderer.isRendering {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Button {
                            renderer.render(day: day,
                                             sleep: store.sleepScore?.total ?? 0,
                                             readiness: store.readinessScore?.total ?? 0,
                                             activity: store.activityScore?.total ?? 0,
                                             ringName: store.ringName)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            PillButton(title: "Render share image", symbol: "photo")
                        }
                        .buttonStyle(.plain)
                    }

                    if renderer.image != nil {
                        Button { presentShare() } label: {
                            PillButton(title: "Share", symbol: "square.and.arrow.up",
                                       tint: Palette.sleep)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("The card carries this app's own scores. It is not a medical record.")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Nothing to share yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .padding(16)
        }
    }

    /// Attach both a PNG file and the bitmap: the file lets the user save the
    /// image, the bitmap lets apps that only take an image still receive one.
    func presentShare() {
        var items = renderer.shareItems()
        items.insert(shareCaption, at: 0)
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // Presented from the hosting window's root rather than a guessed key
        // window: in SwiftUI the key window is not reliably the one on screen.
        sheet.popoverPresentationController?.sourceView = shareAnchor
        shareHost?.present(sheet, animated: true)
    }

    /// Anchor for the iPad popover.
    @State private var shareAnchor: UIView? = nil
    /// Resolved once on appear; the sheet is presented from there.
    @State private var shareHost: UIViewController? = nil

    private func resolveHost() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }

    private var shareCaption: String {
        guard let day else { return "" }
        let s = store.sleepScore?.total ?? 0
        let r = store.readinessScore?.total ?? 0
        let a = store.activityScore?.total ?? 0
        return "\(Fmt.dayTitle(day.date)): sleep \(s), readiness \(r), activity \(a). Tracked with Luck Ring."
    }
}

/// Live, scaled-down render of the export card.
struct ShareCardPreview: View {
    let day: DailySnapshot
    let sleep: Int
    let readiness: Int
    let activity: Int
    let ringName: String

    var body: some View {
        ShareCard(day: day, sleepScore: sleep, readinessScore: readiness,
                  activityScore: activity, ringName: ringName)
            .scaleEffect(0.34, anchor: .topLeading)
            .frame(width: 1080 * 0.34, height: 1350 * 0.34, alignment: .topLeading)
            .clipped()
    }
}