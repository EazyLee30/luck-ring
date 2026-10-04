import SwiftUI
import UIKit

// MARK: - Type scale

/// Multiplier applied to every fixed-size font in the app.
///
/// The design system uses precise point sizes because the typography is part of the
/// product — but `.font(.system(size:))` does **not** respond to Dynamic Type, so
/// without this the app would silently ignore the user's text size setting. A
/// single multiplier is injected at the root and every font reads it, which keeps
/// the intended proportions instead of mixing scaled and unscaled text.
enum TypeScale {

    /// The unscaled body size the app's point sizes were designed against.
    static let baseBodySize: CGFloat = 16

    /// Upper bound on the multiplier.
    ///
    /// The layout is a fixed-geometry dashboard: gauges, three-across stat rows and
    /// banded calendar cells. Past roughly 1.35× the cards clip and the calendar
    /// stops fitting, so the app honours larger text sizes up to a point and stops
    /// there rather than presenting something broken. Capping is a deliberate
    /// layout decision, not an oversight — `DynamicTypeSize.accessibility1` is the
    /// last size honoured.
    static let ceiling: CGFloat = 1.35

    /// Multiplier for a given Dynamic Type body size. Pure, so the policy is unit
    /// tested rather than only observable by changing a system setting.
    ///
    /// Never returns less than 1: a user who has turned text *down* still gets the
    /// designed layout rather than a shrunken one, which would break the fixed
    /// geometry the same way oversizing does.
    static func factor(forBodySize size: CGFloat) -> CGFloat {
        guard size > 0 else { return 1 }
        return min(ceiling, max(1, size / baseBodySize))
    }

    /// The Dynamic Type range the app renders. Anything above `accessibility1` is
    /// clamped here as well as in the factor, so a screen reader running at a larger
    /// size gets the capped layout rather than a partially-scaled one.
    static var supportedRange: ClosedRange<DynamicTypeSize> {
        .xSmall ... .accessibility1
    }
}

private struct TypeScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var typeScale: CGFloat {
        get { self[TypeScaleKey.self] }
        set { self[TypeScaleKey.self] = newValue }
    }
}

/// Reads the user's body size and publishes the multiplier. Applied once, at the
/// root, so every font below it scales together.
struct TypeScaleProvider: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = TypeScale.baseBodySize

    func body(content: Content) -> some View {
        content
            .environment(\.typeScale, TypeScale.factor(forBodySize: bodySize))
            .dynamicTypeSize(TypeScale.supportedRange)
    }
}

extension View {
    /// Replaces `.font(.system(size: n))` with a font that still honours Dynamic
    /// Type. Weight and design are passed through unchanged.
    func scaledFont(_ size: CGFloat,
                    weight: Font.Weight = .regular,
                    design: Font.Design = .default) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight, design: design))
    }
}

private struct ScaledFontModifier: ViewModifier {
    @Environment(\.typeScale) private var scale
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: size * scale, weight: weight, design: design))
    }
}

// MARK: - Motion

/// Motion helpers that stand down when Reduce Motion is on.
///
/// `UIAccessibility` is read directly rather than through the environment because
/// most call sites are inside button actions and gestures, where a modifier's
/// environment is not in scope.
enum Motion {

    static var isReduced: Bool { UIAccessibility.isReduceMotionEnabled }

    /// `withAnimation` that becomes an immediate state change when motion is reduced.
    /// The state still updates — only the animation is dropped, which is the
    /// difference between respecting the setting and breaking the interaction.
    static func with(_ animation: Animation = .easeOut(duration: 0.25),
                     _ body: () -> Void) {
        if isReduced {
            body()
        } else {
            withAnimation(animation, body)
        }
    }
}

/// Drops implicit `withAnimation` and `.animation(value:)` transitions — including
/// every gauge, bar and chart animation — while leaving explicit state changes
/// intact. Applied at the root alongside `TypeScaleProvider`.
struct ReduceMotionRespected: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduce

    func body(content: Content) -> some View {
        content.transaction { transaction in
            if reduce { transaction.animation = nil }
        }
    }
}

extension View {
    /// Applies the root accessibility environment: type scaling and motion policy.
    func accessibilityEnvironment() -> some View {
        modifier(TypeScaleProvider())
            .modifier(ReduceMotionRespected())
    }
}

// MARK: - Control helpers

extension View {
    /// Marks a purely decorative element so VoiceOver skips it. Use on glows,
    /// dividers, backgrounds and any shape that carries no information.
    func decorative() -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityHidden(true)
    }

    /// Presents a control as a single VoiceOver stop with the supplied description.
    func accessibilityControl(label: String, value: String? = nil,
                              isSelected: Bool? = nil,
                              hint: String? = nil) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value ?? "")
            .modifier(SelectedTrait(isSelected: isSelected))
            .modifier(HintTrait(hint: hint))
    }

    /// Marks a control as adjustable and forwards swipe gestures to `onChange`,
    /// which is how VoiceOver drives a segmented control.
    func accessibilityAdjustable(label: String, value: String,
                                 onIncrement: @escaping () -> Void,
                                 onDecrement: @escaping () -> Void) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onIncrement()
                case .decrement: onDecrement()
                @unknown default: break
                }
            }
    }
}

private struct SelectedTrait: ViewModifier {
    let isSelected: Bool?
    func body(content: Content) -> some View {
        if let isSelected {
            content.accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        } else {
            content.accessibilityAddTraits(.isButton)
        }
    }
}

private struct HintTrait: ViewModifier {
    let hint: String?
    func body(content: Content) -> some View {
        if let hint, !hint.isEmpty {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

// MARK: - Chart descriptions

/// Turns a series into something a screen reader can say out loud.
///
/// A sparkline or trend chart is pure geometry — VoiceOver would otherwise read
/// nothing, or worse, a meaningless string of numbers. Describing the shape in
/// words is the only version of a chart that is not visual.
enum ChartDescription {

    /// One sentence covering direction, size and extremes.
    static func trend(_ values: [Int], unit: String, name: String) -> String {
        guard values.count > 1 else {
            guard let only = values.first else { return "\(name): no data" }
            return "\(name): \(only) \(unit)"
        }
        let first = values.first!
        let last = values.last!
        let high = values.max()!
        let low = values.min()!

        let direction: String
        switch last - first {
        case 2...: direction = "up"
        case ...(-2): direction = "down"
        default: direction = "steady"
        }
        let average = values.reduce(0, +) / values.count
        return "\(name) over \(values.count) days, \(direction) from \(first) "
            + "to \(last) \(unit). Average \(average), high \(high), low \(low)."
    }

    /// For a single-value gauge inside a row of others.
    static func gauge(_ value: Int, of total: Int, name: String) -> String {
        "\(name) \(value) out of \(total)"
    }

    /// Percentage composition, e.g. "Deep 1h 20m, 18%".
    static func share(_ value: TimeInterval, percent: Int, name: String) -> String {
        "\(name) \(Fmt.duration(value)), \(percent) percent"
    }
}
