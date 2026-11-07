//
//  PhotoDeleteFilterToolbarButton.swift
//  PhotoDelete
//
//  导航栏筛选按钮：line.3.horizontal.decrease，48pt 圆钮规格。
//  默认：液态玻璃圆 + 白图标；筛选非默认：玻璃圆内叠加浅色填充 + 描边（accentSoftFill / accentSoftStroke）。
//  放进 ToolbarItem 时，iOS 26+ 请加 .sharedBackgroundVisibility(.hidden)，
//  避免系统玻璃圆再套一层。
//

import SwiftUI

struct PhotoDeleteFilterToolbarButton: View {
    var isActive: Bool = false
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        PhotoDeleteCircleIconButton(
            systemName: "line.3.horizontal.decrease",
            accessibilityLabel: L10n.string("Filter and sort"),
            accessibilityIdentifier: accessibilityIdentifier,
            isSelected: isActive,
            action: action
        )
        .accessibilityValue(isActive ? L10n.string("Filters applied") : "")
        .animation(.easeOut(duration: 0.18), value: isActive)
    }
}
