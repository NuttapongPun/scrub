import XCTest
@testable import Scrub

/// `SessionClock.compact` is the pure formatter behind every history row and the total-time
/// hint. These pin the boundaries that the `<m>m <ss>s` / `<h>h <mm>m <ss>s` switch hinges on.
final class SessionClockTests: XCTestCase {

    func testZero() {
        XCTAssertEqual(SessionClock.compact(0), "0m 00s")
    }

    func testSubMinutePadsSeconds() {
        XCTAssertEqual(SessionClock.compact(7), "0m 07s")
        XCTAssertEqual(SessionClock.compact(59), "0m 59s")
    }

    func testMinutesAndSeconds() {
        XCTAssertEqual(SessionClock.compact(127), "2m 07s")
    }

    func testExactlyOneHourSurfacesHours() {
        XCTAssertEqual(SessionClock.compact(3600), "1h 00m 00s")
    }

    func testHoursMinutesSeconds() {
        // 1h 02m 03s = 3723s
        XCTAssertEqual(SessionClock.compact(3723), "1h 02m 03s")
    }

    func testRoundsToNearestSecond() {
        XCTAssertEqual(SessionClock.compact(59.4), "0m 59s")
        XCTAssertEqual(SessionClock.compact(59.6), "1m 00s")
        // Rounding can tip a sub-hour value over the hour boundary.
        XCTAssertEqual(SessionClock.compact(3599.6), "1h 00m 00s")
    }

    func testNegativeClampsToZero() {
        XCTAssertEqual(SessionClock.compact(-5), "0m 00s")
    }

    func testFormatAddsPrefix() {
        XCTAssertEqual(SessionClock.format(127), "Cleaned for 2m 07s")
    }
}
