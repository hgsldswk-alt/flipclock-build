import Foundation

struct ClockSettings: Codable, Equatable {
    var keepAwake: Bool = true
    var burnIn: Bool = true
    var flipSound: String = "off"
    var flipVolume: Double = 0.25
    var alertSound: String = "bell"
    var alertVolume: Double = 0.5
    var vibrateOnly: Bool = false
    var respectSilent: Bool = false
    var chime: String = "off"
    var chimeWindow: HourWindow = HourWindow()
    var nightMode: String = "off"
    var nightWindow: HourWindow = HourWindow(start: 22, end: 7)
    var plan: FocusPlan = FocusPlan()
    var transparentWidget: Bool = false
    var orientation: String = "system"
    init() {}
    enum CodingKeys: String, CodingKey { case keepAwake, burnIn, flipSound, flipVolume, alertSound, alertVolume, vibrateOnly, respectSilent, chime, chimeWindow, nightMode, nightWindow, plan, transparentWidget, orientation }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keepAwake = try c.decodeIfPresent(Bool.self, forKey: .keepAwake) ?? true
        burnIn = try c.decodeIfPresent(Bool.self, forKey: .burnIn) ?? true
        flipSound = try c.decodeIfPresent(String.self, forKey: .flipSound) ?? "off"
        flipVolume = try c.decodeIfPresent(Double.self, forKey: .flipVolume) ?? 0.25
        alertSound = try c.decodeIfPresent(String.self, forKey: .alertSound) ?? "bell"
        alertVolume = try c.decodeIfPresent(Double.self, forKey: .alertVolume) ?? 0.5
        vibrateOnly = try c.decodeIfPresent(Bool.self, forKey: .vibrateOnly) ?? false
        respectSilent = try c.decodeIfPresent(Bool.self, forKey: .respectSilent) ?? false
        chime = try c.decodeIfPresent(String.self, forKey: .chime) ?? "off"
        chimeWindow = try c.decodeIfPresent(HourWindow.self, forKey: .chimeWindow) ?? HourWindow()
        nightMode = try c.decodeIfPresent(String.self, forKey: .nightMode) ?? "off"
        nightWindow = try c.decodeIfPresent(HourWindow.self, forKey: .nightWindow) ?? HourWindow(start: 22, end: 7)
        plan = try c.decodeIfPresent(FocusPlan.self, forKey: .plan) ?? FocusPlan()
        transparentWidget = try c.decodeIfPresent(Bool.self, forKey: .transparentWidget) ?? false
        orientation = try c.decodeIfPresent(String.self, forKey: .orientation) ?? "system"
    }
    func isNight(at date: Date, calendar: Calendar = .current) -> Bool {
        nightMode == "manual" || (nightMode == "auto" && nightWindow.contains(calendar.component(.hour, from: date), endInclusive: false))
    }
}
