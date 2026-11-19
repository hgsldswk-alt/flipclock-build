import SwiftUI
import StoreKit
import WidgetKit
import UIKit
import UserNotifications

enum SheetRoute: String, Identifiable { case picker, share, settings, paywall, help, statistics
    var id: String { rawValue }
}
enum ClockScreen: Equatable { case clock, focus, timers, stopwatch }

@MainActor
final class AppModel: ObservableObject {
    @Published var data: AppData
    @Published var now = Date()
    @Published var screen: ClockScreen = .clock
    @Published var sheet: SheetRoute?
    @Published var message: String?
    @Published var milestones: [String] = []
    @Published var completionVisible = false
    @Published var reviewRequested = false
    @Published var products: [Product] = []
    @Published var purchasing = false
    @Published var productLoadFailed = false
    @Published var notificationDenied = false
    @Published var lowBatteryPrompt = false
    @Published private var importedPreview: FaceConfiguration?
    @Published private var previewEnd: Date?
    private let storage: UserDefaults
    private var canWrite = true
    private var transactionTask: Task<Void, Never>?
    private var lastChimeHour: Date?
    let demo: Bool
    let isolated: Bool
    let landscapeHint: Bool
    let sound = SoundPlayer()
    let live = LiveActivityController()
    static let demoDate: Date = {
        var c = Calendar(identifier: .gregorian); c.timeZone = .current
        return c.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 10, minute: 24, second: 36))!
    }()
    var premium: Bool { data.entitlement.hasPro(at: now) }
    var effectiveSettings: ClockSettings {
        var value = data.settings
        if !premium {
            value.flipSound = "off"; value.chime = "off"; value.plan = FocusPlan(); value.alertSound = "bell"
            value.transparentWidget = false
            if value.nightMode == "auto" { value.nightMode = "off" }
        }
        return value
    }
    var configuration: FaceConfiguration {
        if effectiveSettings.isNight(at: now) { var value = data.face; value.faceID = "night"; value.foreground = nil; value.background = nil; return value }
        if let importedPreview, let previewEnd, now < previewEnd { return importedPreview }
        guard !premium else { return data.face }
        var value = data.face; value.faceID = Face.find(value.faceID).fallbackID; value.font = .mono; value.foreground = nil; value.background = nil; return value
    }
    var face: Face { Face.find(configuration.faceID) }
    var timerMinutes: [Int] { data.recentMinutes + [1, 3, 5, 10, 15, 25, 30, 60].filter { !data.recentMinutes.contains($0) } }
    var proID: String { Bundle.main.object(forInfoDictionaryKey: "FlipClockProProductID") as? String ?? "com.hgsldswk.flipclock.pro" }
    var trialID: String { Bundle.main.object(forInfoDictionaryKey: "FlipClockTrialProductID") as? String ?? "com.hgsldswk.flipclock.trial" }
    var todayMinutes: Int { data.stats.todayMinutes(now: now) }
    var streak: Int { data.stats.streak(now: now) }

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        demo = Launch.supportsFixtures && arguments.contains("-demo")
        let fixtures = ["-ui-testing", "-paid-mode", "-paywall", "-expired", "-focus", "-picker", "-share", "-settings", "-milestone", "-face", "-landscape-hint"]
        isolated = Launch.supportsFixtures && (demo || arguments.contains { fixtures.contains($0) })
        landscapeHint = Launch.supportsFixtures && arguments.contains("-landscape-hint")
        let suite = "com.hgsldswk.flipclock.fixtures"
        storage = isolated ? UserDefaults(suiteName: suite)! : Store.defaults
        if isolated && (arguments.contains("-reset") || demo) { storage.removePersistentDomain(forName: suite) }
        var loadError = false
        do { data = try Store.load(from: storage) } catch { data = AppData(); canWrite = false; loadError = true }
        now = demo ? Self.demoDate : Date()
        if !Launch.isFree && data.entitlement.proStartedAt == nil { data.entitlement.proStartedAt = now }
        if isolated {
            if demo {
                data = AppData(); data.entitlement.firstOpen = now; data.entitlement.proStartedAt = Launch.isFree ? nil : now
                let c = Calendar.current
                for day in 0..<6 {
                    let start = c.startOfDay(for: c.date(byAdding: .day, value: -day, to: now)!)
                    data.stats.records.append(FocusRecord(id: UUID(), startedAt: start, duration: 6000, completed: true))
                }
            }
            if arguments.contains("-expired") {
                data.entitlement = Entitlement(firstOpen: now.addingTimeInterval(-31 * 86400), proStartedAt: now.addingTimeInterval(-31 * 86400))
            }
            if let i = arguments.firstIndex(of: "-face"), arguments.indices.contains(i + 1), Face.all.contains(where: { $0.id == arguments[i + 1] }) { data.face.faceID = arguments[i + 1] }
            if arguments.contains("-picker") { sheet = .picker }
            if arguments.contains("-share") { sheet = .share }
            if arguments.contains("-settings") { sheet = .settings }
            if arguments.contains("-paywall") { sheet = .paywall }
            if arguments.contains("-focus") {
                var timer = FocusTimer(); timer.kind = .pomodoro; timer.round = 2; timer.start(duration: 1104, now: now); data.timer = timer; screen = .focus
            }
            if arguments.contains("-milestone") { milestones = ["hours-100"]; completionVisible = true; screen = .focus }
            if let i = arguments.firstIndex(of: "-clipboard-code"), arguments.indices.contains(i + 1) { UIPasteboard.general.string = arguments[i + 1] }
        }
        NotificationScheduler.shared.enabled = !isolated
        if loadError { message = L.t("数据暂时无法读取，原始数据已保留。请关闭后重试。") }
        if let timer = data.timer, timer.isRunning || timer.isPaused { screen = .focus }
        persist()
    }
    deinit { transactionTask?.cancel() }
    func start() async {
        OrientationController.apply(data.settings.orientation)
        guard !isolated else { return }
        NotificationScheduler.shared.install()
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        notificationDenied = notificationSettings.authorizationStatus == .denied
        if !Launch.isFree {
            transactionTask = Task { [weak self] in
                for await verification in Transaction.updates {
                    guard let self, !Task.isCancelled else { return }
                    if case .verified(let transaction) = verification, [proID, trialID].contains(transaction.productID) {
                        await refreshEntitlements(); await transaction.finish()
                    }
                }
            }
            await refreshEntitlements()
        }
        tick(Date()); reschedule(); live.sync(timer: data.timer, now: now, allowed: premium)
    }
    func persist() {
        guard canWrite else { return }
        do { try Store.save(data, to: storage) } catch { message = L.t("保存失败，请稍后重试。") }
        if !isolated { WidgetCenter.shared.reloadAllTimelines() }
    }
    func changeFace(_ change: (inout FaceConfiguration) -> Void) { change(&data.face); importedPreview = nil; previewEnd = nil; persist() }
    func changeSettings(_ change: (inout ClockSettings) -> Void) {
        let oldChime = data.settings.chime
        change(&data.settings); persist(); reschedule()
        if oldChime != data.settings.chime && data.settings.chime != "off" && !isolated {
            Task { @MainActor in notificationDenied = !(await NotificationScheduler.shared.requestPermission()); reschedule() }
        }
    }
    @discardableResult func requirePro() -> Bool { if premium { return true }; sheet = .paywall; return false }
    func selectFace(_ face: Face) {
        guard face.free || requirePro() else { return }
        changeFace { $0.faceID = face.id; $0.foreground = nil; $0.background = nil }
    }
    func tick(_ date: Date) {
        let previous = now; now = demo ? Self.demoDate : date
        if let previewEnd, now >= previewEnd { self.previewEnd = nil; importedPreview = nil }
        if let timer = data.timer, timer.isFinished(now: now) { finishTimer() }
        let clockFlipped = screen == .clock && Calendar.current.component(.minute, from: previous) != Calendar.current.component(.minute, from: now)
        let timerFlipped = screen == .focus && data.timer?.isRunning == true && data.timer?.remaining(now: previous) != data.timer?.remaining(now: now)
        if !isolated && sheet == nil && (clockFlipped || timerFlipped) {
            sound.flip(settings: effectiveSettings, night: effectiveSettings.isNight(at: now), premium: premium)
        }
        let c = Calendar.current
        if c.component(.minute, from: now) == 0 && c.component(.second, from: now) <= 1,
           effectiveSettings.chimeWindow.contains(c.component(.hour, from: now)), !effectiveSettings.isNight(at: now), premium {
            let hour = c.dateInterval(of: .hour, for: now)?.start
            if lastChimeHour != hour { lastChimeHour = hour; sound.chime(settings: effectiveSettings, now: now) }
        }
        if !premium, !data.expiryNoticeShown { data.expiryNoticeShown = true; persist(); message = L.t("试用已结束，免费时钟和已有记录可继续使用。原配色已保留。") }
    }
    func startPomodoro() {
        guard canWrite else { return }; tick(Date()); recordPartial()
        var timer = FocusTimer(); timer.kind = .pomodoro; timer.start(duration: effectiveSettings.plan.duration(.focus), now: now)
        data.timer = timer; screen = .focus; completionVisible = false; milestones = []; persist(); timerChanged(requestPermission: true)
    }
    func startCountdown(minutes: Int) {
        guard canWrite else { return }; tick(Date()); recordPartial()
        var timer = FocusTimer(); timer.start(duration: TimeInterval(minutes * 60), now: now); data.timer = timer
        data.recentMinutes.removeAll { $0 == minutes }; data.recentMinutes.insert(minutes, at: 0); data.recentMinutes = Array(data.recentMinutes.prefix(8))
        screen = .focus; completionVisible = false; milestones = []; persist(); timerChanged(requestPermission: true)
    }
    func toggleTimer() {
        guard canWrite else { return }; tick(Date())
        guard var timer = data.timer else { return }
        guard !completionVisible else { return }
        if timer.isRunning { recordPartial(); timer.pause(now: now) }
        else { timer.resume(now: now); timer.startedAt = now }
        data.timer = timer; persist(); timerChanged()
    }
    private func recordPartial(until: Date? = nil, completed: Bool = false) {
        guard let timer = data.timer, timer.kind == .pomodoro, timer.phase == .focus, timer.isRunning, let start = timer.startedAt else { return }
        let end = min(until ?? now, timer.endAt ?? now)
        let duration = max(0, end.timeIntervalSince(start))
        if duration > 0 { data.stats.records.append(FocusRecord(id: UUID(), startedAt: start, duration: duration, completed: completed)) }
        data.timer?.startedAt = end
    }
    private func finishTimer() {
        guard canWrite, var timer = data.timer else { return }
        recordPartial(until: timer.endAt, completed: true)
        if timer.kind == .pomodoro && timer.phase == .focus {
            data.completedPomodoros += 1; milestones = data.stats.claimMilestones(now: now)
            claimReview(.completedPomodoro)
        }
        completionVisible = true
        if timer.kind == .pomodoro {
            let auto = effectiveSettings.plan.autoStart
            timer.next(plan: effectiveSettings.plan, now: now, startImmediately: auto)
            if auto && milestones.isEmpty { completionVisible = false }
            data.timer = timer
        } else { timer.stop(); data.timer = timer }
        persist(); timerChanged()
        if !isolated && UIApplication.shared.applicationState == .active { sound.alert(settings: effectiveSettings) }
    }
    func nextPhase() {
        if completionVisible { completionVisible = false; if data.timer?.isPaused == true { toggleTimer() }; return }
        recordPartial()
        if var timer = data.timer, timer.kind == .pomodoro { timer.next(plan: effectiveSettings.plan, now: now, startImmediately: true); data.timer = timer }
        else { data.timer = nil; screen = .timers }
        persist(); timerChanged()
    }
    func endTimer() { recordPartial(); data.timer = nil; completionVisible = false; screen = .clock; persist(); timerChanged() }
    func adjustTimer(minutes: Int) {
        guard canWrite else { return }; tick(Date())
        guard var timer = data.timer, !completionVisible else { return }
        if timer.kind == .pomodoro && !requirePro() { return }
        recordPartial(); let paused = timer.isPaused
        timer.start(duration: TimeInterval(max(1, min(180, minutes)) * 60), now: now)
        if paused { timer.pause(now: now) }
        data.timer = timer; persist(); timerChanged()
    }
    func timerChanged(requestPermission: Bool = false) {
        if !isolated { live.sync(timer: data.timer, now: now, allowed: premium) }
        if requestPermission && !isolated {
            Task { @MainActor in notificationDenied = !(await NotificationScheduler.shared.requestPermission()); reschedule() }
        } else { reschedule() }
    }
    func reschedule() {
        guard !isolated else { return }
        var snapshot = data; snapshot.settings = effectiveSettings
        NotificationScheduler.shared.schedule(data: snapshot, now: now)
    }
    func importCode(_ text: String) {
        guard let face = ShareCode.decode(text) else { message = L.t("未识别出口令，请复制完整表盘口令后重试。"); return }
        if !premium && (!Face.find(face.faceID).free || face.foreground != nil || face.background != nil || face.font != .mono) {
            importedPreview = face; previewEnd = now.addingTimeInterval(10); message = L.t("已预览同款表盘，10 秒后恢复免费表盘。")
        } else { data.face = face; persist() }
    }
    func claimReview(_ event: ReviewEvent) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        if ReviewGate.claim(event: event, version: version, data: &data), !isolated { reviewRequested = true }
    }
    func batteryCheck() {
        guard !isolated, !data.lowBatteryNoticeShown, data.settings.keepAwake else { return }
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        if level >= 0 && level < 0.2 && UIDevice.current.batteryState == .unplugged { data.lowBatteryNoticeShown = true; persist(); lowBatteryPrompt = true }
    }
    func loadProducts() async {
        guard !Launch.isFree else { return }
        guard !isolated else { productLoadFailed = true; return }; productLoadFailed = false
        do { products = try await Product.products(for: [proID, trialID]); productLoadFailed = products.count < 2 }
        catch { productLoadFailed = true }
    }
    func purchase(_ id: String) async {
        guard !purchasing, !Launch.isFree, let product = products.first(where: { $0.id == id }) else { return }
        purchasing = true; defer { purchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { message = L.t("无法验证购买，请尝试恢复购买。"); return }
                if transaction.productID == trialID { data.entitlement.trialClaimedAt = min(data.entitlement.trialClaimedAt ?? transaction.originalPurchaseDate, transaction.originalPurchaseDate) }
                await refreshEntitlements(); await transaction.finish(); if premium { sheet = nil }
            case .pending: message = L.t("购买正在等待批准。")
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = L.t("购买未完成，请稍后重试。") }
    }
    func restore() async {
        guard !purchasing, !Launch.isFree else { return }; purchasing = true; defer { purchasing = false }
        do { try await AppStore.sync(); await refreshEntitlements(); message = L.t("已检查购买记录。") }
        catch { message = L.t("恢复购买失败，请稍后重试。") }
    }
    func refreshEntitlements() async {
        guard !Launch.isFree, !isolated else { return }
        var purchased = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            if transaction.productID == proID { purchased = true }
            if transaction.productID == trialID { data.entitlement.trialClaimedAt = min(data.entitlement.trialClaimedAt ?? transaction.originalPurchaseDate, transaction.originalPurchaseDate) }
        }
        data.entitlement.purchasedPro = purchased; now = Date(); persist(); reschedule()
    }
}
