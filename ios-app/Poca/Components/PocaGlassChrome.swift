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

/// 自定义尺寸按钮的玻璃圆底。
/// 说明：这里不用 iOS 26 的 `glassEffect`——放在自定义尺寸按钮的 label 里会让
/// 按钮的命中区域塌缩到图标本身，点击失效。用材质 + 高光描边模拟同一观感。
/// 也不要给这层加 `.allowsHitTesting(false)`，否则整个按钮都收不到点击。
struct PhotoDeleteGlassCircleBackground: View {
    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
    }
}

/// 整理页历史命名，指向共用实现。
typealias ReviewGlassCircleChrome = PhotoDeleteGlassCircleChrome
typealias ReviewGlassCapsuleChrome = PhotoDeleteGlassCapsuleChrome
