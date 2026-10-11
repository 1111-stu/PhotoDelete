//
//  PhotoDeleteCircleIconButton.swift
//  PhotoDelete
//
//  标题栏圆形 icon 按钮：可见圆 32 / 图标 14，触控区 44。
//  iOS 26+ 液态玻璃圆钮，老系统回落 elevatedSurface 实心圆。
//  尺寸 token：Theme.sizeIcon / textSizeSm / sizeTap。
//

import SwiftUI

struct PhotoDeleteCircleIconButton<Badge: View>: View {
    let systemName: String
    let accessibilityLabel: String
    var accessibilityIdentifier: String? = nil
    /// 默认白图标；筛选非默认等「有状态」入口可传琥珀。
    var iconColor: Color = Theme.primaryText
    let action: () -> Void
    @ViewBuilder private var badge: () -> Badge

    init(
        systemName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String? = nil,
        iconColor: Color = Theme.primaryText,
        action: @escaping () -> Void
    ) where Badge == EmptyView {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.iconColor = iconColor
        self.action = action
        self.badge = { EmptyView() }
    }

    init(
        systemName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String? = nil,
        iconColor: Color = Theme.primaryText,
        action: @escaping () -> Void,
        @ViewBuilder badge: @escaping () -> Badge
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.iconColor = iconColor
        self.action = action
        self.badge = badge
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                glassButton
            } else {
                elevatedButton
            }
        }
        .overlay(alignment: .topTrailing) { badge() }
        .accessibilityLabel(accessibilityLabel)
        .modifier(OptionalAccessibilityIdentifier(accessibilityIdentifier))
    }

    @available(iOS 26.0, *)
    private var glassButton: some View {
        // 原生 .glass：可见圆跟 label（sizeIcon）；外层 frame + contentShape 扩到 sizeTap，不撑大玻璃。
        Button(action: action) {
            iconLabel
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .foregroundStyle(iconColor)
        .frame(
            width: Theme.sizeTap,
            height: Theme.sizeTap
        )
        .contentShape(Circle())
    }

    private var elevatedButton: some View {
        Button(action: action) {
            iconLabel
                .foregroundColor(iconColor)
                .background(Theme.elevatedSurface, in: Circle())
                .frame(
                    width: Theme.sizeTap,
                    height: Theme.sizeTap
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var iconLabel: some View {
        Image(systemName: systemName)
            .font(.system(size: Theme.textSizeSm, weight: .semibold))
            .frame(
                width: Theme.sizeIcon,
                height: Theme.sizeIcon
            )
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
