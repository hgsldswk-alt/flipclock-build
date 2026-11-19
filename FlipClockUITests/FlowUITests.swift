import XCTest

final class FlowUITests: XCTestCase {
    private var app: XCUIApplication!
    private var lastUIAction = "set up"
    private var recordingDiagnostics = false

    override func setUp() {
        continueAfterFailure = false; app = XCUIApplication(); XCUIDevice.shared.orientation = .portrait
    }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait; app.terminate() }

    override func record(_ issue: XCTIssue) {
        if !recordingDiagnostics, let app {
            recordingDiagnostics = true
            defer { recordingDiagnostics = false }
            let state = app.state
            print("UI failure at \(lastUIAction) [\(state)]: \(issue.compactDescription)")
            if state == .runningForeground {
                let tree = app.debugDescription
                let identifiers = ["clockSurface", "clockMenuActions", "orientationMenu", "openPicker",
                                   "startPomodoro", "openTimers", "openShare", "openSettings", "backToClock",
                                   "focusTitle", "toggleTimer", "lapStopwatch", "closeSheet", "facePreview",
                                   "sharePreview", "timeFormat", "openPaywall"]
                let keyElements = tree.split(separator: "\n").filter { line in
                    identifiers.contains { line.contains("identifier: '\($0)'") }
                        || line.contains("NavigationBar,") || line.contains("Alert,")
                }
                print("UI key elements:")
                print(keyElements.isEmpty ? "(none found in accessibility hierarchy)" : keyElements.joined(separator: "\n"))

                let hierarchy = XCTAttachment(string: tree)
                hierarchy.name = "ui-failure-accessibility"
                hierarchy.lifetime = .keepAlways
                add(hierarchy)
                let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                screenshot.name = "ui-failure-screen"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
        }
        super.record(issue)
    }

    private func launch(_ extra: [String] = [], reset: Bool = true, language: String = "zh-Hans", locale: String = "zh_CN",
                        ready identifier: String = "clockSurface") {
        lastUIAction = "launch, expecting \(identifier)"
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(\(language))", "-AppleLocale", locale] + (reset ? ["-reset"] : []) + extra
        app.launch()
        XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 8), identifier)
    }
    private func tap(_ identifier: String, inHorizontalScrollView scrollIdentifier: String? = nil) {
        lastUIAction = "find tappable \(identifier) after \(lastUIAction)"
        let button = app.buttons[identifier].firstMatch
        if let scrollIdentifier {
            if !button.exists || !button.isHittable {
                let scrollView = app.scrollViews[scrollIdentifier]
                XCTAssertTrue(wait(timeout: 3) { scrollView.exists && scrollView.isHittable }, scrollIdentifier)
                scrollView.swipeLeft()
            }
            XCTAssertTrue(wait(timeout: 7) { button.exists && button.isHittable }, identifier)
        } else {
            XCTAssertTrue(button.waitForExistence(timeout: 7), identifier)
            if identifier != "clockSurface", !button.isHittable { app.swipeUp() }
            XCTAssertTrue(wait(timeout: 3) { button.isHittable }, "\(identifier) must be tappable")
        }
        lastUIAction = "tap \(identifier)"
        button.tap()
    }
    private func menu() {
        tap("clockSurface")
        XCTAssertTrue(app.buttons["openPicker"].waitForExistence(timeout: 3), "openPicker after tapping clockSurface")
    }
    private func wait(timeout: TimeInterval = 8, _ condition: @escaping () -> Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
    private func shot(_ name: String) throws {
        lastUIAction = "capture \(name)"
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        if let folder = ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_SHOTS_DIR"], !folder.isEmpty {
            do {
                let url = URL(fileURLWithPath: folder, isDirectory: true)
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                try png.write(to: url.appendingPathComponent(name + ".png"))
            } catch {
                let note = XCTAttachment(string: "Use xcresult attachment when host SHOTS_DIR is outside the simulator sandbox: \(error)")
                note.lifetime = .keepAlways; add(note)
            }
        }
    }
    func testClockFaceFocusPauseShareAndSettings() throws {
        launch()
        XCTAssertEqual(app.buttons["clockSurface"].value as? String, "ink")
        try shot("flow-01-first-clock")
        menu(); tap("quickFace-paper")
        XCTAssertTrue(wait { self.app.buttons["clockSurface"].value as? String == "paper" })
        try shot("flow-02-paper-menu")
        tap("startPomodoro")
        XCTAssertTrue(app.buttons["toggleTimer"].waitForExistence(timeout: 5)); XCTAssertTrue(app.staticTexts["focusTitle"].label.contains("专注"))
        try shot("flow-03-focus-started")
        tap("toggleTimer"); XCTAssertEqual(app.buttons["toggleTimer"].label, "继续")
        try shot("flow-04-paused")
        tap("backToClock"); menu(); tap("openPicker"); tap("face-olive")
        try shot("flow-05-olive-picker"); tap("closeSheet")
        XCTAssertEqual(app.buttons["clockSurface"].value as? String, "olive")
        menu(); tap("openShare")
        XCTAssertTrue(app.images["sharePreview"].waitForExistence(timeout: 10)); XCTAssertTrue(app.buttons["shareImage"].exists)
        try shot("flow-06-share"); tap("closeSheet")
        menu(); tap("openSettings", inHorizontalScrollView: "clockMenuActions"); tap("timeFormat")
        let twelve = app.buttons["12 小时制"].firstMatch
        XCTAssertTrue(twelve.waitForExistence(timeout: 5)); twelve.tap()
        try shot("flow-07-settings-twelve"); tap("closeSheet")
        XCTAssertTrue(wait {
            let label = self.app.buttons["clockSurface"].label
            return label.hasSuffix("上午") || label.hasSuffix("下午")
        })
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(wait { self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height })
        try shot("flow-08-landscape")
        app.terminate(); launch(reset: false, ready: "toggleTimer")
        XCTAssertTrue(app.buttons["toggleTimer"].waitForExistence(timeout: 8)); XCTAssertEqual(app.buttons["toggleTimer"].label, "继续")
        tap("backToClock"); XCTAssertEqual(app.buttons["clockSurface"].value as? String, "olive")
    }
    func testCountdownStopwatchAndLaps() throws {
        launch(); menu(); tap("openTimers"); tap("duration-1")
        XCTAssertTrue(app.buttons["toggleTimer"].waitForExistence(timeout: 5)); tap("toggleTimer")
        XCTAssertEqual(app.buttons["toggleTimer"].label, "继续"); tap("toggleTimer")
        XCTAssertEqual(app.buttons["toggleTimer"].label, "暂停")
        tap("timerMore"); app.buttons["结束计时"].tap()
        menu(); tap("openTimers"); tap("openStopwatch")
        XCTAssertTrue(app.buttons["lapStopwatch"].waitForExistence(timeout: 5)); tap("lapStopwatch")
        XCTAssertTrue(app.staticTexts["第 1 次"].exists)
        try shot("flow-09-stopwatch-lap")
        tap("toggleStopwatch"); tap("resetStopwatch"); XCTAssertFalse(app.staticTexts["第 1 次"].exists)
    }
    func testScreenshotScreens() throws {
        try captureStoreScreens(language: "zh-Hans", locale: "zh_CN", pickerTitle: "表盘")
    }
    func testScreenshotScreensEnglish() throws {
        try captureStoreScreens(language: "en", locale: "en_US", pickerTitle: "Clock faces")
    }
    func testScreenshotScreensTraditionalChinese() throws {
        try captureStoreScreens(language: "zh-Hant", locale: "zh_TW", pickerTitle: "錶面")
    }
    private func captureStoreScreens(language: String, locale: String, pickerTitle: String) throws {
        func launchDemo(_ arguments: [String], ready: String = "clockSurface") {
            launch(["-demo"] + arguments, language: language, locale: locale, ready: ready)
        }
        let prefix = "store-\(language)-"
        launchDemo(["-face", "ink", "-landscape-hint"])
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(wait { self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height })
        try shot(prefix + "01-ink-landscape")
        menu(); tap("quickFace-paper")
        XCTAssertTrue(wait { self.app.buttons["clockSurface"].value as? String == "paper" })
        try shot(prefix + "02-paper-menu")
        app.terminate(); XCUIDevice.shared.orientation = .portrait
        launchDemo(["-face", "oat"])
        XCTAssertTrue(wait { self.app.windows.firstMatch.frame.height > self.app.windows.firstMatch.frame.width })
        XCTAssertEqual(app.buttons["clockSurface"].value as? String, "oat")
        try shot(prefix + "03-oat-portrait")
        app.terminate(); launchDemo(["-focus"], ready: "toggleTimer"); try shot(prefix + "04-focus")
        app.terminate(); launchDemo(["-picker", "-face", "olive"], ready: "closeSheet")
        XCTAssertTrue(app.navigationBars[pickerTitle].waitForExistence(timeout: 5))
        try shot(prefix + "05-picker")
        app.terminate(); launchDemo(["-share", "-face", "paper"], ready: "closeSheet")
        XCTAssertTrue(app.images["sharePreview"].waitForExistence(timeout: 10)); try shot(prefix + "06-share")
        app.terminate(); launchDemo(["-settings"], ready: "closeSheet"); try shot(prefix + "07-settings")
        app.terminate(); launchDemo(["-milestone"], ready: "backToClock")
        XCTAssertTrue(app.images["milestoneCard"].waitForExistence(timeout: 10)); try shot(prefix + "08-milestone")
    }
    func testExpiredTrialFallbackAndPaywall() throws {
        launch(["-demo", "-expired", "-face", "olive"])
        if app.alerts.firstMatch.waitForExistence(timeout: 3) { app.alerts.firstMatch.buttons.firstMatch.tap() }
        XCTAssertEqual(app.buttons["clockSurface"].value as? String, "ink")
        menu(); tap("openPicker"); tap("face-olive")
        XCTAssertTrue(app.navigationBars["解锁全部功能"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["试用剩余 0 天"].exists)
        try shot("paid-01-paywall")
    }
    func testPaywallLaunchShowsActiveTrial() {
        launch(["-paywall"], ready: "closeSheet")
        XCTAssertTrue(app.navigationBars["解锁全部功能"].exists)
        XCTAssertTrue(app.staticTexts["试用剩余 30 天"].exists)
    }
}
