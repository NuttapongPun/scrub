import XCTest
@testable import Scrub

/// `EndReason.historyCause` is the contract that decides which exits get logged. The critical
/// case is `manual -> nil`: the Quit / menu-stop escape hatch must never appear in history.
final class EndReasonTests: XCTestCase {

    func testGenuineExitsMapToCauses() {
        XCTAssertEqual(EndReason.chord.historyCause, .chord)
        XCTAssertEqual(EndReason.forceEnd.historyCause, .forceEnd)
        XCTAssertEqual(EndReason.failOpen.historyCause, .failOpen)
    }

    func testManualIsNotLogged() {
        XCTAssertNil(EndReason.manual.historyCause)
    }
}
