import SwiftUI

/// Storage, CSV export, Apple Health and deletion. Presented from the quick-actions
/// menu rather than living inside the ring sheet, because managing your data is a
/// different job from managing your ring.
struct DataSheet: View {
    @ObservedObject var store: HealthStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    DataCard(store: store)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("Your data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
