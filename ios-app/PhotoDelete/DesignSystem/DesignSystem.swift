import SwiftUI

#if canImport(UIKit)
import UIKit

struct SystemShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// 设计原语与共享控件；token 见 DesignSystem/PhotoDeleteStyle.swift / 仓库根目录 style.md。

enum PhotoDeleteAdaptiveLayout {
    static func isRegularPad(horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        isPad && horizontalSizeClass == .regular
    }

    static func prefersExpandedContent(in size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        isPad && horizontalSizeClass == .regular && size.width >= 760 && size.height >= 560
    }

    static func homeContentMaxWidth(in size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        prefersExpandedContent(in: size, horizontalSizeClass: horizontalSizeClass) ? min(size.width - 48, 1040) : 520
    }

    static func homeHorizontalPadding(in size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        prefersExpandedContent(in: size, horizontalSizeClass: horizontalSizeClass) ? 32 : PhotoDeleteStyle.screenHorizontalPadding
    }

    static func homeTopPadding(in size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        PhotoDeleteStyle.rootContentTopSpacing
    }

    static func readableContentMaxWidth(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat? {
        isRegularPad(horizontalSizeClass: horizontalSizeClass) ? 760 : nil
    }

    static func listContentMaxWidth(horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat? {
        isRegularPad(horizontalSizeClass: horizontalSizeClass) ? 860 : nil
    }

    static func prefersReviewSidebar(in size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        isPad && horizontalSizeClass == .regular && size.width >= 820 && size.height >= 600
    }

    static func reviewSidebarWidth(totalWidth: CGFloat) -> CGFloat {
        min(max(totalWidth * 0.31, 300), 420)
    }

    static func reviewPhotoCardMaxSize(in containerSize: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> CGSize {
        guard isPad && horizontalSizeClass == .regular && containerSize.width >= 520 && containerSize.height >= 620 else {
            return CGSize(width: 390, height: 590)
        }

        return CGSize(width: 470, height: 700)
    }

    #if canImport(UIKit)
    private static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    #else
    private static var isPad: Bool {
        false
    }
    #endif
}

struct PhotoDeleteScreenBackground: View {

    var body: some View {
        LinearGradient(
            colors: [
                PhotoDeleteStyle.backgroundTop,
                PhotoDeleteStyle.background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct PhotoDeleteCardBackground: ViewModifier {
    var radius: CGFloat = PhotoDeleteStyle.cardRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(PhotoDeleteStyle.surfaceFill())
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(PhotoDeleteStyle.cardStroke, lineWidth: PhotoDeleteStyle.Metrics.cardStrokeWidth)
                    )
            )
    }
}

struct PhotoDeleteFloatingSurface<Content: View>: View {
    let radius: CGFloat
    let content: Content

    init(radius: CGFloat = PhotoDeleteStyle.cardRadius, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(PhotoDeleteStyle.surface.opacity(0.9))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(PhotoDeleteStyle.hairline, lineWidth: PhotoDeleteStyle.Metrics.cardStrokeWidth)
                    }
            }
            .shadow(color: PhotoDeleteStyle.floatingShadow, radius: 12, y: 6)
    }
}

struct PhotoDeleteMetricCard: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(PhotoDeleteStyle.Typography.metric)
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(PhotoDeleteStyle.Typography.secondary.weight(.medium))
                .foregroundStyle(PhotoDeleteStyle.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .padding(.horizontal, 14)
        .photoDeleteCard(radius: PhotoDeleteStyle.Metrics.compactRadius)
    }
}

/// 首页等页面的分区标题：14pt 加粗标题 + 可选右侧琥珀值（对应原型 `.glabel`）。
struct PhotoDeleteSectionHeader: View {
    let title: String
    var trailing: String?

    init(title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(PhotoDeleteStyle.primaryText)

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.accent)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
    }
}

/// 数字格式约定：一律不带千分位（2974，而不是 2,974）。
enum PhotoDeleteCountFormat {
    static func plain(_ count: Int) -> String {
        String(count)
    }
}

enum PhotoDeleteIconTileStyle {
    case soft
    case solid
    case plain
}

struct PhotoDeleteIconTile: View {
    let icon: String
    var tint: Color?
    var size: CGFloat = PhotoDeleteStyle.rowIconSize
    var cornerRadius: CGFloat = 9
    var style: PhotoDeleteIconTileStyle = .soft
    var filled: Bool? = nil

    init(
        icon: String,
        tint: Color? = nil,
        size: CGFloat = PhotoDeleteStyle.rowIconSize,
        cornerRadius: CGFloat = 9,
        style: PhotoDeleteIconTileStyle = .soft,
        filled: Bool? = nil
    ) {
        self.icon = icon
        self.tint = tint
        self.size = size
        self.cornerRadius = cornerRadius
        self.style = style
        self.filled = filled
    }

    var body: some View {
        iconContent
            .frame(width: size, height: size)
    }

    private var resolvedStyle: PhotoDeleteIconTileStyle {
        if let filled {
            return filled ? .solid : .soft
        }
        return style
    }

    private var resolvedTint: Color {
        tint ?? PhotoDeleteStyle.accent
    }

    private var softFill: Color {
        tint == nil ? PhotoDeleteStyle.iconTileFill : resolvedTint.opacity(0.14)
    }

    private var softStroke: Color {
        tint == nil ? PhotoDeleteStyle.iconTileStroke : resolvedTint.opacity(0.14)
    }

    private var solidSymbolColor: Color {
        tint == nil ? PhotoDeleteStyle.primaryButtonText : .white
    }

