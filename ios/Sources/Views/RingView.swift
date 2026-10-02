import SwiftUI

/// Pairing, battery, streaming toggle, on-demand measurements, goals, and the
/// live packet console. This is where the ring is actually driven.
struct RingView: View {
    @ObservedObject var store: HealthStore
    @State private var found: [DiscoveredRing] = []
    @State private var selected: DiscoveredRing?
    @State private var streaming = false
    @State private var lines: [String] = []
    @State private var showConsole = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statusCard
                if case .demo = store.connection { demoBanner }
                discoveryCard
                streamingCard
                measurementCard
                goalsCard
                consoleCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Ring")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.onPeripherals = { found = $0 }
            store.onLog = { line in
                lines.append(line)
                if lines.count > 300 { lines.removeFirst(lines.count - 300) }
            }
        }
    }

    // MARK: - Status

    private var statusCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Status", icon: "antenna.radiowaves.left.and.right")
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.ringName)
                            .font(.metric(19))
                            .foregroundStyle(Palette.textPrimary)
                        Text(store.connection.label)
                            .font(.label(13))
                            .foregroundStyle(store.connection.isLive ? Palette.good : Palette.textSecondary)
                    }
                    Spacer()
                    if let b = store.batteryPercent {
                        VStack(spacing: 4) {
                            Text("\(b)%")
                                .font(.score(22))
                                .foregroundStyle(batteryTint(b))
                            Text("battery")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Palette.textTertiary)
                        }
                    }
                }
                if let b = store.batteryPercent {
                    Bar(progress: Double(b) / 100, tint: batteryTint(b), height: 6)
                }
                if let fw = store.firmware {
                    Text("Firmware \(fw)")
                        .font(.label(11))
                        .foregroundStyle(Palette.textTertiary)
                }
                if let sync = store.lastSync {
                    Text("Last sync \(sync.formatted(date: .omitted, time: .shortened))")
                        .font(.label(11))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
    }

    private var demoBanner: some View {
        Card(tint: Palette.temp) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Demo data", icon: "wand.and.stars", tint: Palette.temp)
                Text("Showing generated history. This build defaults to demo mode because the SDK ships arm64 device-only — no simulator slice. Pair a ring below and the same UI fills with real data.")
                    .font(.label(12))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Discovery

    private var discoveryCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Discover", icon: "dot.radiowaves.left.and.right")
                HStack(spacing: 10) {
                    button("Scan") { store.refresh() }
                    button("Connect") {
                        if let s = selected { store.setConnection(.connecting) }
                    }
                    .disabled(selected == nil)
                    button("Disconnect", tone: .danger) { store.setConnection(.disconnected("Disconnected")) }
                }
                if found.isEmpty {
                    Text("No rings yet. Tap Scan and keep the ring within a metre, awake and out of the charger.")
                        .font(.label(12))
                        .foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(found) { ring in
                        Button {
                            selected = ring
                            store.setConnection(.connecting)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ring.name).font(.metric(15)).foregroundStyle(Palette.textPrimary)
                                    Text(ring.subtitle)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Palette.textTertiary)
                                }
                                Spacer()
                                if selected?.id == ring.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.good)
                                }
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Streaming

    private var streamingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Sensor stream", icon: "waveform.path")
                Text("The ring holds steps, sleep and heart-rate history on-device but has no 'fetch history' command — it only uploads while this switch is on. This is the switch.")
                    .font(.label(12))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    button(streaming ? "Streaming…" : "Start streaming", tone: streaming ? .good : .primary) {
                        streaming = true
                    }
                    button("Stop", tone: .danger) { streaming = false }
                        .disabled(!streaming)
                }
                if streaming {
                    HStack(spacing: 6) {
                        Circle().fill(Palette.good).frame(width: 7, height: 7)
                        Text("Uploading — keep the app in the foreground")
                            .font(.label(12))
                            .foregroundStyle(Palette.good)
                    }
                }
            }
        }
    }

    // MARK: - Measurements

    private var measurementCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Measure now", icon: "waveform.path.ecg")
                ForEach(VitalKind.allCases) { kind in
                    HStack {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 14))
                            .foregroundStyle(kind.tint)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(kind.title).font(.metric(14)).foregroundStyle(Palette.textPrimary)
                            Text(kind.sdkCommand)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Palette.textTertiary)
                        }
                        Spacer()
                        Button("Take") {
                            store.onLog?("→ measure \(kind.title) via \(kind.sdkCommand)")
                        }
                        .font(.label(12))
                        .buttonStyle(.bordered)
                        .tint(kind.tint)
                    }
                }
                if let day = store.selectedDay {
                    Divider().overlay(Palette.stroke)
                    if let bp = day.latestBloodPressure {
                        StatRow(title: "Latest BP", value: "\(bp.systolic)/\(bp.diastolic)",
                                unit: "mmHg", tint: Palette.pressure)
                    }
                    StatRow(title: "Latest SpO2", value: day.averageOxygen.map { "\($0)" } ?? "—",
                            unit: "%", tint: Palette.oxygen)
                }
            }
        }
    }

    // MARK: - Goals

    private var goalsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Goals", icon: "target")
                stepper("Step target", value: $store.goals.stepTarget, range: 1000...30000, step: 500, unit: "")
                stepper("Sleep target", value: $store.goals.sleepTargetMinutes, range: 240...600, step: 15, unit: "min")
                stepper("Active minutes", value: $store.goals.activeMinutesTarget, range: 10...180, step: 5, unit: "min")
            }
        }
    }

    // MARK: - Console

    private var consoleCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(title: "Packet console", icon: "terminal")
                    Spacer()
                    Button(showConsole ? "Hide" : "Show") { showConsole.toggle() }
                        .font(.label(12))
                        .buttonStyle(.bordered)
                }
                if showConsole {
                    ScrollView {
                        Text(lines.suffix(120).joined(separator: "\n"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Palette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 180)
                    .padding(8)
                    .background(Palette.bg, in: RoundedRectangle(cornerRadius: 10))
                }
                Text("Raw BLE frames are also written to Documents/captures as JSONL — pull them from the Files app.")
                    .font(.label(11))
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Small builders

    private enum Tone { case primary, good, danger }

    private func button(_ title: String, tone: Tone = .primary, action: @escaping () -> Void) -> some View {
        Button(title) { action() }
            .font(.label(13))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(bg(tone), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(fg(tone))
    }

    private func bg(_ tone: Tone) -> Color {
        switch tone {
        case .primary: return Palette.surfaceHi
        case .good: return Palette.good.opacity(0.18)
        case .danger: return Palette.bad.opacity(0.15)
        }
    }

    private func fg(_ tone: Tone) -> Color {
        switch tone {
        case .primary: return Palette.textPrimary
        case .good: return Palette.good
        case .danger: return Palette.bad
        }
    }

    private func stepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>,
                         step: Int, unit: String) -> some View {
        HStack {
            Text(label).font(.label(13)).foregroundStyle(Palette.textSecondary)
            Spacer()
            Text(unit.isEmpty ? "\(value.wrappedValue)" : "\(value.wrappedValue) \(unit)")
                .font(.metric(15))
                .foregroundStyle(Palette.textPrimary)
            Stepper(label, value: value, in: range, step: step)
                .labelsHidden()
        }
    }

    private func batteryTint(_ level: Int) -> Color {
        level > 40 ? Palette.good : level > 15 ? Palette.warn : Palette.bad
    }
}