//
//  PaywallPricing.swift
//  Poca
//
//  把 StoreKit Product 翻译成 Paywall 的展示文案。此文件不含任何 View，
//  也不持有 SubscriptionManager，因此可以用假 Product 构造来单独验证文案分支。
//

import Foundation
import StoreKit

typealias PaywallPlanType = SubscriptionManager.SubscriptionType

// MARK: - Plan

/// Paywall 的套餐条目：决定展示顺序与标题，价格与副文案由 PaywallPricing 计算
struct PaywallPlan: Identifiable {
    let type: PaywallPlanType
    /// 套餐名（本地化后的显示值）
    let name: String
    /// 价格下方的说明。订阅是计费周期，买断是"一次性购买"，故不叫 period
    let priceCaption: String

    var id: PaywallPlanType { type }

    static let all: [PaywallPlan] = [
        PaywallPlan(type: .yearly, name: L10n.string("Yearly plan"), priceCaption: L10n.string("/ year")),
        PaywallPlan(type: .monthly, name: L10n.string("Monthly membership"), priceCaption: L10n.string("/ month")),
        PaywallPlan(type: .lifetime, name: L10n.string("Lifetime unlock"), priceCaption: L10n.string("Lifetime"))
    ]
}

/// 单个套餐在卡片上的展示文案
struct PlanDisplayPricing: Equatable {
    let priceText: String
    let subtitleText: String?
    let valueNoteText: String?
    let badgeText: String?
}

// MARK: - PaywallPricing

struct PaywallPricing {
    let monthly: Product?
    let yearly: Product?
    let lifetime: Product?

    /// 产品尚未从 App Store 返回时的价格占位
    private static let unavailablePrice = "--"

    func product(for type: PaywallPlanType) -> Product? {
        switch type {
        case .monthly:
            return monthly
        case .yearly:
            return yearly
        case .lifetime:
            return lifetime
        }
    }

    /// 套餐卡文案。产品未就绪时只把价格降级为占位符，其余文案照常——
    /// 因为这些文案只取决于套餐类型，与产品是否加载无关，不需要两套分支。
    func display(for type: PaywallPlanType) -> PlanDisplayPricing {
        let product = product(for: type)
        let priceText = product?.displayPrice ?? Self.unavailablePrice

        switch type {
        case .monthly:
            return PlanDisplayPricing(
                priceText: priceText,
                subtitleText: L10n.string("Billed monthly"),
                valueNoteText: L10n.string("Cancel anytime"),
                badgeText: nil
            )

        case .yearly:
            let presentation = annualPresentation(
                monthlySubtitle: product.flatMap { monthlyEquivalent(product: $0, months: 12) }
            )
            return PlanDisplayPricing(
                priceText: priceText,
                subtitleText: presentation.subtitleText,
                valueNoteText: presentation.valueNoteText,
                badgeText: presentation.badgeText
            )

        case .lifetime:
            return PlanDisplayPricing(
                priceText: priceText,
                subtitleText: L10n.string("Permanent buyout"),
                valueNoteText: L10n.string("Pay once, enjoy lifetime access"),
                badgeText: nil
            )
        }
    }

    // MARK: 套餐卡

    /// 套餐卡的第二行：试用态说试用，其余说计费方式。
    func planTrialText(
        for type: PaywallPlanType,
        isTrialEligible: Bool,
        trialDayCount: Int?
    ) -> String {
        if isTrialOffer(for: type, isTrialEligible: isTrialEligible) {
            return ctaTitle(for: type, isTrialEligible: isTrialEligible, trialDayCount: trialDayCount)
        }

        return display(for: type).subtitleText ?? display(for: type).priceText
    }

    /// 套餐卡底部说明：覆盖自动续订与取消，买断则说明一次付费。
    func planNoteText(for type: PaywallPlanType, isTrialEligible: Bool) -> String {
        if isTrialOffer(for: type, isTrialEligible: isTrialEligible) {
            return L10n.string("Trial ends, then renews automatically. Cancel anytime.")
        }

        switch type {
        case .monthly, .yearly:
            return L10n.string("Renews automatically. Cancel anytime.")
        case .lifetime:
            return L10n.string("Pay once. Yours forever.")
        }
    }

    // MARK: CTA

    /// 底栏主按钮：试用态沿用 `ctaTitle`，其余套餐给出明确的动作。
    func purchaseTitle(
        for type: PaywallPlanType,
        isTrialEligible: Bool,
        trialDayCount: Int?
    ) -> String {
        switch type {
        case .yearly:
            return ctaTitle(for: type, isTrialEligible: isTrialEligible, trialDayCount: trialDayCount)
        case .monthly:
            return L10n.string("Subscribe monthly")
        case .lifetime:
            return L10n.string("Unlock Lifetime Pro")
        }
    }

