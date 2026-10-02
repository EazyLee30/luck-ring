import SwiftUI

struct RootTabView: View {
    @StateObject private var store: HealthStore
    /// `-initialTab trends|ring` lets a screenshot or UI test open straight to a tab.
    @State private var tab: Tab = Tab.fromLaunchArguments()

    enum Tab: Hashable { case today, trends, ring }

    init(store: HealthStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        TabView(selection: $tab) {
            TodayView(store: store)
                .tabItem { Label("Today", systemImage: "circle.grid.2x2.fill") }
                .tag(Tab.today)

            TrendsView(store: store)
                .tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
                .tag(Tab.trends)

            RingView(store: store)
                .tabItem { Label("Ring", systemImage: "circle.dotted.circle") }
                .tag(Tab.ring)
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
        case "trends": return .trends
        case "ring": return .ring
        default: return .today
        }
    }
}