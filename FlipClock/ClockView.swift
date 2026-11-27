import SwiftUI
import StoreKit
import UIKit

struct ClockView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var menuVisible = false
    @State private var menuTask: Task<Void, Never>?
    @State private var hintVisible = false
    @State private var shift = CGSize.zero
    @State private var lastShift = Date()
    @State private var countedClockSession = false
    private let firstTick = ClockFormat.nextSecond(after: Date())
    private var clockBackground: Color { Color(hex: model.configuration.background ?? model.face.background) }

    var body: some View {
        TimelineView(.periodic(from: firstTick, by: 1)) { context in
            GeometryReader { geo in
                ZStack {
                    clockBackground.ignoresSafeArea()
                    Group {
                        switch model.screen {
                        case .clock: clock(size: geo.size)
                        case .focus: FocusView()
                        case .timers: TimerPickerView()
                        case .stopwatch: StopwatchView()
                        }
                    }.offset(shift)
                }
                .overlay(alignment: .topLeading) {
                    if model.screen != .clock {
                        Button { model.screen = .clock } label: { Image(systemName: "clock") }
                            .accessibilityLabel(L.t("返回时钟")).accessibilityIdentifier("backToClock")
                            .padding(.horizontal, 18).padding(.vertical, 12)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if menuVisible { orientationMenu.padding(.horizontal, 18).padding(.vertical, 12) }
                }
                .overlay(alignment: .bottom) {
                    if menuVisible {
                        ClockMenuView(touch: restartMenuTimer, close: { menuVisible = false })
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if hintVisible && model.screen == .clock {
                        Text(L.t("轻点显示菜单")).font(.footnote).opacity(0.4)
                            .padding(.horizontal, 18).padding(.vertical, 12).allowsHitTesting(false)
                    }
                }
                .foregroundStyle(Color(hex: model.configuration.foreground ?? model.face.ink))
                .onChange(of: context.date) { _, date in
                    guard scenePhase == .active else { return }
                    model.tick(date)
                    if model.data.settings.burnIn && date.timeIntervalSince(lastShift) >= 180 {
                        lastShift = date
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 2)) {
                            shift = CGSize(width: CGFloat(Int.random(in: -6...6)), height: CGFloat(Int.random(in: -6...6)))
                        }
                    }
                }
            }
        }
        .statusBarHidden(true).persistentSystemOverlays(.hidden)
        .sheet(item: $model.sheet, onDismiss: updateIdleTimer) { route in
            switch route {
            case .picker: FacePickerView()
            case .share: ShareView()
            case .settings: SettingsView()
            case .paywall: PaywallView()
            case .help: WidgetHelpView()
            case .statistics: StatisticsView()
            }
        }
        .alert(L.t("提示"), isPresented: Binding(get: { model.message != nil && model.sheet == nil }, set: { if !$0 { model.message = nil } })) {
            Button(L.t("好")) { model.message = nil }
        } message: { Text(model.message ?? "") }
        .alert(L.t("电量低于 20%，继续常亮？"), isPresented: $model.lowBatteryPrompt) {
            Button(L.t("继续常亮"), role: .cancel) {}
            Button(L.t("关闭常亮")) { model.changeSettings { $0.keepAwake = false } }
        }
        .task {
            await model.start(); updateIdleTimer(); model.batteryCheck()
            lastShift = Date()
            if !model.data.hintShown {
                hintVisible = true; model.data.hintShown = true; model.persist()
                try? await Task.sleep(for: .seconds(3)); hintVisible = false
            }
        }
        .onChange(of: model.sheet) { _, _ in menuVisible = false; updateIdleTimer() }
        .onChange(of: model.screen) { _, _ in updateIdleTimer() }
        .onChange(of: model.data.settings.keepAwake) { _, _ in updateIdleTimer() }
        .onChange(of: model.data.settings.burnIn) { _, enabled in if !enabled { shift = .zero } }
        .reviewAfterCoreAction(when: reviewHome, alreadyRequested: model.reviewedThisVersion) {
            requestReview()
            model.markReviewRequested()
        }
        .task(id: reviewHome && model.reviewRequested && scenePhase == .active) {
            guard reviewHome, model.reviewRequested, scenePhase == .active, !model.reviewedThisVersion else { return }
            do { try await Task.sleep(for: .milliseconds(800)) } catch { return }
            guard !Task.isCancelled, reviewHome, !model.reviewedThisVersion else { return }
            if CoreReview.shared.attempt({ requestReview() }) { model.markReviewRequested() }
        }
        .task(id: reviewHome && scenePhase == .active && model.screen == .clock) {
            guard reviewHome, scenePhase == .active, model.screen == .clock, !countedClockSession else { return }
            do { try await Task.sleep(for: .seconds(60)) } catch { return }
            guard !Task.isCancelled, reviewHome, model.screen == .clock else { return }
            countedClockSession = true
            CoreReview.shared.record()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.tick(Date()); model.reschedule(); model.batteryCheck()
                if !model.isolated { model.live.sync(timer: model.data.timer, now: model.now, allowed: model.premium) }
            } else {
                if phase == .background { countedClockSession = false }
                model.persist(); model.sound.stop(); menuVisible = false
            }
            updateIdleTimer()
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false; menuTask?.cancel() }
        .onOpenURL { url in
            guard url.scheme == "flipclock" else { return }
            model.sheet = nil; model.tick(Date())
            model.screen = url.host == "focus" ? (model.data.timer == nil ? .timers : .focus) : .clock
        }
    }
    private var reviewHome: Bool {
        !model.isolated && model.sheet == nil && model.message == nil && !model.lowBatteryPrompt && !menuVisible
            && !model.completionVisible && model.data.timer?.isRunning != true
            && (model.screen == .clock || model.screen == .focus)
    }

    private func clock(size: CGSize) -> some View {
        let strings = ClockFormat.strings(at: model.now, settings: model.configuration)
        let vertical = size.height > size.width && !model.landscapeHint
        return ZStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { menuVisible.toggle() }
                if menuVisible { restartMenuTimer() }
            } label: {
                Rectangle().fill(clockBackground).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("clockSurface")
            .accessibilityLabel(strings.time)
            .accessibilityValue(model.configuration.faceID)
            .accessibilityHint(L.t("轻点显示菜单"))
            .overlay {
                ClockPair(first: strings.hour, second: strings.minute, face: model.face, configuration: model.configuration,
                          vertical: vertical, period: strings.period, animated: !model.demo)
                    .padding(.horizontal, vertical ? 36 : 65).padding(.vertical, vertical ? 70 : 38)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            VStack {
                HStack {
                    if let date = strings.date { Text(date) }
                    Spacer()
                    if let seconds = strings.second { Text(seconds).monospacedDigit() }
                }.font(.subheadline).opacity(0.55)
                Spacer()
                if model.effectiveSettings.isNight(at: model.now) {
                    Text(L.t("夜间 · 报时已静音")).font(.footnote).opacity(0.6)
                }
            }.padding(.horizontal, 28).padding(.vertical, 22).allowsHitTesting(false)
        }
    }
    private var orientationMenu: some View {
        Menu {
            ForEach(["system", "landscape", "portrait"], id: \.self) { value in
                Button {
                    model.changeSettings { $0.orientation = value }; OrientationController.apply(value); restartMenuTimer()
                } label: {
                    Label(orientationTitle(value), systemImage: model.data.settings.orientation == value ? "checkmark" : "iphone")
                }
            }
        } label: {
            Image(systemName: model.data.settings.orientation == "system" ? "rotate.right" : "lock.rotation")
                .frame(width: 44, height: 44).background(.black.opacity(0.55), in: Circle()).foregroundStyle(.white)
        }.accessibilityLabel(L.t("屏幕方向")).accessibilityIdentifier("orientationMenu")
    }
    private func orientationTitle(_ value: String) -> String {
        value == "system" ? L.t("跟随系统") : (value == "landscape" ? L.t("锁定横屏") : L.t("锁定竖屏"))
    }
    private func restartMenuTimer() {
        menuTask?.cancel()
        guard !model.isolated else { return }
        menuTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation { menuVisible = false }
        }
    }
    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = scenePhase == .active && model.sheet == nil && model.data.settings.keepAwake
            && (model.screen == .clock || model.screen == .focus || model.screen == .stopwatch)
    }
}

