import SwiftUI

/// Entry point to the template picker. The rendering itself lives in
/// `ShareTemplateSheet` so it can be reached from more than one place.
struct ShareEntryCard: View {
    @ObservedObject var store: HealthStore
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
            Haptics.tap()
        } label: {
            GlowCard(tint: Palette.sleep) {
                VStack(alignment: .leading, spacing: 12) {
                    CardHeaderRow(title: "Share", symbol: "square.and.arrow.up",
                                  tint: Palette.sleep)
                    Text("Day, scores-only, training, week and month cards. Export a PNG for any of them.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PillButton(title: "Choose a format", symbol: "photo", tint: Palette.sleep)
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) { ShareTemplateSheet(store: store) }
    }
}
