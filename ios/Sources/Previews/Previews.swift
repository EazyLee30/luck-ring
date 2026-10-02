import SwiftUI

/// Previews run against generated data, so the UI can be iterated in Xcode
/// without a paired ring.
#Preview("Today") {
    PreviewHost { TodayView(store: $0) }
}

#Preview("Trends") {
    PreviewHost { TrendsView(store: $0) }
}

#Preview("Ring") {
    PreviewHost { RingView(store: $0) }
}

#Preview("Tabs") {
    PreviewHost { RootTabView(store: $0) }
}

private struct PreviewHost<Content: View>: View {
    @ViewBuilder var content: (HealthStore) -> Content
    @StateObject private var store = HealthStore(bridge: DemoRingBridge())

    var body: some View {
        let s = store
        let _ = s.loadDemoData()
        return content(s)
    }
}