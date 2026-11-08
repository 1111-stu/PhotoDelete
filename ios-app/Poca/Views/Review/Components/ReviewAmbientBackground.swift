import SwiftUI

/// 整理页的氛围底色：整屏铺一张当前照片的低分辨率模糊副本。
/// 颜色来自照片本身、空间连续（顶部通常是天空/光源，底部是地面），
/// 边缘和底部压暗以保护 chrome。切换照片时旧图保持不透明、新图淡入。
struct ReviewAmbientBackground: View {
    let backdrop: PhotoAmbientBackdrop?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed: PhotoAmbientBackdrop?
    @State private var incoming: PhotoAmbientBackdrop?
    @State private var incomingOpacity: Double = 1
    @State private var promotionWorkItem: DispatchWorkItem?

    private static let fadeDuration: TimeInterval = 0.4

    var body: some View {
        ZStack {
            Theme.reviewCanvas

            if let displayed {
                imageLayer(displayed)
            }

            if let incoming {
                imageLayer(incoming)
                    .opacity(incomingOpacity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { apply(backdrop, animated: false) }
        .onChange(of: backdrop?.assetID) { _, _ in apply(backdrop, animated: true) }
        .onDisappear { promotionWorkItem?.cancel() }
    }

    private func imageLayer(_ backdrop: PhotoAmbientBackdrop) -> some View {
        GeometryReader { geometry in
            Image(uiImage: backdrop.image)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .opacity(0.94)
        }
        .overlay { chromeScrim }
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
        promotionWorkItem?.cancel()
        promotionWorkItem = nil

        guard let new else {
            displayed = nil
            incoming = nil
            incomingOpacity = 1
            return
        }
        guard new.assetID != incoming?.assetID else { return }

        if !animated || reduceMotion {
            displayed = new
            incoming = nil
            incomingOpacity = 1
            return
        }

        // 旧底图保持不透明，新图以 0 透明度入树后淡入。
        incoming = new
        incomingOpacity = 0
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: Self.fadeDuration)) {
                incomingOpacity = 1
            }
        }

        let targetID = new.assetID
        let workItem = DispatchWorkItem { [self] in
            guard incoming?.assetID == targetID else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                displayed = new
                incoming = nil
                incomingOpacity = 1
            }
        }
        promotionWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.fadeDuration + 0.02,
            execute: workItem
        )
    }
}
