import ActivityKit
import Foundation

struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endAt: Date
        var remaining: Int
        var paused: Bool
        var title: String
        var round: Int
    }
    var sessionID: UUID
}
