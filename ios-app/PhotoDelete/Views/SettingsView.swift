//
//  SettingsView.swift
//  PhotoDelete
//
//  Created by PhotoDelete Team on 11/7/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(MessageUI)
import MessageUI
#endif

enum SettingsChrome {
    static let canvas = PhotoDeleteStyle.background
    static let surface = PhotoDeleteStyle.surface
    static let ink = PhotoDeleteStyle.primaryText
    static let muted = PhotoDeleteStyle.secondaryText
    static let faint = PhotoDeleteStyle.tertiaryText
    static let accent = PhotoDeleteStyle.accent
    static let divider = PhotoDeleteStyle.hairline
    static let pill = PhotoDeleteStyle.elevatedSurface
    static let pageInset: CGFloat = PhotoDeleteStyle.screenHorizontalPadding
    static let cardRadius: CGFloat = PhotoDeleteStyle.cardRadius
    static let sectionSpacing: CGFloat = PhotoDeleteStyle.sectionSpacing
    static let rowMinHeight: CGFloat = PhotoDeleteStyle.rowMinHeight
}

private extension Color {
    init(settingsRGB hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private struct SettingsHairline: View {
    var body: some View {
        SettingsChrome.divider
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}

private struct SettingsSelectionMark: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.body.weight(.semibold))
            .foregroundStyle(isSelected ? SettingsChrome.accent : SettingsChrome.muted)
            .accessibilityHidden(true)
    }
}

extension View {
    func settingsGroupedCard() -> some View {
        background(
            RoundedRectangle(cornerRadius: SettingsChrome.cardRadius, style: .continuous)
                .fill(SettingsChrome.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: SettingsChrome.cardRadius, style: .continuous))
    }

    func settingsSectionHeading() -> some View {
        font(.title2.weight(.bold))
            .foregroundStyle(SettingsChrome.ink)
    }

    func settingsRowTitle() -> some View {
        font(.body.weight(.semibold))
            .foregroundStyle(SettingsChrome.ink)
    }

    func settingsRowValue() -> some View {
        font(.subheadline)
            .foregroundStyle(SettingsChrome.muted)
    }

