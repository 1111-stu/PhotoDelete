//
//  PhotoDeleteApp.swift
//  PhotoDelete
//
//  Created by jackie xiao on 11/7/25.
//

import SwiftUI

@main
struct PhotoDeleteApp: App {
    @AppStorage(AppConstants.appLanguageKey) private var appLanguageValue =
        PhotoDeleteLaunchDefaults.string(
            forKey: AppConstants.appLanguageKey,
            fallback: AppLanguage.system.rawValue
        )
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    init() {
        ReviewPlaybackPreferences.applyLaunchDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, selectedLanguage.locale)
                .modifier(AppLayoutDirectionModifier(language: selectedLanguage))
                .environment(\.photoDeleteTheme, PhotoDeleteTheme.defaultTheme)
                .tint(PhotoDeleteTheme.defaultTheme.navigationTint)
                .preferredColorScheme(.dark)
                .statusBarHidden(false)
                .task {
                    // 启动即挂上交易监听并解析权益 / 拉品：付费页首屏不会出现价格占位符，
                    // 已订阅用户也不会闪一下试用 CTA。
                    subscriptionManager.startListeningForTransactions()
                    await subscriptionManager.checkSubscriptionStatus()
                    await subscriptionManager.fetchProducts()
                }
        }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageValue) ?? .system
    }

}

private enum PhotoDeleteLaunchDefaults {
    private static let prepared: Void = {
        #if DEBUG
        PhotoDeleteUITestDefaults.applyIfNeeded()
        #endif
    }()

    static func string(forKey key: String, fallback: String) -> String {
        _ = prepared
        return UserDefaults.standard.string(forKey: key) ?? fallback
    }
}

private struct AppLayoutDirectionModifier: ViewModifier {
    let language: AppLanguage

    func body(content: Content) -> some View {
        if language == .system {
            content
        } else {
            content.environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
        }
    }
}

#if DEBUG
private enum PhotoDeleteUITestDefaults {
    static func applyIfNeeded() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PHOTO_DELETE_UI_TEST"] == "1" else { return }

        let defaults = UserDefaults.standard
        reset(defaults)

        if let appLanguage = environment["PHOTO_DELETE_UI_TEST_APP_LANGUAGE"] {
            defaults.set(appLanguage, forKey: AppConstants.appLanguageKey)
        }

        if let appAppearance = environment["PHOTO_DELETE_UI_TEST_APP_APPEARANCE"] {
            defaults.set(appAppearance, forKey: AppConstants.appAppearanceKey)
        }

        setBool(
            environment["PHOTO_DELETE_UI_TEST_HAS_COMPLETED_ONBOARDING"],
            forKey: AppConstants.hasCompletedOnboardingKey,
            defaults: defaults
        )
        setBool(
            environment["PHOTO_DELETE_UI_TEST_HAS_SEEN_INTRO"],
            forKey: AppConstants.hasSeenIntroKey,
            defaults: defaults
        )

        // 已解锁态：写入缓存权益，由 SubscriptionManager 的 DEBUG 钩子在
        // StoreKit 返回空交易时合成快照（见 SubscriptionManager.debugUITestEntitlementOverride）。
        // 用买断档，避免订阅档的过期时间边界。
        if environment["PHOTO_DELETE_UI_TEST_SUPPORTER_UNLOCKED"] == "1" {
            defaults.set(true, forKey: AppConstants.supporterEntitlementKey)
            defaults.set(AppConstants.supporterLifetimeProductID, forKey: AppConstants.supporterProductIDKey)
            defaults.set(Date(), forKey: AppConstants.supporterPurchaseDateKey)
        }
    }

    private static func reset(_ defaults: UserDefaults) {
        [
            AppConstants.appLanguageKey,
            AppConstants.hasCompletedOnboardingKey,
            AppConstants.hasSeenIntroKey,
            AppConstants.recentOrganizedPhotosKey,
            AppConstants.reviewedAssetIDsKey,
            AppConstants.pendingDeleteCandidateIDsKey,
            AppConstants.pendingFavoriteCandidateIDsKey,
            AppConstants.reviewMediaAutoPlayKey,
            AppConstants.reviewLivePhotoAutoPlayKey,
            AppConstants.reviewVideoMutedKey,
            AppConstants.reviewSortOrderKey,
            AppConstants.reviewAlbumShortcutsExpandedKey,
            AppConstants.hasSeenAlbumShortcutHintKey,
            AppConstants.hasSeenDeleteButtonTipKey,
            AppConstants.hasDismissedAlbumSwipeHintKey,
            AppConstants.reviewProgressByScopeKey,
            AppConstants.customAlbumOrderKey,
            AppConstants.appAppearanceKey,
            AppConstants.appThemeKey,
            AppConstants.supporterEntitlementKey,
            AppConstants.supporterPurchaseDateKey,
            AppConstants.supporterProductIDKey,
            AppConstants.supporterExpirationDateKey
        ].forEach(defaults.removeObject)
    }

    private static func setBool(_ rawValue: String?, forKey key: String, defaults: UserDefaults) {
        guard let rawValue else { return }
        defaults.set(rawValue == "1", forKey: key)
    }
}
#endif
