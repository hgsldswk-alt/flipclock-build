import XCTest

final class StatsStoreAndEntitlementTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; c.firstWeekday = 2; c.minimumDaysInFirstWeek = 4; return c
    }
    private func date(_ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
    func testCrossMonthMidnightAndWeekStatistics() {
        var stats = FocusStats()
        stats.records = [FocusRecord(id: UUID(), startedAt: date(10, 31, 23, 50), duration: 1200, completed: true),
                         FocusRecord(id: UUID(), startedAt: date(11, 1), duration: 1800, completed: true)]
        XCTAssertEqual(stats.todayMinutes(now: date(10, 31), calendar: calendar), 10)
        XCTAssertEqual(stats.todayMinutes(now: date(11, 1), calendar: calendar), 40)
        XCTAssertEqual(stats.weekMinutes(now: date(11, 1), calendar: calendar), 50)
        XCTAssertEqual(stats.totalMinutes, 50); XCTAssertEqual(stats.streak(now: date(11, 1), calendar: calendar), 2)
        XCTAssertEqual(stats.streak(now: date(11, 2), calendar: calendar), 2)
        XCTAssertEqual(stats.streak(now: date(11, 3), calendar: calendar), 0)
    }
    func testPausedFragmentsAccumulateForStreakAndDST() {
        var stats = FocusStats()
        stats.records = [0, 120].map { FocusRecord(id: UUID(), startedAt: date(11, 1).addingTimeInterval(Double($0)), duration: 40, completed: false) }
        XCTAssertEqual(stats.streak(now: date(11, 1), calendar: calendar), 1)
        var dst = calendar; dst.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let start = dst.date(from: DateComponents(year: 2026, month: 3, day: 8))!
        stats.records = [FocusRecord(id: UUID(), startedAt: start, duration: 23 * 3600, completed: true)]
        XCTAssertEqual(stats.todayMinutes(now: start.addingTimeInterval(3600), calendar: dst), 23 * 60)
    }
    func testMilestonesAreClaimedOnceAndSurviveReload() throws {
        let now = date(11, 18); var stats = FocusStats()
        for day in 0..<30 {
            stats.records.append(FocusRecord(id: UUID(), startedAt: calendar.date(byAdding: .day, value: -day, to: now)!, duration: 17 * 3600, completed: true))
        }
        XCTAssertEqual(Set(stats.claimMilestones(now: now, calendar: calendar)), Set(["hours-10", "hours-50", "hours-100", "hours-500", "days-7", "days-30"]))
        var restored = try JSONDecoder().decode(FocusStats.self, from: JSONEncoder().encode(stats))
        XCTAssertTrue(restored.claimMilestones(now: now, calendar: calendar).isEmpty)
    }
    func testOldDataDefaultsAndRoundTrip() throws {
        let old = Data(#"{"face":{"faceID":"paper"},"settings":{"plan":{"focus":30}},"stats":{},"stopwatch":{}}"#.utf8)
        let state = try JSONDecoder().decode(AppData.self, from: old)
        XCTAssertEqual(state.face.faceID, "paper"); XCTAssertTrue(state.face.showDate)
        XCTAssertEqual(state.settings.plan.focus, 30); XCTAssertEqual(state.settings.plan.shortBreak, 5)
        XCTAssertEqual(state.settings.nightWindow.end, 7); XCTAssertTrue(state.stats.records.isEmpty)
        let name = "FlipClockTests.\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(try Store.load(from: defaults).face.faceID, "ink")
        try Store.save(state, to: defaults); XCTAssertEqual(try Store.load(from: defaults), state)
        defaults.set(Data("corrupt".utf8), forKey: Store.key)
        XCTAssertThrowsError(try Store.load(from: defaults)); XCTAssertEqual(defaults.data(forKey: Store.key), Data("corrupt".utf8))
        defaults.set(Data(#"{"version":99}"#.utf8), forKey: Store.key); XCTAssertThrowsError(try Store.load(from: defaults))
    }
    func testFreePeriodPaidTrialExpiryAndReceiptStart() {
        let start = date(11, 1)
        var value = Entitlement(firstOpen: start.addingTimeInterval(-100 * 86400), proStartedAt: start)
        XCTAssertTrue(value.hasPro(at: start.addingTimeInterval(1000 * 86400), freePeriod: true))
        XCTAssertTrue(value.hasPro(at: start, freePeriod: false))
        XCTAssertTrue(value.hasPro(at: start.addingTimeInterval(30 * 86400 - 0.001), freePeriod: false))
        XCTAssertFalse(value.hasPro(at: start.addingTimeInterval(30 * 86400), freePeriod: false))
        XCTAssertEqual(value.remainingDays(at: start), 30)
        value.trialClaimedAt = start.addingTimeInterval(-10 * 86400)
        XCTAssertFalse(value.hasPro(at: start.addingTimeInterval(21 * 86400), freePeriod: false))
        value.purchasedPro = true; XCTAssertTrue(value.hasPro(at: start.addingTimeInterval(1000 * 86400), freePeriod: false))
    }
}
