//
//  PhotoDeleteCircleIconButton.swift
//  PhotoDelete
//
//  头部圆形 icon 按钮（统一标准）：
//  可见圆 48 / 图标 17 bold rounded / 触控随圆 48。
//  iOS 26+ 液态玻璃圆钮，老系统回落 elevatedSurface。
//

import SwiftUI

struct PhotoDeleteCircleIconButton<Badge: View>: View {
    let systemName: String
    let accessibilityLabel: String
    var accessibilityIdentifier: String? = nil
    /// 默认白图标；筛选非默认等「有状态」入口可传琥珀。
    var iconColor: Color = Theme.primaryText
    var isEnabled: Bool = true
    let action: () -> Void
    @ViewBuilder private var badge: () -> Badge

    init(
        systemName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String? = nil,
        iconColor: Color = Theme.primaryText,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) where Badge == EmptyView {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.iconColor = iconColor
        self.isEnabled = isEnabled
        self.action = action
        self.badge = { EmptyView() }
    }

    init(
        systemName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String? = nil,
        iconColor: Color = Theme.primaryText,
        isEnabled: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder badge: @escaping () -> Badge
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.iconColor = iconColor
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
        }
        .modifier(PhotoDeleteGlassCircleChrome())
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
