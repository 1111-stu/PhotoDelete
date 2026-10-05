import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// 设计规范（色彩 / 组件 / 数字格式的唯一基准）见仓库根目录 style.md。
enum PhotoDeleteTheme: String, CaseIterable, Identifiable, Equatable {
    case moonly

    // Neutral near-black canvas with quiet surfaces, amber actions, and coral/amber gradient entry cards
    // (aligned with designs/home-prototype.html, the single visual source of truth).
    static let defaultTheme: PhotoDeleteTheme = .moonly

    var id: String { rawValue }

    static var current: PhotoDeleteTheme {
        guard hasStoredThemeAccess else { return defaultTheme }
        return normalized(UserDefaults.standard.string(forKey: AppConstants.appThemeKey))
    }

    static func normalized(_ rawValue: String?) -> PhotoDeleteTheme {
        guard let rawValue else { return defaultTheme }
        return PhotoDeleteTheme(rawValue: rawValue) ?? defaultTheme
    }

    private static var hasStoredThemeAccess: Bool {
        let defaults = UserDefaults.standard
        if SupporterCachedEntitlementPolicy.isValid(
            isUnlocked: defaults.bool(forKey: AppConstants.supporterEntitlementKey),
            productID: defaults.string(forKey: AppConstants.supporterProductIDKey),
            expirationDate: defaults.object(forKey: AppConstants.supporterExpirationDateKey) as? Date,
            now: .now
        ) {
            return true
        }

        guard let trialStartDate = defaults.object(forKey: AppConstants.supporterTrialStartDateKey) as? Date else {
            return false
        }

        return Date.now < trialStartDate.addingTimeInterval(AppConstants.supporterTrialDuration)
    }

    var title: String {
        switch self {
        case .moonly: return L10n.string("琥珀夜色")
        }
    }

    var subtitle: String {
        switch self {
        case .moonly: return L10n.string("深色照片画布，配合琥珀色操作反馈。")
        }
    }

    var icon: String {
        switch self {
        case .moonly: return "sun.max.fill"
        }
    }

    var backgroundTop: Color { palette.backgroundTop.color }
    var backgroundBottom: Color { palette.backgroundBottom.color }
    var surface: Color { palette.surface.color }
    var elevatedSurface: Color { palette.elevatedSurface.color }
    var cardStroke: Color { palette.cardStroke.color }
    var hairline: Color { palette.hairline.color }
    var floatingShadow: Color { palette.floatingShadow.color }

    var primaryAccent: Color { palette.primaryAccent.color }
    var primaryAccentPressed: Color { palette.primaryAccentPressed.color }
    var primaryAccentOnFill: Color { palette.primaryAccentOnFill.color }
    var primaryAccentSoftFill: Color { primaryAccent.opacity(0.14) }
    var primaryAccentSoftStroke: Color { primaryAccent.opacity(0.22) }
    var secondaryAccent: Color { palette.secondaryAccent.color }
    var secondaryAccentSoftFill: Color { secondaryAccent.opacity(0.14) }

    var success: Color { palette.success.color }
    var successSoftFill: Color { success.opacity(0.14) }
    var warning: Color { palette.warning.color }
    var warningSoftFill: Color { warning.opacity(0.14) }
    var danger: Color { palette.danger.color }
    var dangerSoftFill: Color { danger.opacity(0.14) }
    var favorite: Color { palette.favorite.color }

    // Gradient entry cards (home 待整理/随机整理 双卡) — absolute colors, same in both schemes.
    var coralGradientTop: Color { palette.coralGradientTop.color }
    var coralGradientBottom: Color { palette.coralGradientBottom.color }
    var coralInk: Color { palette.coralInk.color }
    var amberGradientTop: Color { palette.amberGradientTop.color }
    var amberGradientBottom: Color { palette.amberGradientBottom.color }
    var amberInk: Color { palette.amberInk.color }

    var buttonPrimaryFill: Color { primaryAccent }
    var buttonPrimaryText: Color { primaryAccentOnFill }
    var buttonSecondaryFill: Color { surface }
    var buttonSecondaryText: Color { primaryAccent }
    var buttonSecondaryStroke: Color { primaryAccentSoftStroke }
    var toolbarAction: Color { primaryAccent }
    var tabSelected: Color { primaryAccent }
    var progressTint: Color { primaryAccent }
    var selectionTint: Color { primaryAccent }
    var searchFieldFill: Color { elevatedSurface }
    var searchFieldStroke: Color { primaryAccentSoftStroke }
    var iconTileFill: Color { primaryAccentSoftFill }
    var iconTileStroke: Color { primaryAccentSoftStroke }
    var navigationTint: Color { primaryAccent }

    var readableAccent: Color { primaryAccent }
    var warmAccent: Color { secondaryAccent }
    var primaryButtonText: Color { buttonPrimaryText }

    var swatches: [Color] {
        [primaryAccent, secondaryAccent, backgroundBottom]
    }

