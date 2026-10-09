//
//  SubscriptionManager.swift
//  eisenhower-matrix-ios-app
//
//  Created by xion da on 2026/2/22.
//

import Foundation
import StoreKit
import Combine

// MARK: - Subscription Error

enum SubscriptionError: LocalizedError {
    case productNotFound
    case purchaseCancelled
    case purchasePending
    case verificationFailed
    case networkError
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return NSLocalizedString("Product not found", comment: "")
        case .purchaseCancelled:
            return NSLocalizedString("Purchase cancelled", comment: "")
        case .purchasePending:
            return NSLocalizedString("Purchase pending approval", comment: "")
        case .verificationFailed:
            return NSLocalizedString("Purchase verification failed", comment: "")
        case .networkError:
            return NSLocalizedString("Network error, please try again", comment: "")
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Subscription Manager

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    enum PurchaseBlockReason {
        case lifetimeAlreadyOwned
        case lifetimePurchaseBlockedDuringActiveSubscription
        case currentPlanAlreadyActive
        case upgradeOnly
    }

    // MARK: - Product IDs

    private enum ProductID {
        // NOTE: 季度/年度是占位 ID，接入 App Store Connect 后替换为最终值。
        static let quarterly = "io.xion.dofirst.subscription.quarterly"
        static let yearly = "io.xion.dofirst.subscription.yearly"
        static let lifetime = "io.xion.dofirst.pro"

        static let all: Set<String> = [quarterly, yearly, lifetime]
    }

    // MARK: - Subscription Type

    enum SubscriptionType: String, CaseIterable {
        case quarterly = "io.xion.dofirst.subscription.quarterly"
        case yearly = "io.xion.dofirst.subscription.yearly"
        case lifetime = "io.xion.dofirst.pro"

        var displayName: String {
            switch self {
            case .quarterly:
                return NSLocalizedString("Quarterly", comment: "")
            case .yearly:
                return NSLocalizedString("Yearly", comment: "")
            case .lifetime:
                return NSLocalizedString("Lifetime", comment: "")
            }
        }

        var isSubscription: Bool {
            self != .lifetime
        }

        func canUpgrade(to other: SubscriptionType) -> Bool {
            switch (self, other) {
            case (.quarterly, .yearly):
                return true
            default:
                return false
            }
        }

        static func from(productID: String) -> SubscriptionType? {
            return SubscriptionType(rawValue: productID)
        }
    }

    enum MembershipStatus: Equatable {
        case free
        case quarterly(expirationDate: Date?)
        case yearly(expirationDate: Date?)
        case lifetime
    }

    private struct ActiveSubscription {
        let type: SubscriptionType
        let expirationDate: Date
    }

    private struct EntitlementSnapshot {
        let type: SubscriptionType?
        let expirationDate: Date?

        static let none = EntitlementSnapshot(type: nil, expirationDate: nil)
    }

    // MARK: - Published State

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    /// 商店目录与优惠态是否已解析完（拉品 + 试用资格）。
    /// Paywall CTA 在此为 false 时应只显示 loading，避免文案闪切。
    @Published private(set) var isStoreReady = false
    /// 年订阅是否可用 7 天免费试用：需同时满足「产品带 freeTrial intro offer」
    /// 与「当前 Apple ID 在该订阅组内仍有 intro 资格」。
    @Published private(set) var isTrialEligible = false
    @Published private(set) var currentSubscriptionType: SubscriptionType?
    @Published private(set) var expirationDate: Date?

    // MARK: - Computed Properties

    var isPro: Bool {
        currentSubscriptionType != nil
    }

    var hasLifetimeAccess: Bool {
        currentSubscriptionType == .lifetime
    }

    var quarterlyProduct: Product? {
        product(for: .quarterly)
    }

    var yearlyProduct: Product? {
        product(for: .yearly)
    }

    var lifetimeProduct: Product? {
        product(for: .lifetime)
    }

