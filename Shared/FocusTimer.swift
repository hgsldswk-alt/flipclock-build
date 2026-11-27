import Foundation

enum TimerKind: String, Codable { case pomodoro, countdown }
enum FocusPhase: String, Codable { case focus, shortBreak, longBreak
    var title: String { switch self { case .focus: return L.t("专注"); case .shortBreak: return L.t("短休"); case .longBreak: return L.t("长休") } }
}
struct FocusPlan: Codable, Equatable {
    var focus = 25; var shortBreak = 5; var longBreak = 15; var autoStart = false
    func duration(_ phase: FocusPhase) -> TimeInterval { TimeInterval(max(1, min(180, phase == .focus ? focus : (phase == .shortBreak ? shortBreak : longBreak))) * 60) }
}
extension FocusPlan {
    enum CodingKeys: String, CodingKey { case focus, shortBreak, longBreak, autoStart }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        focus = try c.decodeIfPresent(Int.self, forKey: .focus) ?? 25
        shortBreak = try c.decodeIfPresent(Int.self, forKey: .shortBreak) ?? 5
        longBreak = try c.decodeIfPresent(Int.self, forKey: .longBreak) ?? 15
        autoStart = try c.decodeIfPresent(Bool.self, forKey: .autoStart) ?? false
    }
}
struct FocusTimer: Codable, Equatable {
    var id = UUID()
    var kind: TimerKind = .countdown
    var phase: FocusPhase = .focus
    var round = 1
    var startedAt: Date?
    var endAt: Date?
    var pausedRemaining: TimeInterval?
    var duration: TimeInterval = 0
    var isRunning: Bool { endAt != nil }
    var isPaused: Bool { pausedRemaining != nil }
    mutating func start(duration: TimeInterval, now: Date) {
        id = UUID(); self.duration = max(0, min(86400, duration)); startedAt = now
        endAt = now.addingTimeInterval(self.duration); pausedRemaining = nil
    }
    func rawRemaining(now: Date) -> TimeInterval { max(0, endAt.map { $0.timeIntervalSince(now) } ?? pausedRemaining ?? 0) }
    func remaining(now: Date) -> Int { Int(ceil(rawRemaining(now: now))) }
    func isFinished(now: Date) -> Bool { endAt != nil && rawRemaining(now: now) == 0 }
    mutating func pause(now: Date) {
        guard isRunning else { return }; pausedRemaining = rawRemaining(now: now); endAt = nil
    }
    mutating func resume(now: Date) {
        guard let left = pausedRemaining else { return }; endAt = now.addingTimeInterval(left); pausedRemaining = nil
    }
    mutating func stop() { endAt = nil; pausedRemaining = nil }
    mutating func next(plan: FocusPlan, now: Date, startImmediately: Bool) {
        if phase == .focus { phase = round % 4 == 0 ? .longBreak : .shortBreak }
        else { phase = .focus; round += 1 }
        start(duration: plan.duration(phase), now: now)
        if !startImmediately { pause(now: now) }
    }
}
struct Stopwatch: Codable, Equatable {
    var startedAt: Date?
    var accumulated: TimeInterval = 0
    var laps: [TimeInterval] = []
    var isRunning: Bool { startedAt != nil }
    func elapsed(now: Date) -> TimeInterval { max(0, accumulated + (startedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)) }
    mutating func start(now: Date) { if startedAt == nil { startedAt = now } }
    mutating func pause(now: Date) { accumulated = elapsed(now: now); startedAt = nil }
    mutating func lap(now: Date) { laps.insert(elapsed(now: now), at: 0) }
    mutating func reset() { self = Stopwatch() }
}
extension Stopwatch {
    enum CodingKeys: String, CodingKey { case startedAt, accumulated, laps }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt)
        accumulated = try c.decodeIfPresent(TimeInterval.self, forKey: .accumulated) ?? 0
        laps = try c.decodeIfPresent([TimeInterval].self, forKey: .laps) ?? []
    }
}