    #if canImport(UIKit)
    var uiBackground: UIColor { palette.backgroundBottom.uiColor }
    var uiSurface: UIColor { palette.surface.uiColor }
    var uiHairline: UIColor { palette.hairline.uiColor }
    var uiAccent: UIColor { palette.primaryAccent.uiColor }
    var uiTabSelected: UIColor { palette.primaryAccent.uiColor }
    var uiPrimaryButtonText: UIColor { palette.primaryAccentOnFill.uiColor }
    var uiDanger: UIColor { palette.danger.uiColor }
    var uiFavorite: UIColor { palette.favorite.uiColor }
    var uiSuccess: UIColor { palette.success.uiColor }
    var uiSecondaryText: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.58)
                : UIColor.secondaryLabel
        }
    }
    #endif

    private var palette: PhotoDeleteThemePalette {
        switch self {
        case .moonly:
            return PhotoDeleteThemePalette(
                backgroundTop: .init(light: .init(0.994, 0.968, 0.930), dark: .init(0.039, 0.039, 0.051)),
                backgroundBottom: .init(light: .init(0.956, 0.900, 0.820), dark: .init(0.031, 0.031, 0.039)),
                surface: .init(light: .init(1, 1, 1, 0.82), dark: .init(0.086, 0.086, 0.102)),
                elevatedSurface: .init(light: .init(1, 1, 1, 0.92), dark: .init(0.118, 0.118, 0.141)),
                cardStroke: .init(light: .init(0.56, 0.38, 0.18, 0.11), dark: .init(1, 1, 1, 0.09)),
                hairline: .init(light: .init(0.56, 0.38, 0.18, 0.14), dark: .init(1, 1, 1, 0.075)),
                floatingShadow: .init(light: .init(0.22, 0.12, 0.03, 0.09), dark: .init(0, 0, 0, 0.30)),
                primaryAccent: .init(light: .init(0.72, 0.42, 0.10), dark: .init(0.953, 0.694, 0.298)),
                primaryAccentPressed: .init(light: .init(0.58, 0.31, 0.06), dark: .init(0.788, 0.541, 0.196)),
                primaryAccentOnFill: .init(light: .init(1, 1, 1), dark: .init(0.04, 0.035, 0.03)),
                secondaryAccent: .init(light: .init(0.78, 0.45, 0.16), dark: .init(1.00, 0.78, 0.48)),
                success: .init(light: .init(0.34, 0.46, 0.20), dark: .init(0.72, 0.86, 0.52)),
                warning: .init(light: .init(0.80, 0.45, 0.08), dark: .init(1.00, 0.78, 0.45)),
                danger: .init(light: .init(0.78, 0.18, 0.12), dark: .init(1.00, 0.46, 0.38)),
                favorite: .init(light: .init(0.72, 0.25, 0.36), dark: .init(1.00, 0.64, 0.72)),
                coralGradientTop: .init(light: .init(1.00, 0.62, 0.49), dark: .init(1.00, 0.62, 0.49)),
                coralGradientBottom: .init(light: .init(0.949, 0.439, 0.290), dark: .init(0.949, 0.439, 0.290)),
                coralInk: .init(light: .init(0.180, 0.059, 0.024), dark: .init(0.180, 0.059, 0.024)),
                amberGradientTop: .init(light: .init(1.00, 0.784, 0.369), dark: .init(1.00, 0.784, 0.369)),
                amberGradientBottom: .init(light: .init(0.941, 0.604, 0.133), dark: .init(0.941, 0.604, 0.133)),
                amberInk: .init(light: .init(0.102, 0.071, 0.024), dark: .init(0.102, 0.071, 0.024))
            )
        }
    }
}

private struct PhotoDeleteThemePalette {
    let backgroundTop: PhotoDeleteThemeColor
    let backgroundBottom: PhotoDeleteThemeColor
    let surface: PhotoDeleteThemeColor
    let elevatedSurface: PhotoDeleteThemeColor
    let cardStroke: PhotoDeleteThemeColor
    let hairline: PhotoDeleteThemeColor
    let floatingShadow: PhotoDeleteThemeColor
    let primaryAccent: PhotoDeleteThemeColor
    let primaryAccentPressed: PhotoDeleteThemeColor
    let primaryAccentOnFill: PhotoDeleteThemeColor
    let secondaryAccent: PhotoDeleteThemeColor
    let success: PhotoDeleteThemeColor
    let warning: PhotoDeleteThemeColor
    let danger: PhotoDeleteThemeColor
    let favorite: PhotoDeleteThemeColor
    let coralGradientTop: PhotoDeleteThemeColor
    let coralGradientBottom: PhotoDeleteThemeColor
    let coralInk: PhotoDeleteThemeColor
    let amberGradientTop: PhotoDeleteThemeColor
    let amberGradientBottom: PhotoDeleteThemeColor
    let amberInk: PhotoDeleteThemeColor
}

private struct PhotoDeleteThemeColor {
    let light: PhotoDeleteRGBA
    let dark: PhotoDeleteRGBA

    init(light: PhotoDeleteRGBA, dark: PhotoDeleteRGBA) {
        self.light = light
        self.dark = dark
    }

    var color: Color {
        #if canImport(UIKit)
        Color(uiColor: uiColor)
        #else
        Color(red: light.red, green: light.green, blue: light.blue).opacity(light.alpha)
        #endif
    }

    #if canImport(UIKit)
    var uiColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark.uiColor : light.uiColor
        }
    }
    #endif
}

private struct PhotoDeleteRGBA {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    #if canImport(UIKit)
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    #endif
}

private struct PhotoDeleteThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: PhotoDeleteTheme = .defaultTheme
}

extension EnvironmentValues {
    var photoDeleteTheme: PhotoDeleteTheme {
        get { self[PhotoDeleteThemeEnvironmentKey.self] }
        set { self[PhotoDeleteThemeEnvironmentKey.self] = newValue }
    }
}
