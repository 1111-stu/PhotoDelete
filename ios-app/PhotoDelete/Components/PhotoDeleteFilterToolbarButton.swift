//
//  PhotoDeleteFilterToolbarButton.swift
//  PhotoDelete
//
//  导航栏扁筛选按钮：line.3.horizontal.decrease，尺寸对齐 titleBar icon。
//  默认白图标；非默认筛选时图标变琥珀（不用角标圆点）。
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
            iconColor: isActive ? Theme.accent : Theme.primaryText,
            action: action
        )
    }
}
