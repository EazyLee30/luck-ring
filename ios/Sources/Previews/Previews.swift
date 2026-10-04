import SwiftUI

/// Previews run against generated data, so the UI can be iterated in Xcode
/// without a paired ring.
#Preview("Today") {
    PreviewHost { store in NavigationStack { TodayView(store: store, showDevice: .constant(false), path: .constant([])) } }
}

#Preview("Vitals") {
    PreviewHost { store in NavigationStack { VitalsView(store: store) } }
}

#Preview("My Health") {
    PreviewHost { store in NavigationStack { HealthView(store: store) } }
}

#Preview("Tabs") {
    PreviewHost { store in RootTabView(store: store) }
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