//
//  Theme.swift
//  PhotoDelete
//
//  全局设计 token（暗色静态）。规范见仓库根目录 style.md。
//
//  命名对齐 Tailwind：前缀表达类别，全部打平。
//  - space*  — 间距（严格 4pt 网格）
//  - size*   — 控件边长 / 行高（不是间距）
//  - radius* — 圆角阶梯 12 / 16 / 24
//  - text* / textSize* — Font 字阶 / 字号 CGFloat
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum Theme {

    // MARK: - Color · Canvas

    static let backgroundTop = Color(red: 0.039, green: 0.039, blue: 0.051)
    static let background = Color(red: 0.031, green: 0.031, blue: 0.039)
    /// 整理页幕布：纯黑让照片成为唯一的视觉焦点。
    static let reviewCanvas = Color.black

    // MARK: - Color · Surface

    static let surface = Color(red: 0.086, green: 0.086, blue: 0.102)
    static let elevatedSurface = Color(red: 0.118, green: 0.118, blue: 0.141)
    static let cardStroke = Color.white.opacity(0.09)
    static let hairline = Color.white.opacity(0.075)
    static let floatingShadow = Color.black.opacity(0.30)
    /// 整理页照片框的石墨深灰承托色，不覆盖照片本身，只填充留白和加载态。
    static let reviewPhotoSurface = Color(red: 0.070, green: 0.075, blue: 0.086)
    static let reviewPhotoStroke = Color.white.opacity(0.12)

    // MARK: - Color · Text

    static let primaryText = Color.white.opacity(0.96)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.42)

    // MARK: - Color · Action（琥珀）

    static let accent = Color(red: 0.953, green: 0.694, blue: 0.298)
    static let accentPressed = Color(red: 0.788, green: 0.541, blue: 0.196)
    /// 琥珀填充上的墨色字。
    static let onAccent = Color(red: 0.04, green: 0.035, blue: 0.03)
    static let accentSoftFill = accent.opacity(0.14)
    static let accentSoftStroke = accent.opacity(0.22)
    static let secondaryAccent = Color(red: 1.00, green: 0.78, blue: 0.48)

    // MARK: - Color · Status

    static let positive = Color(red: 0.72, green: 0.86, blue: 0.52)
    static let warning = Color(red: 1.00, green: 0.78, blue: 0.45)
    static let destructive = Color(red: 1.00, green: 0.46, blue: 0.38)
    static let favorite = Color(red: 1.00, green: 0.64, blue: 0.72)

    // MARK: - Color · Home gradient cards

    static let coralGradientTop = Color(red: 0.984, green: 0.522, blue: 0.494)
    static let coralGradientBottom = Color(red: 0.949, green: 0.361, blue: 0.329)
    static let coralInk = Color(red: 0.180, green: 0.059, blue: 0.024)
    static let amberGradientTop = Color(red: 1.00, green: 0.784, blue: 0.369)
    static let amberGradientBottom = Color(red: 0.941, green: 0.604, blue: 0.133)
    static let amberInk = Color(red: 0.102, green: 0.071, blue: 0.024)

    // MARK: - Color · Album reorder

    static let dropSlotStroke = Color.white.opacity(0.34)
    static let dropSlotFill = Color.white.opacity(0.05)
    static let dropSlotLineWidth: CGFloat = 2.5
    static let dropSlotDash: [CGFloat] = [11, 9]

    // MARK: - Color · Photo board

    /// 相纸白边：接近纯白，在近黑板面上读作「冲印出来的相纸」。
    static let boardPaper = Color(red: 0.98, green: 0.98, blue: 0.97)
    /// 相纸墙小木夹：只用于相纸墙这类实物道具；刻意避开琥珀 / 珊瑚语义色。
    static let boardClipPalette: [Color] = [
        Color(red: 0.93, green: 0.84, blue: 0.36), // 柠檬黄
        Color(red: 0.62, green: 0.53, blue: 0.86), // 薰衣草紫
        Color(red: 0.47, green: 0.74, blue: 0.40), // 草绿
        Color(red: 0.38, green: 0.64, blue: 0.90), // 天蓝
        Color(red: 0.88, green: 0.42, blue: 0.58), // 玫红
        Color(red: 0.80, green: 0.64, blue: 0.46)  // 原木
    ]

    // MARK: - Space（4pt 网格，spaceN = N×4）

    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 20
    static let space6: CGFloat = 24
    static let space8: CGFloat = 32
    static let space12: CGFloat = 48
    static let space16: CGFloat = 64
    static let space24: CGFloat = 96

    // MARK: - Size（控件边长 / 行高，勿当间距用）

    static let sizeTap: CGFloat = 44
    /// 列表行左侧 icon tile 边长（不是头部圆钮）。
    static let sizeIcon: CGFloat = 32
    /// 头部圆形 icon 按钮可见直径（首页 / 照片墙 / 整理顶栏统一）。
    static let sizeChrome: CGFloat = 48
    static let sizeRow: CGFloat = 56

    // MARK: - Radius（12 / 16 / 24）

    static let radiusSm: CGFloat = 12
    static let radiusMd: CGFloat = 16
    static let radiusLg: CGFloat = 24
    static let stroke: CGFloat = 1

    // MARK: - Text size（CGFloat）

    static let textSizeSm: CGFloat = 14
    /// 头部圆钮内 SF Symbol 字号（圆 48 时比 20 略收，比旧首页 14 更大）。
    static let textSizeChromeIcon: CGFloat = 17
    static let textSizeLg: CGFloat = 20

    // MARK: - Text（Font 字阶）

    static let textSm: Font = .caption
    static let textBase: Font = .subheadline
    static let textMd: Font = .body
    static let textLg: Font = .headline
    static let textXl: Font = .title2.weight(.semibold)
    static let text2Xl: Font = .title.weight(.semibold)

    // MARK: - UIKit

    #if canImport(UIKit)
    static let uiBackground = UIColor(red: 0.031, green: 0.031, blue: 0.039, alpha: 1)
    static let uiSurface = UIColor(red: 0.086, green: 0.086, blue: 0.102, alpha: 1)
    static let uiHairline = UIColor(white: 1, alpha: 0.075)
    static let uiAccent = UIColor(red: 0.953, green: 0.694, blue: 0.298, alpha: 1)
    static let uiOnAccent = UIColor(red: 0.04, green: 0.035, blue: 0.03, alpha: 1)
    static let uiDanger = UIColor(red: 1.00, green: 0.46, blue: 0.38, alpha: 1)
    static let uiFavorite = UIColor(red: 1.00, green: 0.64, blue: 0.72, alpha: 1)
    static let uiSuccess = UIColor(red: 0.72, green: 0.86, blue: 0.52, alpha: 1)
    static let uiSecondaryText = UIColor(white: 1.0, alpha: 0.58)
    #endif

    // MARK: - Helpers

    static func iconTint(for key: String) -> Color {
        switch key {
        case "delete", "trash": return destructive
        case "favorite", "heart": return favorite
        case "video", "livephoto": return secondaryAccent
        default: return accent
        }
    }
}