struct ClockMenuView: View {
    @EnvironmentObject private var model: AppModel
    let touch: () -> Void
    let close: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Face.all) { face in
                        Button { model.selectFace(face); touch() } label: {
                            RoundedRectangle(cornerRadius: 7).fill(Color(hex: face.top)).frame(width: 36, height: 28)
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(model.configuration.faceID == face.id ? Color.signal : .white.opacity(0.25), lineWidth: 2))
                                .overlay { if !face.free && !model.premium { Image(systemName: "lock.fill").font(.caption2).foregroundStyle(Color(hex: face.ink)) } }
                                .frame(minHeight: 44)
                        }.accessibilityLabel(L.t(face.name)).accessibilityIdentifier("quickFace-" + face.id)
                    }
                }.padding(.horizontal, 12)
            }.frame(maxWidth: 650).background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 16))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    action("更多表盘", icon: "square.grid.2x2", id: "openPicker") { model.sheet = .picker }
                    action("番茄钟", icon: "timer", id: "startPomodoro") { model.startPomodoro() }
                    action("计时器", icon: "stopwatch", id: "openTimers") { model.screen = .timers }
                    action("分享桌搭", icon: "square.and.arrow.up", id: "openShare") { model.sheet = .share }
                    action("设置", icon: "gearshape", id: "openSettings") { model.sheet = .settings }
                    PasteButton(payloadType: String.self) { texts in
                        if let text = texts.first { model.importCode(text) }; touch()
                    }.labelStyle(.iconOnly).tint(.gray).accessibilityLabel(L.t("粘贴口令")).accessibilityIdentifier("pasteCode")
                }.padding(6)
            }.accessibilityIdentifier("clockMenuActions").fixedSize(horizontal: false, vertical: true).frame(maxWidth: 700)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
        }.foregroundStyle(.white)
    }
    private func action(_ key: String, icon: String, id: String, run: @escaping () -> Void) -> some View {
        Button { touch(); close(); run() } label: {
            Label(L.t(key), systemImage: icon).font(.subheadline).fixedSize().padding(.horizontal, 12).frame(minHeight: 44)
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }
}
