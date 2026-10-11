//
//  PhotoDeleteGlassChrome.swift
//  PhotoDelete
//
//  头部共用液态玻璃 chrome：圆钮 / 胶囊。
//

import SwiftUI

/// 圆形液态玻璃：iOS 26+ `glassEffect`，老系统 elevatedSurface 实心圆。
struct PhotoDeleteGlassCircleChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.plain)
                .glassEffect(.regular, in: .circle)
        } else {
            content
                .buttonStyle(.plain)
                .background(Circle().fill(Theme.elevatedSurface))
        }
    }
}

/// 胶囊液态玻璃：iOS 26+ `glassEffect`，老系统 surface 实心胶囊。
struct PhotoDeleteGlassCapsuleChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .capsule)
        } else {
            content
                .background {
                    Capsule(style: .continuous)
                        .fill(Theme.surface.opacity(0.9))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(Theme.hairline, lineWidth: Theme.stroke)
                        }
                }
        }
    }
}

/// 整理页历史命名，指向共用实现。
typealias ReviewGlassCircleChrome = PhotoDeleteGlassCircleChrome
typealias ReviewGlassCapsuleChrome = PhotoDeleteGlassCapsuleChrome
