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
        prefersExpandedContent(in: size, horizontalSizeClass: horizontalSizeClass) ? 32 : Theme.screenHorizontalPadding
    }

    static func homeTopPadding(in size: CGSize, horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        Theme.rootContentTopSpacing
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
    var radius: CGFloat = Theme.cardRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Theme.cardStroke, lineWidth: Theme.Metrics.cardStrokeWidth)
                    )
            )
    }
}

struct PhotoDeleteFloatingSurface<Content: View>: View {
    let radius: CGFloat
    let content: Content

    init(radius: CGFloat = Theme.cardRadius, @ViewBuilder content: () -> Content) {
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
                            .stroke(Theme.hairline, lineWidth: Theme.Metrics.cardStrokeWidth)
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
                .font(Theme.Typography.metric)
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(Theme.Typography.secondary.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .padding(.horizontal, 14)
        .photoDeleteCard(radius: Theme.Metrics.compactRadius)
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
                    .foregroundColor(Theme.accent)
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
    var size: CGFloat = Theme.rowIconSize
    var cornerRadius: CGFloat = 9
    var style: PhotoDeleteIconTileStyle = .soft
    var filled: Bool? = nil

    init(
        icon: String,
        tint: Color? = nil,
        size: CGFloat = Theme.rowIconSize,
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
                        .stroke(softStroke, lineWidth: Theme.Metrics.cardStrokeWidth)
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
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
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
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                            .stroke(Theme.accentSoftStroke, lineWidth: Theme.Metrics.cardStrokeWidth)
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
                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                    .fill(Theme.destructive.opacity(configuration.isPressed ? 0.18 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                        .stroke(Theme.destructive.opacity(0.28), lineWidth: Theme.Metrics.cardStrokeWidth)
                    )
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.42)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension View {
    func photoDeleteMinimumTapTarget(_ size: CGFloat = Theme.Metrics.minimumTapTarget) -> some View {
        frame(
            minWidth: max(size, Theme.Metrics.minimumTapTarget),
            minHeight: max(size, Theme.Metrics.minimumTapTarget)
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
                .font(.system(size: Theme.Metrics.toastIconSize, weight: .semibold))
                .foregroundColor(toastColor)
                .frame(width: 22)

            Text(toast.message)
                .font(.system(size: Theme.Metrics.toastTextSize, weight: .semibold))
                .foregroundColor(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if toast.showsUndo, let onUndo {
                Divider()
                    .frame(height: 18)
                    .background(Theme.hairline)

                Button(L10n.string("Undo"), action: onUndo)
                    .font(.system(size: Theme.Metrics.toastTextSize, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Metrics.toastHorizontalPadding)
        .padding(.vertical, Theme.Metrics.toastVerticalPadding)
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
    func photoDeleteCard(radius: CGFloat = Theme.cardRadius) -> some View {
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
