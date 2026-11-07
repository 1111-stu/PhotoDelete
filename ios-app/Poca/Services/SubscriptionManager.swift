//
//  SubscriptionManager.swift
//  PhotoDelete
//
//  订阅权益的唯一真相来源：月度 / 年度 / 永久买断三档。
//  权益解析结果会写回 AppConstants 的 supporter UserDefaults 键，
//  离线解锁据此工作。
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
            return L10n.string("Product not found")
        case .purchaseCancelled:
            return L10n.string("Purchase cancelled")
        case .purchasePending:
            return L10n.string("Purchase pending approval")
        case .verificationFailed:
            return L10n.string("Purchase verification failed")
        case .networkError:
            return L10n.string("Network error, please try again")
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

    // MARK: - Subscription Type

    /// 三档套餐。商品 ID 只从 `AppConstants` 取一处，避免字面量在多处漂移。
    enum SubscriptionType: CaseIterable {
        case monthly
        case yearly
        case lifetime

        var productID: String {
            switch self {
            case .monthly:
                return AppConstants.supporterMonthlyProductID
            case .yearly:
                return AppConstants.supporterAnnualProductID
            case .lifetime:
                return AppConstants.supporterLifetimeProductID
            }
        }

        var isSubscription: Bool {
            self != .lifetime
        }

        func canUpgrade(to other: SubscriptionType) -> Bool {
            switch (self, other) {
            case (.monthly, .yearly):
                return true
            default:
                return false
            }
        }

        static func from(productID: String) -> SubscriptionType? {
            allCases.first { $0.productID == productID }
        }
    }

    enum MembershipStatus: Equatable {
        case free
        case monthly(expirationDate: Date?)
        case yearly(expirationDate: Date?)
        case lifetime
    }

    private struct ActiveSubscription {
        let type: SubscriptionType
        let expirationDate: Date
        let purchaseDate: Date?
    }

    private struct EntitlementSnapshot {
        let type: SubscriptionType?
        let expirationDate: Date?
        /// 购买日期，缓存到 UserDefaults 供设置页展示（买断无到期时间）。
        let purchaseDate: Date?

        static let none = EntitlementSnapshot(type: nil, expirationDate: nil, purchaseDate: nil)
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

    var monthlyProduct: Product? {
        product(for: .monthly)
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

    var currentProductID: String? {
        currentSubscriptionType?.productID
    }

    var membershipStatus: MembershipStatus {
        guard let currentSubscriptionType else {
            return .free
        }

        switch currentSubscriptionType {
        case .monthly:
            return .monthly(expirationDate: expirationDate)
        case .yearly:
            return .yearly(expirationDate: expirationDate)
        case .lifetime:
            return .lifetime
        }
    }

    var availablePurchaseTypes: [SubscriptionType] {
        guard let currentSubscriptionType else {
            return [.yearly, .monthly, .lifetime]
        }

        switch currentSubscriptionType {
        case .monthly:
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

    /// 幂等：重复调用（如视图重建再次进 `.task`）不会重复起监听。
    func startListeningForTransactions() {
        if let transactionListener, transactionListener.isCancelled == false {
            return
        }

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
            let storeProducts = try await Product.products(for: Set(SubscriptionType.allCases.map(\.productID)))
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

        do {
            let result = try await product.purchase()
            return await handlePurchaseResult(result)
        } catch {
            errorMessage = SubscriptionError.unknown(error).errorDescription
            return false
        }
    }

    func purchase(_ type: SubscriptionType) async -> Bool {
        await refreshEntitlementState()

        guard let blockReason = purchaseBlockReason(for: type) else {
            guard let product = product(for: type) else {
                errorMessage = SubscriptionError.productNotFound.errorDescription
                return false
            }

            return await purchase(product)
        }

        errorMessage = purchaseBlockReasonMessage(blockReason)
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
            return L10n.string("You already have lifetime access")
        case .lifetimePurchaseBlockedDuringActiveSubscription:
            return L10n.string("Lifetime purchase is available after your current subscription expires")
        case .currentPlanAlreadyActive:
            return L10n.string("Current plan is already active")
        case .upgradeOnly:
            return L10n.string("Only upgrades to a higher plan are supported")
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            return
        }

        await refreshEntitlementState()
        await transaction.finish()
    }

    private func handlePurchaseResult(_ result: Product.PurchaseResult) async -> Bool {
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                errorMessage = SubscriptionError.verificationFailed.errorDescription
                return false
            }

            await refreshEntitlementState()
            await transaction.finish()
            return true

        case .userCancelled:
            // 用户主动取消不是错误，不该在付费页弹红字（与旧 PurchaseManager 的既有行为一致）。
            errorMessage = nil
            return false

        case .pending:
            errorMessage = SubscriptionError.purchasePending.errorDescription
            return false

        @unknown default:
            errorMessage = SubscriptionError.verificationFailed.errorDescription
            return false
        }
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
        var lifetimePurchaseDate: Date?
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
                lifetimePurchaseDate = transaction.purchaseDate
                continue
            }

            // 已被升级替代的旧订阅不再代表当前权益，例如月度升级到年度后的旧月度单。
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
            let candidate = ActiveSubscription(
                type: type,
                expirationDate: expirationDate,
                purchaseDate: transaction.purchaseDate
            )
            activeSubscription = mostRecentSubscription(existing: activeSubscription, candidate: candidate)
        }

        // lifetime 的优先级最高，高于月度/年度订阅。
        if let lifetimePurchaseDate {
            return EntitlementSnapshot(
                type: .lifetime,
                expirationDate: nil,
                purchaseDate: lifetimePurchaseDate
            )
        }

        // 没有 lifetime 且没有任何有效订阅时，视为 free。
        guard let activeSubscription else {
            return debugUITestEntitlementOverride() ?? .none
        }

        // 返回当前最合适的有效订阅及其过期时间，供 UI 和业务层统一使用。
        return EntitlementSnapshot(
            type: activeSubscription.type,
            expirationDate: activeSubscription.expirationDate,
            purchaseDate: activeSubscription.purchaseDate
        )
    }

    /// UI 测试用的解锁钩子：本地 StoreKit 在 UI 测试进程里返回空交易，
    /// 会把启动前写好的缓存权益清掉，因此在这里合成一份权益快照。
    private func debugUITestEntitlementOverride() -> EntitlementSnapshot? {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["PHOTO_DELETE_UI_TEST_SUPPORTER_UNLOCKED"] == "1" else {
            return nil
        }

        let defaults = UserDefaults.standard
        guard let rawProductID = defaults.string(forKey: AppConstants.supporterProductIDKey),
              let type = SubscriptionType.from(productID: rawProductID) else {
            return nil
        }

        return EntitlementSnapshot(
            type: type,
            expirationDate: defaults.object(forKey: AppConstants.supporterExpirationDateKey) as? Date,
            purchaseDate: defaults.object(forKey: AppConstants.supporterPurchaseDateKey) as? Date
        )
        #else
        return nil
        #endif
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
        persistSupporterCache(snapshot)
    }

    /// 把权益写回既有的 supporter UserDefaults 键。
    /// `SupporterCachedEntitlementPolicy`
    /// 直接读这些键，因此离线解锁依赖这里。
    private func persistSupporterCache(_ snapshot: EntitlementSnapshot) {
        let defaults = UserDefaults.standard

        // 本机 3 天试用已退役（改由 Apple 年度 intro offer 承担），清掉旧值避免残留。
        defaults.removeObject(forKey: AppConstants.supporterTrialStartDateKey)

        guard let type = snapshot.type else {
            defaults.removeObject(forKey: AppConstants.supporterEntitlementKey)
            defaults.removeObject(forKey: AppConstants.supporterProductIDKey)
            defaults.removeObject(forKey: AppConstants.supporterPurchaseDateKey)
            defaults.removeObject(forKey: AppConstants.supporterExpirationDateKey)
            return
        }

        defaults.set(true, forKey: AppConstants.supporterEntitlementKey)
        defaults.set(type.productID, forKey: AppConstants.supporterProductIDKey)
        if let purchaseDate = snapshot.purchaseDate {
            defaults.set(purchaseDate, forKey: AppConstants.supporterPurchaseDateKey)
        }
        if let expirationDate = snapshot.expirationDate {
            defaults.set(expirationDate, forKey: AppConstants.supporterExpirationDateKey)
        } else {
            // 买断没有到期时间，留着旧订阅的过期时间会误判为已过期。
            defaults.removeObject(forKey: AppConstants.supporterExpirationDateKey)
        }
    }

    private func product(for type: SubscriptionType) -> Product? {
        products.first(where: { $0.id == type.productID })
    }
}
