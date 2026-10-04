import XCTest
@testable import LuckRingDemo

/// The export is the one part of the app someone can take away and paste into a
/// spreadsheet, so it has to be right in the ways that silently corrupt data:
/// quoting, column alignment, and not inventing rows for days with no readings.
final class CSVExportTests: XCTestCase {

    private var calendar: Calendar { Calendar.current }

    private func day(_ offset: Int) -> DailySnapshot {
        DailySnapshot(date: calendar.startOfDay(for: Date())
            .addingTimeInterval(Double(offset) * 86400))
    }

    // MARK: - Shape

    func testDailyCSVHasOneHeaderRowAndOneRowPerDay() {
        let csv = CSVExport.dailyCSV(days: [day(0), day(-1), day(-2)])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        XCTAssertEqual(lines.count, 4, "header plus three days")
        XCTAssertEqual(lines[0], CSVExport.columns.map(\.header).joined(separator: ","))
    }

    /// Every row must have the same field count as the header. One missing comma
    /// shifts an entire day sideways, which is exactly the kind of corruption that
    /// is invisible until someone charts it.
    func testEveryRowHasTheSameFieldCountAsTheHeader() {
        var d0 = day(0)
        d0.activity = ActivitySummary(date: d0.date, steps: 8123, distanceMetres: 6100,
                                      activeSeconds: 4200, calories: 540)
        d0.heartRate = [HeartRateSample(time: d0.date.addingTimeInterval(4 * 3600), bpm: 52)]
        d0.hrv = [HRVSample(time: d0.date.addingTimeInterval(4 * 3600), ms: 61)]
        d0.oxygen = [OxygenSample(time: d0.date.addingTimeInterval(9 * 3600), spo2: 97)]
        d0.temperature = [TemperatureSample(time: d0.date.addingTimeInterval(3 * 3600),
                                            celsius: 34.2)]
        d0.bloodPressure = [BloodPressureSample(time: d0.date.addingTimeInterval(8 * 3600),
                                                systolic: 118, diastolic: 76)]

        let header = CSVExport.columns.count
        let lines = CSVExport.dailyCSV(days: [d0, day(-1)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        for (index, line) in lines.enumerated() where !line.isEmpty {
            XCTAssertEqual(CSVExport.countFields(line), header,
                           "row \(index) has \(CSVExport.countFields(line)) fields, expected \(header)")
        }
    }

    func testRowsAreSortedOldestFirst() {
        let csv = CSVExport.dailyCSV(days: [day(0), day(-2), day(-1)])
        let dates = csv.split(separator: "\n")[1...].map(String.init)
        XCTAssertEqual(dates, dates.sorted(), "rows must be chronological")
    }

    // MARK: - Empty values

    /// A day with no readings gets empty cells, never zeros. A zero step count is a
    /// claim about the world; an empty cell is an absence of data.
    func testMissingReadingsBecomeEmptyCellsNotZeros() {
        let csv = CSVExport.dailyCSV(days: [day(0)])
        let fields = csv.split(separator: "\n")[1]
            .split(separator: ",", omittingEmptySubsequences: false)
            .map(String.init)
        XCTAssertFalse(fields.isEmpty)
        // steps, resting_hr, spo2 and friends must all be blank.
        let headers = CSVExport.columns.map(\.header)
        for header in ["steps", "resting_hr", "spo2", "sleep_seconds", "skin_temp_c"] {
            let index = headers.firstIndex(of: header)
            XCTAssertNotNil(index, "\(header) should be a column")
            XCTAssertEqual(fields[index!], "", "\(header) should be empty, not zero")
        }
    }

    // MARK: - Quoting

    func testValuesContainingCommasAreQuoted() {
        XCTAssertEqual(CSVExport.escape("a,b"), "\"a,b\"")
    }

    func testEmbeddedQuotesAreDoubled() {
        XCTAssertEqual(CSVExport.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
    }

    func testPlainValuesAreNotQuoted() {
        XCTAssertEqual(CSVExport.escape("8123"), "8123")
        XCTAssertEqual(CSVExport.escape(""), "")
    }

    func testCountFieldsRespectsQuotedCommas() {
        XCTAssertEqual(CSVExport.countFields("a,b,c"), 3)
        XCTAssertEqual(CSVExport.countFields("a,\"b,c\",d"), 3)
        XCTAssertEqual(CSVExport.countFields("\"a\"\"\",x\""), 2)
    }

    // MARK: - Long form

    func testSamplesCSVHasOneRowPerReading() {
        var d = day(0)
        d.heartRate = [
            HeartRateSample(time: d.date.addingTimeInterval(4 * 3600), bpm: 52),
            HeartRateSample(time: d.date.addingTimeInterval(12 * 3600), bpm: 71),
        ]
        d.hrv = [HRVSample(time: d.date.addingTimeInterval(4 * 3600), ms: 61)]
        d.oxygen = [OxygenSample(time: d.date.addingTimeInterval(9 * 3600), spo2: 97)]
        d.temperature = [TemperatureSample(time: d.date.addingTimeInterval(3 * 3600),
                                            celsius: 34.2)]
        d.bloodPressure = [BloodPressureSample(time: d.date.addingTimeInterval(8 * 3600),
                                                systolic: 118, diastolic: 76)]

        let lines = CSVExport.samplesCSV(days: [d])
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        XCTAssertEqual(lines.count, 7, "header plus six readings")
        XCTAssertEqual(lines[0], "date,time,metric,value,unit")
        XCTAssertTrue(lines.contains { $0.contains("heart_rate") })
        XCTAssertTrue(lines.contains { $0.contains("hrv") })
        XCTAssertTrue(lines.contains { $0.contains("spo2") })
    }

    /// Blood pressure needs two fields but the header names one `value`, so the
    /// systolic reading sits in `value` and the diastolic has to be findable.
    func testBloodPressureRowCarriesBothNumbers() {
        var d = day(0)
        d.bloodPressure = [BloodPressureSample(time: d.date.addingTimeInterval(8 * 3600),
                                                systolic: 118, diastolic: 76)]
        let row = CSVExport.samplesCSV(days: [d])
            .split(separator: "\n")
            .map(String.init)
            .first { $0.contains("blood_pressure") }
        XCTAssertNotNil(row)
        XCTAssertTrue(row!.contains("118"), "systolic missing")
        XCTAssertTrue(row!.contains("76"), "diastolic missing")
    }

    func testSamplesCSVIsChronologicalWithinADay() {
        var d = day(0)
        d.heartRate = [
            HeartRateSample(time: d.date.addingTimeInterval(20 * 3600), bpm: 70),
            HeartRateSample(time: d.date.addingTimeInterval(4 * 3600), bpm: 52),
            HeartRateSample(time: d.date.addingTimeInterval(12 * 3600), bpm: 61),
        ]
        let times = CSVExport.samplesCSV(days: [d])
            .split(separator: "\n")
            .dropFirst()
            .map { String($0.split(separator: ",")[1]) }
        XCTAssertEqual(times, times.sorted(), "readings must be in time order")
    }

    // MARK: - Workouts

    func testWorkoutsCSVHeaderMatchesItsRows() {
        let csv = CSVExport.workoutsCSV(days: [day(0)])
        XCTAssertEqual(csv.split(separator: "\n").first,
                       "date,start,kind,duration_seconds,distance_m,calories,"
                       + "avg_hr,peak_hr,source")
    }

    func testEmptyWorkoutListProducesOnlyAHeader() {
        let csv = CSVExport.workoutsCSV(days: [day(0), day(-1)])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 1)
    }

    // MARK: - Writing

    func testWriteProducesAReadableFile() throws {
        let csv = CSVExport.dailyCSV(days: [day(0)])
        let url = try XCTUnwrap(CSVExport.write(csv, named: "luckring-test.csv"))
        defer { try? FileManager.default.removeItem(at: url) }

        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(text, csv)
        XCTAssertEqual(url.pathExtension, "csv")
    }
}