    /// 年订阅的免费试用 offer；无试用配置或不是 freeTrial 时为 nil。
    var yearlyFreeTrialOffer: Product.SubscriptionOffer? {
        guard let offer = yearlyProduct?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else {
            return nil
        }
        return offer
    }

    /// 试用天数，由 offer 周期换算，避免把 "7 天" 写死在 UI 里。
    var trialDayCount: Int? {
        guard let offer = yearlyFreeTrialOffer else {
            return nil
        }

        let unitDays: Int
        switch offer.period.unit {
        case .day: unitDays = 1
        case .week: unitDays = 7
        case .month: unitDays = 30
        case .year: unitDays = 365
        @unknown default: return nil
        }

        return offer.period.value * unitDays * offer.periodCount
    }

    // 兼容旧引用命名，后续可移除。
    var monthlyProduct: Product? {
        quarterlyProduct
    }

    var currentProductID: String? {
        currentSubscriptionType?.rawValue
    }

    var membershipStatus: MembershipStatus {
        guard let currentSubscriptionType else {
            return .free
        }

        switch currentSubscriptionType {
        case .quarterly:
            return .quarterly(expirationDate: expirationDate)
        case .yearly:
            return .yearly(expirationDate: expirationDate)
        case .lifetime:
            return .lifetime
        }
    }

    var availablePurchaseTypes: [SubscriptionType] {
        guard let currentSubscriptionType else {
            return [.yearly, .quarterly, .lifetime]
        }

        switch currentSubscriptionType {
        case .quarterly:
            return [.yearly]
        case .yearly:
            return []
        case .lifetime:
            return []
        }
    }

    var availableUpgradeType: SubscriptionType? {
        guard let current = currentSubscriptionType else {
            return nil
        }

        let candidates = SubscriptionType.allCases.filter { current.canUpgrade(to: $0) }
        return candidates.first { product(for: $0) != nil }
    }

    // MARK: - Private State

    private var transactionListener: Task<Void, Never>?

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public Methods

