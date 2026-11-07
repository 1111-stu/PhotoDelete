//
//  PocaCircleIconButton.swift
//  Poca
//
//  头部圆形 icon 按钮（统一标准）：
//  可见圆 48 / 图标 17 bold rounded / 触控随圆 48。
//  默认：玻璃圆 + iconColor 图标；isSelected：玻璃圆内叠加 accentSoftFill 填充 + accentSoftStroke 描边。
//  iOS 26+ 液态玻璃圆钮，老系统回落 elevatedSurface。
//

import SwiftUI

struct PocaCircleIconButton<Badge: View>: View {
    let systemName: String
    let accessibilityLabel: String
    var accessibilityIdentifier: String? = nil
    /// 默认白图标；状态用 isSelected 表达，不要再传彩色表达激活态。
    var iconColor: Color = Theme.primaryText
    /// 轻量选中态：玻璃圆内叠加浅色填充 + 描边（accentSoftFill / accentSoftStroke），用于筛选等「有状态」入口。
    var isSelected: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void
    @ViewBuilder private var badge: () -> Badge

    init(
        systemName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String? = nil,
        iconColor: Color = Theme.primaryText,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) where Badge == EmptyView {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.iconColor = iconColor
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.action = action
        self.badge = { EmptyView() }
    }

    init(
        systemName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String? = nil,
        iconColor: Color = Theme.primaryText,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder badge: @escaping () -> Badge
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.iconColor = iconColor
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.action = action
        self.badge = badge
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: Theme.textSizeChromeIcon, weight: .bold, design: .rounded))
                .foregroundStyle(iconColor)
                .frame(width: Theme.sizeChrome, height: Theme.sizeChrome)
                .background {
                    if isSelected {
                        Circle()
                            .fill(Theme.accentSoftFill)
                            .overlay {
                                Circle()
                                    .stroke(Theme.accentSoftStroke, lineWidth: Theme.stroke)
                            }
                    }
                }
        }
        .modifier(PocaGlassCircleChrome())
        .disabled(!isEnabled)
        .overlay(alignment: .topTrailing) { badge() }
        .accessibilityLabel(accessibilityLabel)
        .modifier(OptionalAccessibilityIdentifier(accessibilityIdentifier))
    }
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
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
