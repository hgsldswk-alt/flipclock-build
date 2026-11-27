import SwiftUI
import UIKit

struct MilestoneCard: View {
    let milestone: String
    let start: Date
    let end: Date
    let configuration: FaceConfiguration
    var body: some View {
        let parts = milestone.split(separator: "-")
        let number = parts.last.flatMap { Int($0) } ?? 100
        let face = Face.find(configuration.faceID)
        VStack(spacing: 24) {
            Text(L.t("每一段专注，都算数。")).font(.system(size: 16)).opacity(0.6)
            Spacer()
            Text(String(number)).font(.system(size: 92, weight: .bold, design: .serif)).minimumScaleFactor(0.5).lineLimit(1)
            Text(milestone.hasPrefix("hours-") ? L.t("小时专注") : L.t("天连续专注")).font(.system(size: 22))
            Text(start.formatted(date: .abbreviated, time: .omitted) + " — " + end.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 12)).opacity(0.6)
            Spacer()
            HStack {
                Text(L.t("翻页时钟 · App Store 搜索同名")).font(.system(size: 10)).opacity(0.65)
                Spacer()
                if let image = ShareArtwork.qrImage { Image(uiImage: image).interpolation(.none).resizable().frame(width: 52, height: 52).padding(5).background(.white) }
            }
        }.padding(28).frame(width: 360, height: 480)
            .foregroundStyle(Color(hex: configuration.foreground ?? face.ink)).background(Color(hex: configuration.background ?? face.background))
    }
}

struct MilestoneView: View {
    @EnvironmentObject private var model: AppModel
    let milestone: String
    @State private var image: UIImage?
    var body: some View {
        VStack(spacing: 14) {
            if let image {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 340).clipShape(RoundedRectangle(cornerRadius: 20))
                    .accessibilityIdentifier("milestoneCard")
                ShareLink(item: Image(uiImage: image), preview: SharePreview(L.t("专注里程碑"), image: Image(uiImage: image))) {
                    Label(L.t("分享这份坚持"), systemImage: "square.and.arrow.up").primaryAction()
                }.accessibilityIdentifier("shareMilestone")
            }
        }.task {
            let start = model.data.stats.records.map(\.startedAt).min() ?? model.now
            let renderer = ImageRenderer(content: MilestoneCard(milestone: milestone, start: start, end: model.now, configuration: model.configuration))
            renderer.scale = 3; image = renderer.uiImage
        }
    }
}
