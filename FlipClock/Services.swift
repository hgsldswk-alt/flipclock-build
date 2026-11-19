import SwiftUI
import AVFoundation
import AudioToolbox
import UserNotifications
import ActivityKit
import UIKit

@MainActor
final class SoundPlayer {
    private var player: AVAudioPlayer?
    private let speech = AVSpeechSynthesizer()
    private var resetTask: Task<Void, Never>?
    private var flipTask: Task<Void, Never>?
    func flip(settings: ClockSettings, night: Bool, premium: Bool) {
        guard premium, !night, settings.flipSound != "off", player?.isPlaying != true, !speech.isSpeaking else { return }
        flipTask?.cancel()
        flipTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled, player?.isPlaying != true else { return }
            play(name: "flip-" + settings.flipSound, volume: settings.flipVolume, ambient: true)
        }
    }
    func alert(settings: ClockSettings) {
        flipTask?.cancel()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        guard !settings.vibrateOnly else { return }
        play(name: "alert-" + settings.alertSound, volume: settings.alertVolume, ambient: settings.respectSilent)
    }
    func stop() {
        flipTask?.cancel(); resetTask?.cancel(); player?.stop(); speech.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func chime(settings: ClockSettings, now: Date) {
        guard settings.chime != "off" else { return }
        if settings.chime == "voice" {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers]); try? session.setActive(true)
            let f = DateFormatter(); f.locale = .current; f.dateStyle = .none; f.timeStyle = .short
            let utterance = AVSpeechUtterance(string: L.f("现在是 %@", f.string(from: now)))
            utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "en-US")
            utterance.volume = Float(settings.alertVolume); speech.speak(utterance)
            resetTask?.cancel()
            resetTask = Task { @MainActor in
                while speech.isSpeaking { try? await Task.sleep(for: .milliseconds(200)); if Task.isCancelled { return } }
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        } else { play(name: "alert-bell", volume: settings.alertVolume, ambient: settings.respectSilent) }
    }
    private func play(name: String, volume: Double, ambient: Bool) {
        guard volume > 0, let url = Bundle.main.url(forResource: name, withExtension: "caf") else { return }
        resetTask?.cancel()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(ambient ? .ambient : .playback, mode: .default, options: ambient ? [.mixWithOthers] : [.mixWithOthers, .duckOthers])
            try session.setActive(true)
            let sound = try AVAudioPlayer(contentsOf: url); sound.volume = Float(max(0, min(1, volume))); player = sound; sound.play()
            resetTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(sound.duration + 0.1))
                guard !Task.isCancelled else { return }; try? session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        } catch { /* Audio failure never interrupts the clock. */ }
    }
}

@MainActor
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationScheduler()
    var onForegroundTimer: (() -> Void)?
    private var generation = 0
    private var task: Task<Void, Never>?
    var enabled = true
    override init() { super.init() }
    func install() { UNUserNotificationCenter.current().delegate = self }
    func requestPermission() async -> Bool {
        guard enabled else { return false }
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined { return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false }
        return status == .authorized || status == .provisional
    }
    func schedule(data: AppData, now: Date) {
        guard enabled else { return }
        generation += 1; let token = generation; task?.cancel()
        task = Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            guard !Task.isCancelled, token == generation else { return }
            let ours = pending.filter { $0.identifier.hasPrefix("flipclock.") }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ours)
            let others = pending.count - ours.count
            var timerCount = 0
            if let timer = data.timer, let end = timer.endAt, end > now {
                let content = UNMutableNotificationContent(); content.title = L.t("计时结束"); content.body = L.t("这一段时间，完成了。")
                if !data.settings.vibrateOnly && data.settings.alertVolume > 0 { content.sound = UNNotificationSound(named: UNNotificationSoundName("alert-" + data.settings.alertSound + ".caf")) }
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSince(now)), repeats: false)
                try? await center.add(UNNotificationRequest(identifier: "flipclock.timer", content: content, trigger: trigger)); timerCount = 1
            }
            guard data.entitlement.hasPro(at: now), data.settings.chime != "off", data.settings.nightMode != "manual" else { return }
            let dates = ChimeScheduler.dates(now: now, window: data.settings.chimeWindow,
                night: data.settings.nightMode == "auto" ? data.settings.nightWindow : nil, timerNotifications: timerCount, existingOtherNotifications: others)
            for (index, date) in dates.enumerated() {
                guard !Task.isCancelled, token == generation else { return }
                let content = UNMutableNotificationContent(); content.title = L.t("整点报时")
                let f = DateFormatter(); f.timeStyle = .short; content.body = L.f("现在是 %@", f.string(from: date))
                if !data.settings.vibrateOnly && data.settings.alertVolume > 0 { content.sound = UNNotificationSound(named: UNNotificationSoundName("alert-bell.caf")) }
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSince(now)), repeats: false)
                try? await center.add(UNNotificationRequest(identifier: "flipclock.chime.\(index)", content: content, trigger: trigger))
            }
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }
}

@MainActor
final class LiveActivityController {
    private var task: Task<Void, Never>?
    private var generation = 0
    func sync(timer: FocusTimer?, now: Date, allowed: Bool) {
        generation += 1; let token = generation; task?.cancel()
        task = Task { @MainActor in
            let active = Activity<TimerActivityAttributes>.activities
            guard allowed, let timer, timer.isRunning || timer.isPaused else {
                for activity in active { await activity.end(nil, dismissalPolicy: .immediate) }; return
            }
            let state = TimerActivityAttributes.ContentState(endAt: timer.endAt ?? now, remaining: timer.remaining(now: now), paused: timer.isPaused,
                title: timer.kind == .pomodoro ? timer.phase.title : L.t("倒计时"), round: timer.round)
            let content = ActivityContent(state: state, staleDate: timer.endAt)
            for activity in active where activity.attributes.sessionID != timer.id { await activity.end(nil, dismissalPolicy: .immediate) }
            guard !Task.isCancelled, token == generation else { return }
            if let activity = active.first(where: { $0.attributes.sessionID == timer.id }) { await activity.update(content) }
            else if ActivityAuthorizationInfo().areActivitiesEnabled {
                _ = try? Activity.request(attributes: TimerActivityAttributes(sessionID: timer.id), content: content, pushType: nil)
            }
        }
    }
}

@MainActor
enum OrientationController {
    static var mask: UIInterfaceOrientationMask = .allButUpsideDown
    static func apply(_ preference: String) {
        mask = preference == "landscape" ? .landscape : (preference == "portrait" ? .portrait : .allButUpsideDown)
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
    }
}
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { OrientationController.mask }
}
