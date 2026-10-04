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
    static let canvas = Color(settingsRGB: 0x17181F)
    static let surface = Color(settingsRGB: 0x22242A)
    static let ink = Color.white
    static let muted = Color(settingsRGB: 0xC8C9CD)
    static let faint = Color(settingsRGB: 0x8E9098)
    static let accent = Color(settingsRGB: 0xF3B14C)
    static let divider = Color.white.opacity(0.10)
    static let pill = Color.white.opacity(0.10)
    static let pageInset: CGFloat = 16
    static let cardRadius: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let rowMinHeight: CGFloat = 44
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
            .navigationTitle(L10n.string("设置"))
            .navigationBarTitleDisplayMode(.large)
            .settingsNavigationChrome()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .mail:
            #if canImport(MessageUI)
                MailComposeView()
            #else
                Text(L10n.string("此设备不支持发送邮件"))
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
        .accessibilityHint(Text(L10n.string("查看购买信息和功能区别")))
    }

    // MARK: - 支持者版
    private var supporterSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.string("购买与恢复"))
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
                ? L10n.string("年度 Pro 已启用")
                : L10n.string("永久 Pro 已解锁")
        }

        if purchaseManager.isUsingTrialSupporterAccess {
            return L10n.string("支持者版试用中")
        }

        if purchaseManager.isSupporterTrialExpired {
            return L10n.string("体验已结束")
        }

        return L10n.string("解锁进阶功能")
    }

    private var supporterRowSubtitle: String {
        if purchaseManager.hasPaidSupporterAccess {
            return purchaseManager.supporterAccessKind == .annual
                ? L10n.string("查看订阅状态和功能区别")
                : L10n.string("查看购买信息和功能区别")
        }

        if purchaseManager.isUsingTrialSupporterAccess {
            return String(format: L10n.string("还剩 %lld 天，可选择年度或永久 Pro"), purchaseManager.supporterTrialDaysRemaining)
        }

        if purchaseManager.isSupporterTrialExpired {
            return L10n.string("3 天体验已结束，可选择年度或永久 Pro")
        }

        if purchaseManager.canStartSupporterTrial {
            return L10n.string("可先免费体验 3 天，也可选择年度或永久 Pro")
        }

        return L10n.string("可选择年度订阅或一次购买的永久 Pro")
    }

    // MARK: - 关于与支持
    private var aboutSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.string("关于与支持"))
                    .settingsSectionHeading()
                Spacer()
            }

            VStack(spacing: 0) {
                SettingRow(
                    title: L10n.string("给删图评分"),
                    showsChevron: false,
                    action: requestAppReview
                )

                SettingsHairline()

                SettingRow(
                    title: L10n.string("邮件反馈"),
                    subtitle: AppConstants.feedbackEmail,
                    action: handleMailAction
                )

                SettingsHairline()

                SettingRow(
                    title: L10n.string("隐私说明"),
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
                Text(L10n.string("偏好设置"))
                    .settingsSectionHeading()
                Spacer()
            }

            VStack(spacing: 0) {
                SettingRow(
                    title: L10n.string("手势与播放"),
                    subtitle: gestureSettingsSubtitle,
                    action: {
                        activeSheet = .gestureSettings
                    }
                )

                SettingsHairline()

                ReviewSortOrderSettingRow(selectedValue: $reviewSortOrderValue)

                SettingsHairline()

                SettingRow(
                    title: L10n.string("语言"),
                    subtitle: selectedLanguage.title,
                    action: {
                        activeSheet = .languageSettings
                    }
                )

                SettingsHairline()

                SettingToggleRow(
                    title: L10n.string("触感反馈"),
                    subtitle: L10n.string("滑动、撤销和归类时提供轻微反馈"),
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
                Text(L10n.string("数据与权限"))
                    .settingsSectionHeading()
                Spacer()
            }

            VStack(spacing: 0) {
                SettingRow(
                    title: L10n.string("本机整理数据"),
                    subtitle: localDataSubtitle,
                    showsChevron: false,
                    action: {
                        showingClearLocalDataConfirmation = true
                    }
                )
                .confirmationDialog(
                    L10n.string("清空本机整理记录？"),
                    isPresented: $showingClearLocalDataConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(L10n.string("清空"), role: .destructive) {
                        clearLocalOrganizeData()
                    }
                    Button(L10n.string("取消"), role: .cancel) {}
                } message: {
                    Text(L10n.string("待删除、待收藏和已整理进度会被清空，不会删除照片库中的任何照片。"))
                }

                SettingsHairline()

                SettingRow(
                    title: L10n.string("照片访问权限"),
                    subtitle: photoAccessSubtitle,
                    action: {
                        dataManager.managePhotoLibraryAccessSettings()
                    }
                )

                SettingsHairline()

                SettingRow(
                    title: L10n.string("重新查看引导"),
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

            Text(L10n.string("让照片整理变得简单"))
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
                .padding(.bottom, 96)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var photoAccessSubtitle: String {
        switch dataManager.photoLibraryManager.authorizationStatus {
        case .authorized:
            return L10n.string("全部照片")
        case .limited:
            return L10n.string("仅 \(dataManager.photoLibraryManager.totalPhotosCount) 张")
        case .denied, .restricted:
            return L10n.string("未授权")
        case .notDetermined:
            return L10n.string("未选择")
        @unknown default:
            return L10n.string("查看权限")
        }
    }

    private var localDataSubtitle: String {
        let reviewedCount = dataManager.reviewedAssetIDs.count
        let pendingCount = dataManager.deleteCandidates.count + dataManager.favoriteCandidates.count
        if reviewedCount > 0 {
            return L10n.string("已整理 \(compactPhotoCount(reviewedCount))")
        }
        if pendingCount > 0 {
            return L10n.string("待确认 \(compactPhotoCount(pendingCount))")
        }
        return L10n.string("无记录")
    }

    private var gestureSettingsSubtitle: String {
        let videoPlayback = reviewVideoAutoPlay ? L10n.string("视频自动") : L10n.string("视频手动")
        let livePhotoPlayback = reviewLivePhotoAutoPlay ? L10n.string("实况自动") : L10n.string("实况手动")
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
                return L10n.string("\(oneDecimalTrimmed(Double(count) / 10_000)) 万张")
            }
            return L10n.string("\(count) 张")
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
            URLQueryItem(name: "subject", value: L10n.string("删图 App 反馈")),
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
        showSettingsToast(L10n.string("已清空本机整理记录"), icon: "checkmark.circle.fill", style: .positive)
    }

    private func resetIntro() {
        hasSeenPhotoDeleteIntro = false
        hasCompletedOnboarding = false
        showSettingsToast(L10n.string("已恢复开屏引导"), icon: "sparkles", style: .positive)
    }

    private func requestAppReview() {
        #if canImport(UIKit)
        UIApplication.shared.open(AppConstants.appStoreReviewURL) { opened in
            guard !opened else { return }
            UIApplication.shared.open(AppConstants.appStoreProductURL)
        }
        #else
        showSettingsToast(
            L10n.string("稍后可在 App Store 评分"),
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

    var id: String {
        switch self {
        case .mail: return "mail"
        case .privacy: return "privacy"
        case .supporter: return "supporter"
        case .gestureSettings: return "gestureSettings"
        case .languageSettings: return "languageSettings"
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
        .accessibilityLabel(Text(title.appLocalized))
        .accessibilityValue(Text(subtitle.appLocalized))
    }

    private var titleLabel: some View {
        Text(title.appLocalized)
            .settingsRowTitle()
            .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    private var subtitleLabel: some View {
        if !subtitle.isEmpty {
            Text(subtitle.appLocalized)
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
                Text(title.appLocalized)
                    .settingsRowTitle()
                    .multilineTextAlignment(.leading)

                Text(subtitle.appLocalized)
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
                    Text(L10n.string("照片顺序"))
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
        .accessibilityLabel(Text(L10n.string("照片顺序")))
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
                    Text(L10n.string("每轮照片数量"))
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
        .accessibilityLabel(Text(L10n.string("每轮照片数量")))
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
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(PhotoDeleteStyle.hairline, lineWidth: 1)
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
                    .padding(.bottom, 24)
                    .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(L10n.string("手势与播放"))
            .navigationBarTitleDisplayMode(.inline)
            .settingsNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("完成")) {
                        dismiss()
                    }
                    .foregroundStyle(SettingsChrome.accent)
                }
            }
        }
    }

    private var reviewSortOrderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("浏览顺序"))
                .settingsSectionHeading()

            ReviewSortOrderSettingRow(selectedValue: $reviewSortOrderValue)
                .settingsGroupedCard()
        }
    }

    private var randomReviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("随机浏览"))
                .settingsSectionHeading()

            VStack(spacing: 0) {
                RandomReviewBatchSizeSettingRow(selectedValue: $randomReviewBatchSizeValue)

                SettingsHairline()

                SettingToggleRow(
                    title: L10n.string("隐藏已归类照片"),
                    subtitle: L10n.string("默认不再显示已加入用户相册的照片"),
                    isOn: $randomReviewHideFiledPhotos
                )
            }
            .settingsGroupedCard()
        }
    }

    private var mediaPlaybackSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string("播放"))
                .settingsSectionHeading()

            VStack(spacing: 0) {
                SettingToggleRow(
                    title: L10n.string("视频自动播放"),
                    subtitle: L10n.string("只播放当前视频，切换后会自动停止"),
                    isOn: $reviewVideoAutoPlay
                )

                SettingsHairline()

                SettingToggleRow(
                    title: L10n.string("实况照片自动播放"),
                    subtitle: L10n.string("进入当前照片时只播放一次，也可点右上角手动控制"),
                    isOn: $reviewLivePhotoAutoPlay
                )

                SettingsHairline()

                SettingToggleRow(
                    title: L10n.string("视频和实况照片静音播放"),
                    subtitle: L10n.string("开启后每次进入整理页默认静音；整理页可临时打开声音"),
                    isOn: $reviewVideoMuted
                )

                SettingsHairline()

                SettingToggleRow(
                    title: L10n.string("触感反馈"),
                    subtitle: L10n.string("滑动、撤销和归类时提供轻微反馈"),
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
                            Text(L10n.string("显示语言"))
                                .settingsSectionHeading()

                            Text(L10n.string("默认跟随 iPhone 系统语言。也可以在这里固定删图的显示语言。"))
                                .font(.body)
                                .foregroundStyle(SettingsChrome.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        searchField

                        languageList
                    }
                    .padding(.horizontal, SettingsChrome.pageInset)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(L10n.string("语言"))
            .navigationBarTitleDisplayMode(.inline)
            .settingsNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("完成")) {
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
                prompt: Text(L10n.string("搜索语言")).foregroundColor(SettingsChrome.muted)
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.body)
            .foregroundStyle(SettingsChrome.ink)
            .submitLabel(.search)
            .accessibilityLabel(Text(L10n.string("搜索语言")))

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
                .accessibilityLabel(Text(L10n.string("清除搜索")))
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: SettingsChrome.cardRadius, style: .continuous)
                .fill(SettingsChrome.surface)
        )
        .accessibilityHint(Text(L10n.string("按语言名称、地区或代码搜索")))
    }

    @ViewBuilder
    private var languageList: some View {
        if visibleLanguages.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(SettingsChrome.muted)

                Text(L10n.string("未找到匹配语言"))
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
        .accessibilityValue(Text(selectedLanguage == language ? L10n.string("已选") : L10n.string("未选择")))
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
        composer.setSubject(L10n.string("删图 App 反馈"))
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
                            Text(L10n.string("隐私优先"))
                                .font(.title.weight(.semibold))
                                .foregroundStyle(PhotoDeleteStyle.primaryText)

                            Text(AppConstants.privacyShortText)
                                .photoDeleteSecondaryLabel(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: 12) {
                            PrivacyInfoRow(
                                icon: "iphone",
                                title: L10n.string("本机整理"),
                                detail: L10n.string("预览、待确认列表和删除确认都保存在你的设备上。")
                            )

                            PrivacyInfoRow(
                                icon: "icloud.slash",
                                title: L10n.string("不上传照片"),
                                detail: L10n.string("删图不接入自己的云端服务，也不会把照片发到服务器。")
                            )

                            PrivacyInfoRow(
                                icon: "person.crop.circle.badge.xmark",
                                title: L10n.string("不需要账号"),
                                detail: L10n.string("授权照片后即可使用，不需要注册或登录。")
                            )
                        }
                    }
                    .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(L10n.string("隐私"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("完成")) {
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

                            Text(L10n.string("版本 \(AppConstants.displayVersion)"))
                                .photoDeleteSecondaryLabel(.body)

                            Text(L10n.string("一个免费的相册整理工具。滑动判断照片去留，完成后再统一确认。"))
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
            .navigationTitle(L10n.string("关于"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("完成")) {
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
