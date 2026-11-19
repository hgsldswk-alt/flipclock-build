import SwiftUI

struct FacePickerView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        SheetFrame(title: L.t("表盘")) {
            ScrollView {
                VStack(spacing: 22) {
                    let strings = ClockFormat.strings(at: model.now, settings: model.configuration)
                    ClockPair(first: strings.hour, second: strings.minute, face: model.face, configuration: model.configuration,
                              period: strings.period, animated: false)
                        .frame(height: 180).padding(24)
                        .background(Color(hex: model.configuration.background ?? model.face.background), in: RoundedRectangle(cornerRadius: 22))
                        .accessibilityIdentifier("facePreview")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                        ForEach(Face.all) { face in
                            Button { model.selectFace(face) } label: {
                                VStack(spacing: 7) {
                                    HStack(spacing: 3) {
                                        mini("1", face: face); mini("0", face: face)
                                    }.frame(maxWidth: .infinity, minHeight: 68)
                                        .background(Color(hex: face.background), in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.data.face.faceID == face.id ? Color.signal : .clear, lineWidth: 2))
                                        .overlay(alignment: .topTrailing) {
                                            if !face.free && !model.premium { Image(systemName: "lock.fill").font(.caption2).padding(5).foregroundStyle(Color(hex: face.ink)) }
                                        }
                                    Text(L.t(face.name)).font(.caption).foregroundStyle(.primary)
                                }
                            }.buttonStyle(.plain).accessibilityIdentifier("face-" + face.id)
                                .accessibilityAddTraits(model.data.face.faceID == face.id ? .isSelected : [])
                        }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text(L.t("数字字体")).font(.subheadline).foregroundStyle(.secondary)
                        Picker(L.t("数字字体"), selection: Binding(get: { model.data.face.font }, set: { font in
                            if model.requirePro() { model.changeFace { $0.font = font } }
                        })) { ForEach(DigitFont.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                        Toggle(L.t("显示秒"), isOn: faceBinding(\.showSeconds)).accessibilityIdentifier("pickerSeconds")
                        Toggle(L.t("显示日期"), isOn: faceBinding(\.showDate))
                        ColorPicker(L.t("数字颜色"), selection: colorBinding(foreground: true), supportsOpacity: false)
                        ColorPicker(L.t("背景颜色"), selection: colorBinding(foreground: false), supportsOpacity: false)
                        Button(L.t("恢复表盘原色")) { model.changeFace { $0.foreground = nil; $0.background = nil } }
                    }
                }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
            }.background(Color(uiColor: .systemGroupedBackground))
        }
    }
    private func mini(_ text: String, face: Face) -> some View {
        Text(text).font(.system(size: 20, weight: .bold)).foregroundStyle(Color(hex: face.ink))
            .frame(width: 23, height: 34).background(Color(hex: face.top), in: RoundedRectangle(cornerRadius: 4))
    }
    private func faceBinding(_ key: WritableKeyPath<FaceConfiguration, Bool>) -> Binding<Bool> {
        Binding(get: { model.data.face[keyPath: key] }, set: { value in model.changeFace { $0[keyPath: key] = value } })
    }
    private func colorBinding(foreground: Bool) -> Binding<Color> {
        Binding(get: { Color(hex: foreground ? (model.data.face.foreground ?? model.face.ink) : (model.data.face.background ?? model.face.background)) }, set: { color in
            guard model.requirePro() else { return }
            model.changeFace { if foreground { $0.foreground = color.hexRGB } else { $0.background = color.hexRGB } }
        })
    }
}
