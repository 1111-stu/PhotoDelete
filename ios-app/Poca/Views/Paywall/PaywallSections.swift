//
//  PaywallSections.swift
//  PhotoDelete
//
//  Paywall 的三个主要区块。每个都是独立组件，依赖通过参数显式传入，
//  不直接访问 SubscriptionManager。
//

import SwiftUI
import UIKit

// MARK: - Feature Section

/// 功能清单。展开状态是纯 UI 状态，父级无需知晓，因此自己持有。
/// 内容全部来自已上线的 Pro 权益（`SupporterPlanComparisonCard` 里 supporter 独占的那 5 项），
/// 不在这里新编产品承诺。
struct PaywallFeatureSection: View {

    let isPro: Bool

    @State private var isExpanded = false

    private struct Feature {
        let icon: String
        let title: SupporterPlanFeatureTitle
        let subKey: String
    }

    private static let items: [Feature] = [
        Feature(
            icon: "list.bullet.rectangle",
            title: .fullTimeList,
            subKey: "Browse every month, not just this year"
        ),
        Feature(
            icon: "externaldrive",
            title: .largeFileCleanup,
            subKey: "See the biggest files first and clear them"
        ),
        Feature(
            icon: "arrow.down.right.and.arrow.up.left",
            title: .imageCompression,
            subKey: "Shrink photos to free up more space"
        ),
        Feature(
            icon: "film",
            title: .videoCompression,
            subKey: "Compress videos to save space"
        ),
        Feature(
            icon: "square.on.square",
            title: .similarPhotoCleanup,
            subKey: "Keep the best shot, clear the rest"
        )
    ]

    /// 默认展示前 3 行，其余展开可见
    private static let collapsedCount = 3

    private var visibleItems: [Feature] {
        isExpanded ? Self.items : Array(Self.items.prefix(Self.collapsedCount))
    }

    private var headline: String {
        // 文案里的 5 是写死的：改成插值会让现有全语言译文失效。
        // 断言保证增删功能项时能在 debug 期立刻暴露不一致。
        assert(Self.items.count == 5, "文案中的数字需与功能项数量一致")
        return isPro
            ? L10n.string("All 5 Pro benefits unlocked")
            : L10n.string("Instantly unlock all 5 Pro benefits")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PaywallDS.Space.lg) {
            Text(headline)
                .font(PaywallFont.sectionTitle)
                .foregroundStyle(PaywallDS.Color.textTertiary)

            VStack(spacing: 0) {
                ForEach(Array(visibleItems.enumerated()), id: \.offset) { _, item in
                    featureRow(item)
                }

                expandToggle
            }
            .background(
                RoundedRectangle(cornerRadius: PaywallDS.Radius.listContainer, style: .continuous)
                    .fill(PaywallDS.Color.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: PaywallDS.Radius.listContainer, style: .continuous)
                            .stroke(PaywallDS.Color.borderSubtle, lineWidth: PaywallDS.Stroke.border)
                    )
            )
        }
    }

    private var expandToggle: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)

            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: PaywallDS.Space.xs) {
                Text(isExpanded ? L10n.string("Show less") : L10n.string("View all"))
                    .font(PaywallDS.Font.captionMedium)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(PaywallDS.Font.caption2Semibold)
            }
            .foregroundStyle(PaywallDS.Color.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, PaywallDS.Space.md)
        }
        .buttonStyle(.plain)
    }

    private func featureRow(_ item: Feature) -> some View {
        HStack(spacing: PaywallDS.Space.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: PaywallDS.Radius.iconTile, style: .continuous)
                    .fill(PaywallDS.Color.iconBackground)
                    .frame(width: 36, height: 36)

                Image(systemName: item.icon)
                    .font(PaywallDS.Font.calloutSemibold)
                    .foregroundStyle(PaywallDS.Color.textPrimary)
            }

            VStack(alignment: .leading, spacing: PaywallDS.Space.xxs) {
                Text(item.title.localizedTitle)
                    .font(PaywallDS.Font.calloutSemibold)
                    .foregroundStyle(PaywallDS.Color.textPrimary)

                Text(L10n.key(item.subKey))
                    .font(PaywallDS.Font.caption)
                    .foregroundStyle(PaywallDS.Color.textSecondary)
            }

            Spacer()

            // 简约对勾：无底色圆，只保留樱粉 ✓
            Image(systemName: "checkmark")
                .font(PaywallFont.featureCheck)
                .foregroundStyle(PaywallDS.Color.accent)
        }
        .padding(.horizontal, PaywallDS.Space.xl)
        .padding(.vertical, PaywallDS.Space.lg)
    }
}

