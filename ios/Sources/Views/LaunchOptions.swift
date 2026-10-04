import SwiftUI

/// Read-only view options driven by launch arguments, so a screenshot or UI test
/// can land on a particular screen without tapping. Not a shipping feature.
enum LaunchOption {
    static func value(_ flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

struct TodayAnchor: ViewModifier {
    enum Anchor { case top, middle, bottom }

    let anchor: Anchor

    func body(content: Content) -> some View {
        switch anchor {
        case .top: content.defaultScrollAnchor(.top)
        case .middle: content
        case .bottom: content.defaultScrollAnchor(.bottom)
        }
    }
}

extension TodayView {
    static var launchAnchor: TodayAnchor.Anchor {
        switch LaunchOption.value("-todayAnchor") {
        case "bottom": return .bottom
        case "middle": return .middle
        default: return .top
        }
    }
}
extension RootTabView {
    /// `-openDetail sleep|activity` pushes a detail screen on launch, so a
    /// screenshot or UI test can land on one without tapping.
    static var launchRoute: DetailRoute? {
        guard let value = LaunchOption.value("-openDetail") else { return nil }
        let today = Date()
        switch value.lowercased() {
        case "sleep": return .sleep(today)
        case "activity": return .activity(today)
        case "readiness": return .readiness(today)
        case "vitals": return .vitals(today)
        case "period": return .period
        default: return nil
        }
    }
}

extension RootTabView {
    /// `-openSheet device|share` presents one of the modal sheets on launch, so a
    /// screenshot can reach a screen that otherwise needs a tap.
    static var launchSheet: String? {
        LaunchOption.value("-openSheet")?.lowercased()
    }
}
