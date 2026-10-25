//
//  PhotoDeleteFilterToolbarButton.swift
//  PhotoDelete
//
//  导航栏扁筛选按钮：line.3.horizontal.decrease，外壳走统一 PhotoDeleteCircleIconButton。
//  图标始终白色；非默认筛选时在圆钮底部显示白点，用形状而不是颜色表达 active。
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
            iconColor: Theme.primaryText,
            action: action
        )
        .overlay(alignment: .bottom) {
            if isActive {
                Circle()
                    .fill(Theme.primaryText)
                    .frame(width: 4, height: 4)
                    .padding(.bottom, 7)
                    .accessibilityHidden(true)
            }
        }
    }
}
