//
//  PaywallView.swift
//  Poca
//
//  Paywall 骨架：持有页面状态与购买动作，把区块组装起来。
//  各区块见 PaywallSections，文案计算见 PaywallPricing，token 见 PaywallTheme。
//

import SwiftUI
import StoreKit

// MARK: - PaywallView

struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedPlanType: PaywallPlanType = .yearly
    @State private var localErrorMessage: String?

    var body: some View {
        ZStack {
            backdrop
            scrollContent
        }
        // 付费页自带配色体系：把 tint 固定成琥珀，链接与玻璃控件统一
        .tint(PaywallDS.Color.accent)
        // 作为导航栈里的整页呈现，隐藏系统导航栏；TabBar 由 tab 根导航出口统一隐藏
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task {
            // 先刷权益再拉商品：避免已订阅用户在 stale nil 权益下短暂闪出试用 CTA
            await subscriptionManager.checkSubscriptionStatus()
            await subscriptionManager.fetchProducts()
            syncSelectedPlanWithCurrentEntitlement()
        }
        .onChange(of: subscriptionManager.currentSubscriptionType) { _, _ in
            syncSelectedPlanWithCurrentEntitlement()
        }
    }
}

// MARK: - Derived State

private extension PaywallView {

    var pricing: PaywallPricing {
        PaywallPricing(
            monthly: subscriptionManager.monthlyProduct,
            yearly: subscriptionManager.yearlyProduct,
            lifetime: subscriptionManager.lifetimeProduct
        )
    }

    /// 只展示当前权益下还能买的套餐（如年订用户不再看到月订）
    var visiblePlans: [PaywallPlan] {
        let availableTypes = Set(subscriptionManager.availablePurchaseTypes)
        return PaywallPlan.all.filter { availableTypes.contains($0.type) }
    }

    /// 选中项失效时退回首个可见套餐，避免 CTA 指向一个已隐藏的套餐
    var selectedPlan: PaywallPlan? {
        visiblePlans.first { $0.type == selectedPlanType } ?? visiblePlans.first
    }

    /// 年订与买断用户已到顶，不再展示任何购买入口；月订用户仍可升级
    var shouldHidePurchaseUI: Bool {
        guard let currentType = subscriptionManager.currentSubscriptionType else {
            return false
        }

        switch currentType {
        case .yearly, .lifetime:
            return true
        case .monthly:
            return false
        }
    }

    /// 本地校验错误优先于 manager 的错误：它更贴近用户刚才的操作
    var displayErrorMessage: String? {
        localErrorMessage ?? subscriptionManager.errorMessage
    }
}

// MARK: - Layout

private extension PaywallView {

