import SwiftUI
import PhotosUI
import CoreImage.CIFilterBuiltins
import UIKit
import ImageIO

enum ShareRatio: String, CaseIterable, Identifiable {
    case square = "1:1", portrait = "3:4", story = "9:16"
    var id: String { rawValue }
    var height: CGFloat { switch self { case .square: return 360; case .portrait: return 480; case .story: return 640 } }
}

struct ShareView: View {
    @EnvironmentObject private var model: AppModel
    @State private var ratio: ShareRatio = .portrait
    @State private var includeStats = true
    @State private var photoItem: PhotosPickerItem?
    @State private var background: UIImage?
    @State private var rendered: UIImage?
    @State private var snapshotDate = Date()
    @State private var generation = 0
    @State private var photoTask: Task<Void, Never>?
    @State private var didOpen = false
    var body: some View {
        SheetFrame(title: L.t("分享桌搭")) {
            ScrollView {
                VStack(spacing: 18) {
                    if let rendered {
                        Image(uiImage: rendered).resizable().scaledToFit().frame(maxHeight: 460)
                            .clipShape(RoundedRectangle(cornerRadius: 18)).shadow(color: .black.opacity(0.12), radius: 15, y: 8)
                            .accessibilityLabel(L.t("桌搭分享图预览")).accessibilityIdentifier("sharePreview")
                    } else { ProgressView().frame(height: 300) }
                    Picker(L.t("图片比例"), selection: $ratio) { ForEach(ShareRatio.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    Toggle(L.t("显示今日专注"), isOn: $includeStats)
                    Text(L.t("话题文案已复制，可直接粘贴到分享文案。")).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $photoItem, matching: .images) { Label(L.t("用我的桌面照"), systemImage: "photo") }
                            .frame(maxWidth: .infinity, minHeight: 48).accessibilityIdentifier("chooseBackground")
                        if let rendered {
                            ShareLink(item: Image(uiImage: rendered), preview: SharePreview(L.t("分享桌搭"), image: Image(uiImage: rendered))) {
                                Text(L.t("保存 / 分享")).primaryAction()
                            }.accessibilityIdentifier("shareImage")
                        }
                    }
                    if background != nil { Button(L.t("移除背景照片")) { photoTask?.cancel(); generation += 1; photoItem = nil; background = nil; render() } }
                    Button(L.t("复制表盘口令")) {
                        guard model.requirePro(), let code = ShareCode.encode(model.configuration) else { return }
                        UIPasteboard.general.string = code; model.message = L.t("表盘口令已复制，朋友粘贴即可同款。")
                    }.frame(minHeight: 44).accessibilityIdentifier("copyShareCode")
                }.padding(22).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }.background(Color(uiColor: .systemGroupedBackground))
        }
        .onAppear {
            guard !didOpen else { return }; didOpen = true; snapshotDate = model.now
            UIPasteboard.general.string = L.t("#桌面布置 #桌搭 #翻页时钟 #学习打卡")
            render()
        }
        .onChange(of: ratio) { _, _ in render() }
        .onChange(of: includeStats) { _, _ in render() }
        .onChange(of: photoItem) { _, item in
            generation += 1; let token = generation; photoTask?.cancel()
            guard let item else { return }
            photoTask = Task { @MainActor in
                do {
                    guard let bytes = try await item.loadTransferable(type: Data.self), !Task.isCancelled, token == generation else { return }
                    guard let source = CGImageSourceCreateWithData(bytes as CFData, nil),
                          let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                            kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                            kCGImageSourceThumbnailMaxPixelSize: 2160] as CFDictionary) else {
                        model.message = L.t("照片无法读取，请换一张重试。"); return
                    }
                    let photo = UIImage(cgImage: thumbnail)
                    background = photo; render()
                } catch { if !Task.isCancelled { model.message = L.t("照片无法读取，请换一张重试。") } }
            }
        }
        .onDisappear { photoTask?.cancel() }
    }
    @MainActor private func render() {
        let card = DeskShareCard(configuration: model.configuration, date: snapshotDate, focusMinutes: includeStats ? model.todayMinutes : nil,
                                 background: background, premium: model.premium, height: ratio.height)
        let renderer = ImageRenderer(content: card.frame(width: 360, height: ratio.height)); renderer.scale = 3
        guard let image = renderer.uiImage else { model.message = L.t("图片暂时无法生成，请重试。"); return }
        rendered = image
        model.claimReview(.generatedShare); model.persist()
    }
}

struct DeskShareCard: View {
    let configuration: FaceConfiguration
    let date: Date
    let focusMinutes: Int?
    let background: UIImage?
    let premium: Bool
    let height: CGFloat
    var body: some View {
        let face = Face.find(configuration.faceID)
        let strings = ClockFormat.strings(at: date, settings: configuration)
        ZStack {
            Color(hex: configuration.background ?? face.background)
            if let background {
                Image(uiImage: background).resizable().scaledToFill().frame(width: 360, height: height).clipped()
                Color.black.opacity(0.30)
            }
            VStack(alignment: .leading, spacing: height == 360 ? 10 : 14) {
                Text(date.formatted(date: .complete, time: .omitted)).font(.system(size: 12)).opacity(0.65)
                Spacer(minLength: 0)
                ClockPair(first: strings.hour, second: strings.minute, face: face, configuration: configuration, period: strings.period, animated: false)
                    .frame(height: height == 360 ? 130 : 190)
                if height != 360 { HStack { Spacer(); Text(L.t(face.name)).font(.system(size: 12)).opacity(0.6); Spacer() } }
                if let focusMinutes {
                    VStack(spacing: 6) {
                        Text(L.t("今日专注")).font(.system(size: 12)).opacity(0.6)
                        Text(durationText(focusMinutes)).font(.system(size: height == 360 ? 22 : 25, weight: .semibold)).minimumScaleFactor(0.6).lineLimit(1)
                    }.frame(maxWidth: .infinity)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t("翻页时钟 · App Store 搜索同名")).font(.system(size: 10))
                        if !premium { Text("Flip Clock").font(.system(size: 9)).opacity(0.55) }
                    }.opacity(0.65)
                    Spacer()
                    if let qr = ShareArtwork.qrImage { Image(uiImage: qr).interpolation(.none).resizable().frame(width: 56, height: 56).padding(5).background(.white, in: RoundedRectangle(cornerRadius: 5)) }
                }
            }.padding(height == 360 ? 24 : 28)
        }.foregroundStyle(background == nil ? Color(hex: configuration.foreground ?? face.ink) : .white).clipped()
    }
}

enum ShareArtwork {
    static var storeURL: URL? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "APP_STORE_ID") as? String,
              !id.isEmpty, id.allSatisfy(\.isNumber) else { return nil }
        return URL(string: "https://apps.apple.com/app/id" + id)
    }
    static var qrImage: UIImage? {
        guard let url = storeURL else { return nil }
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(url.absoluteString.utf8); filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image)
    }
}