    /// CTA 主文案。试用只挂年订，且要求当前 Apple ID 在订阅组内仍有 intro 资格：
    /// 只判断产品带 offer 是不够的，已用掉 intro 的用户会被误导。
    func ctaTitle(
        for type: PaywallPlanType,
        isTrialEligible: Bool,
        trialDayCount: Int?
    ) -> String {
        guard isTrialOffer(for: type, isTrialEligible: isTrialEligible) else {
            return L10n.string("Unlock Now")
        }

        // 7 天有独立译文；其他时长退回不含天数的通用文案，
        // 避免为动态天数拼接字符串导致部分语言语序错乱。
        return trialDayCount == 7
            ? L10n.string("Try 7 days free")
            : L10n.string("Start free trial")
    }

    /// 试用态专属副文案：说明试用结束后的年费。非试用态不重申成本。
    func trialSubline(for type: PaywallPlanType, isTrialEligible: Bool) -> String? {
        guard isTrialOffer(for: type, isTrialEligible: isTrialEligible),
              let product = product(for: type) else {
            return nil
        }

        let priceWithPeriod = product.displayPrice + " " + L10n.string("/ year")
        return String(
            format: L10n.string("Cancel anytime during the trial · Then %@ · Auto-renews"),
            priceWithPeriod
        )
    }

    /// CTA 副文案：试用态优先，其次是订阅自动续订说明；买断没有副文案。
    func ctaSubline(for type: PaywallPlanType, isTrialEligible: Bool) -> String? {
        if let trialSubline = trialSubline(for: type, isTrialEligible: isTrialEligible) {
            return trialSubline
        }

        switch type {
        case .monthly:
            return L10n.string("Auto-renews monthly · Cancel anytime")
        case .yearly:
            return L10n.string("Auto-renews yearly · Cancel anytime")
        case .lifetime:
            return nil
        }
    }

    private func isTrialOffer(for type: PaywallPlanType, isTrialEligible: Bool) -> Bool {
        type == .yearly && isTrialEligible
    }
}

// MARK: - Annual Savings

private extension PaywallPricing {

    struct AnnualPresentation {
        let badgeText: String
        let subtitleText: String?
        let valueNoteText: String?
    }

    struct AnnualSavings {
        let discountPercent: Int
    }

    /// 年订相对月订的节省。缺任一产品、或算不出正的节省时返回 nil，此时退回通用推荐徽章。
    var annualSavings: AnnualSavings? {
        guard let monthly, let yearly else {
            return nil
        }

        let monthlyAnnualized = multiply(monthly.price, by: 12)
        guard monthlyAnnualized > 0 else {
            return nil
        }

        let savedAmount = monthlyAnnualized - yearly.price
        guard savedAmount > 0 else {
            return nil
        }

        let percent = discountPercent(savedAmount: savedAmount, baseAmount: monthlyAnnualized)
        guard percent > 0 else {
            return nil
        }

        return AnnualSavings(discountPercent: percent)
    }

    /// 有节省数据时用利益型徽章（SAVE X%），否则退回通用推荐徽章。
    ///
    /// 注意 `%` 的两层规则：源码里字面 `%` 要写成 `%%`（printf 语义），
    /// 且 xcstrings 里 key 与译文 value 都必须写 `%%`——key 少了查不到译文，
    /// value 少了会把 `%` 吞掉。
    func annualPresentation(monthlySubtitle: String?) -> AnnualPresentation {
        guard let savings = annualSavings else {
            return AnnualPresentation(
                badgeText: L10n.string("Recommended"),
                subtitleText: monthlySubtitle,
                valueNoteText: nil
            )
        }

        return AnnualPresentation(
            badgeText: String(format: L10n.string("SAVE %lld%%"), savings.discountPercent),
            subtitleText: monthlySubtitle,
            valueNoteText: String(format: L10n.string("Save %lld%% vs monthly"), savings.discountPercent)
        )
    }

    func monthlyEquivalent(product: Product, months: Int) -> String? {
        guard let monthlyPrice = divide(product.price, by: months) else {
            return nil
        }

        return String(
            format: L10n.string("≈ %@ / month"),
            monthlyPrice.formatted(product.priceFormatStyle)
        )
    }

    func discountPercent(savedAmount: Decimal, baseAmount: Decimal) -> Int {
        guard baseAmount > 0 else {
            return 0
        }

        // 全程留在 Decimal，避免经 Double 出现 49.999… 再被 floor 成 49
        var percent = (savedAmount / baseAmount) * Decimal(100)
        var floored = Decimal()
        NSDecimalRound(&floored, &percent, 0, .down)
        return NSDecimalNumber(decimal: floored).intValue
    }

    func multiply(_ value: Decimal, by multiplier: Int) -> Decimal {
        NSDecimalNumber(decimal: value)
            .multiplying(by: NSDecimalNumber(value: multiplier))
            .decimalValue
    }

    func divide(_ value: Decimal, by divisor: Int) -> Decimal? {
        guard divisor > 0 else {
            return nil
        }

        return NSDecimalNumber(decimal: value)
            .dividing(by: NSDecimalNumber(value: divisor))
            .decimalValue
    }
}