    func settingsNavigationChrome() -> some View {
        toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppConstants.hasSeenIntroKey) private var hasSeenPhotoDeleteIntro = false
    @AppStorage(AppConstants.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @AppStorage(AppConstants.hapticsEnabledKey) private var hapticsEnabled = true
    @AppStorage(AppConstants.appLanguageKey) private var appLanguageValue = AppLanguage.system.rawValue
    @AppStorage(AppConstants.reviewVideoAutoPlayKey) private var reviewVideoAutoPlay = true
    @AppStorage(AppConstants.reviewLivePhotoAutoPlayKey) private var reviewLivePhotoAutoPlay = false
    @AppStorage(AppConstants.reviewSortOrderKey) private var reviewSortOrderValue = PhotoReviewSortOrder.newestFirst.rawValue
    @State private var activeSheet: SettingsSheet?
    @State private var showingClearLocalDataConfirmation = false
    @State private var settingsToast: PhotoDeleteToast?

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsChrome.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SettingsChrome.sectionSpacing) {
                        supporterBanner

                        if AppConstants.advancedPaywallEnabled {
                            supporterSection
                        }

                        // 偏好设置
                        preferencesSection

                        // 数据与权限
                        dataPermissionsSection

                        // 关于与支持
                        aboutSection

                        moreAppsSection

                        // 版本信息
                        versionInfo

                        // 底部安全区域
                        Spacer()
                            .frame(height: 100)
                    }
                    .padding(.horizontal, SettingsChrome.pageInset)
                    .padding(.top, PhotoDeleteStyle.rootContentTopSpacing)
                    .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                    .frame(maxWidth: .infinity)
                }

                if let settingsToast {
                    settingsToastView(settingsToast)
                }
            }
            .navigationTitle(L10n.string("Settings"))
            .navigationBarTitleDisplayMode(.large)
            .settingsNavigationChrome()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .mail:
            #if canImport(MessageUI)
                MailComposeView()
            #else
                Text(L10n.string("This device cannot send email"))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                    .padding()
            #endif
            case .privacy:
                PrivacyInfoView()
            case .supporter:
                SupporterView()
                    .environmentObject(dataManager)
                    .environmentObject(purchaseManager)
            case .gestureSettings:
                GestureSettingsView()
            case .languageSettings:
                LanguageSettingsView()
            case .stats:
                NavigationStack {
                    StatsView()
                        .environmentObject(dataManager)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(L10n.string("Done")) {
                                    activeSheet = nil
                                }
                                .foregroundColor(PhotoDeleteStyle.accent)
                            }
                        }
                }
            }
        }
    }

    private var supporterBanner: some View {
        Button {
            activeSheet = .supporter
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(supporterRowTitle)
                        .settingsRowTitle()
                        .multilineTextAlignment(.leading)
                    Text(supporterRowSubtitle)
                        .settingsRowValue()
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SettingsChrome.muted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(minHeight: SettingsChrome.rowMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .settingsGroupedCard()
        .accessibilityHint(Text(L10n.string("View purchase info and feature differences")))
    }

    // MARK: - 支持者版
    private var supporterSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.string("Purchases & Restore"))
                    .settingsSectionHeading()
                Spacer()
            }

            VStack(spacing: 0) {
                SettingRow(
                    title: supporterRowTitle,
                    subtitle: supporterRowSubtitle,
                    action: {
                        activeSheet = .supporter
                    }
                )
            }
            .settingsGroupedCard()
        }
    }

    private var supporterRowTitle: String {
        if purchaseManager.hasPaidSupporterAccess {
            return purchaseManager.supporterAccessKind == .annual
                ? L10n.string("Annual Pro Active")
                : L10n.string("Lifetime Pro Unlocked")
        }

        if purchaseManager.isUsingTrialSupporterAccess {
            return L10n.string("Supporter Trial Active")
        }

        if purchaseManager.isSupporterTrialExpired {
            return L10n.string("Trial Ended")
        }

        return L10n.string("Unlock Advanced Features")
    }

    private var supporterRowSubtitle: String {
        if purchaseManager.hasPaidSupporterAccess {
            return purchaseManager.supporterAccessKind == .annual
                ? L10n.string("View subscription status and plan features")
                : L10n.string("View purchase info and feature differences")
        }

        if purchaseManager.isUsingTrialSupporterAccess {
            return String(format: L10n.string("%lld days remaining. Choose Annual or Lifetime Pro anytime."), purchaseManager.supporterTrialDaysRemaining)
        }

        if purchaseManager.isSupporterTrialExpired {
            return L10n.string("The 3-day trial has ended. Choose Annual or Lifetime Pro.")
        }

        if purchaseManager.canStartSupporterTrial {
            return L10n.string("Try free for 3 days, or choose Annual or Lifetime Pro.")
        }

        return L10n.string("Choose an annual subscription or a one-time Lifetime Pro purchase.")
    }

    // MARK: - 关于与支持
    private var aboutSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.string("About and Support"))
                    .settingsSectionHeading()
                Spacer()
            }

            VStack(spacing: 0) {
                SettingRow(
                    title: L10n.string("Rate OnePhoto"),
                    showsChevron: false,
                    action: requestAppReview
                )

                SettingsHairline()

                SettingRow(
                    title: L10n.string("Email Feedback"),
                    subtitle: AppConstants.feedbackEmail,
                    action: handleMailAction
                )

                SettingsHairline()

                SettingRow(
                    title: L10n.string("Privacy Notes"),
                    action: {
                        activeSheet = .privacy
                    }
                )
            }
            .settingsGroupedCard()
        }
    }

    // MARK: - One Apps 系列
    private var moreAppsSection: some View {
        OneAppsPromotionSection()
    }

    // MARK: - 偏好设置
    private var preferencesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.string("Preferences"))
                    .settingsSectionHeading()
                Spacer()
            }

            VStack(spacing: 0) {
                SettingRow(
                    title: L10n.string("Gestures & Playback"),
                    subtitle: gestureSettingsSubtitle,
                    action: {
                        activeSheet = .gestureSettings
                    }
                )

                SettingsHairline()

                ReviewSortOrderSettingRow(selectedValue: $reviewSortOrderValue)

                SettingsHairline()

                SettingRow(
                    title: L10n.string("Language"),
                    subtitle: selectedLanguage.title,
                    action: {
                        activeSheet = .languageSettings
                    }
                )

                SettingsHairline()

                SettingToggleRow(
                    title: L10n.string("Haptic Feedback"),
                    subtitle: L10n.string("Light feedback while swiping, undoing, and sorting"),
                    isOn: $hapticsEnabled
                )
            }
            .settingsGroupedCard()
        }
    }

    // MARK: - 数据与权限
    private var dataPermissionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.string("Data & Permissions"))
                    .settingsSectionHeading()
                Spacer()
            }

            VStack(spacing: 0) {
                SettingRow(
                    title: L10n.string("Local Cleanup Data"),
                    subtitle: localDataSubtitle,
                    showsChevron: false,
                    action: {
                        showingClearLocalDataConfirmation = true
                    }
                )
                .confirmationDialog(
                    L10n.string("Clear local cleanup records?"),
                    isPresented: $showingClearLocalDataConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(L10n.string("Clear"), role: .destructive) {
                        clearLocalOrganizeData()
                    }
                    Button(L10n.string("Cancel"), role: .cancel) {}
                } message: {
                    Text(L10n.string("Pending deletes, pending favorites, and local review progress will be cleared. No photos will be deleted."))
                }

                SettingsHairline()

                SettingRow(
                    title: L10n.string("Usage stats"),
                    action: {
                        activeSheet = .stats
                    }
                )
                .accessibilityIdentifier("settings-stats-entry")

                SettingsHairline()

                SettingRow(
                    title: L10n.string("Photo Access"),
                    subtitle: photoAccessSubtitle,
                    action: {
                        dataManager.managePhotoLibraryAccessSettings()
                    }
                )

                SettingsHairline()

                SettingRow(
                    title: L10n.string("Show Intro Again"),
                    showsChevron: false,
                    action: resetIntro
                )
            }
            .settingsGroupedCard()
        }
    }

    // MARK: - 版本信息
    private var versionInfo: some View {
        VStack(spacing: 8) {
            Text("\(AppConstants.appDisplayName) v\(AppConstants.displayVersion)")
                .font(.subheadline)
                .foregroundStyle(SettingsChrome.muted)

            Text(L10n.string("Make photo cleanup simple"))
                .font(.footnote)
                .foregroundStyle(SettingsChrome.faint)
        }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageValue) ?? .system
    }

    private func settingsToastView(_ toast: PhotoDeleteToast) -> some View {
        VStack {
            Spacer()
            PhotoDeleteToastView(toast: toast)
                .padding(.bottom, PhotoDeleteStyle.Metrics.bottomChromeSpacing)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var photoAccessSubtitle: String {
        switch dataManager.photoLibraryManager.authorizationStatus {
        case .authorized:
            return L10n.string("All Photos")
        case .limited:
            return L10n.string("\(dataManager.photoLibraryManager.totalPhotosCount) photos only")
        case .denied, .restricted:
            return L10n.string("No Access")
        case .notDetermined:
            return L10n.string("Not Set")
        @unknown default:
            return L10n.string("Review Access")
        }
    }

    private var localDataSubtitle: String {
        let reviewedCount = dataManager.reviewedAssetIDs.count
        let pendingCount = dataManager.deleteCandidates.count + dataManager.favoriteCandidates.count
        if reviewedCount > 0 {
            return L10n.string("\(compactPhotoCount(reviewedCount)) reviewed")
        }
        if pendingCount > 0 {
            return L10n.string("\(compactPhotoCount(pendingCount)) pending")
        }
        return L10n.string("No Records")
    }

    private var gestureSettingsSubtitle: String {
        let videoPlayback = reviewVideoAutoPlay ? L10n.string("Video auto") : L10n.string("Video manual")
        let livePhotoPlayback = reviewLivePhotoAutoPlay ? L10n.string("Live auto") : L10n.string("Live manual")
        return "\(videoPlayback) · \(livePhotoPlayback)"
    }

    private var usesChineseCompactText: Bool {
        switch selectedLanguage {
        case .zhHans, .zhHant:
            return true
        case .system:
            return Locale.autoupdatingCurrent.language.languageCode?.identifier == "zh"
        default:
            return false
        }
    }

    private func compactPhotoCount(_ count: Int) -> String {
        if usesChineseCompactText {
            if count >= 10_000 {
                return L10n.string("\(oneDecimalTrimmed(Double(count) / 10_000))0K photos")
            }
            return L10n.string("\(count) images")
        }

        return L10n.string("\(compactPlainCount(count)) photos")
    }

    private func compactPlainCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return "\(oneDecimalTrimmed(Double(count) / 1_000_000))M"
        }
        if count >= 1_000 {
            return "\(oneDecimalTrimmed(Double(count) / 1_000))K"
        }
        return "\(count)"
    }

    private func oneDecimalTrimmed(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return String(Int(rounded))
        }
        return rounded.formatted(.number.grouping(.never).precision(.fractionLength(1)))
    }

    private func handleMailAction() {
        #if canImport(MessageUI)
        if MFMailComposeViewController.canSendMail() {
            activeSheet = .mail
        } else {
            openFeedbackMailURL()
        }
        #else
        openFeedbackMailURL()
        #endif
    }

    // MARK: - 方法
    private func openFeedbackMailURL() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConstants.feedbackEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: L10n.string("OnePhoto Feedback")),
            URLQueryItem(name: "body", value: FeedbackDiagnostics.emailBody())
        ]

        if let url = components.url {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #endif
        }
    }

    private func clearLocalOrganizeData() {
        dataManager.clearLocalOrganizeData()
        showSettingsToast(L10n.string("Local cleanup records cleared"), icon: "checkmark.circle.fill", style: .positive)
    }

    private func resetIntro() {
        hasSeenPhotoDeleteIntro = false
        hasCompletedOnboarding = false
        showSettingsToast(L10n.string("Intro will be shown again"), icon: "sparkles", style: .positive)
    }

    private func requestAppReview() {
        #if canImport(UIKit)
        UIApplication.shared.open(AppConstants.appStoreReviewURL) { opened in
            guard !opened else { return }
            UIApplication.shared.open(AppConstants.appStoreProductURL)
        }
        #else
        showSettingsToast(
            L10n.string("You can rate us later in the App Store"),
            icon: "star",
            style: .positive
        )
        #endif
    }

    private func showSettingsToast(_ message: String, icon: String, style: PhotoDeleteToastStyle) {
        let toast = PhotoDeleteToast(message: message, icon: icon, style: style)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            settingsToast = toast
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard settingsToast?.id == toast.id else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                settingsToast = nil
            }
        }
    }
}

