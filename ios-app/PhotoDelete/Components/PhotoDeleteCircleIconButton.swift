//
//  PhotoDeleteCircleIconButton.swift
//  PhotoDelete
//
//  标题栏圆形 icon 按钮：可见圆 36 / 图标 15，触控区仍为 44。
//  iOS 26+ 液态玻璃圆钮，老系统回落 elevatedSurface 实心圆。
//  尺寸 token 见 Theme.Metrics（titleBarIcon* / minimumTapTarget）。
//

import SwiftUI

struct PhotoDeleteCircleIconButton<Badge: View>: View {
    let systemName: String
    let accessibilityLabel: String
    var accessibilityIdentifier: String? = nil
    let action: () -> Void
    @ViewBuilder private var badge: () -> Badge

    init(
        systemName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) where Badge == EmptyView {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
        self.badge = { EmptyView() }
    }

    init(
        systemName: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder badge: @escaping () -> Badge
    ) {
        self.systemName = systemName
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
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
        // 原生 .glass：可见圆跟 label（36）；外层 frame + contentShape 扩到 44 触控，不撑大玻璃。
        Button(action: action) {
            iconLabel
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .foregroundStyle(Theme.primaryText)
        .frame(
            width: Theme.Metrics.minimumTapTarget,
            height: Theme.Metrics.minimumTapTarget
        )
        .contentShape(Circle())
    }

    private var elevatedButton: some View {
        Button(action: action) {
            iconLabel
                .foregroundColor(Theme.primaryText)
                .background(Theme.elevatedSurface, in: Circle())
                .frame(
                    width: Theme.Metrics.minimumTapTarget,
                    height: Theme.Metrics.minimumTapTarget
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var iconLabel: some View {
        Image(systemName: systemName)
            .font(.system(size: Theme.Metrics.titleBarIconPointSize, weight: .semibold))
            .frame(
                width: Theme.Metrics.titleBarIconVisualSize,
                height: Theme.Metrics.titleBarIconVisualSize
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
