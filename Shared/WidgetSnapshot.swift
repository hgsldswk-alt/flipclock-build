import Foundation

struct WidgetSnapshot {
    let data: AppData
    let date: Date
    var freePeriod = Launch.isFree
    var premium: Bool { data.entitlement.hasPro(at: date, freePeriod: freePeriod) }
    var configuration: FaceConfiguration {
        var face = data.face
        if !premium {
            face.faceID = ["paper", "blush", "oat", "glass", "line", "mist"].contains(face.faceID) ? "paper" : "ink"
            face.foreground = nil; face.background = nil; face.font = .mono
        }
        if data.settings.nightMode == "manual" || (premium && data.settings.isNight(at: date)) {
            face.faceID = "night"; face.foreground = nil; face.background = nil
        }
        face.showSeconds = false
        return face
    }
    var strings: ClockStrings { ClockFormat.strings(at: date, settings: configuration) }
    var nextChime: Date? {
        guard premium, data.settings.chime != "off", data.settings.nightMode != "manual" else { return nil }
        return ChimeScheduler.dates(now: date, window: data.settings.chimeWindow,
                                   night: data.settings.nightMode == "auto" ? data.settings.nightWindow : nil).first
    }
    static func entryDates(now: Date) -> [Date] {
        let start = floor(now.timeIntervalSince1970 / 60) * 60
        return [now] + (1..<60).map { Date(timeIntervalSince1970: start + Double($0) * 60) }
    }
}
