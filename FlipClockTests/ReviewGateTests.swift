import XCTest

final class ReviewGateTests: XCTestCase {
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
