import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        SheetFrame(title: L.t("设置")) {
            Form {
                Section(L.t("时钟")) {
                    Picker(L.t("时间格式"), selection: Binding(get: { model.data.face.format }, set: { value in model.changeFace { $0.format = value } })) {
                        ForEach(TimeFormat.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.menu).accessibilityIdentifier("timeFormat")
                    Toggle(L.t("显示秒"), isOn: face(\.showSeconds))
                    Toggle(L.t("显示日期"), isOn: face(\.showDate))
                    Toggle(L.t("显示上午 / 下午"), isOn: face(\.showPeriod))
                    if !ClockFormat.uses24(model.data.face.format, locale: .current) {
                        Toggle(L.t("小时不补 0（7:30）"), isOn: face(\.hideLeadingZero)).accessibilityIdentifier("hideLeadingZero")
                    }
                    Toggle(L.t("屏幕常亮"), isOn: setting(\.keepAwake))
                    Toggle(L.t("防烧屏微移"), isOn: setting(\.burnIn))
                }
                Section(L.t("声音")) {
                    Picker(L.t("翻页声"), selection: setting(\.flipSound, pro: true)) {
                        Text(L.t("关闭")).tag("off"); Text(L.t("机械")).tag("mechanical")
                        Text(L.t("轻木")).tag("wood"); Text(L.t("纸片")).tag("paper")
                    }
                    volume("翻页声音量", key: \.flipVolume, pro: true)
                    Picker(L.t("提示音"), selection: Binding(get: { model.data.settings.alertSound }, set: { value in
                        if value == "bell" || model.requirePro() { model.changeSettings { $0.alertSound = value } }
                    })) {
                        Text(L.t("清铃")).tag("bell"); Text(L.t("柔和")).tag("soft"); Text(L.t("双音")).tag("double")
                    }
                    volume("提示音量", key: \.alertVolume)
                    Toggle(L.t("只震动"), isOn: setting(\.vibrateOnly))
                    Toggle(L.t("提示音跟随静音键"), isOn: setting(\.respectSilent))
                    Button(L.t("试听提示音")) { model.sound.alert(settings: model.effectiveSettings) }
                }
                Section {
                    Picker(L.t("整点报时"), selection: setting(\.chime, pro: true)) {
                        Text(L.t("关闭")).tag("off"); Text(L.t("提示音")).tag("sound"); Text(L.t("语音")).tag("voice")
                    }
                    if model.data.settings.chime != "off" {
                        hourPicker("报时开始", key: \.chimeWindow.start)
                        hourPicker("报时结束", key: \.chimeWindow.end)
                    }
                } footer: { Text(L.t("后台报时使用通知提示音，语音仅在前台播放。通知声音由系统音量控制。")) }
                Section(L.t("夜间")) {
                    Picker(L.t("夜间模式"), selection: Binding(get: { model.data.settings.nightMode }, set: { value in
                        if value != "auto" || model.requirePro() { model.changeSettings { $0.nightMode = value } }
                    })) {
                        Text(L.t("关闭")).tag("off"); Text(L.t("手动开启")).tag("manual"); Text(L.t("定时自动")).tag("auto")
                    }
                    if model.data.settings.nightMode == "auto" {
                        hourPicker("夜间开始", key: \.nightWindow.start)
                        hourPicker("夜间结束", key: \.nightWindow.end)
                    }
                }
                Section(L.t("番茄钟")) {
                    Stepper(L.f("专注 %d 分钟", model.data.settings.plan.focus), value: setting(\.plan.focus, pro: true), in: 1...180)
                    Stepper(L.f("短休 %d 分钟", model.data.settings.plan.shortBreak), value: setting(\.plan.shortBreak, pro: true), in: 1...60)
                    Stepper(L.f("长休 %d 分钟", model.data.settings.plan.longBreak), value: setting(\.plan.longBreak, pro: true), in: 1...90)
                    Toggle(L.t("自动开始下一轮"), isOn: setting(\.plan.autoStart, pro: true))
                    Text(L.t("每完成 4 轮专注，安排一次长休。")).font(.footnote).foregroundStyle(.secondary)
                    Button(L.t("专注统计")) { model.sheet = .statistics }.accessibilityIdentifier("settingsStatistics")
                }
                Section(L.t("小组件与待机")) {
                    Toggle(L.t("透明小组件背景"), isOn: setting(\.transparentWidget, pro: true))
                    Button(L.t("添加小组件与待机说明")) { model.sheet = .help }.accessibilityIdentifier("widgetHelp")
                }
                if model.notificationDenied {
                    Section {
                        Text(L.t("通知已关闭，前台仍会提醒。可在系统设置开启通知。"))
                        if let url = URL(string: UIApplication.openSettingsURLString) { Link(L.t("打开系统设置"), destination: url) }
                    }
                }
                if !Launch.isFree {
                    Section {
                        if !model.data.entitlement.purchasedPro {
                            Button(model.premium ? L.f("试用剩余 %d 天", model.data.entitlement.remainingDays(at: model.now)) : L.t("解锁全部功能")) { model.sheet = .paywall }.accessibilityIdentifier("openPaywall")
                        }
                        Button(L.t("恢复购买")) { Task { await model.restore() } }.disabled(model.purchasing).accessibilityIdentifier("restorePurchases")
                    }
                }
                Section {
                    if let url = appURL("FlipClockPrivacyURL") { Link(L.t("隐私政策"), destination: url) }
                    if let url = appURL("FlipClockHelpURL") { Link(L.t("帮助与反馈"), destination: url) }
                    Text(L.t("数据仅保存在本机，无账号、无广告。")).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
    private func appURL(_ key: String) -> URL? { (Bundle.main.object(forInfoDictionaryKey: key) as? String).flatMap(URL.init(string:)) }
    private func face(_ key: WritableKeyPath<FaceConfiguration, Bool>) -> Binding<Bool> {
        Binding(get: { model.data.face[keyPath: key] }, set: { value in model.changeFace { $0[keyPath: key] = value } })
    }
    private func setting<T>(_ key: WritableKeyPath<ClockSettings, T>, pro: Bool = false) -> Binding<T> {
        Binding(get: { model.data.settings[keyPath: key] }, set: { value in
            guard !pro || model.requirePro() else { return }
            model.changeSettings { $0[keyPath: key] = value }
        })
    }
    private func volume(_ title: String, key: WritableKeyPath<ClockSettings, Double>, pro: Bool = false) -> some View {
        VStack(alignment: .leading) {
            HStack { Text(L.t(title)); Spacer(); Text(model.data.settings[keyPath: key], format: .percent.precision(.fractionLength(0))).foregroundStyle(.secondary) }
            Slider(value: setting(key, pro: pro), in: 0...1).accessibilityLabel(L.t(title))
        }
    }
    private func hourPicker(_ title: String, key: WritableKeyPath<ClockSettings, Int>) -> some View {
        Picker(L.t(title), selection: setting(key, pro: true)) { ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) } }
    }
}

struct WidgetHelpView: View {
    var body: some View {
        SheetFrame(title: L.t("小组件与待机")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    instruction("rectangle.grid.2x2", title: "桌面小组件", detail: "长按桌面空白处，选择编辑与添加小组件，搜索翻页时钟，选择小、中或大号。")
                    instruction("lock", title: "锁屏小组件", detail: "长按锁屏，轻点自定，在小组件区域添加翻页时钟。时间格式跟随 App 设置。")
                    instruction("iphone.gen3.landscape", title: "待机显示", detail: "在系统设置开启待机显示。充电、锁屏并横放 iPhone，长按待机小组件，添加翻页时钟或专注计时。")
                    Text(L.t("小组件按分钟更新，由系统决定刷新时机；系统不支持每秒真翻页。App 内提供完整翻页动画。"))
                    Text(L.t("透明背景由系统决定是否保留。待机的夜间红色由 iOS 自动处理。"))
                    Text(L.t("通知提示音最长 30 秒。后台无法单独调整通知音量，也无法保证只震动或跟随静音设置，请结合系统通知设置使用。"))
                }.padding(24).foregroundStyle(.secondary)
            }
        }
    }
    private func instruction(_ symbol: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 40)).foregroundStyle(Color.signal).accessibilityHidden(true)
            Text(L.t(title)).font(.title3.bold()).foregroundStyle(.primary)
            Text(L.t(detail))
        }
    }
}

struct StatisticsView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        SheetFrame(title: L.t("专注统计")) {
            List {
                LabeledContent(L.t("今日"), value: durationText(model.todayMinutes))
                LabeledContent(L.t("本周"), value: durationText(model.data.stats.weekMinutes(now: model.now)))
                LabeledContent(L.t("累计"), value: durationText(model.data.stats.totalMinutes))
                LabeledContent(L.t("连续天数"), value: L.f("%d 天", model.streak))
                Section(L.t("最近专注")) {
                    ForEach(model.data.stats.records.sorted { $0.startedAt > $1.startedAt }.prefix(50)) { record in
                        LabeledContent(record.startedAt.formatted(date: .abbreviated, time: .shortened), value: durationText(Int(record.duration / 60)))
                    }
                    if model.data.stats.records.isEmpty { Text(L.t("完成一段专注后，记录会显示在这里。")).foregroundStyle(.secondary) }
                }
            }
        }
    }
}
