import ActivityKit
import WidgetKit
import SwiftUI

struct ActivityTimerText: View {
    let state: TimerActivityAttributes.ContentState
    var body: some View {
        if state.paused {
            let p = ClockFormat.timer(state.remaining)
            Text(p.0 + ":" + p.1).monospacedDigit()
        } else {
            let now = Date()
            Text(timerInterval: now...max(now, state.endAt), countsDown: true).monospacedDigit()
        }
    }
}

struct FlipClockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            HStack(spacing: 18) {
                Image(systemName: "timer").font(.title2).foregroundStyle(Color(hex: "E8632B"))
                VStack(alignment: .leading, spacing: 5) {
                    Text(L.f("%@ · 第 %d 轮", context.state.title, context.state.round)).font(.subheadline)
                    Text(context.state.paused ? L.t("已暂停") : L.f("%@ 结束", context.state.endAt.formatted(date: .omitted, time: .shortened))).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                ActivityTimerText(state: context.state).font(.system(size: 30, weight: .bold)).foregroundStyle(Color(hex: "E8632B")).frame(maxWidth: 145)
            }.padding(18).activityBackgroundTint(Color(hex: "191919")).activitySystemActionForegroundColor(.white)
                .foregroundStyle(.white).widgetURL(URL(string: "flipclock://focus"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label(context.state.title, systemImage: "timer").font(.headline) }
                DynamicIslandExpandedRegion(.trailing) { Text(L.f("第 %d 轮", context.state.round)).font(.caption) }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
                        ActivityTimerText(state: context.state).font(.largeTitle.bold())
                        if context.state.paused { Text(L.t("已暂停")).font(.caption) }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.paused ? "pause.fill" : "timer").foregroundStyle(Color(hex: "E8632B"))
            } compactTrailing: {
                ActivityTimerText(state: context.state).font(.caption).frame(width: 52)
            } minimal: {
                Image(systemName: context.state.paused ? "pause.fill" : "timer")
            }
            .widgetURL(URL(string: "flipclock://focus")).keylineTint(Color(hex: "E8632B"))
        }
    }
}
