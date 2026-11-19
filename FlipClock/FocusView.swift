import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editDuration = false
    @State private var minutes = 25
    private var timer: FocusTimer? { model.data.timer }
    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width > geo.size.height
            if model.completionVisible {
                completion
            } else {
                VStack(spacing: compact ? 8 : 24) {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Text(title).font(.headline).foregroundStyle(Color.signal).accessibilityIdentifier("focusTitle")
                            if timer?.kind == .pomodoro {
                                HStack(spacing: 7) {
                                    ForEach(1...4, id: \.self) { i in
                                        Circle().fill(i <= ((timer?.round ?? 1) - 1) % 4 + 1 ? Color.signal : Color.gray.opacity(0.35)).frame(width: 6, height: 6)
                                    }
                                }.accessibilityHidden(true)
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, compact ? 10 : 45)
                    let pair = ClockFormat.timer(timer?.remaining(now: model.now) ?? 0)
                    ClockPair(first: pair.0, second: pair.1, face: model.face, configuration: model.configuration, animated: !model.demo)
                        .frame(maxHeight: compact ? 190 : 340).accessibilityElement(children: .ignore)
                        .accessibilityLabel(pair.0 + ":" + pair.1).accessibilityIdentifier("focusRemaining")
                    HStack(spacing: 8) {
                        Text(L.t("分 · 秒"))
                        if let end = timer?.endAt { Text(L.f("%@ 结束", end.formatted(date: .omitted, time: .shortened))) }
                        else { Text(L.t("已暂停")) }
                    }.font(.footnote).opacity(0.6)
                    if !compact { Spacer(minLength: 0) }
                    HStack(spacing: 12) {
                        Button { model.toggleTimer() } label: {
                            Text(timer?.isRunning == true ? L.t("暂停") : L.t("继续")).primaryAction()
                        }.accessibilityIdentifier("toggleTimer")
                        Menu {
                            if timer?.kind == .pomodoro { Button(L.t("跳过这一段")) { model.nextPhase() } }
                            Button(L.t("改时长")) { minutes = max(1, (timer?.remaining(now: model.now) ?? 1500) / 60); editDuration = true }
                            Button(L.t("结束计时"), role: .destructive) { model.endTimer() }
                        } label: {
                            Image(systemName: "ellipsis").frame(width: 50, height: 50).background(.gray.opacity(0.18), in: Circle())
                        }.accessibilityLabel(L.t("更多计时操作")).accessibilityIdentifier("timerMore")
                    }.frame(maxWidth: 440)
                    Button { model.sheet = .statistics } label: {
                        Text(L.f("今日专注 %@ · 连续 %d 天", durationText(model.todayMinutes), model.streak)).font(.footnote).opacity(0.6)
                    }.accessibilityIdentifier("openStatistics")
                    if model.notificationDenied { Text(L.t("通知已关闭，前台仍会提醒。可在系统设置开启通知。")).font(.caption).foregroundStyle(.secondary) }
                }.padding(.horizontal, compact ? 60 : 24).padding(.bottom, compact ? 8 : 28)
            }
        }
        .sheet(isPresented: $editDuration) {
            SheetFrame(title: L.t("改时长")) {
                Form {
                    Stepper(L.f("%d 分钟", minutes), value: $minutes, in: 1...180)
                    Button(L.t("应用时长")) { model.adjustTimer(minutes: minutes); editDuration = false }.accessibilityIdentifier("applyTimerDuration")
                }
            }.presentationDetents([.medium])
        }
    }
    private var title: String {
        guard let timer else { return L.t("计时结束") }
        return timer.kind == .pomodoro ? L.f("%@ · 第 %d 轮", timer.phase.title, timer.round) : L.t("倒计时")
    }
    private var completion: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle").font(.system(size: 40)).foregroundStyle(Color.signal).padding(.top, 50)
                Text(L.t("这一段时间，完成了。")).font(.title2).accessibilityIdentifier("timerCompleted")
                Text(L.f("今日专注 %@", durationText(model.todayMinutes))).foregroundStyle(.secondary)
                ForEach(model.milestones, id: \.self) { id in MilestoneView(milestone: id) }
                if timer?.kind == .pomodoro {
                    Button { model.nextPhase() } label: {
                        Text(timer?.isRunning == true ? L.t("返回计时") : L.f("开始%@", timer?.phase.title ?? L.t("专注"))).primaryAction()
                    }
                        .accessibilityIdentifier("nextPhase")
                }
                Button(L.t("返回时钟")) { model.screen = .clock; model.completionVisible = false }.frame(minHeight: 44)
            }.padding(24).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
    }
}