    var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("Poca")
                Text("Pro")
                Text("!").italic()
            }
            .font(PaywallDS.Font.brand)
            .tracking(-0.6)
            .foregroundStyle(PaywallDS.Color.textPrimary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Poca Pro"))

            Spacer(minLength: 0)

            closeButton
        }
        .padding(.top, 8)
    }

    var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PaywallDS.Color.textPrimary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.055)))
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                .frame(width: Theme.sizeTap, height: Theme.sizeTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.string("Close")))
        .accessibilityIdentifier("paywall-close-button")
        .accessibilitySortPriority(2)
    }

    var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                topBar

                PaywallBenefitCarousel()
                    .padding(.top, 16)

                if shouldHidePurchaseUI == false {
                    Text(L10n.string("Choose your plan"))
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(-0.1)
                        .foregroundStyle(PaywallDS.Color.textPrimary.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 24)

                    PaywallPlanSection(
                        plans: visiblePlans,
                        pricing: pricing,
                        selectedType: $selectedPlanType,
                        isTrialEligible: subscriptionManager.isStoreReady && subscriptionManager.isTrialEligible,
                        trialDayCount: subscriptionManager.trialDayCount,
                        onSelect: handlePlanSelected
                    )
                    // 让 SKU 横排铺到屏幕边缘，内容再用 contentMargins 收回 20pt，
                    // 这样两侧是系统滚边模糊，而不是在正文留白处硬切。
                    .padding(.horizontal, -PaywallLayout.pageHorizontalPadding)
                    .padding(.top, 12)
                }

                legalRow
                    .padding(.top, 8)
            }
            .padding(.horizontal, PaywallLayout.pageHorizontalPadding)
            .padding(.bottom, PaywallLayout.contentBottomPadding)
            .frame(maxWidth: 470)
            .frame(maxWidth: .infinity)
        }
        // 把 Footer 挂进底部安全区，ScrollView 会自动让出对应高度，
        // 不必手工估算一个占位块——Footer 变高（如出现错误提示）时也不会遮住正文
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
    }

    @ViewBuilder
    var footer: some View {
        if shouldHidePurchaseUI == false {
            PaywallFooter(cta: footerCTA, errorMessage: displayErrorMessage)
                .background(alignment: .bottom) {
                    bottomScrim
                }
        }
    }

    /// 玻璃卡下方那条底部安全区不能裸奔：滚动内容会从卡片下缘一路露到屏幕底部。
    /// 用画布色渐显盖住——必须是灵活视图 + ignoresSafeArea，固定高度会停在安全区边界。
    var bottomScrim: some View {
        LinearGradient(
            stops: [
                .init(color: PaywallDS.Color.pageBackground.opacity(0), location: 0),
                .init(color: PaywallDS.Color.pageBackground.opacity(0), location: 0.62),
                .init(color: PaywallDS.Color.pageBackground, location: 0.84)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }

    var footerCTA: PaywallFooter.CTA? {
        guard let type = selectedPlan?.type else {
            return nil
        }

        // isStoreReady：首屏等商店态；isLoading：仅购买/恢复。二者分开，避免拉品刷新闪整块 footer
        let isStoreReady = subscriptionManager.isStoreReady
        let isCTALoading = isStoreReady == false || subscriptionManager.isLoading
        let isTrialEligible = isStoreReady && subscriptionManager.isTrialEligible
        let title = isStoreReady
            ? pricing.purchaseTitle(
                for: type,
                isTrialEligible: isTrialEligible,
                trialDayCount: subscriptionManager.trialDayCount
            )
            : ""

        return PaywallFooter.CTA(
            title: title,
            isLoading: isCTALoading,
            isEnabled: isCTALoading == false && canPurchase(type),
            action: handlePurchase
        )
    }

    func canPurchase(_ type: PaywallPlanType) -> Bool {
        guard pricing.product(for: type) != nil else {
            return false
        }

        return subscriptionManager.canPurchase(type)
    }
}

// MARK: - Legal Row

private extension PaywallView {

    var legalRow: some View {
        HStack(spacing: 8) {
            Link(L10n.string("Privacy Policy"), destination: AppConstants.privacyPolicyURL)
                .foregroundStyle(PaywallDS.Color.textSecondary)
                .frame(minHeight: Theme.sizeTap)
                .contentShape(Rectangle())
                .accessibilityIdentifier("supporter-privacy-policy-link")

            separator

            Link(L10n.string("Terms of Use"), destination: AppConstants.termsOfUseURL)
                .foregroundStyle(PaywallDS.Color.textSecondary)
                .frame(minHeight: Theme.sizeTap)
                .contentShape(Rectangle())
                .accessibilityIdentifier("supporter-terms-of-use-link")

            separator

            Button(action: handleRestore) {
                Text(L10n.string("Restore Purchases"))
                    .foregroundStyle(PaywallDS.Color.textSecondary)
                    .frame(minHeight: Theme.sizeTap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paywall-restore-button")
        }
        .font(PaywallDS.Font.legal)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
    }

    var separator: some View {
        Text("·")
            .font(PaywallDS.Font.legal)
            .foregroundStyle(PaywallDS.Color.textTertiary)
            .accessibilityHidden(true)
    }
}

// MARK: - Backdrop

private extension PaywallView {

    /// 背景整体不参与命中测试，滚动手势不会被背景截断
    var backdrop: some View {
        ZStack {
            LinearGradient(
                colors: [PaywallDS.Color.pageBackground, PaywallDS.Color.pageBackgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Color.white.opacity(0.075), .clear],
                center: UnitPoint(x: 0.5, y: -0.08),
                startRadius: 0,
                endRadius: 520
            )

            RadialGradient(
                colors: [PaywallDS.Color.accent.opacity(0.05), .clear],
                center: UnitPoint(x: 0.1, y: -0.06),
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Actions

private extension PaywallView {

    /// 权益变化后（如刚升级为年订）选中项可能已从列表消失，归位到首个可见套餐
    func syncSelectedPlanWithCurrentEntitlement() {
        guard let firstVisiblePlan = visiblePlans.first else {
            return
        }

        guard visiblePlans.contains(where: { $0.type == selectedPlanType }) == false else {
            return
        }

        selectedPlanType = firstVisiblePlan.type
    }

    func handlePlanSelected(_ type: PaywallPlanType) {
        localErrorMessage = nil
    }

    func handlePurchase() {
        localErrorMessage = nil

        guard let targetType = selectedPlan?.type else {
            return
        }

        guard pricing.product(for: targetType) != nil else {
            localErrorMessage = L10n.string("Product not found")
            return
        }

        guard subscriptionManager.canPurchase(targetType) else {
            localErrorMessage = subscriptionManager.purchaseBlockMessage(for: targetType)
                ?? L10n.string("Purchase is not available for the current plan")
            return
        }

        Task {
            let success = await subscriptionManager.purchase(targetType)
            guard success else {
                return
            }

            dismiss()
        }
    }

    func handleRestore() {
        localErrorMessage = nil

        Task {
            await subscriptionManager.restorePurchases()

            guard subscriptionManager.errorMessage == nil else {
                return
            }

            guard subscriptionManager.isPro else {
                localErrorMessage = L10n.string("No purchases found to restore")
                return
            }

            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("Dark Mode") {
    NavigationStack { PaywallView() }
        .preferredColorScheme(.dark)
}
