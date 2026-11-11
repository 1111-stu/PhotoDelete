import SwiftUI

// Paywall 设计语言：暖黑画布 + 单一琥珀。
//
// 与 App 的视觉层保持一致：照片是主角，UI 只是黑底上的材质与光。
// App 全局强制暗色（PocaApp.preferredColorScheme(.dark)），这里只保留暗色 token，
// 不再维护不可达的 light 分支。
// token 只在本目录使用，不要外扩到全局样式层。

enum PaywallDS {

    // MARK: - Color

    enum Color {
        /// 页面画布：暖黑
        static let pageBackground = SwiftUI.Color(red: 10 / 255, green: 10 / 255, blue: 13 / 255)

        /// 画布底部，比顶部再压暗一档
        static let pageBackgroundBottom = SwiftUI.Color(red: 7 / 255, green: 7 / 255, blue: 9 / 255)

        /// 全页唯一彩色点缀：琥珀。选中态、徽章、轮播数字共用。
        static let accent = SwiftUI.Color(red: 245 / 255, green: 194 / 255, blue: 95 / 255)

        /// 琥珀的深端，用于徽章与进度渐变
        static let accentDeep = SwiftUI.Color(red: 230 / 255, green: 162 / 255, blue: 58 / 255)

        /// 琥珀底上的墨色字
        static let onAccent = SwiftUI.Color(red: 28 / 255, green: 19 / 255, blue: 5 / 255)

        static let textPrimary = SwiftUI.Color(red: 244 / 255, green: 244 / 255, blue: 246 / 255)

        static let textSecondary = SwiftUI.Color.white.opacity(0.58)

        /// 三级文本（法务、圆点、次要说明）
        static let textTertiary = SwiftUI.Color.white.opacity(0.32)

        /// 主表面：权益页卡片、弹层容器
        static let surfacePrimary = SwiftUI.Color(red: 17 / 255, green: 17 / 255, blue: 20 / 255)

        /// 细边框、发丝分割线
        static let borderSubtle = SwiftUI.Color.white.opacity(0.09)

        // MARK: 套餐卡

        /// 未选中卡片的上下渐变
        static let planCardFillTop = SwiftUI.Color.white.opacity(0.055)
        static let planCardFillBottom = SwiftUI.Color.white.opacity(0.018)
        static let planCardBorder = SwiftUI.Color.white.opacity(0.09)

        /// 选中卡片：烟灰玻璃。三段都是不透明色，避免黑底透上来把卡片压虚。
        /// 保持冷灰的高级感，不要为了统一暖黑画布而调成暖灰。
        static let planSelectedTop = SwiftUI.Color(red: 74 / 255, green: 76 / 255, blue: 82 / 255).opacity(0.66)
        static let planSelectedMid = SwiftUI.Color(red: 44 / 255, green: 46 / 255, blue: 52 / 255).opacity(0.72)
        static let planSelectedBottom = SwiftUI.Color(red: 30 / 255, green: 32 / 255, blue: 38 / 255).opacity(0.78)
        static let planSelectedBorder = SwiftUI.Color.white.opacity(0.32)
        static let planSelectedHighlight = SwiftUI.Color.white.opacity(0.18)
        static let planSelectedTopInner = SwiftUI.Color.white.opacity(0.25)
        static let planSelectedBottomInner = SwiftUI.Color.black.opacity(0.2)
        static let planCardShadow = SwiftUI.Color.black.opacity(0.32)

        static let recommendedBadgeFill = accent
        /// 琥珀底配墨色字
        static let recommendedBadgeText = onAccent

        // MARK: 虹彩（设置页 Pro 入口材质）

        /// 中低饱和的暖虹彩色，只服务 `ProEntryBanner` 的玻璃珠、2pt 描边和外圈光晕。
        static let iridescentPink = SwiftUI.Color(red: 242 / 255, green: 169 / 255, blue: 198 / 255)
        static let iridescentPeach = SwiftUI.Color(red: 244 / 255, green: 210 / 255, blue: 188 / 255)
        static let iridescentCoral = SwiftUI.Color(red: 239 / 255, green: 158 / 255, blue: 144 / 255)
        static let iridescentMint = SwiftUI.Color(red: 147 / 255, green: 217 / 255, blue: 195 / 255)

        // MARK: CTA

        /// 奶油纸底墨字
        static let ctaButtonFill = SwiftUI.Color(red: 247 / 255, green: 243 / 255, blue: 233 / 255)
        static let ctaButtonText = SwiftUI.Color(red: 27 / 255, green: 20 / 255, blue: 6 / 255)
        static let ctaButtonBorder = SwiftUI.Color.white.opacity(0.6)
        static let ctaButtonShadow = SwiftUI.Color.black.opacity(0.28)

        // MARK: 底栏玻璃卡（iOS 26 以下降级为 material）

        static let glassFallbackBorder = SwiftUI.Color.white.opacity(0.18)
        static let glassFallbackShadow = SwiftUI.Color.black.opacity(0.5)