func durationText(_ minutes: Int) -> String { L.f("%d 小时 %d 分", minutes / 60, minutes % 60) }

struct TimerPickerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var customMinutes = 20
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(L.t("计时器")).font(.largeTitle.bold()).padding(.top, 50)
                Text(L.t("点一下时长，即刻开始")).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                    ForEach(model.timerMinutes, id: \.self) { minutes in
                        Button { model.startCountdown(minutes: minutes) } label: {
                            Text(L.f("%d 分钟", minutes)).font(.headline).frame(maxWidth: .infinity, minHeight: 58)
                                .background(.gray.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                        }.accessibilityIdentifier("duration-\(minutes)")
                    }
                }
                Stepper(L.f("自定 %d 分钟", customMinutes), value: $customMinutes, in: 1...180)
                Button { model.startCountdown(minutes: customMinutes) } label: { Text(L.t("开始自定倒计时")).primaryAction() }
                Button {
                    model.screen = .stopwatch
                    if !model.data.stopwatch.isRunning { model.data.stopwatch.start(now: model.now); model.persist() }
                } label: { Label(L.t("正计时"), systemImage: "stopwatch").frame(maxWidth: .infinity, minHeight: 48) }.accessibilityIdentifier("openStopwatch")
                if model.data.timer != nil {
                    Button(L.t("返回正在进行的计时")) { model.screen = .focus }.accessibilityIdentifier("returnToTimer")
                }
            }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
    }
}

struct StopwatchView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 16) {
                Text(L.t("正计时")).font(.headline).padding(.top, 45)
                let pair = ClockFormat.timer(Int(model.data.stopwatch.elapsed(now: model.now)))
                ClockPair(first: pair.0, second: pair.1, face: model.face, configuration: model.configuration)
                    .frame(height: min(geo.size.height * 0.42, 320))
                HStack {
                    Button(model.data.stopwatch.isRunning ? L.t("暂停") : L.t("继续")) {
                        if model.data.stopwatch.isRunning { model.data.stopwatch.pause(now: model.now) }
                        else { model.data.stopwatch.start(now: model.now) }; model.persist()
                    }.primaryAction().accessibilityIdentifier("toggleStopwatch")
                    Button(L.t("计次")) {
                        if model.requirePro() { model.data.stopwatch.lap(now: model.now); model.persist() }
                    }.frame(minWidth: 60, minHeight: 48).disabled(!model.data.stopwatch.isRunning).accessibilityIdentifier("lapStopwatch")
                    Button(L.t("重置")) { model.data.stopwatch.reset(); model.persist() }.frame(minWidth: 60, minHeight: 48).accessibilityIdentifier("resetStopwatch")
                }
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(model.data.stopwatch.laps.enumerated()), id: \.offset) { index, elapsed in
                            HStack {
                                Text(L.f("第 %d 次", model.data.stopwatch.laps.count - index)); Spacer()
                                let p = ClockFormat.timer(Int(elapsed))
                                Text(p.0 + ":" + p.1).monospacedDigit()
                            }
                        }
                    }
                }
            }.padding(.horizontal, 24).padding(.bottom, 12)
        }
    }
}
