import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// Paywall 专属设计语言：冷调画布 + 墨色主导 + 单一樱粉点缀。
//
// 这是 style.md「暖黑画布 + 单一琥珀行动色」的**有意例外**——付费页换一套材质语言来拉开
// 「产品内」与「购买决策」的语境差异，token 只在本目录使用，不要外扩到全局样式层。
// 视觉基准：eisenhower-matrix-app 的 Views/Paywall（dark 模式），本文件是其 token 的等价物。

enum PaywallDS {

    // MARK: - Color

    enum Color {
        /// 页面画布：冷调蓝黑（无限画板感的数字画布）
        static let pageBackground = resolve(
            light: (242 / 255, 244 / 255, 246 / 255),
            dark: (18 / 255, 23 / 255, 34 / 255)
        )

        /// 背景细点阵纹理。深色下用 5% 白点，浅色下是实心冷灰点。
        static let dot = resolve(
            light: (224 / 255, 229 / 255, 236 / 255),
            dark: (1, 1, 1),
            lightOpacity: 1,
            darkOpacity: 0.05
        )

        /// 全页唯一彩色点缀：樱花粉。选中描边 / radio 圆点 / 徽章共用。
        static let accent = resolve(
            light: (238 / 255, 157 / 255, 184 / 255),
            dark: (240 / 255, 170 / 255, 200 / 255)
        )

        static let textPrimary = resolve(
            light: (17 / 255, 17 / 255, 17 / 255),
            dark: (245 / 255, 245 / 255, 245 / 255)
        )

        static let textSecondary = resolve(
            light: (102 / 255, 107 / 255, 115 / 255),
            dark: (163 / 255, 168 / 255, 175 / 255)
        )

        /// 三级文本（已带透明度）：分区路标、链接
        static let textTertiary = resolve(
            light: (102 / 255, 107 / 255, 115 / 255),
            dark: (163 / 255, 168 / 255, 175 / 255),
            lightOpacity: 0.82,
            darkOpacity: 0.72
        )

        /// 主表面：功能清单卡、未选中套餐卡的填充（深色下纯黑）
        static let surfacePrimary = resolve(light: (1, 1, 1), dark: (0, 0, 0))

        /// 图标底板
        static let iconBackground = resolve(
            light: (0, 0, 0),
            dark: (1, 1, 1),
            lightOpacity: 0.04,
            darkOpacity: 0.08
        )

        /// 细边框、发丝分割线
        static let borderSubtle = resolve(
            light: (0, 0, 0),
            dark: (1, 1, 1),
            lightOpacity: 0.078,
            darkOpacity: 0.12
        )

        // MARK: 套餐卡

        static let skuCardFill = surfacePrimary
        static let skuCardBorder = borderSubtle

        /// 选中套餐卡填充。深色下的提亮必须用**不透明**颜色：
        /// 半透明白（如 white 0.05）会让点阵透上来，选中卡比未选中卡更"虚"，层级倒挂。
        static let selectedSKUCardFill = resolve(
            light: (1, 1, 1),
            dark: (30 / 255, 34 / 255, 46 / 255)
        )

        static let selectedSKUCardDot = accent

        static let recommendedBadgeFill = accent

        /// 粉底配墨色字，强对比，与 CTA 的墨色呼应
        static let recommendedBadgeText = resolve(
            light: (17 / 255, 17 / 255, 17 / 255),
            dark: (17 / 255, 17 / 255, 17 / 255)
        )

        /// 评论引导里的星标金。这是本页除樱粉外的第二个点缀色，
        /// 只允许用在星形上，不要扩散到按钮或徽章。
        static let accentGold = resolve(
            light: (244 / 255, 188 / 255, 35 / 255),
            dark: (255 / 255, 232 / 255, 126 / 255)
        )

        // MARK: CTA

        /// 深色下反色为白底墨字
        static let ctaButtonFill = resolve(light: (17 / 255, 17 / 255, 17 / 255), dark: (1, 1, 1))
        static let ctaButtonText = resolve(light: (1, 1, 1), dark: (17 / 255, 17 / 255, 17 / 255))

