import Foundation

struct FocusRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var startedAt: Date
    var duration: TimeInterval
    var completed: Bool
}
struct FocusStats: Codable, Equatable {
    var records: [FocusRecord] = []
    var announced: [String] = []
    func seconds(in interval: DateInterval? = nil) -> TimeInterval {
        records.reduce(0) { total, record in
            let end = record.startedAt.addingTimeInterval(max(0, record.duration))
            guard let interval else { return total + max(0, record.duration) }
            return total + max(0, min(end, interval.end).timeIntervalSince(max(record.startedAt, interval.start)))
        }
    }
    func todayMinutes(now: Date, calendar: Calendar = .current) -> Int { Int(seconds(in: calendar.dateInterval(of: .day, for: now)) / 60) }
    func weekMinutes(now: Date, calendar: Calendar = .current) -> Int { Int(seconds(in: calendar.dateInterval(of: .weekOfYear, for: now)) / 60) }
    var totalMinutes: Int { Int(seconds() / 60) }
    func streak(now: Date, calendar: Calendar = .current) -> Int {
        var dailySeconds: [Date: TimeInterval] = [:]
        for record in records where record.duration > 0 {
            var day = calendar.startOfDay(for: record.startedAt)
            let end = record.startedAt.addingTimeInterval(record.duration)
            while day < end {
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                dailySeconds[day, default: 0] += max(0, min(end, next).timeIntervalSince(max(day, record.startedAt)))
                day = next
            }
        }
        let days = Set(dailySeconds.filter { $0.value >= 60 }.map(\.key))
        var day = calendar.startOfDay(for: now), count = 0
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        while days.contains(day) { count += 1; day = calendar.date(byAdding: .day, value: -1, to: day) ?? .distantPast }
        return count
    }
    mutating func claimMilestones(now: Date, calendar: Calendar = .current) -> [String] {
        let hours = [10, 50, 100, 500].filter { totalMinutes >= $0 * 60 }.map { "hours-\($0)" }
        let days = [7, 30].filter { streak(now: now, calendar: calendar) >= $0 }.map { "days-\($0)" }
        let fresh = (hours + days).filter { !announced.contains($0) }; announced += fresh; return fresh
    }
}

extension FocusStats {
    enum CodingKeys: String, CodingKey { case records, announced }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        records = try c.decodeIfPresent([FocusRecord].self, forKey: .records) ?? []
        announced = try c.decodeIfPresent([String].self, forKey: .announced) ?? []
    }
}
