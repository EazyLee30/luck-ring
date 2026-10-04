import SwiftUI

/// Interaction layer: the gestures that make the app feel like an app rather
/// than a stack of static cards.
///
///  * tap a card header to expand or collapse its detail
///  * drag shortcuts to reorder them, persisted for the session
///  * swipe left/right to move between days
///  * haptic feedback on every state change that matters
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

// MARK: - Expandable card

/// A card whose header is always visible and whose body unfolds on tap. Collapsing
/// is what keeps a long scroll manageable.
struct ExpandableCard<Content: View>: View {
    let title: String
    var symbol: String?
    var status: String?
    var tint: Color
    var initiallyExpanded: Bool = false
    @ViewBuilder var content: Content

    @State private var expanded: Bool = false
    @State private var rendered = false

    var body: some View {
        GlowCard(tint: tint) {
            VStack(alignment: .leading, spacing: expanded ? 14 : 0) {
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        expanded.toggle()
                    }
                    Haptics.tap()
                } label: {
                    HStack(spacing: 10) {
                        if let symbol {
                            IconBadge(symbol: symbol, tint: tint, size: 30)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title)
                                .scaledFont(15, weight: .medium)
                                .foregroundStyle(Palette.textPrimary)
                            if let status {
                                CapsLabel(text: status, tint: tint, size: 9)
                            }
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .scaledFont(11, weight: .bold)
                            .foregroundStyle(Palette.textTertiary)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    content
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    // Cheap placeholder keeps the collapsed card the right height
                    // without building the detail view at all.
                    Color.clear.frame(height: 0)
                }
            }
            .padding(16)
        }
        .onAppear {
            expanded = initiallyExpanded
            rendered = true
        }
    }
}

// MARK: - Reorderable shortcut row

/// Horizontal shortcut row that supports drag-to-reorder, closing a gap the
/// README had listed as missing. Order is held by the parent so it survives
/// re-renders.
struct ReorderableShortcuts: View {
    let items: [Shortcut]
    @Binding var order: [String]
    var diameter: CGFloat = 68

    @State private var dragging: String?
    @State private var dragOffset: CGFloat = 0

    private var ordered: [Shortcut] {
        order.compactMap { id in items.first { $0.id == id } }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ordered) { item in
                    ShortcutBadge(title: item.title, value: item.value,
                                  symbol: item.symbol, tint: item.tint,
                                  diameter: diameter)
                        .offset(x: dragging == item.id ? dragOffset : 0)
                        .scaleEffect(dragging == item.id ? 1.12 : 1)
                        .zIndex(dragging == item.id ? 1 : 0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.8),
                                   value: dragging)
                        .gesture(dragGesture(for: item))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
        }
    }

    /// Horizontal drag reorders. Commits on release and fires a haptic so the
    /// drop is felt rather than inferred from the new position.
    private func dragGesture(for item: Shortcut) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if dragging != item.id {
                    dragging = item.id
                    Haptics.select()
                }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                defer {
                    dragging = nil
                    dragOffset = 0
                }
                let step = diameter + 26
                let shift = Int((value.translation.width / step).rounded())
                guard shift != 0 else { return }

                var next = order
                if let from = next.firstIndex(of: item.id) {
                    let to = min(max(0, from + shift), next.count - 1)
                    next.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                }
                order = next
                Haptics.tap()
            }
    }
}

// MARK: - Day paging

/// Wraps content so a horizontal swipe moves one day, the way a calendar view
/// should behave. Conflicts with the shortcut row, which is itself horizontal, so
/// the row opts out via `ScrollView` and this only sees drags on the body.
struct DayPager<Content: View>: View {
    @ObservedObject var store: HealthStore
    @ViewBuilder var content: (DailySnapshot) -> Content

    @State private var dragX: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                content(store.selectedDay ?? DailySnapshot(date: Date()))
                    .offset(x: dragX)
                    .allowsHitTesting(dragX == 0)

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 28)
                            .onChanged { value in
                                // Only claim the drag once it is clearly
                                // horizontal, so vertical scrolling still works.
                                guard abs(value.translation.width) > abs(value.translation.height) else {
                                    dragX = 0
                                    return
                                }
                                dragX = value.translation.width * 0.4
                            }
                            .onEnded { value in
                                guard abs(value.translation.width) > 60 else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dragX = 0 }
                                    return
                                }
                                page(forward: value.translation.width < 0)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dragX = 0 }
                            }
                    )
            }
            .frame(width: width, alignment: .center)
        }
        .onChange(of: dragX) { _, new in
            if new != 0 && dragX == 0 { Haptics.select() }
        }
    }

    /// Moves one day in the ordered history, oldest → newest on swipe right.
    private func page(forward: Bool) {
        let ordered = store.orderedDays
        guard !ordered.isEmpty else { return }
        let current = store.selectedDay?.date ?? ordered[0].date
        guard let index = ordered.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: current) })
        else { return }

        let target = forward ? index + 1 : index - 1
        guard ordered.indices.contains(target) else {
            Haptics.warning()
            return
        }
        store.select(day: ordered[target].date)
        Haptics.tap()
    }
}

// MARK: - Reveal

/// Fade-and-rise used when a card expands or a tab changes.
struct Reveal: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(delay)) { shown = true }
            }
    }
}

extension View {
    func reveal(delay: Double = 0) -> some View { modifier(Reveal(delay: delay)) }
}