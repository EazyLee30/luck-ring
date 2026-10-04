import SwiftUI

/// Storage, export and deletion — the three things you can do to the app's copy
/// of your data. Lives in the ring sheet rather than on a tab because it is a
/// once-in-a-while destination, not somewhere you browse.
struct DataCard: View {
    @ObservedObject var store: HealthStore
    @State private var model = HealthExportViewModel()
    @State private var confirmClear = false
    @State private var clearedNote = false

    private var days: [DailySnapshot] { store.orderedDays }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "internaldrive")
                        .scaledFont(15, weight: .semibold)
                        .foregroundStyle(Palette.textSecondary)
                    Text("Stored history")
                        .scaledFont(15, weight: .semibold, design: .rounded)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("\(days.count) days")
                        .scaledFont(11, weight: .medium)
                        .foregroundStyle(Palette.textTertiary)
                }

                Divider().overlay(Palette.stroke)

                row("On this device", Bytes.human(store.localStorageBytes))
                row("Records", "\(days.reduce(0) { $0 + $1.heartRate.count }) heart-rate samples")

                Divider().overlay(Palette.stroke)

                exportSection
                healthSection
                deleteSection

                if clearedNote {
                    Text("Local history deleted. Your ring still holds its own records.")
                        .scaledFont(11)
                        .foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear { model.refresh() }
        .confirmationDialog("Delete all locally stored history?",
                            isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Delete \(days.count) days", role: .destructive) {
                store.deleteLocalHistory()
                clearedNote = true
                Haptics.warning()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("This removes the app's copy only. Nothing is sent to the ring, and any change you make on the ring will reappear here the next time it syncs.")
        }
    }

    // MARK: - Rows

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .scaledFont(13)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Text(value)
                .scaledFont(13, weight: .medium, design: .rounded)
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Export as CSV")
                .scaledFont(13, weight: .medium)
                .foregroundStyle(Palette.textPrimary)
            Text("Three files: a daily summary, every individual reading, and your sessions. Missing values are left blank rather than written as zero.")
                .scaledFont(11)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                csvLink("Daily", "luckring-daily.csv",
                        CSVExport.dailyCSV(days: days))
                csvLink("Readings", "luckring-readings.csv",
                        CSVExport.samplesCSV(days: days))
                csvLink("Sessions", "luckring-sessions.csv",
                        CSVExport.workoutsCSV(days: days))
            }
        }
    }

    /// The file is written up front because `ShareLink` needs a `Transferable`, and
    /// a URL is the one it handles without ceremony. A failed write degrades to a
    /// disabled tile rather than a button that does nothing.
    @ViewBuilder
    private func csvLink(_ title: String, _ name: String, _ contents: String) -> some View {
        if let url = CSVExport.write(contents, named: name) {
            ShareLink(item: url) { csvTile(title) }
        } else {
            csvTile(title).opacity(0.4)
        }
    }

    private func csvTile(_ title: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: "tablecells")
                .scaledFont(14, weight: .medium)
            Text(title)
                .scaledFont(11, weight: .medium)
        }
        .foregroundStyle(Palette.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Palette.surfaceHi, in: RoundedRectangle(cornerRadius: 10,
                                                           style: .continuous))
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Apple Health")
                .scaledFont(13, weight: .medium)
                .foregroundStyle(Palette.textPrimary)
            Text(model.status.detail)
                .scaledFont(11)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if model.status.wantsAuthorization {
                    Button {
                        Task { await model.connect() }
                        Haptics.tap()
                    } label: {
                        label("Connect", "heart.text.square")
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isWorking)
                } else if model.isAvailable && !model.isWorking {
                    Button {
                        Task { await model.export(days: days) }
                        Haptics.tap()
                    } label: {
                        label("Export \(days.count) days", "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                    .disabled(days.isEmpty)
                }
                if model.isWorking {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private func label(_ title: String, _ symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .scaledFont(12, weight: .semibold)
            Text(title)
                .scaledFont(12, weight: .semibold)
        }
        .foregroundStyle(Palette.bg)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Palette.sleep, in: Capsule())
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                confirmClear = true
                Haptics.tap()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .scaledFont(12, weight: .semibold)
                    Text("Delete local history")
                        .scaledFont(12, weight: .semibold)
                }
                .foregroundStyle(Palette.bad)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .overlay(Capsule().strokeBorder(Palette.bad.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)

            if case .demo = store.connection {
                Text("Demo mode will regenerate sample days straight after, since that is what the UI is being reviewed with.")
                    .scaledFont(11)
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}