private enum SettingsSheet: Identifiable {
    case mail
    case privacy
    case supporter
    case gestureSettings
    case languageSettings
    case stats

    var id: String {
        switch self {
        case .mail: return "mail"
        case .privacy: return "privacy"
        case .supporter: return "supporter"
        case .gestureSettings: return "gestureSettings"
        case .languageSettings: return "languageSettings"
        case .stats: return "stats"
        }
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .bold()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .allowsTightening(true)

            Text(label)
                .photoDeleteSecondaryLabel(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 设置行
struct SettingRow: View {
    let title: String
    var subtitle = ""
    var showsChevron = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    titleLabel
                    subtitleLabel
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SettingsChrome.muted)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(minHeight: SettingsChrome.rowMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(subtitle))
    }

    private var titleLabel: some View {
        Text(title)
            .settingsRowTitle()
            .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    private var subtitleLabel: some View {
        if !subtitle.isEmpty {
            Text(subtitle)
                .settingsRowValue()
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}

struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .settingsRowTitle()
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .settingsRowValue()
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .tint(SettingsChrome.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(minHeight: SettingsChrome.rowMinHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReviewSortOrderSettingRow: View {
    @Binding var selectedValue: String

    private var selectedOrder: PhotoReviewSortOrder {
        PhotoReviewSortOrder.normalized(selectedValue)
    }

    var body: some View {
        Menu {
            ForEach(PhotoReviewSortOrder.allCases) { order in
                Button {
                    selectedValue = order.rawValue
                } label: {
                    Label(
                        order.title,
                        systemImage: order == selectedOrder ? "checkmark" : order.icon
                    )
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("Photo Order"))
                        .settingsRowTitle()
                        .multilineTextAlignment(.leading)

                    Text(selectedOrder.title)
                        .settingsRowValue()
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SettingsChrome.muted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(minHeight: SettingsChrome.rowMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.string("Photo Order")))
        .accessibilityValue(Text(selectedOrder.title))
    }
}

struct RandomReviewBatchSizeSettingRow: View {
    @Binding var selectedValue: Int

    private var selectedSize: PhotoRandomReviewBatchSize {
        PhotoRandomReviewBatchSize.normalized(selectedValue)
    }

    var body: some View {
        Menu {
            ForEach(PhotoRandomReviewBatchSize.allCases) { size in
                Button {
                    selectedValue = size.rawValue
                } label: {
                    Label(
                        size.title,
                        systemImage: size == selectedSize ? "checkmark" : "photo.stack"
                    )
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("Photos per round"))
                        .settingsRowTitle()
                        .multilineTextAlignment(.leading)

                    Text(selectedSize.subtitle)
                        .settingsRowValue()
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SettingsChrome.muted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(minHeight: SettingsChrome.rowMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.string("Photos per round")))
        .accessibilityValue(Text(selectedSize.subtitle))
        .accessibilityIdentifier("random-review-batch-size-setting")
    }
}

private struct AppPromotionRow: View {
    let imageName: String
    let title: String
    let subtitle: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: PhotoDeleteStyle.Metrics.thumbnailRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PhotoDeleteStyle.Metrics.thumbnailRadius, style: .continuous)
                            .stroke(PhotoDeleteStyle.hairline, lineWidth: PhotoDeleteStyle.Metrics.cardStrokeWidth)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .photoDeletePrimaryLabel()
                        .lineLimit(1)
                        .minimumScaleFactor(0.84)

                    Text(subtitle)
                        .photoDeleteSecondaryLabel(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.84)
                }

                Spacer(minLength: 12)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PhotoDeleteStyle.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: PhotoDeleteStyle.rowMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(subtitle))
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

// MARK: - 手势设置
struct GestureSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppConstants.reviewVideoAutoPlayKey) private var reviewVideoAutoPlay = true
    @AppStorage(AppConstants.reviewLivePhotoAutoPlayKey) private var reviewLivePhotoAutoPlay = false
    @AppStorage(AppConstants.reviewVideoMutedKey) private var reviewVideoMuted = true
    @AppStorage(AppConstants.reviewSortOrderKey) private var reviewSortOrderValue = PhotoReviewSortOrder.newestFirst.rawValue
    @AppStorage(AppConstants.hapticsEnabledKey) private var hapticsEnabled = true
    @AppStorage(AppConstants.randomReviewHideFiledPhotosKey) private var randomReviewHideFiledPhotos = true
    @AppStorage(AppConstants.randomReviewBatchSizeKey) private var randomReviewBatchSizeValue = PhotoRandomReviewBatchSize.defaultValue.rawValue

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsChrome.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SettingsChrome.sectionSpacing) {
                        reviewSortOrderSection
                        randomReviewSection
                        mediaPlaybackSection
                    }
                    .padding(.horizontal, SettingsChrome.pageInset)
                    .padding(.top, 16)
                    .padding(.bottom, PhotoDeleteStyle.Metrics.contentBottomPadding)
                    .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(L10n.string("Gestures & Playback"))
            .navigationBarTitleDisplayMode(.inline)
            .settingsNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) {
                        dismiss()
                    }
                    .foregroundStyle(SettingsChrome.accent)
                }
            }
        }
    }

    private var reviewSortOrderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("Browsing Order"))
                .settingsSectionHeading()

            ReviewSortOrderSettingRow(selectedValue: $reviewSortOrderValue)
                .settingsGroupedCard()
        }
    }

    private var randomReviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("Random Browse"))
                .settingsSectionHeading()

            VStack(spacing: 0) {
                RandomReviewBatchSizeSettingRow(selectedValue: $randomReviewBatchSizeValue)

                SettingsHairline()

                SettingToggleRow(
                    title: L10n.string("Hide filed photos"),
                    subtitle: L10n.string("Photos already added to your albums are hidden by default"),
                    isOn: $randomReviewHideFiledPhotos
                )
            }
            .settingsGroupedCard()
        }
    }

    private var mediaPlaybackSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("Playback"))
                .settingsSectionHeading()

            VStack(spacing: 0) {
                SettingToggleRow(
                    title: L10n.string("Auto-play videos"),
                    subtitle: L10n.string("Only the current video plays. Playback stops when you switch photos."),
                    isOn: $reviewVideoAutoPlay
                )

                SettingsHairline()

                SettingToggleRow(
                    title: L10n.string("Auto-play Live Photos"),
                    subtitle: L10n.string("Plays once when you open the current photo. You can also control it from the top-right button."),
                    isOn: $reviewLivePhotoAutoPlay
                )

                SettingsHairline()

                SettingToggleRow(
                    title: L10n.string("Play videos and Live Photos muted"),
                    subtitle: L10n.string("When on, each review session starts muted. You can turn sound on temporarily in the review screen."),
                    isOn: $reviewVideoMuted
                )

                SettingsHairline()

                SettingToggleRow(
                    title: L10n.string("Haptic Feedback"),
                    subtitle: L10n.string("Light feedback while swiping, undoing, and sorting"),
                    isOn: $hapticsEnabled
                )
            }
            .settingsGroupedCard()
        }
    }
}

