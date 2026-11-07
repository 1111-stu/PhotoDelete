//
//  PaywallView.swift
//  PhotoDelete
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
        ZStack(alignment: .topTrailing) {
            backdrop
            scrollContent
            closeButton.padding(PaywallLayout.closeButtonInset)
        }
        // 付费页自带配色体系：把 tint 固定成樱粉，否则玻璃关闭按钮会继承全局琥珀 tint
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
        .onChange(of: subscriptionManager.currentSubscriptionType) { _ in
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

    var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection
                    .padding(.top, PaywallDS.Space.heroTop)

                PaywallFeatureSection(isPro: subscriptionManager.isPro)
                    .padding(.top, PaywallDS.Space.lg)

                if shouldHidePurchaseUI == false {
                    PaywallPlanSection(
                        plans: visiblePlans,
                        pricing: pricing,
                        selectedType: $selectedPlanType,
                        onSelect: handlePlanSelected
                    )
                    .padding(.top, PaywallDS.Space.sectionGap)
                }

                linksSection
                    .padding(.top, PaywallDS.Space.sectionGapSmall)
            }
            .padding(.horizontal, PaywallLayout.pageHorizontalPadding)
            .padding(.bottom, PaywallLayout.contentBottomPadding)
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
    /// 用画布色渐显盖住——**必须是灵活视图 + ignoresSafeArea**（本仓滑动页 / 进阶页底栏同款做法）：
    /// 一旦先固定 frame 高度，safeAreaInset 内容就停在安全区边界，遮不住下面那条。
    ///
    /// 渐变铺满「整个底栏 + 安全区」，所以不能让它线性渐隐——那会把玻璃卡下半段也压暗。
    /// 用显式 stop 把过渡压在最后三成（≈ 安全区 + 玻璃卡内边距），卡片主体保持通透。
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
            ? pricing.ctaTitle(for: type, isTrialEligible: isTrialEligible, trialDayCount: subscriptionManager.trialDayCount)
            : ""
        let subline = isStoreReady ? pricing.ctaSubline(for: type, isTrialEligible: isTrialEligible) : nil

        return PaywallFooter.CTA(
            title: title,
            subline: subline,
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

// MARK: - Backdrop

private extension PaywallView {

    /// 背景整体不参与命中测试，滚动手势不会被点阵截断
    var backdrop: some View {
        ZStack {
            PaywallDS.Color.pageBackground
            dotGrid
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// 细点阵纹理（冷灰点）：无限画板质感的数字画布
    var dotGrid: some View {
        Canvas { context, size in
            let spacing: CGFloat = 24
            let dot: CGFloat = 2.4
            var x = spacing / 2
            while x < size.width {
                var y = spacing / 2
                while y < size.height {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)),
                        with: .color(PaywallDS.Color.dot)
                    )
                    y += spacing
                }
                x += spacing
            }
        }
    }

    @ViewBuilder
    var closeButton: some View {
        // glassEffect 挂在 Button label 内时 hit 区会缩成 glyph，表现为点了没反应，
        // 因此必须走原生 .glass buttonStyle
        if #available(iOS 26.0, *) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(PaywallDS.Font.calloutMedium)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.regular)
            .accessibilityIdentifier("paywall-close-button")
        } else {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(PaywallDS.Font.calloutMedium)
                    .foregroundStyle(PaywallDS.Color.textPrimary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(Circle().fill(.ultraThinMaterial))
            .accessibilityIdentifier("paywall-close-button")
        }
    }
}

// MARK: - Hero / Links

private extension PaywallView {

    var heroSection: some View {
        VStack(spacing: PaywallDS.Space.xs) {
            HStack(spacing: PaywallDS.Space.sm) {
                Text(L10n.string("Poca Pro"))
                    .font(PaywallFont.heroTitle)
                    .foregroundStyle(PaywallDS.Color.textPrimary)

                Image(systemName: "crown.fill")
                    .font(PaywallDS.Font.title3)
                    .foregroundStyle(PaywallDS.Color.accent)
            }

            Text(L10n.string("Unlock the full timeline, compression, and similar-photo cleanup."))
                .font(PaywallFont.heroSubtitle)
                .foregroundStyle(PaywallDS.Color.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(PaywallDS.Space.xs)
        }
        .padding(.horizontal, PaywallDS.Space.sm)
        .padding(.bottom, PaywallDS.Space.xs)
    }

    var linksSection: some View {
        HStack(spacing: 0) {
            Spacer()

            linkButton(L10n.string("Restore Purchases"), identifier: "paywall-restore-button", action: handleRestore)
            pipeSeparator
            Link(L10n.string("Privacy Policy"), destination: AppConstants.privacyPolicyURL)
                .accessibilityIdentifier("supporter-privacy-policy-link")
                .font(PaywallDS.Font.caption)
                .foregroundStyle(PaywallDS.Color.textTertiary)
            pipeSeparator
            Link(L10n.string("Terms of Use"), destination: AppConstants.termsOfUseURL)
                .accessibilityIdentifier("supporter-terms-of-use-link")
                .font(PaywallDS.Font.caption)
                .foregroundStyle(PaywallDS.Color.textTertiary)

            Spacer()
        }
    }

    var pipeSeparator: some View {
        Text("｜")
            .font(PaywallDS.Font.caption)
            .foregroundStyle(PaywallDS.Color.textTertiary.opacity(0.6))
            .padding(.horizontal, PaywallDS.Space.sm)
    }

    func linkButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PaywallDS.Font.caption)
                .foregroundStyle(PaywallDS.Color.textTertiary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
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
