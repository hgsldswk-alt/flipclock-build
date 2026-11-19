import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        SheetFrame(title: Launch.isFree ? L.t("翻页时钟") : L.t("解锁全部功能")) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if Launch.isFree {
                        Text(L.t("本版本所有功能均可使用。")).font(.title2)
                    } else {
                        Text(L.t("让桌面，成为你的专注空间。")).font(.largeTitle.bold())
                        Text(L.t("12 款表盘、自定义配色与字体、翻页声、整点报时、实时活动与全部小组件。"))
                        Text(L.t("一次买断，无广告。换手机可用同一 Apple ID 恢复购买。")).foregroundStyle(.secondary)
                        Text(L.f("试用剩余 %d 天", model.data.entitlement.remainingDays(at: model.now)))
                        if let product = model.products.first(where: { $0.id == model.proID }) {
                            Button { Task { await model.purchase(product.id) } } label: { Text(L.f("一次买断 %@", product.displayPrice)).primaryAction() }
                                .accessibilityIdentifier("buyPro")
                        }
                        if model.data.entitlement.trialClaimedAt == nil, model.now < model.data.entitlement.trialEnd,
                           let trial = model.products.first(where: { $0.id == model.trialID }) {
                            Button(L.t("领取 30 天试用凭证")) { Task { await model.purchase(trial.id) } }.frame(minHeight: 44)
                            Text(L.t("试用从收费版首次启动或已领取凭证的较早日期起算，不会重复延长。")).font(.footnote).foregroundStyle(.secondary)
                        }
                        if model.products.isEmpty && !model.productLoadFailed { ProgressView().frame(maxWidth: .infinity) }
                        if model.productLoadFailed {
                            Text(L.t("暂时无法载入价格，请检查网络后重试。"))
                            Button(L.t("重试")) { Task { await model.loadProducts() } }
                        }
                        Button(L.t("恢复购买")) { Task { await model.restore() } }.accessibilityIdentifier("paywallRestore")
                        Text(L.t("试用结束后，免费时钟、基础计时与已有记录仍可使用。")).font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(28).frame(maxWidth: 560).frame(maxWidth: .infinity).disabled(model.purchasing)
            }
        }.task { await model.loadProducts() }
    }
}