        static let errorText = SwiftUI.Color.red
    }

    // MARK: - Gradient

    enum Gradient {
        /// 选中套餐卡：左上受光的烟灰玻璃
        static var planSelectedFill: LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: Color.planSelectedTop, location: 0),
                    .init(color: Color.planSelectedMid, location: 0.55),
                    .init(color: Color.planSelectedBottom, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        static var planSelectedSheen: RadialGradient {
            RadialGradient(
                colors: [Color.planSelectedHighlight, .clear],
                center: UnitPoint(x: 0.18, y: 0),
                startRadius: 0,
                endRadius: 260
            )
        }

        /// 设置页 Pro 入口的虹彩环：粉 → 蜜桃 → 薄荷 → 珊瑚 → 粉。
        /// 各站透明度故意不等（0.95 / 0.5 / 0.9 …），让环上出现“受光”和“背光”段。
        static var iridescent: AngularGradient {
            AngularGradient(
                stops: [
                    .init(color: Color.iridescentPink.opacity(0.95), location: 0.00),
                    .init(color: Color.iridescentPeach.opacity(0.50), location: 0.20),
                    .init(color: Color.iridescentMint.opacity(0.90), location: 0.42),
                    .init(color: Color.iridescentCoral.opacity(0.88), location: 0.68),
                    .init(color: Color.iridescentPink.opacity(0.95), location: 1.00)
                ],
                center: .center,
                angle: .degrees(220)
            )
        }
    }

    // MARK: - Space

    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
        static let sectionGap: CGFloat = 24
        static let sectionGapSmall: CGFloat = 16
    }

    // MARK: - Radius

    enum Radius {
        static let iconTile: CGFloat = 10
        static let chip: CGFloat = 14
        static let card: CGFloat = 16
        static let listContainer: CGFloat = 16
        static let floatingCard: CGFloat = 22
        static let carousel: CGFloat = 28
    }

    // MARK: - Stroke

    enum Stroke {
        static let hairline: CGFloat = 0.5
        static let border: CGFloat = 1
    }

    // MARK: - Font

    /// 全部走系统文字样式，跟随 Dynamic Type。
    /// 轮播画布里的字号是画布内固定值（随卡片等比缩放），不放这里。
    enum Font {
        static let skuName = SwiftUI.Font.system(.footnote).weight(.semibold)
        static let skuPrice = SwiftUI.Font.system(.title).weight(.bold)
        static let skuUnit = SwiftUI.Font.system(.caption).weight(.medium)
        static let skuTrial = SwiftUI.Font.system(.caption2)
        static let skuNote = SwiftUI.Font.system(.caption2)
        static let badge = SwiftUI.Font.system(.caption2).weight(.bold)
        static let legal = SwiftUI.Font.system(.caption2)
        static let cta = SwiftUI.Font.system(.callout).weight(.semibold)
        static let trust = SwiftUI.Font.system(.caption2)

        static let calloutSemibold = SwiftUI.Font.system(.callout).weight(.semibold)

        static let caption = SwiftUI.Font.system(.caption)
        static let captionMedium = SwiftUI.Font.system(.caption).weight(.medium)
        static let captionSemibold = SwiftUI.Font.system(.caption).weight(.semibold)

        static let caption2Medium = SwiftUI.Font.system(.caption2).weight(.medium)
        static let caption2Bold = SwiftUI.Font.system(.caption2).weight(.bold)
    }
}

// MARK: - Layout

enum PaywallLayout {
    /// 页面内容横向留白
    static let pageHorizontalPadding: CGFloat = 20

    /// 顶栏横向留白
    static let topBarHorizontalPadding: CGFloat = 18

    /// 玻璃卡内部横向留白：比页面留白略宽松，让 CTA 不贴边
    static let footerCardHorizontalPadding: CGFloat = 20

    /// 正文末尾收尾留白。底栏高度由 safeAreaInset 自动让位，这里只负责呼吸区
    static let contentBottomPadding: CGFloat = 24
}

// MARK: - 玻璃底

/// 底栏悬浮卡的玻璃底：iOS 26 用真 Liquid Glass，更低版本降级为 material。
/// 只有底栏在用——内容卡用不透明填充，避免半透明叠在暖黑画布上发灰。
private struct PaywallGlassCard: ViewModifier {
    let radius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            content.background(
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(shape.stroke(PaywallDS.Color.glassFallbackBorder, lineWidth: PaywallDS.Stroke.hairline))
                    .shadow(color: PaywallDS.Color.glassFallbackShadow, radius: 24, y: 12)
            )
        }
    }
}

extension View {
    func paywallGlassCard(radius: CGFloat) -> some View {
        modifier(PaywallGlassCard(radius: radius))
    }
}

// MARK: - Press feedback

/// 付费页统一的按压反馈：按下即缩小，约 140ms 收敛。
/// 只改变 transform/opacity，不触发布局。
struct PaywallPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
