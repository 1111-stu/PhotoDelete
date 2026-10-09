//
//  PaywallPricing.swift
//  PhotoDelete
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
        PaywallPlan(type: .yearly, name: L10n.string("Yearly"), priceCaption: L10n.string("/ year")),
        PaywallPlan(type: .quarterly, name: L10n.string("Quarterly"), priceCaption: L10n.string("/ quarter")),
        PaywallPlan(type: .lifetime, name: L10n.string("Lifetime"), priceCaption: L10n.string("Lifetime"))
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
    let quarterly: Product?
    let yearly: Product?
    let lifetime: Product?

    /// 产品尚未从 App Store 返回时的价格占位
    private static let unavailablePrice = "--"

    func product(for type: PaywallPlanType) -> Product? {
        switch type {
        case .quarterly:
            return quarterly
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
        case .quarterly:
            return PlanDisplayPricing(
                priceText: priceText,
                subtitleText: product.flatMap { monthlyEquivalent(product: $0, months: 3) },
                valueNoteText: L10n.string("Flexible subscription for short-term use"),
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

    // MARK: CTA

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

    /// CTA 副文案：仅试用态展示。正常购买不显示——价格已经在套餐卡上，
    /// 不在点击瞬间重申成本。
    func trialSubline(for type: PaywallPlanType, isTrialEligible: Bool) -> String? {
        guard isTrialOffer(for: type, isTrialEligible: isTrialEligible),
              let product = product(for: type) else {
            return nil
        }

        let priceWithPeriod = product.displayPrice + " " + L10n.string("/ year")
        return String(
            format: L10n.string("Cancel anytime during the trial · Then %@"),
            priceWithPeriod
        )
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

    /// 年订相对季度订的节省。缺任一产品、或算不出正的节省时返回 nil，此时退回通用推荐徽章。
    var annualSavings: AnnualSavings? {
        guard let quarterly, let yearly else {
            return nil
        }

        let quarterlyAnnualized = multiply(quarterly.price, by: 4)
        guard quarterlyAnnualized > 0 else {
            return nil
        }

        let savedAmount = quarterlyAnnualized - yearly.price
        guard savedAmount > 0 else {
            return nil
        }

        let percent = discountPercent(savedAmount: savedAmount, baseAmount: quarterlyAnnualized)
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
            valueNoteText: String(format: L10n.string("Save %lld%% vs quarterly"), savings.discountPercent)
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
