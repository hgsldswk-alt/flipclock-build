import Foundation

struct AppData: Codable, Equatable {
    var version = 1
    var face = FaceConfiguration()
    var settings = ClockSettings()
    var entitlement = Entitlement()
    var timer: FocusTimer?
    var stopwatch = Stopwatch()
    var stats = FocusStats()
    var recentMinutes: [Int] = []
    var hintShown = false
    var expiryNoticeShown = false
    var lowBatteryNoticeShown = false
    var reviewedVersions: [String] = []
    var completedPomodoros = 0
    var didShare = false
    init() {}
    enum CodingKeys: String, CodingKey {
        case version, face, settings, entitlement, timer, stopwatch, stats, recentMinutes, hintShown, expiryNoticeShown, lowBatteryNoticeShown, reviewedVersions, completedPomodoros, didShare
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        face = try c.decodeIfPresent(FaceConfiguration.self, forKey: .face) ?? FaceConfiguration()
        settings = try c.decodeIfPresent(ClockSettings.self, forKey: .settings) ?? ClockSettings()
        entitlement = try c.decodeIfPresent(Entitlement.self, forKey: .entitlement) ?? Entitlement()
        timer = try c.decodeIfPresent(FocusTimer.self, forKey: .timer)
        stopwatch = try c.decodeIfPresent(Stopwatch.self, forKey: .stopwatch) ?? Stopwatch()
        stats = try c.decodeIfPresent(FocusStats.self, forKey: .stats) ?? FocusStats()
        recentMinutes = try c.decodeIfPresent([Int].self, forKey: .recentMinutes) ?? []
        hintShown = try c.decodeIfPresent(Bool.self, forKey: .hintShown) ?? false
        expiryNoticeShown = try c.decodeIfPresent(Bool.self, forKey: .expiryNoticeShown) ?? false
        lowBatteryNoticeShown = try c.decodeIfPresent(Bool.self, forKey: .lowBatteryNoticeShown) ?? false
        reviewedVersions = try c.decodeIfPresent([String].self, forKey: .reviewedVersions) ?? []
        completedPomodoros = try c.decodeIfPresent(Int.self, forKey: .completedPomodoros) ?? 0
        didShare = try c.decodeIfPresent(Bool.self, forKey: .didShare) ?? false
    }
}
enum Store {
    static let key = "FlipClock.state.v1"
    static var defaults: UserDefaults {
        let group = Bundle.main.object(forInfoDictionaryKey: "FlipClockAppGroup") as? String ?? "group.com.hgsldswk.flipclock"
        return UserDefaults(suiteName: group) ?? .standard
    }
    static func load(from defaults: UserDefaults = Store.defaults) throws -> AppData {
        guard let data = defaults.data(forKey: key) else { return AppData() }
        let result = try JSONDecoder().decode(AppData.self, from: data)
        guard result.version <= 1 else { throw CocoaError(.coderReadCorrupt) }
        return result
    }
    static func save(_ data: AppData, to defaults: UserDefaults = Store.defaults) throws { defaults.set(try JSONEncoder().encode(data), forKey: key) }
}
