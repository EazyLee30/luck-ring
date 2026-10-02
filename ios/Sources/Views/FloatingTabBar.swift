import SwiftUI

/// Bottom navigation as a floating translucent pill with a separate circular
/// action button, inset from the edges rather than flush with the screen bottom.
struct FloatingTabBar: View {
    let selection: Binding<RootTabView.Tab>
    let action: () -> Void

    @Namespace private var bar

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            pill
            actionButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private var pill: some View {
        HStack(spacing: 0) {
            item(.today, "Today", "sun.max.fill")
            item(.vitals, "Vitals", "waveform.path.ecg")
            item(.health, "My Health", "heart.text.square.fill")
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.stroke.opacity(0.9), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
    }

    private func item(_ tab: RootTabView.Tab, _ title: String, _ symbol: String) -> some View {
        let isSelected = selection.wrappedValue == tab
        return Button {
            withAnimation(.easeOut(duration: 0.22)) { selection.wrappedValue = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Palette.surfaceHi)
                        .matchedGeometryEffect(id: "tab", in: bar)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var actionButton: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.bg)
                .frame(width: 46, height: 46)
                .background(Palette.textPrimary, in: Circle())
                .shadow(color: .black.opacity(0.4), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick actions")
    }
}