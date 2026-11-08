import SwiftUI

/// 整理页的氛围底色：照片主色铺成两层静态径向渐变，纯黑仍是基底。
/// 只在切换照片时淡入，不做呼吸/漂移（style.md：Static is static）。
struct ReviewAmbientBackground: View {
    let palette: PhotoAmbientPalette?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Theme.reviewCanvas

            if let palette {
                glow(palette)
                    .id(palette.assetID)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.45),
            value: palette?.assetID
        )
    }

    private func glow(_ palette: PhotoAmbientPalette) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let longSide = max(width, height)

            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.top.opacity(0.58),
                                palette.top.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: longSide * 0.46
                        )
                    )
                    .frame(width: width * 1.5, height: height * 0.62)
                    .position(x: width / 2, y: height * 0.10)
                    .blur(radius: 54)

                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.bottom.opacity(0.40),
                                palette.bottom.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: longSide * 0.42
                        )
                    )
                    .frame(width: width * 1.6, height: height * 0.45)
                    .position(x: width / 2, y: height * 0.98)
                    .blur(radius: 60)

                // 顶部与底部各压一点黑，保证页头白字和玻璃按钮的对比度。
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.16), location: 0),
                        .init(color: .clear, location: 0.30),
                        .init(color: .clear, location: 0.68),
                        .init(color: .black.opacity(0.30), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}
