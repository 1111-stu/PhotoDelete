//
//  SupporterEntitlementPolicy.swift
//  PhotoDelete
//
//  缓存的会员权益判定。`SubscriptionManager` 把权益写进 AppConstants 的 supporter
//  UserDefaults 键，这里负责判断那份缓存还能不能信（离线解锁等）。
//

import Foundation

enum SupporterAccessKind: String, Equatable {
    case quarterly
    case annual
    case lifetime

    init?(productID: String) {
        switch productID {
        case AppConstants.supporterQuarterlyProductID:
            self = .quarterly
        case AppConstants.supporterAnnualProductID:
            self = .annual
        case AppConstants.supporterLifetimeProductID:
            self = .lifetime
        default:
            return nil
        }
    }
}

enum SupporterCachedEntitlementPolicy {
    static func isValid(
        isUnlocked: Bool,
        productID: String?,
        expirationDate: Date?,
        now: Date
    ) -> Bool {
        guard isUnlocked else { return false }

        // Existing purchases predate the product-ID cache and are permanent unlocks.
        guard let productID else { return true }
        guard let accessKind = SupporterAccessKind(productID: productID) else { return false }

        switch accessKind {
        case .lifetime:
            return true
        case .quarterly, .annual:
            // 订阅类权益必须有尚未到期的过期时间，否则视为已失效。
            guard let expirationDate else { return false }
            return expirationDate > now
        }
    }
}
