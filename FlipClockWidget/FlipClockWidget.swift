import SwiftUI
import WidgetKit

struct ClockEntry: TimelineEntry {
    let date: Date
    let data: AppData
    var snapshot: WidgetSnapshot { WidgetSnapshot(data: data, date: date) }
}

struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { ClockEntry(date: Date(), data: AppData()) }
    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: Date(), data: (try? Store.load()) ?? AppData()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let now = Date(), data = (try? Store.load()) ?? AppData()
        let entries = WidgetSnapshot.entryDates(now: now).map { ClockEntry(date: $0, data: data) }
        let next = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970 / 60) * 60 + 3600)
        completion(Timeline(entries: entries, policy: .after(next)))
    }
}

struct WidgetCard: View {
    let value: String
    let face: Face
    let configuration: FaceConfiguration
    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) { Color(hex: face.top); Color(hex: face.bottom) }
                Text(value).font(.system(size: geo.size.width * 0.65, weight: .bold, design: configuration.font == .serif ? .serif : .default))
                    .fontWidth(configuration.font == .condensed ? .condensed : .standard).monospacedDigit()
                    .foregroundStyle(Color(hex: configuration.foreground ?? face.ink)).lineLimit(1).minimumScaleFactor(0.3).padding(.horizontal, 4)
                    .contentTransition(.numericText())
                Rectangle().fill(Color(hex: face.seam)).frame(height: 1.5)
            }.clipShape(RoundedRectangle(cornerRadius: geo.size.width * 0.08))
        }
    }
}

struct ClockWidgetView: View {
    let entry: ClockEntry
    var focusOnly = false
    @Environment(\.widgetFamily) private var family
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var face: Face { Face.find(snapshot.configuration.faceID) }
    private var locked: Bool {
        !snapshot.premium && (focusOnly || family == .systemMedium || family == .systemLarge
                              || (family == .systemSmall && (!showsBackground || entry.data.settings.transparentWidget)))
    }
    var body: some View {
        Group {
            if locked {
                VStack(spacing: 8) {
                    Image(systemName: "lock"); Text(L.t("打开 App 解锁全部小组件")).font(.caption).multilineTextAlignment(.center)
                }
            } else {
                switch family {
                case .accessoryCircular: circular
                case .accessoryRectangular: rectangular
                case .accessoryInline: inline
                default: desktop
                }
            }
        }
        .containerBackground(for: .widget) {
            if !(snapshot.premium && entry.data.settings.transparentWidget) { Color(hex: snapshot.configuration.background ?? face.background) }
        }
        .widgetURL(URL(string: focusOnly ? "flipclock://focus" : "flipclock://clock"))
        .accessibilityElement(children: .combine)
    }
    private var desktop: some View {
        VStack(spacing: family == .systemLarge ? 16 : 7) {
            if focusOnly {
                Text(L.t("专注计时")).font(.caption).foregroundStyle(ink.opacity(0.65))
                if let timer = entry.data.timer, timer.isRunning || timer.isPaused { timerText(timer).font(.system(size: 40, weight: .bold)).minimumScaleFactor(0.5) }
                else { Text(L.t("开始一段专注")).font(.headline).foregroundStyle(ink) }
            } else {
                if family == .systemLarge, let date = snapshot.strings.date { Text(date).font(.subheadline).foregroundStyle(ink.opacity(0.65)) }
                GeometryReader { geo in
                    let height = min(geo.size.height, (geo.size.width - 8) / 2 * 0.83)
                    HStack(spacing: 8) {
                        WidgetCard(value: snapshot.strings.hour, face: face, configuration: snapshot.configuration)
                        WidgetCard(value: snapshot.strings.minute, face: face, configuration: snapshot.configuration)
                    }.frame(height: height).frame(maxHeight: .infinity)
                }
                if let period = snapshot.strings.period { Text(period).font(.caption2).foregroundStyle(ink.opacity(0.65)) }
                if family != .systemSmall, let timer = entry.data.timer, timer.isRunning || timer.isPaused {
                    HStack { Text(timer.kind == .pomodoro ? timer.phase.title : L.t("倒计时")); Spacer(); timerText(timer) }.font(.caption).foregroundStyle(ink)
                }
            }
        }
    }
    private var circular: some View {
        VStack(spacing: 2) {
            if let timer = entry.data.timer, timer.isRunning || timer.isPaused {
                Image(systemName: "timer").font(.caption2)
                timerText(timer).font(.caption2).minimumScaleFactor(0.5)
            } else {
                Text(snapshot.strings.hour).font(.headline)
                Text(snapshot.strings.minute).font(.title3.bold()).contentTransition(.numericText())
                if let period = snapshot.strings.period { Text(period).font(.system(size: 8)) }
            }
        }
    }
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(snapshot.strings.time).font(.headline).monospacedDigit().contentTransition(.numericText())
            if let timer = entry.data.timer, timer.isRunning || timer.isPaused { timerText(timer).font(.caption) }
            else if let next = snapshot.nextChime {
                Text(L.f("下次报时 %@", ClockFormat.strings(at: next, settings: snapshot.configuration).time)).font(.caption2)
            } else { Text(L.t("翻页时钟")).font(.caption) }
        }
    }
    private var inline: some View { Text(snapshot.strings.time).monospacedDigit() }
    private var ink: Color { Color(hex: snapshot.configuration.foreground ?? face.ink) }
    @ViewBuilder private func timerText(_ timer: FocusTimer) -> some View {
        if let end = timer.endAt, end > entry.date {
            Text(timerInterval: entry.date...end, countsDown: true).monospacedDigit()
        } else {
            let p = ClockFormat.timer(timer.remaining(now: entry.date))
            Text(p.0 + ":" + p.1).monospacedDigit()
        }
    }
}

struct FlipClockHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlipClock.Clock", provider: ClockProvider()) { ClockWidgetView(entry: $0) }
            .configurationDisplayName(L.t("翻页时钟")).description(L.t("与你的表盘同步，锁屏也支持 12 小时制。"))
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
struct FlipClockFocusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlipClock.Focus", provider: ClockProvider()) { ClockWidgetView(entry: $0, focusOnly: true) }
            .configurationDisplayName(L.t("待机 · 专注计时")).description(L.t("在待机小组件中查看正在进行的番茄钟或倒计时。"))
            .supportedFamilies([.systemSmall])
    }
}

@main
struct FlipClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlipClockHomeWidget()
        FlipClockFocusWidget()
        FlipClockLiveActivity()
    }
}
