import Foundation

struct HourWindow: Codable, Equatable {
    var start = 8; var end = 22
    func contains(_ hour: Int, endInclusive: Bool = true) -> Bool {
        let beforeEnd = endInclusive ? hour <= end : hour < end
        return start == end || (start < end ? (hour >= start && beforeEnd) : (hour >= start || beforeEnd))
    }
}
extension HourWindow {
    enum CodingKeys: String, CodingKey { case start, end }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start = max(0, min(23, try c.decodeIfPresent(Int.self, forKey: .start) ?? 8))
        end = max(0, min(23, try c.decodeIfPresent(Int.self, forKey: .end) ?? 22))
    }
}
enum ChimeScheduler {
    static func dates(now: Date, calendar: Calendar = .current, window: HourWindow = HourWindow(), night: HourWindow? = nil,
                      timerNotifications: Int = 1, existingOtherNotifications: Int = 0) -> [Date] {
        let budget = max(0, min(48, 64 - max(0, timerNotifications) - max(0, existingOtherNotifications)))
        guard budget > 0, let hour = calendar.dateInterval(of: .hour, for: now)?.start else { return [] }
        let horizon = now.addingTimeInterval(48 * 3600)
        return (1...48).compactMap { calendar.date(byAdding: .hour, value: $0, to: hour) }
            .filter { $0 <= horizon && window.contains(calendar.component(.hour, from: $0)) && !(night?.contains(calendar.component(.hour, from: $0), endInclusive: false) ?? false) }
            .prefix(budget).map { $0 }
    }
}
