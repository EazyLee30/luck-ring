import XCTest
import SwiftUI
import UIKit
@testable import LuckRingDemo

/// Dynamic Type support is a policy decision, so the policy is tested rather than
/// only observable by changing a system setting. `TypeScale.factor(forBodySize:)`
/// is the single place that decision lives.
final class TypeScaleTests: XCTestCase {

    // MARK: - Scale factor

    func testDefaultBodySizeIsUnscaled() {
        XCTAssertEqual(TypeScale.factor(forBodySize: TypeScale.baseBodySize), 1,
                       accuracy: 0.0001)
    }

    func testLargerTextScalesUp() {
        let factor = TypeScale.factor(forBodySize: 20)
        XCTAssertGreaterThan(factor, 1)
        XCTAssertEqual(factor, 1.25, accuracy: 0.0001)
    }

    /// Shrinking text must not shrink the layout: the cards and gauges are fixed
    /// geometry, and a smaller-than-designed dashboard breaks them the same way an
    /// oversized one does.
    func testSmallerTextNeverShrinksBelowOne() {
        for size in [8.0, 12.0, 14.0, 15.0] {
            XCTAssertEqual(TypeScale.factor(forBodySize: size), 1,
                           "size \(size) must not scale the layout down")
        }
    }

    /// The ceiling is what stops the banded calendar cells and three-across stat
    /// rows from clipping, so it is asserted rather than assumed.
    func testScaleIsCappedAtTheDocumentedCeiling() {
        XCTAssertEqual(TypeScale.ceiling, 1.35, accuracy: 0.0001)
        XCTAssertEqual(TypeScale.factor(forBodySize: 30), TypeScale.ceiling, accuracy: 0.0001)
        XCTAssertEqual(TypeScale.factor(forBodySize: 1000), TypeScale.ceiling, accuracy: 0.0001)
    }

    func testScaleIsMonotonic() {
        var previous = 0.0
        for size in stride(from: 12.0, through: 40.0, by: 1.0) {
            let factor = TypeScale.factor(forBodySize: size)
            XCTAssertGreaterThanOrEqual(factor, previous,
                                        "scale dipped at body size \(size)")
            previous = factor
        }
    }

    func testDegenerateInputIsSafe() {
        XCTAssertEqual(TypeScale.factor(forBodySize: 0), 1)
        XCTAssertEqual(TypeScale.factor(forBodySize: -5), 1)
    }

    /// The rendered range has to agree with the ceiling, or a user at a larger size
    /// gets a partially-scaled layout: the clamp would hold the environment value
    /// at the ceiling while the type kept growing.
    ///
    /// Driven through real `UIFont`s rather than a hand-written table, because what
    /// matters is the point size the system actually hands back at each category.
    func testSupportedRangeEndsAtTheLastHonouredSize() {
        XCTAssertEqual(TypeScale.supportedRange.upperBound, .accessibility1)
        let honoured: [UIContentSizeCategory] = [
            .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge,
            .extraExtraExtraLarge, .accessibilityMedium, .accessibilityLarge,
            .accessibilityExtraLarge,
        ]
        for category in honoured {
            let body = UIFont.preferredFont(
                forTextStyle: .body,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: category))
            XCTAssertLessThanOrEqual(TypeScale.factor(forBodySize: body.pointSize),
                                     TypeScale.ceiling + 0.0001,
                                     "\(category.rawValue) exceeded the ceiling")
        }
    }

    /// A category above the supported range must be clamped by the environment
    /// rather than silently ignored.
    func testLargerCategoriesStillResolveThroughTheSameFactor() {
        for category in [UIContentSizeCategory.accessibilityExtraExtraLarge,
                         .accessibilityExtraExtraExtraLarge] {
            let body = UIFont.preferredFont(
                forTextStyle: .body,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: category))
            XCTAssertEqual(TypeScale.factor(forBodySize: body.pointSize),
                           TypeScale.ceiling, accuracy: 0.0001,
                           "\(category.rawValue) should clamp to the ceiling")
        }
    }
}

/// The spoken descriptions are the only non-visual version of the charts, so their
/// wording is tested too.
final class ChartDescriptionTests: XCTestCase {

    func testRisingSeriesIsDescribedAsUp() {
        let text = ChartDescription.trend([70, 74, 79], unit: "points", name: "Sleep")
        XCTAssertTrue(text.contains("up"), text)
        XCTAssertTrue(text.contains("3 days"), text)
        XCTAssertTrue(text.contains("Average 74"), text)
    }

    func testFallingSeriesIsDescribedAsDown() {
        let text = ChartDescription.trend([80, 74, 66], unit: "points", name: "Sleep")
        XCTAssertTrue(text.contains("down"), text)
    }

    /// A two-point change is noise, not a direction.
    func testFlatSeriesIsNotCalledUpOrDown() {
        let text = ChartDescription.trend([70, 71, 70], unit: "points", name: "Sleep")
        XCTAssertTrue(text.contains("steady"), text)
    }

    func testExtremesAreAlwaysStated() {
        let text = ChartDescription.trend([40, 95, 60], unit: "points", name: "Sleep")
        XCTAssertTrue(text.contains("high 95"), text)
        XCTAssertTrue(text.contains("low 40"), text)
    }

    func testSinglePointIsReadWithoutDirection() {
        let text = ChartDescription.trend([88], unit: "points", name: "Sleep")
        XCTAssertTrue(text.contains("88 points"), text)
        XCTAssertFalse(text.contains("up"), text)
    }

    func testEmptySeriesSaysSoRatherThanDescribingNothing() {
        let text = ChartDescription.trend([], unit: "points", name: "Sleep")
        XCTAssertTrue(text.lowercased().contains("no data"), text)
    }

    func testGaugeIsReadAsAFractionOfAHundred() {
        XCTAssertEqual(ChartDescription.gauge(83, of: 100, name: "sleep"),
                       "sleep 83 out of 100")
    }

    func testShareIncludesDurationAndPercent() {
        let text = ChartDescription.share(4800, percent: 18, name: "Deep")
        XCTAssertTrue(text.hasPrefix("Deep 1h 20m"), text)
        XCTAssertTrue(text.hasSuffix("18 percent"), text)
    }
}
