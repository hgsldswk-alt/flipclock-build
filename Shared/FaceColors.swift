import SwiftUI

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0
        let hasAlpha = hex.count == 8
        let rgb = hasAlpha ? value >> 8 : value
        self.init(.sRGB, red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255,
                  blue: Double(rgb & 255) / 255, opacity: hasAlpha ? Double(value & 255) / 255 : 1)
    }
}
