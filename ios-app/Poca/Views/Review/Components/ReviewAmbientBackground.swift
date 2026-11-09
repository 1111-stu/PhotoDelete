import SwiftUI

/// 整理页的氛围底色：整屏铺一张当前照片的低分辨率模糊副本。
/// 颜色来自照片本身、空间连续（顶部通常是天空/光源，底部是地面），
/// 边缘和底部压暗以保护 chrome。
///
/// 交叉淡入只作用于**完全不透明**的图片层；压暗和渐变遮罩都放在淡入层之外。
/// 两层始终留在树上，只改透明度：插入/移除带黑底的 GeometryReader 会在淡入开始时闪一帧黑。
struct ReviewAmbientBackground: View {
    let backdrop: PhotoAmbientBackdrop?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var displayed: PhotoAmbientBackdrop?
    @State private var incoming: PhotoAmbientBackdrop?
    @State private var pending: PhotoAmbientBackdrop?
    @State private var incomingOpacity: Double = 0
    @State private var isFading = false
    @State private var fadeGeneration = 0

    private static let fadeDuration: TimeInterval = 0.6

    var body: some View {
        ZStack {
            Theme.reviewCanvas
            imageLayer(displayed)
            imageLayer(incoming)
                .opacity(incomingOpacity)
            Color.black.opacity(0.06)
            chromeScrim
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { apply(backdrop, animated: false) }
        .onChange(of: backdrop?.assetID) { _, _ in apply(backdrop, animated: true) }
        .onDisappear { fadeGeneration += 1 }
    }

    /// 槽位始终占着全屏；没有图时是透明的，旧图能透出来。
    private func imageLayer(_ backdrop: PhotoAmbientBackdrop?) -> some View {
        GeometryReader { geometry in
            if let backdrop {
                Image(uiImage: backdrop.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .transition(.identity)
            }
        }
        .accessibilityHidden(true)
    }

    /// 顶部（页头/状态栏）和底部（工具条）压暗；中段保持照片本身的颜色。
    private var chromeScrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.26), location: 0),
                .init(color: .clear, location: 0.14),
                .init(color: .clear, location: 0.74),
                .init(color: .black.opacity(0.30), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func apply(_ new: PhotoAmbientBackdrop?, animated: Bool) {
        guard let new else {
            snap(to: nil)
            return
        }

        let visualTargetID = incoming?.assetID ?? displayed?.assetID
        if new.assetID == visualTargetID {
            pending = nil
            return
        }

        if !animated || reduceMotion {
            snap(to: new)
            return
        }

        pending = new
        startNextFadeIfNeeded()
    }

    private func snap(to new: PhotoAmbientBackdrop?) {
        fadeGeneration += 1
        pending = nil
        isFading = false
        var transaction = Transaction()
        transaction.disablesAnimations = true
        transaction.animation = nil
        withTransaction(transaction) {
            displayed = new
            incoming = nil
            incomingOpacity = 0
        }
    }

    private func startNextFadeIfNeeded() {
        guard !isFading, let next = pending else { return }
        pending = nil
        guard next.assetID != displayed?.assetID else { return }

        isFading = true
        fadeGeneration += 1
        let generation = fadeGeneration

        // 新图必须在「无动画、透明度为 0」时进入已布局的槽位。
        // incomingOpacity 休息态就是 0，避免先从 1 闪到 0 再淡入。
        var plant = Transaction()
        plant.disablesAnimations = true
        plant.animation = nil
        withTransaction(plant) {
            incoming = next
            incomingOpacity = 0
        }

        Task { @MainActor in
            // 等一帧把透明度为 0 的层画上去；async 不够，SwiftUI 常会把 0 和 1 合成一次更新。
            try? await Task.sleep(for: .milliseconds(17))
            guard generation == fadeGeneration, incoming?.assetID == next.assetID else {
                return
            }

            withAnimation(.easeInOut(duration: Self.fadeDuration)) {
                incomingOpacity = 1
            } completion: {
                guard generation == fadeGeneration, incoming?.assetID == next.assetID else {
                    return
                }
                var settle = Transaction()
                settle.disablesAnimations = true
                settle.animation = nil
                withTransaction(settle) {
                    displayed = next
                    incoming = nil
                    incomingOpacity = 0
                }
                isFading = false
                startNextFadeIfNeeded()
            }
        }
    }
}