    @ViewBuilder
    private var iconContent: some View {
        switch resolvedStyle {
        case .soft:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(softFill)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(softStroke, lineWidth: PhotoDeleteStyle.Metrics.cardStrokeWidth)
                )
                .overlay(symbol.foregroundColor(resolvedTint))
        case .solid:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(resolvedTint)
                .overlay(symbol.foregroundColor(solidSymbolColor))
        case .plain:
            symbol.foregroundColor(resolvedTint)
        }
    }

    private var symbol: some View {
        Image(systemName: icon)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: max(size * 0.46, 14), weight: .medium))
    }
}

struct PhotoDeletePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(PhotoDeleteStyle.buttonPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                    .fill(configuration.isPressed ? PhotoDeleteStyle.accentPressed : PhotoDeleteStyle.buttonPrimaryFill)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.42)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct PhotoDeleteSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(PhotoDeleteStyle.buttonSecondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                    .fill(PhotoDeleteStyle.buttonSecondaryFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                            .stroke(PhotoDeleteStyle.buttonSecondaryStroke, lineWidth: PhotoDeleteStyle.Metrics.cardStrokeWidth)
                    )
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.74 : 1) : 0.42)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct PhotoDeleteDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(PhotoDeleteStyle.destructive)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                    .fill(PhotoDeleteStyle.destructive.opacity(configuration.isPressed ? 0.18 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                        .stroke(PhotoDeleteStyle.destructive.opacity(0.28), lineWidth: PhotoDeleteStyle.Metrics.cardStrokeWidth)
                    )
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.42)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension View {
    func photoDeleteMinimumTapTarget(_ size: CGFloat = PhotoDeleteStyle.Metrics.minimumTapTarget) -> some View {
        frame(
            minWidth: max(size, PhotoDeleteStyle.Metrics.minimumTapTarget),
            minHeight: max(size, PhotoDeleteStyle.Metrics.minimumTapTarget)
        )
            .contentShape(Rectangle())
    }

    func photoDeleteSectionHeading() -> some View {
        font(.headline)
            .foregroundStyle(PhotoDeleteStyle.primaryText)
    }

    func photoDeletePrimaryLabel(_ font: Font = .body) -> some View {
        self.font(font)
            .foregroundStyle(PhotoDeleteStyle.primaryText)
    }

    func photoDeleteSecondaryLabel(_ font: Font = .subheadline) -> some View {
        self.font(font)
            .foregroundStyle(PhotoDeleteStyle.secondaryText)
    }
}

// MARK: - App Constants
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
    static let hasSeenIntroKey = "hasSeenPhotoDeleteIntro"
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

// MARK: - Haptic Manager
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

// MARK: - Shared Toast
struct PhotoDeleteToast: Identifiable {
    let id = UUID()
    let message: String
    let icon: String
    let style: PhotoDeleteToastStyle
    var showsUndo: Bool = false
}

enum PhotoDeleteToastStyle {
    case neutral
    case positive
    case destructive
    case favorite
    case warning

    var color: Color {
        switch self {
        case .neutral: return PhotoDeleteStyle.accent
        case .positive: return PhotoDeleteStyle.positive
        case .destructive: return PhotoDeleteStyle.destructive
        case .favorite: return PhotoDeleteStyle.favorite
        case .warning: return PhotoDeleteStyle.warning
        }
    }
}

struct PhotoDeleteToastView: View {
    let toast: PhotoDeleteToast
    var onUndo: (() -> Void)?

    private var toastColor: Color {
        toast.style.color
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .font(.system(size: PhotoDeleteStyle.Metrics.toastIconSize, weight: .semibold))
                .foregroundColor(toastColor)
                .frame(width: 22)

            Text(toast.message)
                .font(.system(size: PhotoDeleteStyle.Metrics.toastTextSize, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if toast.showsUndo, let onUndo {
                Divider()
                    .frame(height: 18)
                    .background(PhotoDeleteStyle.hairline)

                Button(L10n.string("Undo"), action: onUndo)
                    .font(.system(size: PhotoDeleteStyle.Metrics.toastTextSize, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.toolbarAction)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PhotoDeleteStyle.Metrics.toastHorizontalPadding)
        .padding(.vertical, PhotoDeleteStyle.Metrics.toastVerticalPadding)
        .background(
            Capsule(style: .continuous)
                .fill(PhotoDeleteStyle.elevatedSurface.opacity(0.94))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(toastColor.opacity(0.34), lineWidth: 1)
                )
        )
        .shadow(color: PhotoDeleteStyle.floatingShadow, radius: 10, x: 0, y: 5)
    }
}

// MARK: - Authorization Card
struct PhotoAuthorizationCard: View {
    let subtitle: String
    let onRequestAccess: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.largeTitle.weight(.medium))
                .foregroundStyle(PhotoDeleteStyle.accent)
                .accessibilityHidden(true)

            Text(L10n.string("Photo Library Access Needed"))
                .font(.title2.weight(.semibold))
                .foregroundStyle(PhotoDeleteStyle.primaryText)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(PhotoDeleteStyle.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: onRequestAccess) {
                Text(L10n.string("Continue"))
                    .frame(maxWidth: 180)
            }
            .photoDeletePrimaryButton()
        }
        .padding(24)
        .photoDeleteCard()
    }
}

extension View {
    func photoDeleteCard(radius: CGFloat = PhotoDeleteStyle.cardRadius) -> some View {
        modifier(PhotoDeleteCardBackground(radius: radius))
    }

    func photoDeletePrimaryButton() -> some View {
        buttonStyle(PhotoDeletePrimaryButtonStyle())
    }

    func photoDeleteSecondaryButton() -> some View {
        buttonStyle(PhotoDeleteSecondaryButtonStyle())
    }

    func photoDeleteDestructiveButton() -> some View {
        buttonStyle(PhotoDeleteDestructiveButtonStyle())
    }
}