// MARK: - 语言设置
private struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppConstants.appLanguageKey) private var selectedLanguageID = AppLanguage.system.rawValue
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsChrome.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("Display Language"))
                                .settingsSectionHeading()

                            Text(L10n.string("By default, OnePhoto follows your iPhone language. You can also pin a display language here."))
                                .font(.body)
                                .foregroundStyle(SettingsChrome.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        searchField

                        languageList
                    }
                    .padding(.horizontal, SettingsChrome.pageInset)
                    .padding(.top, 16)
                    .padding(.bottom, PhotoDeleteStyle.Metrics.contentBottomPadding)
                    .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(L10n.string("Language"))
            .navigationBarTitleDisplayMode(.inline)
            .settingsNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) {
                        dismiss()
                    }
                    .foregroundStyle(SettingsChrome.accent)
                }
            }
        }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguageID) ?? .system
    }

    private var sortedLanguages: [AppLanguage] {
        AppLanguage.appLanguages.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    private var visibleLanguages: [AppLanguage] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return [AppLanguage.system] + sortedLanguages
        }

        return [AppLanguage.system]
            .filter { matches($0, query: trimmedQuery) }
            + sortedLanguages.filter { matches($0, query: trimmedQuery) }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(SettingsChrome.muted)

            TextField(
                "",
                text: $searchText,
                prompt: Text(L10n.string("Search languages")).foregroundColor(SettingsChrome.muted)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.body)
            .foregroundStyle(SettingsChrome.ink)
            .submitLabel(.search)
            .accessibilityLabel(Text(L10n.string("Search languages")))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    HapticManager.impact(.light)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(SettingsChrome.muted)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L10n.string("Clear search")))
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: SettingsChrome.cardRadius, style: .continuous)
                .fill(SettingsChrome.surface)
        )
        .accessibilityHint(Text(L10n.string("Search by language name, region, or code")))
    }

    @ViewBuilder
    private var languageList: some View {
        if visibleLanguages.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(SettingsChrome.muted)

                Text(L10n.string("No matching languages"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SettingsChrome.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .settingsGroupedCard()
        } else {
            VStack(spacing: 0) {
                ForEach(visibleLanguages) { language in
                    languageRow(language)

                    if language != visibleLanguages.last {
                        SettingsHairline()
                    }
                }
            }
            .settingsGroupedCard()
        }
    }

    private func languageRow(_ language: AppLanguage) -> some View {
        Button {
            selectedLanguageID = language.rawValue
            HapticManager.impact(.light)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.title)
                        .settingsRowTitle()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(language.detail)
                        .settingsRowValue()
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 8)

                if language.isRightToLeft {
                    Text("RTL")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(SettingsChrome.ink)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Capsule().fill(SettingsChrome.pill))
                }

                SettingsSelectionMark(isSelected: selectedLanguage == language)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(minHeight: SettingsChrome.rowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(language.title))
        .accessibilityHint(Text(language.detail))
        .accessibilityAddTraits(selectedLanguage == language ? .isSelected : [])
        .accessibilityValue(Text(selectedLanguage == language ? L10n.string("Selected") : L10n.string("Not Set")))
    }

    private func matches(_ language: AppLanguage, query: String) -> Bool {
        language.searchTokens.contains { token in
            token.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}

// MARK: - 邮件编写视图
#if canImport(MessageUI)
struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(L10n.string("OnePhoto Feedback"))
        composer.setToRecipients([AppConstants.feedbackEmail])
        composer.setMessageBody(FeedbackDiagnostics.emailBody(), isHTML: false)

        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposeView

        init(_ parent: MailComposeView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}
#endif

// MARK: - 隐私说明视图
struct PrivacyInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PhotoDeleteScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("Privacy First"))
                                .font(.title.weight(.semibold))
                                .foregroundStyle(PhotoDeleteStyle.primaryText)

                            Text(AppConstants.privacyShortText)
                                .photoDeleteSecondaryLabel(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: 12) {
                            PrivacyInfoRow(
                                icon: "iphone",
                                title: L10n.string("On-device cleanup"),
                                detail: L10n.string("Previews, pending lists, and delete confirmations stay on your device.")
                            )

                            PrivacyInfoRow(
                                icon: "icloud.slash",
                                title: L10n.string("No photo uploads"),
                                detail: L10n.string("OnePhoto does not use its own cloud service and never sends photos to a server.")
                            )

                            PrivacyInfoRow(
                                icon: "person.crop.circle.badge.xmark",
                                title: L10n.string("No account needed"),
                                detail: L10n.string("Grant photo access and start using it. No sign-up or login required.")
                            )
                        }
                    }
                    .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.string("Privacy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) {
                        dismiss()
                    }
                    .foregroundColor(PhotoDeleteStyle.accent)
                }
            }
        }
    }
}

