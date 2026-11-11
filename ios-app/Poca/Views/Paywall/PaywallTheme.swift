import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// Paywall 设计语言：暖黑画布 + 单一琥珀。
//
// 与 App 的视觉层保持一致：照片是主角，UI 只是黑底上的材质与光。
// token 只在本目录使用，不要外扩到全局样式层。

enum PaywallDS {

    // MARK: - Color

    enum Color {
        /// 页面画布：暖黑
        static let pageBackground = resolve(
            light: (245 / 255, 242 / 255, 234 / 255),
            dark: (10 / 255, 10 / 255, 13 / 255)
        )

        /// 画布底部，比顶部再压暗一档
        static let pageBackgroundBottom = resolve(
            light: (236 / 255, 231 / 255, 220 / 255),
            dark: (7 / 255, 7 / 255, 9 / 255)
        )

        /// 全页唯一彩色点缀：琥珀。选中态、徽章、轮播数字共用。
        static let accent = resolve(
            light: (216 / 255, 154 / 255, 46 / 255),
            dark: (245 / 255, 194 / 255, 95 / 255)
        )

        /// 琥珀的深端，用于徽章与进度渐变
        static let accentDeep = resolve(
            light: (190 / 255, 128 / 255, 26 / 255),
            dark: (230 / 255, 162 / 255, 58 / 255)
        )

        /// 琥珀底上的墨色字
        static let onAccent = SwiftUI.Color(red: 28 / 255, green: 19 / 255, blue: 5 / 255)

        static let textPrimary = resolve(
            light: (23 / 255, 23 / 255, 26 / 255),
            dark: (244 / 255, 244 / 255, 246 / 255)
        )

        static let textSecondary = resolve(
            light: (107 / 255, 100 / 255, 89 / 255),
            dark: (1, 1, 1),
            darkOpacity: 0.58
        )

        /// 三级文本（法务、圆点、次要说明）
        static let textTertiary = resolve(
            light: (138 / 255, 131 / 255, 120 / 255),
            dark: (1, 1, 1),
            darkOpacity: 0.32
        )

        /// 主表面：权益页卡片、弹层容器
        static let surfacePrimary = resolve(
            light: (1, 1, 1),
            dark: (17 / 255, 17 / 255, 20 / 255)
        )

        /// 细边框、发丝分割线
        static let borderSubtle = resolve(
            light: (0, 0, 0),
            dark: (1, 1, 1),
            lightOpacity: 0.08,
            darkOpacity: 0.09
        )

        // MARK: 套餐卡

        /// 未选中卡片的上下渐变
        static let planCardFillTop = SwiftUI.Color.white.opacity(0.055)
        static let planCardFillBottom = SwiftUI.Color.white.opacity(0.018)
        static let planCardBorder = SwiftUI.Color.white.opacity(0.09)

        /// 选中卡片：烟灰玻璃。三段都是不透明色，避免黑底透上来把卡片压虚。
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

        /// 深色下是奶油纸底墨字；浅色下反色
        static let ctaButtonFill = resolve(
            light: (23 / 255, 23 / 255, 26 / 255),
            dark: (247 / 255, 243 / 255, 233 / 255)
        )
        static let ctaButtonText = resolve(
            light: (255 / 255, 248 / 255, 232 / 255),
            dark: (27 / 255, 20 / 255, 6 / 255)
        )
        static let ctaButtonBorder = resolve(
            light: (0, 0, 0),
            dark: (1, 1, 1),
            lightOpacity: 0.1,
            darkOpacity: 0.6
        )
        static let ctaButtonShadow = resolve(
            light: (0, 0, 0),
            dark: (0, 0, 0),
            lightOpacity: 0.16,
            darkOpacity: 0.28
        )

        // MARK: 底栏玻璃卡（iOS 26 以下降级为 material）

        static let glassFallbackBorder = resolve(
            light: (1, 1, 1),
            dark: (1, 1, 1),
            lightOpacity: 0.6,
            darkOpacity: 0.18
        )

        static let glassFallbackShadow = resolve(
            light: (0, 0, 0),
            dark: (0, 0, 0),
            lightOpacity: 0.08,
            darkOpacity: 0.5
        )

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

    enum Font {
        static let brand = SwiftUI.Font.system(size: 22, weight: .bold)
        static let carouselTitle = SwiftUI.Font.system(size: 20, weight: .bold)
        static let carouselBody = SwiftUI.Font.system(size: 12.5, weight: .regular)
        static let slideStat = SwiftUI.Font.system(size: 34, weight: .bold)
        static let slideCaption = SwiftUI.Font.system(size: 10, weight: .regular)

        static let skuName = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let skuPrice = SwiftUI.Font.system(size: 30, weight: .bold)
        static let skuUnit = SwiftUI.Font.system(size: 12, weight: .medium)
        static let skuTrial = SwiftUI.Font.system(size: 10.5, weight: .regular)
        static let skuNote = SwiftUI.Font.system(size: 10, weight: .regular)
        static let badge = SwiftUI.Font.system(size: 10, weight: .bold)
        static let legal = SwiftUI.Font.system(size: 10.5, weight: .regular)
        static let cta = SwiftUI.Font.system(size: 16, weight: .semibold)
        static let trust = SwiftUI.Font.system(size: 11, weight: .regular)

        static let title3 = SwiftUI.Font.system(size: 18, weight: .semibold)
        static let title2Bold = SwiftUI.Font.system(size: 20, weight: .bold, design: .rounded)

        static let bodySemibold = SwiftUI.Font.system(size: 16, weight: .semibold)

        static let calloutMedium = SwiftUI.Font.system(size: 15, weight: .medium)
        static let calloutSemibold = SwiftUI.Font.system(size: 15, weight: .semibold)

        static let caption = SwiftUI.Font.system(size: 12, weight: .regular)
        static let captionMedium = SwiftUI.Font.system(size: 12, weight: .medium)
        static let captionSemibold = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let captionBold = SwiftUI.Font.system(size: 12, weight: .bold)

        static let caption2 = SwiftUI.Font.system(size: 10, weight: .regular)
        static let caption2Medium = SwiftUI.Font.system(size: 10, weight: .medium)
        static let caption2Semibold = SwiftUI.Font.system(size: 10, weight: .semibold)
        static let caption2Bold = SwiftUI.Font.system(size: 10, weight: .bold)
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

// MARK: - 明暗解析

/// 明暗两套值的解析器。应用主 token 在 `Theme`；此处
/// 为保持影响面在 paywall 目录内，这里不公开它而是自带一份等价的。
private func resolve(
    light: (CGFloat, CGFloat, CGFloat),
    dark: (CGFloat, CGFloat, CGFloat),
    lightOpacity: CGFloat = 1,
    darkOpacity: CGFloat = 1
) -> Color {
    #if canImport(UIKit)
    return Color(uiColor: UIColor { traits in
        let isDark = traits.userInterfaceStyle == .dark
        let rgb = isDark ? dark : light
        let alpha = isDark ? darkOpacity : lightOpacity
        return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: alpha)
    })
    #else
    return Color(red: light.0, green: light.1, blue: light.2).opacity(lightOpacity)
    #endif
}
