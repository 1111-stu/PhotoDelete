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
    /// 首页专项清理行与时间卡共用 16.5 字号；标准行保持 15/600。
    var titleFont: Font = .system(size: 15, weight: .semibold)
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
                        .font(titleFont)
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

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
    /// 语义标记：便于调用方表达意图，不参与配色（功能层保持单色）。
    let style: PhotoDeleteToastStyle
    var showsUndo: Bool = false
    /// 极短反馈（如静音、到头提示）可覆盖默认停留时长。
    var duration: TimeInterval? = nil
}

enum PhotoDeleteToastStyle {
    case neutral
    case positive
    case destructive
    case favorite
    case warning
}

enum PhotoDeleteToastTiming {
    static let standard: TimeInterval = 2.4
    static let undoable: TimeInterval = 4.5
    static let enter: Animation = .easeOut(duration: 0.30)
    /// Reduce Motion 下只保留淡入淡出。
    static let reducedEnter: Animation = .easeOut(duration: 0.18)
    private static let fade: Animation = .easeOut(duration: 0.22)
    private static let transform: Animation = .easeOut(duration: 0.30)

    static func visibleDuration(for toast: PhotoDeleteToast) -> TimeInterval {
        toast.duration ?? (toast.showsUndo ? undoable : standard)
    }

    /// style.md §8.2：0.22s 透明度 + 0.30s 位移；Reduce Motion 只保留透明度。
    static func transition(reduceMotion: Bool, edge: Edge) -> AnyTransition {
        guard !reduceMotion else {
            return .opacity.animation(reducedEnter)
        }
        return .opacity.animation(fade)
            .combined(with: .move(edge: edge).animation(transform))
    }
}

enum PhotoDeleteToastPlacement {
    case top(inset: CGFloat)
    case bottom(inset: CGFloat)

    fileprivate var alignment: Alignment {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        }
    }

    fileprivate var edge: Edge {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        }
    }

    fileprivate var padding: EdgeInsets {
        switch self {
        case let .top(inset):
            return EdgeInsets(top: inset, leading: Theme.space5, bottom: 0, trailing: Theme.space5)
        case let .bottom(inset):
            return EdgeInsets(top: 0, leading: Theme.space5, bottom: inset, trailing: Theme.space5)
        }
    }
}

struct PhotoDeleteToastView: View {
    let toast: PhotoDeleteToast
    var onUndo: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .font(.system(size: Theme.textSizeSm, weight: .semibold))
                .foregroundColor(Theme.primaryText)
                .frame(width: 20)

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
                    .foregroundColor(Theme.primaryText)
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
                        .stroke(Theme.hairline, lineWidth: Theme.stroke)
                )
        )
        .shadow(color: Theme.floatingShadow, radius: 10, x: 0, y: 5)
        // Undo 必须是独立可达元素；纯信息 Toast 合并成一条朗读。
        .accessibilityElement(children: toast.showsUndo && onUndo != nil ? .contain : .combine)
    }
}

private struct PhotoDeleteToastPresenter: ViewModifier {
    @Binding var toast: PhotoDeleteToast?
    let placement: PhotoDeleteToastPlacement
    let maxWidth: CGFloat
    let onUndo: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: placement.alignment) {
                if let toast {
                    PhotoDeleteToastView(toast: toast, onUndo: onUndo)
                        .frame(maxWidth: maxWidth)
                        .padding(placement.padding)
                        .allowsHitTesting(toast.showsUndo && onUndo != nil)
                        .transition(PhotoDeleteToastTiming.transition(reduceMotion: reduceMotion, edge: placement.edge))
                }
            }
            .animation(
                reduceMotion ? PhotoDeleteToastTiming.reducedEnter : PhotoDeleteToastTiming.enter,
                value: toast?.id
            )
            .photoDeleteToastAutoDismiss($toast)
    }
}

private struct PhotoDeleteToastAutoDismiss: ViewModifier {
    @Binding var toast: PhotoDeleteToast?

    func body(content: Content) -> some View {
        content.task(id: toast?.id) {
            guard let toast else { return }
            let duration = PhotoDeleteToastTiming.visibleDuration(for: toast)
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(PhotoDeleteToastTiming.enter) {
                self.toast = nil
            }
        }
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
    /// 统一 Toast：位置、入场/退场动画、停留时长、Reduce Motion 与点击穿透。
    func photoDeleteToast(
        _ toast: Binding<PhotoDeleteToast?>,
        placement: PhotoDeleteToastPlacement,
        maxWidth: CGFloat = 420,
        onUndo: (() -> Void)? = nil
    ) -> some View {
        modifier(
            PhotoDeleteToastPresenter(
                toast: toast,
                placement: placement,
                maxWidth: maxWidth,
                onUndo: onUndo
            )
        )
    }

    /// 仅统一自动消失；用于托盘等需要自定义 Toast 位置的场景。
    func photoDeleteToastAutoDismiss(_ toast: Binding<PhotoDeleteToast?>) -> some View {
        modifier(PhotoDeleteToastAutoDismiss(toast: toast))
    }

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