        static let ctaButtonBorder = resolve(
            light: (0, 0, 0),
            dark: (1, 1, 1),
            lightOpacity: 0.16,
            darkOpacity: 0.22
        )

        /// 深色下加重，才能与提亮后的按钮填充拉开层次
        static let ctaButtonShadow = resolve(
            light: (0, 0, 0),
            dark: (0, 0, 0),
            lightOpacity: 0.12,
            darkOpacity: 0.18
        )

        // MARK: 底栏玻璃卡（iOS 26 以下降级为 material）

        static let glassFallbackBorder = resolve(
            light: (1, 1, 1),
            dark: (1, 1, 1),
            lightOpacity: 0.6,
            darkOpacity: 0.12
        )

        static let glassFallbackShadow = resolve(
            light: (0, 0, 0),
            dark: (0, 0, 0),
            lightOpacity: 0.08,
            darkOpacity: 0.30
        )

        static let errorText = SwiftUI.Color.red
    }

    // MARK: - Gradient

    enum Gradient {
        /// 选中套餐卡描边与 radio 指示器共用：樱花粉 → 奶油蜜桃 → 薄荷。
        /// 中间站必须走暖色区——粉→薄荷直插会穿过低饱和灰色区，过渡带发灰。
        static var selectedCardBorder: LinearGradient {
            LinearGradient(
                colors: [
                    resolve(light: (246 / 255, 183 / 255, 208 / 255), dark: (240 / 255, 170 / 255, 200 / 255)),
                    resolve(light: (250 / 255, 224 / 255, 205 / 255), dark: (235 / 255, 205 / 255, 190 / 255)),
                    resolve(light: (169 / 255, 229 / 255, 206 / 255), dark: (140 / 255, 210 / 255, 190 / 255))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
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
        static let heroTop: CGFloat = 28
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
    }

    // MARK: - Stroke

    enum Stroke {
        static let hairline: CGFloat = 0.5
        static let border: CGFloat = 1
        static let radioUnselected: CGFloat = 1.5
        static let radioSelected: CGFloat = 1.8
        static let selectedCard: CGFloat = 3
    }

    // MARK: - Font

    enum Font {
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

// MARK: - Paywall 专属排版

/// Georgia 衬线只留给 hero 标题（稀缺才显高级）；分区路标统一 14 rounded medium，
/// 圆润弱化层级，只起"路标"作用，不与卡片内容竞争。
enum PaywallFont {
    static let heroTitle = Font.custom("Georgia", size: 26).weight(.bold)
    static let heroSubtitle = Font.system(size: 12, weight: .semibold)
    static let sectionTitle = Font.system(size: 14, weight: .medium, design: .rounded)
    static let planValueNote = Font.system(size: 11)
    static let featureCheck = Font.system(size: 13, weight: .semibold)
}

enum PaywallLayout {
    /// 页面内容横向留白
    static let pageHorizontalPadding = PaywallDS.Space.xxl

    /// 玻璃卡内部横向留白：比页面留白略宽松，让 CTA 不贴边
    static let footerCardHorizontalPadding: CGFloat = 20

    /// 正文末尾收尾留白。底栏高度由 safeAreaInset 自动让位，这里只负责呼吸区
    static let contentBottomPadding: CGFloat = 36

    static let closeButtonInset = EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: PaywallDS.Space.xl)
}

// MARK: - 玻璃底

/// 底栏悬浮卡的玻璃底：iOS 26 用真 Liquid Glass，更低版本降级为 material。
/// 只有底栏在用——内容卡用不透明填充，避免半透明叠在冷灰画布上发灰。
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
                    .shadow(color: PaywallDS.Color.glassFallbackShadow, radius: 16, y: 6)
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

/// 明暗两套值的解析器。应用主 token 在 `PhotoDeleteStyle`；此处
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
