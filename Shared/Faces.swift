import Foundation

enum DigitFont: String, Codable, CaseIterable { case mono, condensed, serif
    var title: String { switch self { case .mono: return L.t("等宽"); case .condensed: return L.t("窄体"); case .serif: return L.t("衬线") } }
}
struct Face: Identifiable, Equatable {
    let id: String
    let name: String
    let background: String
    let top: String
    let bottom: String
    let ink: String
    let seam: String
    let free: Bool
    static let all: [Face] = [
        Face(id: "ink", name: "墨", background: "111111", top: "232323", bottom: "1E1E1E", ink: "EDE8DF", seam: "090909", free: true),
        Face(id: "paper", name: "纸", background: "F2EEE6", top: "FDFBF6", bottom: "F5F1E9", ink: "1C1C1C", seam: "CFC8BC", free: true),
        Face(id: "mist", name: "雾", background: "D9DBD8", top: "EEF0ED", bottom: "E4E6E2", ink: "3A3D3B", seam: "BEC2BC", free: true),
        Face(id: "night", name: "夜", background: "000000", top: "120C0B", bottom: "0E0909", ink: "8A2A20", seam: "000000", free: true),
        Face(id: "blush", name: "樱", background: "F3E3E0", top: "FFFDFC", bottom: "FAF3F1", ink: "7A4B4B", seam: "DECBC7", free: false),
        Face(id: "oat", name: "燕麦", background: "E9DFCF", top: "F7F0E4", bottom: "EFE5D5", ink: "5A4535", seam: "CEBFA9", free: false),
        Face(id: "olive", name: "橄榄", background: "2E3A2F", top: "36443A", bottom: "303D33", ink: "EDE6D6", seam: "1F2A22", free: false),
        Face(id: "navy", name: "海军", background: "16202E", top: "22303F", bottom: "1C2938", ink: "E9E4DA", seam: "0F1722", free: false),
        Face(id: "signal", name: "橘", background: "151515", top: "232323", bottom: "1E1E1E", ink: "E8632B", seam: "090909", free: false),
        Face(id: "walnut", name: "胡桃", background: "5B3E2B", top: "2A2420", bottom: "231E1B", ink: "EFE6D3", seam: "16120F", free: false),
        Face(id: "glass", name: "玻璃", background: "9AA6AA", top: "C3CBCDA0", bottom: "B1BEC180", ink: "FFFFFF", seam: "829194", free: false),
        Face(id: "line", name: "极简", background: "F4F3F0", top: "F4F3F000", bottom: "F4F3F000", ink: "111111", seam: "999999", free: false)
    ]
    static func find(_ id: String) -> Face { all.first { $0.id == id } ?? all[0] }
    var fallbackID: String { ["paper", "mist", "night"].contains(id) ? id : (["blush", "oat", "line", "glass"].contains(id) ? "paper" : "ink") }
}
struct FaceConfiguration: Codable, Equatable {
    var faceID = "ink"
    var foreground: String?
    var background: String?
    var font: DigitFont = .mono
    var format: TimeFormat = .system
    var showSeconds = false
    var showDate = true
    var showPeriod = true
    var hideLeadingZero = false
    var isValid: Bool {
        Face.all.contains { $0.id == faceID } && [foreground, background].allSatisfy { $0 == nil || Self.validHex($0!) }
    }
    static func validHex(_ value: String) -> Bool { value.count == 6 && value.utf8.allSatisfy { (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) } }
    enum CodingKeys: String, CodingKey { case faceID, foreground, background, font, format, showSeconds, showDate, showPeriod, hideLeadingZero }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        faceID = try c.decodeIfPresent(String.self, forKey: .faceID) ?? "ink"
        foreground = try c.decodeIfPresent(String.self, forKey: .foreground); background = try c.decodeIfPresent(String.self, forKey: .background)
        font = try c.decodeIfPresent(DigitFont.self, forKey: .font) ?? .mono
        format = try c.decodeIfPresent(TimeFormat.self, forKey: .format) ?? .system
        showSeconds = try c.decodeIfPresent(Bool.self, forKey: .showSeconds) ?? false
        showDate = try c.decodeIfPresent(Bool.self, forKey: .showDate) ?? true
        showPeriod = try c.decodeIfPresent(Bool.self, forKey: .showPeriod) ?? true
        hideLeadingZero = try c.decodeIfPresent(Bool.self, forKey: .hideLeadingZero) ?? false
    }
}
