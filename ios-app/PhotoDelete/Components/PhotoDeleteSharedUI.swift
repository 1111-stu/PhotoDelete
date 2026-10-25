//
//  PhotoDeleteSharedUI.swift
//  PhotoDelete
//
//  全局共用 UI：背景 / 卡片 / 按钮样式 / Toast 等。Token 见 DesignSystem/Theme.swift。
//

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
        prefersExpandedContent(in: size, horizontalSizeClass: horizontalSizeClass) ? Theme.space8 : Theme.space5
    }

    static func homeTopPadding(in size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        Theme.space2
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
                Theme.backgroundTop,
                Theme.background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct PhotoDeleteCardBackground: ViewModifier {
    var radius: CGFloat = Theme.radiusLg

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Theme.cardStroke, lineWidth: Theme.stroke)
                    )
            )
    }
}

struct PhotoDeleteFloatingSurface<Content: View>: View {
    let radius: CGFloat
    let content: Content

    init(radius: CGFloat = Theme.radiusLg, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface.opacity(0.9))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Theme.hairline, lineWidth: Theme.stroke)
                    }
            }
            .shadow(color: Theme.floatingShadow, radius: 12, y: 6)
    }
}

struct PhotoDeleteMetricCard: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(Theme.text2Xl)
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(Theme.textBase.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .padding(.horizontal, 14)
        .photoDeleteCard(radius: Theme.radiusMd)
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
                .foregroundColor(Theme.primaryText)

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
    }
}

/// 列表行（style.md §4.4）：32 icon tile + 15/600 标题 + 次级值 + chevron。
struct PhotoDeleteListRow: View {
    var icon: String? = nil
    /// 彩色插画图标（切图 PNG）。提供时优先于 `icon`，且不套灰色图标砖。
    var iconImage: String? = nil
    /// 图标的光学尺寸：同一组图标按视觉重量分别给 33–42，而不是一律 36。
    var iconImageSize: CGFloat = 36
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: iconImage != nil ? 16 : (icon == nil ? 12 : 14)) {
                if let iconImage {
                    Image(iconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconImageSize, height: iconImageSize)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
                        // 透明的 48pt 槽位：中心落在 40、标题落在 80，行高保持 62。
                        // 不再加底色，和时间卡的插画保持同一种“无容器”语言。
                        .frame(width: 48, height: 48)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                        .frame(width: Theme.sizeIcon, height: Theme.sizeIcon)
                        .background(
                            Color.white.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.primaryText)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundColor(Theme.secondaryText)
                    }
                }

                Spacer(minLength: 8)

                if let value {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.secondaryText)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.tertiaryText)
            }
            .padding(.leading, iconImage == nil ? 18 : 16)
            .padding(.trailing, 18)
            .padding(.vertical, iconImage == nil ? 13 : 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(PhotoDeleteOptionalAccessibilityIdentifier(accessibilityIdentifier))
    }
}

private struct PhotoDeleteOptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    init(_ identifier: String?) {
        self.identifier = identifier
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
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
    var size: CGFloat = Theme.sizeIcon
    var cornerRadius: CGFloat = Theme.radiusSm
    var style: PhotoDeleteIconTileStyle = .soft
    var filled: Bool? = nil

    init(
        icon: String,
        tint: Color? = nil,
        size: CGFloat = Theme.sizeIcon,
        cornerRadius: CGFloat = Theme.radiusSm,
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
        tint ?? Theme.accent
    }

    private var softFill: Color {
        tint == nil ? Theme.accentSoftFill : resolvedTint.opacity(0.14)
    }

    private var softStroke: Color {
        tint == nil ? Theme.accentSoftStroke : resolvedTint.opacity(0.14)
    }

    private var solidSymbolColor: Color {
        tint == nil ? Theme.onAccent : .white
    }

    @ViewBuilder
    private var iconContent: some View {
        switch resolvedStyle {
        case .soft:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(softFill)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(softStroke, lineWidth: Theme.stroke)
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
            .foregroundColor(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .fill(configuration.isPressed ? Theme.accentPressed : Theme.accent)
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
            .foregroundColor(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                            .stroke(Theme.accentSoftStroke, lineWidth: Theme.stroke)
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
            .foregroundColor(Theme.destructive)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .fill(Theme.destructive.opacity(configuration.isPressed ? 0.18 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                        .stroke(Theme.destructive.opacity(0.28), lineWidth: Theme.stroke)
                    )
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.42)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension View {
    /// Legacy no-op. Tab bar visibility is structural (`MainTabView` root `NavigationStack` over `TabView`).
    func photoDeleteMainTabBarVisible() -> some View {
        self
    }

    /// Legacy no-op. Tab bar visibility is structural (`MainTabView` root `NavigationStack` over `TabView`).
    func photoDeleteHidesMainTabBar() -> some View {
        self
    }

    /// Navigation bar visible + trailing toolbar items on a pushed page.
    func photoDeletePushedToolbar<Content: ToolbarContent>(
        @ToolbarContentBuilder content: () -> Content
    ) -> some View {
        toolbar(.visible, for: .navigationBar)
            .toolbar(content: content)
    }

    func photoDeleteMinimumTapTarget(_ size: CGFloat = Theme.sizeTap) -> some View {
        frame(
            minWidth: max(size, Theme.sizeTap),
            minHeight: max(size, Theme.sizeTap)
        )
            .contentShape(Rectangle())
    }

    func photoDeleteSectionHeading() -> some View {
        font(.headline)
            .foregroundStyle(Theme.primaryText)
    }

    func photoDeletePrimaryLabel(_ font: Font = .body) -> some View {
        self.font(font)
            .foregroundStyle(Theme.primaryText)
    }

    func photoDeleteSecondaryLabel(_ font: Font = .subheadline) -> some View {
        self.font(font)
            .foregroundStyle(Theme.secondaryText)
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
        case .neutral: return Theme.accent
        case .positive: return Theme.positive
        case .destructive: return Theme.destructive
        case .favorite: return Theme.favorite
        case .warning: return Theme.warning
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
                .font(.system(size: Theme.textSizeSm, weight: .semibold))
                .foregroundColor(toastColor)
                .frame(width: 22)

            Text(toast.message)
                .font(.system(size: Theme.textSizeSm, weight: .semibold))
                .foregroundColor(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if toast.showsUndo, let onUndo {
                Divider()
                    .frame(height: 18)
                    .background(Theme.hairline)

                Button(L10n.string("Undo"), action: onUndo)
                    .font(.system(size: Theme.textSizeSm, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.space4)
        .padding(.vertical, Theme.space3)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.elevatedSurface.opacity(0.94))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(toastColor.opacity(0.34), lineWidth: 1)
                )
        )
        .shadow(color: Theme.floatingShadow, radius: 10, x: 0, y: 5)
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
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)

            Text(L10n.string("Photo Library Access Needed"))
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.primaryText)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(Theme.secondaryText)
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
    func photoDeleteCard(radius: CGFloat = Theme.radiusLg) -> some View {
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
