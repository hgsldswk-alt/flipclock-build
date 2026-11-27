import SwiftUI

struct FlipCardView: View {
    let value: String
    let face: Face
    var configuration = FaceConfiguration()
    var period: String? = nil
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var old = ""
    @State private var shown = ""
    @State private var topAngle: Double = 0
    @State private var bottomAngle: Double = 90
    @State private var flipping = false
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                half(shown.isEmpty ? value : shown, upper: true, width: w, height: h).offset(y: -h / 4)
                half(flipping ? old : (shown.isEmpty ? value : shown), upper: false, width: w, height: h).offset(y: h / 4)
                if flipping {
                    half(old, upper: true, width: w, height: h)
                        .rotation3DEffect(.degrees(topAngle), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.45).offset(y: -h / 4).zIndex(2)
                    half(shown, upper: false, width: w, height: h)
                        .overlay(Color.black.opacity(bottomAngle > 0 ? 0.20 : 0))
                        .rotation3DEffect(.degrees(bottomAngle), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.45).offset(y: h / 4).zIndex(3)
                }
                Rectangle().fill(Color(hex: face.seam)).frame(height: max(1, w / 180))
                if face.id != "line" {
                    HStack { pin; Spacer(); pin }.padding(.horizontal, w * 0.018)
                }
                if let period { Text(period).font(.system(size: max(10, w * 0.06), weight: .medium)).foregroundStyle(ink.opacity(0.65)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(w * 0.075) }
            }
            .frame(width: w, height: h).clipShape(RoundedRectangle(cornerRadius: face.id == "line" ? 0 : w * 0.08))
            .shadow(color: .black.opacity(face.id == "night" || face.id == "line" ? 0 : 0.22), radius: w * 0.045, y: w * 0.025)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel(value)
        .onAppear { shown = value; old = value }
        .onChange(of: value) { _, next in change(to: next) }
        .onDisappear { animationTask?.cancel() }
    }
    private var ink: Color { Color(hex: configuration.foreground ?? face.ink) }
    private var pin: some View { Capsule().fill(Color(hex: face.seam)).frame(width: 4, height: 12) }
    private func half(_ text: String, upper: Bool, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if face.id == "glass" { Rectangle().fill(.ultraThinMaterial) }
            Color(hex: upper ? face.top : face.bottom)
            Text(text).font(.system(size: width * (face.id == "line" ? 0.68 : 0.66), weight: face.id == "line" ? .light : .bold,
                                   design: configuration.font == .serif ? .serif : .default))
                .monospacedDigit().fontWidth(configuration.font == .condensed ? .condensed : .standard)
                .foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.35).padding(.horizontal, width * 0.055).contentTransition(.opacity)
        }
        .frame(width: width, height: height)
        .offset(y: upper ? height / 4 : -height / 4)
        .frame(width: width, height: height / 2).clipped()
    }
    private func change(to next: String) {
        animationTask?.cancel()
        guard animated, !reduceMotion else {
            flipping = false
            withAnimation(.easeInOut(duration: 0.18)) { shown = next }
            return
        }
        old = shown; shown = next; topAngle = 0; bottomAngle = 90; flipping = true
        animationTask = Task { @MainActor in
            withAnimation(.easeIn(duration: 0.22)) { topAngle = -90 }
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            withAnimation(.interpolatingSpring(stiffness: 260, damping: 24)) { bottomAngle = 0 }
            try? await Task.sleep(for: .milliseconds(230))
            guard !Task.isCancelled else { return }; flipping = false
        }
    }
}

struct ClockPair: View {
    let first: String; let second: String; let face: Face; let configuration: FaceConfiguration
    var vertical = false
    var period: String? = nil
    var animated = true
    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = vertical ? 20 : 16
            let w = max(0, vertical ? min(geo.size.width, (geo.size.height - gap) / 1.66) : min((geo.size.width - gap) / 2, geo.size.height / 0.84))
            let h = w * 0.83
            let layout = vertical ? AnyLayout(VStackLayout(spacing: gap)) : AnyLayout(HStackLayout(spacing: gap))
            layout {
                FlipCardView(value: first, face: face, configuration: configuration, period: period, animated: animated).frame(width: w, height: h)
                FlipCardView(value: second, face: face, configuration: configuration, animated: animated).frame(width: w, height: h)
            }.frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
