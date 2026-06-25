import XCTest
@testable import Scrub

/// `SessionHistory` is best-effort JSON persistence: it must round-trip a written log and must
/// degrade to `[]` (never throw) on a missing or corrupt file, so history never blocks a clean.
final class SessionHistoryTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScrubTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func historyFile() -> URL {
        tempDir.appendingPathComponent("history.json")
    }

    func testRoundTrip() {
        let history = SessionHistory(fileURL: historyFile())
        // Whole-second start so ISO-8601 (no fractional seconds) round-trips exactly.
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let first = SessionRecord(start: start, duration: 127, endedBy: .chord)
        let second = SessionRecord(start: start.addingTimeInterval(200), duration: 5, endedBy: .forceEnd)

        history.append(first)
        history.append(second)

        let records = history.records()
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].start, first.start)
        XCTAssertEqual(records[0].duration, first.duration)
        XCTAssertEqual(records[0].endedBy, .chord)
        XCTAssertEqual(records[1].endedBy, .forceEnd)
    }

    func testMissingFileReturnsEmpty() {
        let history = SessionHistory(fileURL: historyFile())
        XCTAssertEqual(history.records().count, 0)
    }

    func testCorruptFileReturnsEmpty() throws {
        let url = historyFile()
        try Data("this is not json".utf8).write(to: url)
        let history = SessionHistory(fileURL: url)
        XCTAssertEqual(history.records().count, 0)
    }

    func testAppendOverCorruptFileStartsFresh() throws {
        let url = historyFile()
        try Data("garbage".utf8).write(to: url)
        let history = SessionHistory(fileURL: url)
        let record = SessionRecord(
            start: Date(timeIntervalSince1970: 1_700_000_000),
            duration: 42,
            endedBy: .failOpen
        )
        history.append(record)

        let records = history.records()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].endedBy, .failOpen)
    }
}