// MARK: - Review Prompt Section

// MARK: - Plan Section

/// 套餐选择。选中项交回父级（Footer 的 CTA 要用），埋点与清错误由父级在 onSelect 里处理。
struct PaywallPlanSection: View {

    let plans: [PaywallPlan]
    let pricing: PaywallPricing
    @Binding var selectedType: PaywallPlanType
    let onSelect: (PaywallPlanType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PaywallDS.Space.lg) {
            Text(L10n.string("Choose your plan"))
                .font(PaywallFont.sectionTitle)
                .foregroundStyle(PaywallDS.Color.textTertiary)

            VStack(spacing: PaywallDS.Space.lg) {
                ForEach(plans) { planCard($0) }
            }
        }
    }

    private func planCard(_ plan: PaywallPlan) -> some View {
        let isSelected = selectedType == plan.type
        let display = pricing.display(for: plan.type)

        return Button {
            select(plan.type)
        } label: {
            HStack(spacing: PaywallDS.Space.xl) {
                radioIndicator(isSelected: isSelected)
                planLabel(plan, display: display)
                Spacer()
                planPrice(plan, display: display)
            }
            .padding(PaywallDS.Space.xl)
            .background(
                RoundedRectangle(cornerRadius: PaywallDS.Radius.card, style: .continuous)
                    .fill(isSelected ? PaywallDS.Color.selectedSKUCardFill : PaywallDS.Color.skuCardFill)
                    .overlay(cardBorder(isSelected: isSelected))
            )
            .scaleEffect(isSelected ? 1 : 0.992)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("paywall-plan-\(plan.type.accessibilitySlug)")
    }

    private func select(_ type: PaywallPlanType) {
        onSelect(type)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
            selectedType = type
        }
    }

    /// 选中态直接换成渐变描边，而不是在常规描边之上再叠一层
    @ViewBuilder
    private func cardBorder(isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: PaywallDS.Radius.card, style: .continuous)

        if isSelected {
            shape.stroke(PaywallDS.Gradient.selectedCardBorder, lineWidth: PaywallDS.Stroke.selectedCard)
        } else {
            shape.stroke(PaywallDS.Color.skuCardBorder, lineWidth: PaywallDS.Stroke.border)
        }
    }

    private func planLabel(_ plan: PaywallPlan, display: PlanDisplayPricing) -> some View {
        VStack(alignment: .leading, spacing: PaywallDS.Space.xs) {
            // 标题行按内容 intrinsic 宽度占位，禁止被中间 Spacer 压窄后把徽章挤换行。
            HStack(spacing: PaywallDS.Space.md) {
                Text(plan.name)
                    .font(PaywallDS.Font.calloutSemibold)
                    .foregroundStyle(PaywallDS.Color.textPrimary)

                if let badgeText = display.badgeText {
                    Text(badgeText)
                        .font(PaywallDS.Font.caption2Bold)
                        .tracking(0.3)
                        .foregroundStyle(PaywallDS.Color.recommendedBadgeText)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, PaywallDS.Space.xs)
                        .background(Capsule().fill(PaywallDS.Color.recommendedBadgeFill))
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            optionalText(display.subtitleText, font: PaywallDS.Font.captionMedium)
            optionalText(display.valueNoteText, font: PaywallFont.planValueNote)
        }
    }

    private func planPrice(_ plan: PaywallPlan, display: PlanDisplayPricing) -> some View {
        VStack(alignment: .trailing, spacing: PaywallDS.Space.xxs) {
            Text(display.priceText)
                .font(PaywallDS.Font.title2Bold)
                .foregroundStyle(PaywallDS.Color.textPrimary)

            Text(plan.priceCaption)
                .font(PaywallDS.Font.caption2)
                .foregroundStyle(PaywallDS.Color.textTertiary)
        }
    }

    private func radioIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected
                        ? AnyShapeStyle(PaywallDS.Gradient.selectedCardBorder)
                        : AnyShapeStyle(PaywallDS.Color.skuCardBorder),
                    lineWidth: isSelected ? PaywallDS.Stroke.radioSelected : PaywallDS.Stroke.radioUnselected
                )
                .frame(width: 20, height: 20)

            if isSelected {
                Circle()
                    .fill(PaywallDS.Color.selectedSKUCardDot)
                    .frame(width: 10, height: 10)
            }
        }
    }

    @ViewBuilder
    private func optionalText(_ text: String?, font: Font) -> some View {
        if let text, text.isEmpty == false {
            Text(text)
                .font(font)
                .foregroundStyle(PaywallDS.Color.textSecondary)
        }
    }
}

