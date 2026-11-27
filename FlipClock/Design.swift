import SwiftUI
import UIKit

extension Color {
    var hexRGB: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
    static let signal = Color(hex: "E8632B")
}
struct SheetFrame<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    var body: some View {
        NavigationStack {
            content().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel(L.t("关闭")).accessibilityIdentifier("closeSheet")
                } }
        }.tint(.signal)
            .alert(L.t("提示"), isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
                Button(L.t("好")) { model.message = nil }
            } message: { Text(model.message ?? "") }
    }
}
extension View {
    func primaryAction() -> some View { self.font(.headline).frame(maxWidth: .infinity, minHeight: 48).background(Color.primary, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(Color(uiColor: .systemBackground)) }
}
