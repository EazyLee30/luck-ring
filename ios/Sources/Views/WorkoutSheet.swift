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
                                    .scaledFont(19, weight: .semibold)
                                Text(k.title)
                                    .scaledFont(11, weight: .medium)
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
                        .scaledFont(12)
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
                            .scaledFont(16, weight: .medium)
                            .foregroundStyle(Palette.textPrimary)
                        Text("In progress")
                            .scaledFont(11)
                            .foregroundStyle(Palette.textTertiary)
                    }
                    Spacer()
                }

                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(Fmt.duration(active.duration))
                        .scaledFont(44, weight: .regular, design: .serif)
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
                                .scaledFont(14, weight: .medium)
                                .foregroundStyle(Palette.textPrimary)
                            Text("\(Fmt.clock(w.start)) · \(Fmt.duration(w.duration))"
                                 + (w.distanceMetres > 0
                                    ? " · \(Fmt.distance(w.distanceMetres))\(Fmt.distanceUnit(w.distanceMetres))"
                                    : ""))
                                .scaledFont(11)
                                .foregroundStyle(Palette.textTertiary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(w.calories)")
                                .scaledFont(15, weight: .semibold, design: .rounded)
                                .foregroundStyle(Palette.textPrimary)
                            Text("kcal")
                                .scaledFont(9)
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

    private var shareSection: some View { ShareEntryCard(store: store) }

}
