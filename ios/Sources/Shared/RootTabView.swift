import SwiftUI

struct RootTabView: View {
    @StateObject private var store: HealthStore
    /// `-initialTab vitals|health|today` lets a screenshot or UI test open
    /// straight to a tab without tapping.
    @State private var tab: Tab = Tab.fromLaunchArguments()
    @State private var showActions = false
    @State private var showDevice = false

    enum Tab: Hashable { case today, vitals, health }

    init(store: HealthStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.bg.ignoresSafeArea()

            // A custom tab bar means a custom container: switching tabs must move
            // each destination into its own NavigationStack so per-tab titles,
            // back buttons and sheets behave.
            switch tab {
            case .today:
                TodayView(store: store, showDevice: $showDevice)
            case .vitals:
                NavigationStack { VitalsView(store: store) }
            case .health:
                NavigationStack { HealthView(store: store) }
            }

            FloatingTabBar(selection: $tab) { showActions = true }
                .padding(.bottom, 2)
        }
        .animation(.easeOut(duration: 0.2), value: tab)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showActions) {
            QuickActionsSheet(showDevice: $showDevice, showActions: $showActions)
        }
        .onAppear { store.start() }
    }
}

/// Bottom-right "+" menu. Mirrors the reference design's action affordance and
/// gives the ring controls and the log a home outside the metric tabs.
struct QuickActionsSheet: View {
    @Binding var showDevice: Bool
    @Binding var showActions: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            // A hand-rolled list rather than SwiftUI `List`: `Section` resolves
            // ambiguously against its LocalizedStringKey overload here, and the
            // reference design wants dark rows anyway.
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    group("Ring", [
                        .init(symbol: "circle.dotted.circle", label: "Pair and manage ring") { showDevice = true },
                        .init(symbol: "waveform.path.ecg", label: "Start a measurement"),
                        .init(symbol: "figure.run", label: "Log an activity"),
                    ])
                    group("Data", [
                        .init(symbol: "square.and.arrow.up", label: "Export readings"),
                        .init(symbol: "terminal", label: "Open packet console"),
                    ])
                }
                .padding(18)
            }
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("Quick actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private struct Row: Identifiable {
        let id = UUID()
        let symbol: String
        let label: String
        var action: () -> Void = {}

        init(symbol: String, label: String, action: @escaping () -> Void = {}) {
            self.symbol = symbol
            self.label = label
            self.action = action
        }
    }

    private func group(_ title: String, _ items: [Row]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CapsLabel(text: title)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        item.action()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Palette.sleep)
                                .frame(width: 26)
                            Text(item.label)
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Palette.textTertiary)
                        }
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Divider().overlay(Palette.stroke).padding(.leading, 38)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16,
                                                             style: .continuous))
        }
    }
}

extension RootTabView.Tab {
    static func fromLaunchArguments() -> RootTabView.Tab {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-initialTab"), i + 1 < args.count else { return .today }
        switch args[i + 1].lowercased() {
        case "vitals": return .vitals
        case "health": return .health
        default: return .today
        }
    }
}