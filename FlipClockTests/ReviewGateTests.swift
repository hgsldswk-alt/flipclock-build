import Foundation
import XCTest

final class ReviewGateTests: XCTestCase {
    func testCoreReviewRequiresThreeActionsOnTwoLocalDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 23)))
        let nextDay = firstDay.addingTimeInterval(2 * 3600)
        let empty = try JSONDecoder().decode(CoreReviewProgress.self, from: Data("{}".utf8))
        XCTAssertFalse(empty.isEligible)
        var progress = CoreReviewProgress.recording(empty, at: firstDay, calendar: calendar)
        var twoDays = progress
        twoDays.record(at: nextDay, calendar: calendar)
        XCTAssertFalse(twoDays.isEligible)
        progress.record(at: firstDay, calendar: calendar)
        XCTAssertFalse(progress.isEligible)

        var sameDay = progress
        sameDay.record(at: firstDay, calendar: calendar)
        XCTAssertFalse(sameDay.isEligible)

        let data = try JSONEncoder().encode(progress)
        progress = try JSONDecoder().decode(CoreReviewProgress.self, from: data)
        progress.record(at: nextDay, calendar: calendar)
        XCTAssertTrue(progress.isEligible)
    }

    func testThirdCompletionOncePerVersionAndFirstShareOnly() {
        var data = AppData()
        for count in 1...5 {
            data.completedPomodoros = count
            XCTAssertEqual(ReviewGate.claim(event: .completedPomodoro, version: "1.0", data: &data), count == 3)
        }
        XCTAssertFalse(ReviewGate.claim(event: .generatedShare, version: "1.0", data: &data))
        XCTAssertTrue(data.didShare); XCTAssertEqual(data.reviewedVersions, ["1.0"])
        XCTAssertFalse(ReviewGate.claim(event: .generatedShare, version: "1.1", data: &data))
        data = AppData()
        XCTAssertTrue(ReviewGate.claim(event: .generatedShare, version: "1.0", data: &data))
        XCTAssertFalse(ReviewGate.claim(event: .generatedShare, version: "1.0", data: &data))
        data.completedPomodoros = 3
        XCTAssertFalse(ReviewGate.claim(event: .completedPomodoro, version: "1.0", data: &data))
    }
}