    func startListeningForTransactions() {
        transactionListener?.cancel()
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handleTransactionUpdate(result)
            }
        }
    }

    func fetchProducts() async {
        // 拉品不占用 isLoading：该标志只表示购买/恢复进行中。
        // Paywall CTA 的首屏过渡靠 isStoreReady，避免每次进页因拉品把整块 footer 闪成 spinner。
        errorMessage = nil

        do {
            let storeProducts = try await Product.products(for: ProductID.all)
            guard !storeProducts.isEmpty else {
                products = []
                isTrialEligible = false
                errorMessage = SubscriptionError.productNotFound.errorDescription
                isStoreReady = true
                return
            }

            products = storeProducts.sorted(by: { $0.price < $1.price })
            await checkTrialEligibility()
            isStoreReady = true
        } catch {
            isTrialEligible = false
            errorMessage = SubscriptionError.networkError.errorDescription
            isStoreReady = true
        }
    }

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let type = SubscriptionType.from(productID: product.id)
        do {
            let result = try await product.purchase()
            return await handlePurchaseResult(result, type: type)
        } catch {
            errorMessage = SubscriptionError.unknown(error).errorDescription
            trackPurchaseFailureIfPossible(type: type, reason: errorMessage)
            return false
        }
    }

    func purchase(_ type: SubscriptionType) async -> Bool {
        await refreshEntitlementState()

        guard let blockReason = purchaseBlockReason(for: type) else {
            guard let product = product(for: type) else {
                errorMessage = SubscriptionError.productNotFound.errorDescription
                AnalyticsService.trackPurchaseFailed(plan: type, reason: "product_not_found")
                return false
            }

            return await purchase(product)
        }

        errorMessage = purchaseBlockReasonMessage(blockReason)
        AnalyticsService.trackPurchaseFailed(plan: type, reason: "purchase_blocked")
        return false
    }

    func canPurchase(_ type: SubscriptionType) -> Bool {
        purchaseBlockReason(for: type) == nil
    }

    func purchaseBlockMessage(for type: SubscriptionType) -> String? {
        guard let reason = purchaseBlockReason(for: type) else {
            return nil
        }

        return purchaseBlockReasonMessage(reason)
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshEntitlementState()
        } catch {
            errorMessage = SubscriptionError.networkError.errorDescription
        }
    }

    func checkSubscriptionStatus(refreshFromAppStore: Bool = false) async {
        if refreshFromAppStore {
            try? await AppStore.sync()
        }
        await refreshEntitlementState()
    }

    /// 解析年订阅的试用资格。Apple 规则：同一订阅组内每个 Apple ID 终身只能用一次
    /// introductory offer，且当前已有权益的用户不再展示试用。
    func checkTrialEligibility() async {
        guard let subscription = yearlyProduct?.subscription,
              yearlyFreeTrialOffer != nil,
              currentSubscriptionType == nil else {
            isTrialEligible = false
            return
        }

        let eligible = await subscription.isEligibleForIntroOffer
        // await 期间权益可能已被并发的交易更新改写，落值前重新确认一次
        isTrialEligible = eligible && currentSubscriptionType == nil
    }

    // MARK: - Private Methods

    private func purchaseBlockReason(for type: SubscriptionType) -> PurchaseBlockReason? {
        guard let currentType = currentSubscriptionType else {
            return nil
        }

        guard currentType != .lifetime else {
            return .lifetimeAlreadyOwned
        }

        guard type != .lifetime else {
            return .lifetimePurchaseBlockedDuringActiveSubscription
        }

        guard currentType != type else {
            return .currentPlanAlreadyActive
        }

        guard currentType.canUpgrade(to: type) else {
            return .upgradeOnly
        }

        return nil
    }

    private func purchaseBlockReasonMessage(_ reason: PurchaseBlockReason) -> String {
        switch reason {
        case .lifetimeAlreadyOwned:
            return NSLocalizedString("You already have lifetime access", comment: "")
        case .lifetimePurchaseBlockedDuringActiveSubscription:
            return NSLocalizedString("Lifetime purchase is available after your current subscription expires", comment: "")
        case .currentPlanAlreadyActive:
            return NSLocalizedString("Current plan is already active", comment: "")
        case .upgradeOnly:
            return NSLocalizedString("Only upgrades to a higher plan are supported", comment: "")
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            return
        }

        await refreshEntitlementState()
        await transaction.finish()
    }

    private func handlePurchaseResult(
        _ result: Product.PurchaseResult,
        type: SubscriptionType?
    ) async -> Bool {
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                errorMessage = SubscriptionError.verificationFailed.errorDescription
                trackPurchaseFailureIfPossible(type: type, reason: "verification_failed")
                return false
            }

            let isTrialStart = transaction.offerType == .introductory
            await refreshEntitlementState()
            await transaction.finish()
            trackPurchaseCompletedIfPossible(type: type, isTrialStart: isTrialStart)
            return true

        case .userCancelled:
            errorMessage = SubscriptionError.purchaseCancelled.errorDescription
            trackPurchaseCancelledIfPossible(type: type)
            return false

        case .pending:
            errorMessage = SubscriptionError.purchasePending.errorDescription
            trackPurchasePendingIfPossible(type: type)
            return false

        @unknown default:
            errorMessage = SubscriptionError.verificationFailed.errorDescription
            trackPurchaseFailureIfPossible(type: type, reason: "unknown_purchase_result")
            return false
        }
    }

    /// - Parameter isTrialStart: 本笔交易是否实际开启试用（来自 StoreKit offerType）
    private func trackPurchaseCompletedIfPossible(
        type: SubscriptionType?,
        isTrialStart: Bool
    ) {
        guard let type else {
            return
        }
        AnalyticsService.trackPurchaseCompleted(plan: type, isTrialStart: isTrialStart)
    }

    private func trackPurchaseCancelledIfPossible(type: SubscriptionType?) {
        guard let type else {
            return
        }
        AnalyticsService.trackPurchaseCancelled(plan: type)
    }

    private func trackPurchasePendingIfPossible(type: SubscriptionType?) {
        guard let type else {
            return
        }
        AnalyticsService.trackPurchasePending(plan: type)
    }

    private func trackPurchaseFailureIfPossible(type: SubscriptionType?, reason: String?) {
        guard let type else {
            return
        }
        AnalyticsService.trackPurchaseFailed(plan: type, reason: reason)
    }

    private func refreshEntitlementState() async {
        let snapshot = await resolveCurrentEntitlement()
        apply(snapshot)
        // 权益变化会影响试用资格（例如刚订阅成功后不该再展示试用）
        await checkTrialEligibility()
    }

    /// 读取 StoreKit 当前已生效的会员权益，并归一化成应用内部的会员状态。
    /// 判定优先级：
    /// 1. 只处理 verified 交易
    /// 2. 跳过已撤销/退款的交易
    /// 3. 只识别当前定义过的 product id
    /// 4. 只要存在 lifetime，最终就返回 lifetime
    /// 5. 否则在有效订阅里选择到期时间最晚的一个
    private func resolveCurrentEntitlement() async -> EntitlementSnapshot {
        var activeSubscription: ActiveSubscription?
        var hasLifetimeAccess = false
        let now = Date()

        for await result in Transaction.currentEntitlements {
            // StoreKit 只允许把验证通过的交易视为可信会员权益。
            guard case .verified(let transaction) = result else {
                continue
            }

            // 退款、撤销、家庭共享被收回等场景都不应继续授予会员权益。
            let isRevoked = transaction.revocationDate != nil || transaction.revocationReason != nil
            guard isRevoked == false else {
                continue
            }

            // 只处理当前应用里声明过的 SKU，未知 product id 一律忽略。
            guard let type = SubscriptionType.from(productID: transaction.productID) else {
                continue
            }

            // lifetime 是永久买断，只要存在一条有效 entitlement，最终就优先返回 lifetime。
            if type == .lifetime {
                hasLifetimeAccess = true
                continue
            }

            // 已被升级替代的旧订阅不再代表当前权益，例如季度升级到年度后的旧季度单。
            guard transaction.isUpgraded == false else {
                continue
            }

            // 自动续订订阅必须带有过期时间；没有过期时间就不是这里要处理的有效订阅。
            guard let expirationDate = transaction.expirationDate else {
                continue
            }

            // 过期订阅不再授予会员权益。
            guard expirationDate.timeIntervalSince(now) > 0 else {
                continue
            }

            // 如果存在多个有效订阅，保留到期时间更晚的那个。
            let candidate = ActiveSubscription(type: type, expirationDate: expirationDate)
            activeSubscription = mostRecentSubscription(existing: activeSubscription, candidate: candidate)
        }

        // lifetime 的优先级最高，高于季度/年度订阅。
        guard hasLifetimeAccess == false else {
            return EntitlementSnapshot(type: .lifetime, expirationDate: nil)
        }

        // 没有 lifetime 且没有任何有效订阅时，视为 free。
        guard let activeSubscription else {
            return .none
        }

        // 返回当前最合适的有效订阅及其过期时间，供 UI 和业务层统一使用。
        return EntitlementSnapshot(
            type: activeSubscription.type,
            expirationDate: activeSubscription.expirationDate
        )
    }

    private func mostRecentSubscription(
        existing: ActiveSubscription?,
        candidate: ActiveSubscription
    ) -> ActiveSubscription {
        guard let existing else {
            return candidate
        }

        guard candidate.expirationDate > existing.expirationDate else {
            return existing
        }

        return candidate
    }

    private func apply(_ snapshot: EntitlementSnapshot) {
        currentSubscriptionType = snapshot.type
        expirationDate = snapshot.expirationDate
        AppSettings.shared.isPremiumUser = snapshot.type != nil
    }

    private func product(for type: SubscriptionType) -> Product? {
        products.first(where: { $0.id == type.rawValue })
    }
}