struct PrivacyInfoRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.accent)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PhotoDeleteStyle.elevatedSurface)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .photoDeletePrimaryLabel(.body.weight(.semibold))

                Text(detail)
                    .photoDeleteSecondaryLabel(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .photoDeleteCard()
    }
}

// MARK: - 关于视图
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PhotoDeleteScreenBackground()

                ScrollView {
                    VStack(spacing: 32) {
                        // App图标
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(PhotoDeleteStyle.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(PhotoDeleteStyle.hairline, lineWidth: 1)
                                )
                                .frame(width: 120, height: 120)

                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48, weight: .medium))
                                .foregroundColor(PhotoDeleteStyle.accent)
                        }

                        // App信息
                        VStack(spacing: 16) {
                            Text(AppConstants.appDisplayName)
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(PhotoDeleteStyle.primaryText)

                            Text(L10n.string("Version \(AppConstants.displayVersion)"))
                                .photoDeleteSecondaryLabel(.body)

                            Text(L10n.string("A free photo cleanup tool. Swipe to decide what stays, then confirm everything at the end."))
                                .photoDeleteSecondaryLabel(.body)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                        }
                    }
                    .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    .padding(.top, 52)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(L10n.string("About"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) {
                        dismiss()
                    }
                    .foregroundColor(PhotoDeleteStyle.accent)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataManager())
        .environmentObject(PurchaseManager())
}
