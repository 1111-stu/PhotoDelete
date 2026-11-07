//
//  AppSupport.swift
//  Poca
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

    static let feedbackEmail = "2981451773@qq.com"
    static let appStoreID = "6779493280"
    static let appStoreProductURL = URL(string: "https://apps.apple.com/app/id6779493280")!
    static let appStoreReviewURL = URL(string: "itms-apps://itunes.apple.com/app/id6779493280?action=write-review")!
    static let doFirstAppStoreURL = URL(string: "https://apps.apple.com/app/id6755933357")!
    static var privacyPolicyURL: URL {
        let path = AppLanguage.current.usesChineseText ? "privacy/" : "en/privacy/"
        return URL(string: "https://photodelete.01mvp.com/\(path)")!
    }
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let technicalAppName = "Poca"
    static let zhHansAppStoreName = "Poca"
    static let enAppStoreName = "Poca"
    static var appDisplayName: String {
        L10n.string("Poca")
    }
    static let landscapeBreakpoint: CGFloat = 700
    static let hasCompletedOnboardingKey = "hasCompletedPocaOnboarding"
    static let reviewedAssetIDsKey = "pocaReviewedAssetIDs"
    static let recentOrganizedPhotosKey = "pocaRecentOrganizedPhotosV1"
    static let pendingDeleteCandidateIDsKey = "pocaPendingDeleteCandidateIDs"
    static let pendingFavoriteCandidateIDsKey = "pocaPendingFavoriteCandidateIDs"
    static let customAlbumOrderKey = "pocaCustomAlbumOrder"
    static let hasSeenAlbumSwipeHintKey = "pocaHasSeenAlbumSwipeHint"
    static let hasDismissedAlbumSwipeHintKey = "pocaHasDismissedAlbumSwipeHintV3"
    static let albumDisplayStyleKey = "pocaAlbumDisplayStyle"
    static let appLanguageKey = "pocaAppLanguage"
    static let reviewVideoAutoPlayKey = "pocaReviewMediaAutoPlay"
    static let reviewMediaAutoPlayKey = reviewVideoAutoPlayKey
    static let reviewLivePhotoAutoPlayKey = "pocaReviewLivePhotoAutoPlay"
    static let randomReviewHideFiledPhotosKey = "pocaRandomReviewHideFiledPhotos"
    static let randomReviewBatchSizeKey = "pocaRandomReviewBatchSize"
    static let reviewVideoMutedKey = "pocaReviewVideoMuted"
    static let reviewSortOrderKey = "pocaReviewSortOrder"
    static let reviewAlbumShortcutsExpandedKey = "pocaReviewAlbumShortcutsExpanded"
    static let hasSeenAlbumShortcutHintKey = "pocaHasSeenAlbumShortcutHintV2"
    static let hasSeenAlbumDownSwipeHintKey = "pocaHasSeenAlbumDownSwipeHint"
    static let hasSeenDeleteButtonTipKey = "pocaHasSeenDeleteButtonTip"
    static let hasSeenDayWallHintKey = "pocaHasSeenDayWallHint"
    static let reviewProgressByScopeKey = "pocaReviewProgressByScope"
    static let shareCardTemplateKey = "pocaShareCardTemplate"
    static let shareCardTicketPaletteKey = "pocaShareCardTicketPalette"
    static let shareCardShowDateKey = "pocaShareCardShowDate"
    static let shareCardShowLocationKey = "pocaShareCardShowLocation"
    static let openAlbumsTabNotificationName = Notification.Name("pocaOpenAlbumsTab")
    static let showsAlbumsTab = true
    /// 「上线开关」：为 false 时进阶页不进入锁定态，付费页只在设置页横幅可达。
    /// 订阅制付费页完成后打开（2026-10-09）；要临时收回只需改回 false。
    static let advancedPaywallEnabled = true
    /// 「回到那天」入口开关：第一版先隐藏，后续视觉/交互优化后再打开。
    static let dayWallEnabled = false
    static let achievementsEnabled = false
    static let supporterMonthlyProductID = "com.01mvp.photodelete.pro.monthly"
    static let supporterAnnualProductID = "com.01mvp.photodelete.pro.annual"
    static let supporterLifetimeProductID = "com.01mvp.photodelete.supporter.stats"
    static let supporterProductIDs: Set<String> = [
        supporterMonthlyProductID,
        supporterAnnualProductID,
        supporterLifetimeProductID
    ]
    static let supporterEntitlementKey = "pocaSupporterUnlocked"
    static let supporterPurchaseDateKey = "pocaSupporterPurchaseDate"
    static let supporterProductIDKey = "pocaSupporterProductID"
    static let supporterExpirationDateKey = "pocaSupporterExpirationDate"
    /// 已退役的本机 3 天试用遗留键（现由 Apple 年度 intro offer 承担试用）。
    /// 保留常量只为让 SubscriptionManager 在解析权益时清掉旧值。
    static let supporterTrialStartDateKey = "pocaSupporterTrialStartDate"
    static let isImageCompressionVisible = true
    static var privacyShortText: String {
        L10n.string("Photo cleanup happens only on this device. No account is required, and your photos are never uploaded.")
    }
}

enum HapticManager {
    private static let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private static let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private static let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private static let softFeedback = UIImpactFeedbackGenerator(style: .soft)
    private static let notificationFeedback = UINotificationFeedbackGenerator()
    private static let selectionFeedback = UISelectionFeedbackGenerator()

    /// 滚轮 / 导轨逐格划过时的「咔哒」；连续触发前先 prepare 以压低首帧延迟。
    static func prepareSelection() {
        selectionFeedback.prepare()
        softFeedback.prepare()
    }

    static func selection() {
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
    }

    /// 轻柔的落定感，用于吸附停稳等收尾时刻。
    static func softImpact(intensity: CGFloat) {
        softFeedback.impactOccurred(intensity: intensity)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .medium: mediumFeedback.impactOccurred()
        case .light: lightFeedback.impactOccurred()
        case .heavy: heavyFeedback.impactOccurred()
        default: UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationFeedback.notificationOccurred(type)
    }

}

