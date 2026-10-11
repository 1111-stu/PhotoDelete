//
//  AppSupport.swift
//  PhotoDelete
//
//  应用常量与触觉反馈（非设计 token）。
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppConstants {
    static var version: String { bundleShortVersion }
    static var displayVersion: String {
        "\(bundleShortVersion) (\(bundleBuildNumber))"
    }

    private static var bundleShortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private static var bundleBuildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static let feedbackEmail = "contact@01mvp.com"
    static let appStoreID = "6779493280"
    static let appStoreProductURL = URL(string: "https://apps.apple.com/app/id6779493280")!
    static let appStoreReviewURL = URL(string: "itms-apps://itunes.apple.com/app/id6779493280?action=write-review")!
    static let oneZenAppStoreURL = URL(string: "https://apps.apple.com/app/id6780318004")!
    static let oneAppsStudioURL = URL(string: "https://oneapps.studio")!
    static let oneAppsCatalogURL = URL(string: "https://oneapps.studio/apps")!
    static var privacyPolicyURL: URL {
        let path = AppLanguage.current.usesChineseText ? "privacy/" : "en/privacy/"
        return URL(string: "https://photodelete.01mvp.com/\(path)")!
    }
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let technicalAppName = "PhotoDelete"
    static let zhHansAppStoreName = "删图"
    static let enAppStoreName = "OnePhoto"
    static var appDisplayName: String {
        L10n.string("OnePhoto")
    }
    static let landscapeBreakpoint: CGFloat = 700
    static let hapticsEnabledKey = "photoDeleteHapticsEnabled"
    static let hasCompletedOnboardingKey = "hasCompletedPhotoDeleteOnboarding"
    static let reviewedAssetIDsKey = "photoDeleteReviewedAssetIDs"
    static let recentOrganizedPhotosKey = "photoDeleteRecentOrganizedPhotosV1"
    static let pendingDeleteCandidateIDsKey = "photoDeletePendingDeleteCandidateIDs"
    static let pendingFavoriteCandidateIDsKey = "photoDeletePendingFavoriteCandidateIDs"
    static let customAlbumOrderKey = "photoDeleteCustomAlbumOrder"
    static let hasSeenAlbumSwipeHintKey = "photoDeleteHasSeenAlbumSwipeHint"
    static let hasDismissedAlbumSwipeHintKey = "photoDeleteHasDismissedAlbumSwipeHintV3"
    static let albumDisplayStyleKey = "photoDeleteAlbumDisplayStyle"
    static let appLanguageKey = "photoDeleteAppLanguage"
    static let anonymousUserIDKey = "photoDeleteAnonymousUserID"
    static let reviewVideoAutoPlayKey = "photoDeleteReviewMediaAutoPlay"
    static let reviewMediaAutoPlayKey = reviewVideoAutoPlayKey
    static let reviewLivePhotoAutoPlayKey = "photoDeleteReviewLivePhotoAutoPlay"
    static let randomReviewHideFiledPhotosKey = "photoDeleteRandomReviewHideFiledPhotos"
    static let randomReviewBatchSizeKey = "photoDeleteRandomReviewBatchSize"
    static let reviewVideoMutedKey = "photoDeleteReviewVideoMuted"
    static let reviewSortOrderKey = "photoDeleteReviewSortOrder"
    static let pendingPhotoWallDisplayModeKey = "photoDeletePendingPhotoWallDisplayMode"
    static let reviewAlbumShortcutsExpandedKey = "photoDeleteReviewAlbumShortcutsExpanded"
    static let hasSeenAlbumShortcutHintKey = "photoDeleteHasSeenAlbumShortcutHintV2"
    static let hasSeenAlbumDownSwipeHintKey = "photoDeleteHasSeenAlbumDownSwipeHint"
    static let hasSeenDeleteButtonTipKey = "photoDeleteHasSeenDeleteButtonTip"
    static let reviewProgressByScopeKey = "photoDeleteReviewProgressByScope"
    static let openAlbumsTabNotificationName = Notification.Name("photoDeleteOpenAlbumsTab")
    static let showsAlbumsTab = true
    /// 「上线开关」：为 false 时进阶页不进入锁定态，付费页只在设置页横幅可达。
    /// 订阅制付费页完成后打开（2026-10-09）；要临时收回只需改回 false。
    static let advancedPaywallEnabled = true
    static let achievementsEnabled = false
    static let supporterQuarterlyProductID = "com.01mvp.photodelete.pro.quarterly"
    static let supporterAnnualProductID = "com.01mvp.photodelete.pro.annual"
    static let supporterLifetimeProductID = "com.01mvp.photodelete.supporter.stats"
    static let supporterProductIDs: Set<String> = [
        supporterQuarterlyProductID,
        supporterAnnualProductID,
        supporterLifetimeProductID
    ]
    static let supporterEntitlementKey = "photoDeleteSupporterUnlocked"
    static let supporterPurchaseDateKey = "photoDeleteSupporterPurchaseDate"
    static let supporterProductIDKey = "photoDeleteSupporterProductID"
    static let supporterExpirationDateKey = "photoDeleteSupporterExpirationDate"
    /// 已退役的本机 3 天试用遗留键（现由 Apple 年度 intro offer 承担试用）。
    /// 保留常量只为让 SubscriptionManager 在解析权益时清掉旧值。
    static let supporterTrialStartDateKey = "photoDeleteSupporterTrialStartDate"
    static let isImageCompressionVisible = true
    static var privacyShortText: String {
        L10n.string("Photo cleanup happens only on this device. No account is required, and your photos are never uploaded.")
    }
}

enum HapticManager {
    private static let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private static let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private static let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private static let notificationFeedback = UINotificationFeedbackGenerator()

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        switch style {
        case .medium: mediumFeedback.impactOccurred()
        case .light: lightFeedback.impactOccurred()
        case .heavy: heavyFeedback.impactOccurred()
        default: UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(type)
    }

    private static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: AppConstants.hapticsEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: AppConstants.hapticsEnabledKey)
    }
}

