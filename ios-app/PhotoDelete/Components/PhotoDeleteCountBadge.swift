//
//  PhotoDeleteCountBadge.swift
//  PhotoDelete
//
//  头部圆形按钮的数量角标（统一标准）：
//  胶囊最小 20pt / destructive 底 / 白色 11.5 bold / 99+ 封顶 / 无描边环。
//  首页、待整理照片墙、整理页共用，不要再各自手写。
//

import SwiftUI

struct PhotoDeleteCountBadge: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : PhotoDeleteCountFormat.plain(count))
            .font(.system(size: 11.5, weight: .bold))
            .monospacedDigit()
            .lineLimit(1)
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20)
            .background(Capsule(style: .continuous).fill(Theme.destructive))
            .offset(x: 3, y: -3)
            .accessibilityHidden(true)
    }
}
