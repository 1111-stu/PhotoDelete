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
    static let canvas = Theme.background
    static let surface = Theme.surface
    static let ink = Theme.primaryText
    static let muted = Theme.secondaryText
    static let faint = Theme.tertiaryText
    static let accent = Theme.accent
    static let divider = Theme.hairline
    static let pill = Theme.elevatedSurface
    static let pageInset: CGFloat = Theme.space5
    static let cardRadius: CGFloat = Theme.radiusLg
    static let sectionSpacing: CGFloat = Theme.space6
    static let rowMinHeight: CGFloat = Theme.sizeRow
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
    @EnvironmentObject private var router: MainTabRouter
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppConstants.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @AppStorage(AppConstants.appLanguageKey) private var appLanguageValue = AppLanguage.system.rawValue
    @AppStorage(AppConstants.reviewVideoAutoPlayKey) private var reviewVideoAutoPlay = true
    @AppStorage(AppConstants.reviewLivePhotoAutoPlayKey) private var reviewLivePhotoAutoPlay = false
    @AppStorage(AppConstants.randomReviewBatchSizeKey) private var randomReviewBatchSizeValue = PhotoRandomReviewBatchSize.defaultValue.rawValue
    @AppStorage(AppConstants.randomReviewHideFiledPhotosKey) private var randomReviewHideFiledPhotos = true
    @State private var activeSheet: SettingsSheet?
    @State private var showingClearLocalDataConfirmation = false
    @State private var settingsToast: PhotoDeleteToast?

    var body: some View {
        ZStack {
            SettingsChrome.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: SettingsChrome.sectionSpacing) {
                    if AppConstants.advancedPaywallEnabled {
                        ProEntryBanner(subscriptionType: subscriptionManager.currentSubscriptionType) {
                            router.pushPaywall()
                        }
                    }

                    // 偏好设置
                    preferencesSection

                    // 随机浏览
                    randomBrowseSection

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
                .padding(.top, Theme.space3)
                .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
        }
        .photoDeleteToast($settingsToast, placement: .bottom(inset: Theme.space24))
        .navigationTitle(L10n.string("Settings"))
        .navigationBarTitleDisplayMode(.large)
        .settingsNavigationChrome()
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .mail:
            #if canImport(MessageUI)
                MailComposeView()
            #else
                Text(L10n.string("This device cannot send email"))
                    .foregroundColor(Theme.primaryText)
                    .padding()
            #endif
            case .privacy:
                PrivacyInfoView()
            case .languageSettings:
                LanguageSettingsView()
            }
        }
    }

    // MARK: - 关于与支持
    private var aboutSection: some View {
        VStack(spacing: 16) {
            PhotoDeleteSectionHeader(title: L10n.string("About and Support"))

            VStack(spacing: 0) {
                SettingRow(
                    title: L10n.string("Rate Poca"),
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
            PhotoDeleteSectionHeader(title: L10n.string("Preferences"))

            VStack(spacing: 0) {
                SettingRow(
                    title: L10n.string("Language"),
                    value: selectedLanguage.title,
                    action: {
                        activeSheet = .languageSettings
                    }
                )

                SettingsHairline()

                SettingToggleRow(
                    title: L10n.string("Auto-play videos"),
                    isOn: $reviewVideoAutoPlay
                )

                SettingsHairline()

                SettingToggleRow(
                    title: L10n.string("Auto-play Live Photos"),
                    isOn: $reviewLivePhotoAutoPlay
                )
            }
            .settingsGroupedCard()
        }
    }

    // MARK: - 随机浏览
    private var randomBrowseSection: some View {
        VStack(spacing: 16) {
            PhotoDeleteSectionHeader(title: L10n.string("Random Browse"))

            VStack(spacing: 0) {
                RandomReviewBatchSizeSettingRow(selectedValue: $randomReviewBatchSizeValue)

                SettingsHairline()

                SettingToggleRow(
                    title: L10n.string("Hide filed photos"),
                    isOn: $randomReviewHideFiledPhotos
                )
            }
            .settingsGroupedCard()
        }
    }

    // MARK: - 数据与权限
    private var dataPermissionsSection: some View {
        VStack(spacing: 16) {
            PhotoDeleteSectionHeader(title: L10n.string("Data & Permissions"))

            VStack(spacing: 0) {
                SettingRow(
                    title: L10n.string("Local Cleanup Data"),
                    value: localDataSubtitle,
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
                    title: L10n.string("Photo Access"),
                    value: photoAccessSubtitle,
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
            URLQueryItem(name: "subject", value: L10n.string("Poca Feedback")),
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
        settingsToast = PhotoDeleteToast(message: message, icon: icon, style: style)
    }
}

private enum SettingsSheet: Identifiable {
    case mail
    case privacy
    case languageSettings

    var id: String {
        switch self {
        case .mail: return "mail"
        case .privacy: return "privacy"
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
    var value = ""
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

                if !value.isEmpty {
                    Text(value)
                        .settingsRowValue()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

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
        .accessibilityValue(Text(value.isEmpty ? subtitle : value))
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
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .settingsRowTitle()
                .multilineTextAlignment(.leading)
        }
        .tint(Theme.positive)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(minHeight: SettingsChrome.rowMinHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                Text(L10n.string("Photos per round"))
                    .settingsRowTitle()
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(selectedSize.title)
                    .settingsRowValue()
                    .lineLimit(1)

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
        .accessibilityValue(Text(selectedSize.title))
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
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                            .stroke(Theme.hairline, lineWidth: Theme.stroke)
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
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: Theme.sizeRow)
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

// MARK: - 语言设置
private struct LanguageSettingsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppConstants.appLanguageKey) private var selectedLanguageID = AppLanguage.system.rawValue

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsChrome.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        languageList
                    }
                    .padding(.horizontal, SettingsChrome.pageInset)
                    .padding(.top, Theme.space2)
                    .padding(.bottom, Theme.space6)
                    .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(L10n.string("Language"))
            .navigationBarTitleDisplayMode(.inline)
            .settingsNavigationChrome()
        }
        .presentationDetents([.medium])
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
        [AppLanguage.system] + sortedLanguages
    }

    private var languageList: some View {
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

    private func languageRow(_ language: AppLanguage) -> some View {
        Button {
            selectedLanguageID = language.rawValue
            HapticManager.impact(.light)
        } label: {
            HStack(spacing: 12) {
                Text(language.title)
                    .settingsRowTitle()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

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
        .accessibilityAddTraits(selectedLanguage == language ? .isSelected : [])
        .accessibilityValue(Text(selectedLanguage == language ? L10n.string("Selected") : L10n.string("Not Set")))
    }
}

// MARK: - 邮件编写视图
#if canImport(MessageUI)
struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(L10n.string("Poca Feedback"))
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
                                .foregroundStyle(Theme.primaryText)

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
                                detail: L10n.string("Poca does not use its own cloud service and never sends photos to a server.")
                            )

                            PrivacyInfoRow(
                                icon: "person.crop.circle.badge.xmark",
                                title: L10n.string("No account needed"),
                                detail: L10n.string("Grant photo access and start using it. No sign-up or login required.")
                            )
                        }
                    }
                    .padding(.horizontal, Theme.space5)
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
                    .foregroundColor(Theme.accent)
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
                .foregroundColor(Theme.accent)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                        .fill(Theme.elevatedSurface)
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
                                .fill(Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Theme.hairline, lineWidth: 1)
                                )
                                .frame(width: 120, height: 120)

                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48, weight: .medium))
                                .foregroundColor(Theme.accent)
                        }

                        // App信息
                        VStack(spacing: 16) {
                            Text(AppConstants.appDisplayName)
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(Theme.primaryText)

                            Text(L10n.string("Version \(AppConstants.displayVersion)"))
                                .photoDeleteSecondaryLabel(.body)

                            Text(L10n.string("A free photo cleanup tool. Swipe to decide what stays, then confirm everything at the end."))
                                .photoDeleteSecondaryLabel(.body)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                        }
                    }
                    .padding(.horizontal, Theme.space5)
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
                    .foregroundColor(Theme.accent)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataManager())
        .environmentObject(MainTabRouter())
}
