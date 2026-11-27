import Foundation

enum TimeFormat: String, Codable, CaseIterable { case system, twelve, twentyFour
    var title: String { switch self { case .system: return L.t("跟随系统"); case .twelve: return L.t("12 小时制"); case .twentyFour: return L.t("24 小时制") } }
}
struct ClockStrings: Equatable {
    let hour: String; let minute: String; let second: String?; let period: String?; let date: String?
    var time: String { hour + ":" + minute + (second.map { ":" + $0 } ?? "") + (period.map { " " + $0 } ?? "") }
}
enum ClockFormat {
    static func uses24(_ format: TimeFormat, locale: Locale) -> Bool {
        switch format {
        case .twentyFour: return true
        case .twelve: return false
        case .system:
            let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "HH"
            return pattern.contains("H") || pattern.contains("k")
        }
    }
    static func strings(at date: Date, calendar: Calendar = .current, locale: Locale = .current, settings: FaceConfiguration) -> ClockStrings {
        let h = calendar.component(.hour, from: date), m = calendar.component(.minute, from: date)
        let is24 = uses24(settings.format, locale: locale)
        let hour = is24 ? h : (h % 12 == 0 ? 12 : h % 12)
        let chinese = locale.language.languageCode?.identifier == "zh"
        let period = settings.showPeriod && !is24 ? (chinese ? (h < 12 ? LString.morning : LString.afternoon) : (h < 12 ? "AM" : "PM")) : nil
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMM d EEE")
        return ClockStrings(hour: !is24 && settings.hideLeadingZero ? String(hour) : String(format: "%02d", hour), minute: String(format: "%02d", m),
                            second: settings.showSeconds ? String(format: "%02d", calendar.component(.second, from: date)) : nil,
                            period: period, date: settings.showDate ? formatter.string(from: date) : nil)
    }
    private enum LString { static let morning = "上午"; static let afternoon = "下午" }
    static func nextSecond(after date: Date) -> Date { Date(timeIntervalSince1970: floor(date.timeIntervalSince1970) + 1) }
    static func timer(_ seconds: Int) -> (String, String) { (String(format: "%02d", max(0, seconds) / 60), String(format: "%02d", max(0, seconds) % 60)) }
}
