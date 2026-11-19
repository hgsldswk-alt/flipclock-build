import XCTest

final class ShareChimeAndWidgetTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    func testShareCodeBothPrefixesWhitespaceAndCorruption() throws {
        var face = FaceConfiguration(); face.faceID = "olive"; face.foreground = "AB1234"; face.background = "000000"
        face.font = .condensed; face.format = .twelve; face.showSeconds = true; face.showDate = false
        for language in ["zh_CN", "en_US"] {
            let code = try XCTUnwrap(ShareCode.encode(face, locale: Locale(identifier: language)))
            XCTAssertTrue(code.hasPrefix(language == "zh_CN" ? "#翻页时钟#" : "#FlipClock#"))
            XCTAssertEqual(ShareCode.decode("before\n" + code + "\nafter"), face)
            let marker = language == "zh_CN" ? ShareCode.marker : ShareCode.englishMarker
            let wrapped = marker + code.dropFirst(marker.count).map(String.init).joined(separator: "\n")
            XCTAssertEqual(ShareCode.decode(wrapped), face)
        }
        XCTAssertNil(ShareCode.decode("#FlipClock#bad!#")); XCTAssertNil(ShareCode.decode(String(repeating: "x", count: 6001)))
        XCTAssertNil(ShareCode.decode("#FlipClock#a#")); XCTAssertNil(ShareCode.decode("nothing"))
        let packed = try XCTUnwrap(ShareCode.pack(Data("test".utf8)))
        XCTAssertEqual(ShareCode.unpack(packed), Data("test".utf8))
        var corrupt = packed; corrupt[corrupt.count - 1] ^= 1; XCTAssertNil(ShareCode.unpack(corrupt))
        face.foreground = "bad-hex"; XCTAssertNil(ShareCode.encode(face))
    }
    func testChimeFortyEightHourHorizonBudgetAndNightExclusion() {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!
        let all = HourWindow(start: 0, end: 0)
        let dates = ChimeScheduler.dates(now: now, calendar: c, window: all, timerNotifications: 0)
        XCTAssertEqual(dates.count, 48); XCTAssertTrue(dates.allSatisfy { $0 > now && $0 <= now.addingTimeInterval(48 * 3600) })
        XCTAssertTrue(dates.allSatisfy { c.component(.minute, from: $0) == 0 && c.component(.second, from: $0) == 0 })
        XCTAssertEqual(ChimeScheduler.dates(now: now, calendar: c, window: all, timerNotifications: 1, existingOtherNotifications: 60).count, 3)
        XCTAssertTrue(ChimeScheduler.dates(now: now, window: all, timerNotifications: 1, existingOtherNotifications: 64).isEmpty)
        let daytime = ChimeScheduler.dates(now: now, calendar: c, window: HourWindow(start: 8, end: 22), night: HourWindow(start: 22, end: 7))
        XCTAssertTrue(daytime.allSatisfy { (8..<22).contains(c.component(.hour, from: $0)) })
        XCTAssertTrue(HourWindow(start: 22, end: 7).contains(0, endInclusive: false))
        XCTAssertFalse(HourWindow(start: 22, end: 7).contains(7, endInclusive: false))
    }
    func testWidgetEntriesConfigurationAndNightBoundary() {
        let entries = WidgetSnapshot.entryDates(now: now.addingTimeInterval(17.5))
        XCTAssertEqual(entries.count, 60); XCTAssertEqual(entries.first, now.addingTimeInterval(17.5))
        for index in 2..<entries.count { XCTAssertEqual(entries[index].timeIntervalSince(entries[index - 1]), 60) }
        var data = AppData(); data.face.faceID = "olive"; data.face.showSeconds = true; data.face.format = .twelve
        let snapshot = WidgetSnapshot(data: data, date: now)
        XCTAssertNil(snapshot.strings.second); XCTAssertNotNil(snapshot.strings.period)
        data.entitlement = Entitlement(firstOpen: now.addingTimeInterval(-31 * 86400), proStartedAt: now.addingTimeInterval(-31 * 86400))
        data.face.foreground = "FF0000"; data.face.font = .serif
        let expired = WidgetSnapshot(data: data, date: now, freePeriod: false)
        XCTAssertFalse(expired.premium); XCTAssertEqual(expired.configuration.faceID, "ink")
        XCTAssertEqual(expired.configuration.font, .mono); XCTAssertNil(expired.configuration.foreground)
        XCTAssertEqual(WidgetSnapshot(data: data, date: now, freePeriod: true).configuration.faceID, "olive")
        data.settings.nightMode = "auto"
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!
        let night = c.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 22))!
        XCTAssertTrue(data.settings.isNight(at: night, calendar: c))
        XCTAssertFalse(data.settings.isNight(at: night.addingTimeInterval(9 * 3600), calendar: c))
    }
}
