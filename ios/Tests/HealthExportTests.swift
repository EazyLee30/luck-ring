import XCTest
@testable import LuckRingDemo

/// The export status is what the user reads to decide whether their data left the
/// phone, so the wording and the button logic matter as much as the code path.
final class HealthExportTests: XCTestCase {

    // MARK: - Status wording

    func testConnectIsOfferedUntilWritingIsPermitted() {
        // Once authorised the primary action becomes "export", so the connect
        // button must go away rather than sit above it.
        XCTAssertTrue(HealthExportStatus.notDetermined.wantsAuthorization)
        XCTAssertFalse(HealthExportStatus.ready.wantsAuthorization)
        XCTAssertFalse(HealthExportStatus.wrote(samples: 5).wantsAuthorization)
        XCTAssertFalse(HealthExportStatus.unsupported("x").wantsAuthorization)
    }

    func testRefusedOffersToReconnectRatherThanHiding() {
        // A refusal is usually fixable in Settings, so the button comes back.
        XCTAssertTrue(HealthExportStatus.refused.wantsAuthorization)
        XCTAssertTrue(HealthExportStatus.refused.detail.contains("Settings"))
    }

    func testZeroWrittenIsExplainedRatherThanReportedAsSuccess() {
        let status = HealthExportStatus.wrote(samples: 0)
        XCTAssertEqual(status.label, "0 written")
        XCTAssertTrue(status.detail.contains("declined"),
                      "a zero write is ambiguous and the copy has to say why")
    }

    func testNonZeroWriteWarnsThatRepeatingAddsASecondSet() {
        // Re-exporting does not replace what is already in Health, and saying so
        // is the difference between an honest export and a confusing one.
        XCTAssertTrue(HealthExportStatus.wrote(samples: 120).detail
            .contains("second set"))
    }

    func testUnsupportedCarriesItsReason() {
        XCTAssertEqual(HealthExportStatus.unsupported("no framework").label, "Unavailable")
        XCTAssertEqual(HealthExportStatus.unsupported("no framework").detail,
                       "no framework")
    }

    func testLabelsAreDistinctPerState() {
        let all: [HealthExportStatus] = [
            .unsupported("x"), .notDetermined, .ready, .refused,
            .wrote(samples: 3), .failed("boom"),
        ]
        XCTAssertEqual(Set(all.map(\.label)).count, all.count,
                       "two states sharing a label would be indistinguishable in the UI")
    }

    // MARK: - Storage figures

    func testZeroBytesIsNotRenderedAsAFileSize() {
        // "Zero KB" on a storage row reads as a bug rather than as an empty store.
        XCTAssertEqual(Bytes.human(0), "Nothing stored")
    }

    func testBytesAreFormattedWithAUnit() {
        let text = Bytes.human(132_000)
        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(text.contains("KB") || text.contains("MB"), "got \(text)")
    }

    // MARK: - Registry

    func testUnsetRegistryReportsUnavailableRatherThanCrashing() async {
        // The demo target links no HealthKit, so nothing is installed and the UI
        // must say so instead of offering a dead button.
        guard HealthExportRegistry.service == nil else { return }
        let model = await MainActor.run { HealthExportViewModel() }
        await model.refresh()
        let available = await model.isAvailable
        let label = await model.status.label
        XCTAssertFalse(available)
        XCTAssertEqual(label, "Unavailable")
    }

    func testExportingWithNoServiceWritesNothing() async {
        guard HealthExportRegistry.service == nil else { return }
        let model = await MainActor.run { HealthExportViewModel() }
        let written = await model.export(days: [])
        XCTAssertEqual(written, 0)
    }
}
