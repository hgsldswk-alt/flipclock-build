import Foundation

struct Entitlement: Codable, Equatable {
    var firstOpen = Date()
    var proStartedAt: Date?
    var trialClaimedAt: Date?
    var purchasedPro = false
    init(firstOpen: Date = Date(), proStartedAt: Date? = nil, trialClaimedAt: Date? = nil, purchasedPro: Bool = false) {
        self.firstOpen = firstOpen; self.proStartedAt = proStartedAt
        self.trialClaimedAt = trialClaimedAt; self.purchasedPro = purchasedPro
    }
    enum CodingKeys: String, CodingKey { case firstOpen, proStartedAt, trialClaimedAt, purchasedPro }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        firstOpen = try c.decodeIfPresent(Date.self, forKey: .firstOpen) ?? Date()
        proStartedAt = try c.decodeIfPresent(Date.self, forKey: .proStartedAt)
        trialClaimedAt = try c.decodeIfPresent(Date.self, forKey: .trialClaimedAt)
        purchasedPro = try c.decodeIfPresent(Bool.self, forKey: .purchasedPro) ?? false
    }
    var trialStart: Date { trialClaimedAt.map { min($0, proStartedAt ?? $0) } ?? proStartedAt ?? firstOpen }
    var trialEnd: Date { trialStart.addingTimeInterval(30 * 86400) }
    func hasPro(at now: Date, freePeriod: Bool = Launch.isFree) -> Bool {
        freePeriod || purchasedPro || (proStartedAt == nil && trialClaimedAt == nil) || (now >= trialStart && now < trialEnd)
    }
    func remainingDays(at now: Date) -> Int { max(0, min(30, Int(ceil(trialEnd.timeIntervalSince(now) / 86400)))) }
}
