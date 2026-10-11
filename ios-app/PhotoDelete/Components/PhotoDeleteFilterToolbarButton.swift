//
//  PhotoDeleteFilterToolbarButton.swift
//  PhotoDelete
//
//  导航栏扁筛选按钮：白色 line.3.horizontal.decrease，尺寸对齐 titleBar icon。
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
            action: action
        ) {
            if isActive {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 7, height: 7)
                    .overlay(
                        Circle()
                            .stroke(Theme.backgroundTop, lineWidth: 1.5)
                    )
                    .offset(x: 2, y: -2)
                    .accessibilityHidden(true)
            }
        }
    }
}