// MARK: - Footer

/// 固定在底部的购买区。纯展示组件：所有文案由外部算好传入，
/// 因此它不需要知道试用规则，也能脱离 StoreKit 预览。
struct PaywallFooter: View {

    /// 为 nil 时不渲染购买按钮，只保留错误提示与安全声明
    struct CTA {
        let title: String
        let subline: String?
        let isLoading: Bool
        let isEnabled: Bool
        let action: () -> Void
    }

    let cta: CTA?
    let errorMessage: String?

    var body: some View {
        VStack(spacing: PaywallDS.Space.lg) {
            if let cta {
                purchaseButton(cta)

                // 按钮副文案：价格与退订保障留给主动寻找的人，不占 CTA
                if let subline = cta.subline {
                    Text(subline)
                        .font(PaywallDS.Font.caption2)
                        .foregroundStyle(PaywallDS.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(PaywallDS.Font.caption2Medium)
                    .foregroundStyle(PaywallDS.Color.errorText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            trustRow
        }
        // 卡内留白：内容 ↔ 玻璃边缘
        .padding(
            EdgeInsets(
                top: PaywallDS.Space.lg,
                leading: PaywallLayout.footerCardHorizontalPadding,
                bottom: PaywallDS.Space.xl,
                trailing: PaywallLayout.footerCardHorizontalPadding
            )
        )
        .paywallGlassCard(radius: PaywallDS.Radius.floatingCard)
        // 卡外间距：玻璃卡 ↔ 屏幕/安全区
        .padding(EdgeInsets(top: 0, leading: PaywallDS.Space.xl, bottom: PaywallDS.Space.sm, trailing: PaywallDS.Space.xl))
    }

    private func purchaseButton(_ cta: CTA) -> some View {
        Button(action: cta.action) {
            ZStack {
                if cta.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(PaywallDS.Color.ctaButtonText)
                } else {
                    Text(cta.title)
                        .font(PaywallDS.Font.bodySemibold)
                        .foregroundStyle(PaywallDS.Color.ctaButtonText)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: PaywallDS.Radius.chip, style: .continuous)
                    .fill(PaywallDS.Color.ctaButtonFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: PaywallDS.Radius.chip, style: .continuous)
                            .stroke(PaywallDS.Color.ctaButtonBorder, lineWidth: PaywallDS.Stroke.border)
                    )
            )
            .shadow(color: PaywallDS.Color.ctaButtonShadow, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(cta.isEnabled == false)
        .accessibilityIdentifier("paywall-unlock-cta")
    }

    private var trustRow: some View {
        HStack(spacing: PaywallDS.Space.sm) {
            Image(systemName: "lock.shield")
                .font(PaywallDS.Font.caption2Semibold)
                .foregroundStyle(PaywallDS.Color.textSecondary.opacity(0.9))

            Text(L10n.string("Apple protected · secure payment"))
                .font(PaywallDS.Font.caption2)
                .foregroundStyle(PaywallDS.Color.textSecondary)
        }
    }
}

// MARK: - 套餐标识

extension SubscriptionManager.SubscriptionType {
    /// 用于 UI 测试的 accessibility identifier 片段
    var accessibilitySlug: String {
        switch self {
        case .monthly: return "monthly"
        case .yearly: return "yearly"
        case .lifetime: return "lifetime"
        }
    }
}
