import SwiftUI

struct RootTabView: View {
    @StateObject private var store: HealthStore
    /// `-initialTab vitals|health|today` lets a screenshot or UI test open
    /// straight to a tab without tapping.
    @State private var tab: Tab = Tab.fromLaunchArguments()

    enum Tab: Hashable { case today, vitals, health }

    init(store: HealthStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        // Each tab carries its own NavigationStack. Wrapping the TabView in a
        // single stack leaves navigationTitle ambiguous, so per-tab titles never
        // render.
        TabView(selection: $tab) {
            NavigationStack {
                TodayView(store: store)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Today", systemImage: "circle.grid.2x2.fill") }
            .tag(Tab.today)

            NavigationStack {
                VitalsView(store: store)
            }
            .tabItem { Label("Vitals", systemImage: "list.bullet.rectangle.portrait.fill") }
            .tag(Tab.vitals)

            NavigationStack {
                HealthView(store: store)
            }
            .tabItem { Label("My Health", systemImage: "heart.text.square.fill") }
            .tag(Tab.health)
        }
        .tint(Palette.sleep)
        .preferredColorScheme(.dark)
        .onAppear { store.start() }
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