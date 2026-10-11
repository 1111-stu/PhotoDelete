//
//  PhotoDeleteStyle.swift
//  PhotoDelete
//
//  唯一全局设计 token（暗色）。规范见仓库根目录 style.md。
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum PhotoDeleteStyle {
    // MARK: - Metrics

    enum Metrics {
        static let minimumTapTarget: CGFloat = 44
        /// 标题栏圆形 icon 按钮的可见圆直径（触控仍用 `minimumTapTarget`）。
        static let titleBarIconVisualSize: CGFloat = 36
        static let titleBarIconPointSize: CGFloat = 15
        /// 整理页顶/底栏圆形 chrome（有意更大一档，勿与标题栏混用）。
        static let reviewChromeTarget: CGFloat = 52
        static let reviewChromeIconPointSize: CGFloat = 19
        static let screenHorizontalPadding: CGFloat = 20
        static let cardRadius: CGFloat = 22
        static let controlRadius: CGFloat = 14
        static let sectionSpacing: CGFloat = 24
        static let rootContentTopSpacing: CGFloat = 8
        static let rowIconSize: CGFloat = 32
        static let rowMinHeight: CGFloat = 58
        static let cardStrokeWidth: CGFloat = 1
        static let toastHorizontalPadding: CGFloat = 14
        static let toastVerticalPadding: CGFloat = 11
        static let toastIconSize: CGFloat = 15
        static let toastTextSize: CGFloat = 14
        static let thumbnailRadius: CGFloat = 12
        static let compactRadius: CGFloat = 16
        static let capsuleHorizontalPadding: CGFloat = 14
        static let bottomChromeSpacing: CGFloat = 96
        static let contentBottomPadding: CGFloat = 24
    }

    // MARK: - Typography

    enum Typography {
        static let pageTitle: Font = .title2.weight(.semibold)
        static let cardTitle: Font = .headline
        static let body: Font = .body
        static let secondary: Font = .subheadline
        static let label: Font = .caption
        static let metric: Font = .title.weight(.semibold)
    }

    // MARK: - Canvas / surface（原 moonly dark）

    static let backgroundTop = Color(red: 0.039, green: 0.039, blue: 0.051)
    /// 页面主背景（原 `backgroundBottom`）。
    static let background = Color(red: 0.031, green: 0.031, blue: 0.039)
    static let surface = Color(red: 0.086, green: 0.086, blue: 0.102)
    static let elevatedSurface = Color(red: 0.118, green: 0.118, blue: 0.141)
    static let cardStroke = Color.white.opacity(0.09)
    static let hairline = Color.white.opacity(0.075)
    static let floatingShadow = Color.black.opacity(0.30)
    /// 整理页幕布，比首页画布略亮一档。
    static let reviewCanvas = Color(red: 23.0 / 255.0, green: 24.0 / 255.0, blue: 31.0 / 255.0)

    // MARK: - Text

    static let primaryText = Color.white.opacity(0.96)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.42)

    // MARK: - Accent / semantic

    static let accent = Color(red: 0.953, green: 0.694, blue: 0.298)
    static let accentPressed = Color(red: 0.788, green: 0.541, blue: 0.196)
    static let primaryButtonText = Color(red: 0.04, green: 0.035, blue: 0.03)
    static let secondaryAccent = Color(red: 1.00, green: 0.78, blue: 0.48)
    static let positive = Color(red: 0.72, green: 0.86, blue: 0.52)
    static let warning = Color(red: 1.00, green: 0.78, blue: 0.45)
    static let destructive = Color(red: 1.00, green: 0.46, blue: 0.38)
    static let favorite = Color(red: 1.00, green: 0.64, blue: 0.72)

    static let accentSoftFill = accent.opacity(0.14)
    static let accentSoftStroke = accent.opacity(0.22)
    static let secondaryAccentSoftFill = secondaryAccent.opacity(0.14)
    static let positiveSoftFill = positive.opacity(0.14)
    static let warningSoftFill = warning.opacity(0.14)
    static let destructiveSoftFill = destructive.opacity(0.14)

    // MARK: - Gradient entry cards

    static let coralGradientTop = Color(red: 0.984, green: 0.522, blue: 0.494)
    static let coralGradientBottom = Color(red: 0.949, green: 0.361, blue: 0.329)
    static let coralInk = Color(red: 0.180, green: 0.059, blue: 0.024)
    static let amberGradientTop = Color(red: 1.00, green: 0.784, blue: 0.369)
    static let amberGradientBottom = Color(red: 0.941, green: 0.604, blue: 0.133)
    static let amberInk = Color(red: 0.102, green: 0.071, blue: 0.024)

    // MARK: - Derived roles

    static let buttonPrimaryFill = accent
    static let buttonPrimaryText = primaryButtonText
    static let buttonSecondaryFill = surface
    static let buttonSecondaryText = accent
    static let buttonSecondaryStroke = accentSoftStroke
    static let toolbarAction = accent
    static let tabSelected = accent
    static let progressTint = accent
    static let selectionTint = accent
    static let searchFieldFill = elevatedSurface
    static let searchFieldStroke = accentSoftStroke
    static let iconTileFill = accentSoftFill
    static let iconTileStroke = accentSoftStroke
    static let navigationTint = accent

    // MARK: - Geometry aliases

    static let screenHorizontalPadding = Metrics.screenHorizontalPadding
    static let cardRadius = Metrics.cardRadius
    static let controlRadius = Metrics.controlRadius
    static let sectionSpacing = Metrics.sectionSpacing
    static let rootContentTopSpacing = Metrics.rootContentTopSpacing
    static let rowIconSize = Metrics.rowIconSize
    static let rowMinHeight = Metrics.rowMinHeight
    static var contentBottomPadding: CGFloat { Metrics.contentBottomPadding }

    // MARK: - Album reorder

    // 站位用中性虚线：琥珀只留给可执行行动（designs/albums-reorder-prototype.html）。
    static let dropSlotStroke = Color.white.opacity(0.34)
    static let dropSlotFill = Color.white.opacity(0.05)
    static let dropSlotLineWidth: CGFloat = 2.5
    static let dropSlotDash: [CGFloat] = [11, 9]
    static let albumListCardRadius: CGFloat = 16
    static let albumListCardSpacing: CGFloat = 8
    static let albumListCardMinHeight: CGFloat = 64

    // MARK: - UIKit bridges

    #if canImport(UIKit)
    static let uiBackground = UIColor(red: 0.031, green: 0.031, blue: 0.039, alpha: 1)
    static let uiSurface = UIColor(red: 0.086, green: 0.086, blue: 0.102, alpha: 1)
    static let uiHairline = UIColor(white: 1, alpha: 0.075)
    static let uiAccent = UIColor(red: 0.953, green: 0.694, blue: 0.298, alpha: 1)
    static let uiPrimaryButtonText = UIColor(red: 0.04, green: 0.035, blue: 0.03, alpha: 1)
    static let uiDanger = UIColor(red: 1.00, green: 0.46, blue: 0.38, alpha: 1)
    static let uiFavorite = UIColor(red: 1.00, green: 0.64, blue: 0.72, alpha: 1)
    static let uiSuccess = UIColor(red: 0.72, green: 0.86, blue: 0.52, alpha: 1)
    static let uiSecondaryText = UIColor(white: 1.0, alpha: 0.58)
    #endif

    // MARK: - Helpers

    static func iconTint(for key: String) -> Color {
        switch key {
        case "delete", "trash":
            return destructive
        case "favorite", "heart":
            return favorite
        case "video", "livephoto":
            return secondaryAccent
        case "screenshot", "iphone", "photo", "album":
            return accent
        default:
            return accent
        }
    }

    static func surfaceFill(elevated: Bool = false) -> Color {
        elevated ? elevatedSurface : surface
    }
}
