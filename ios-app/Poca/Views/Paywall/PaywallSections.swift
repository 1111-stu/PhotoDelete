//
//  PaywallSections.swift
//  Poca
//
//  Paywall 的三块内容：权益轮播、套餐横排、玻璃底栏。
//  每个组件都通过参数取依赖，不直接访问 SubscriptionManager。
//

import SwiftUI
import UIKit

// MARK: - Benefit Carousel

/// 五张权益轮播，画布 700×525（4:3），Quiet Keep 五条 Pro 权益：
/// Cover Flow / Quiet Slider / Keep+Similar / Date Wall / Share Peek。
/// 整张画布等比缩进卡片，文案随画布一起缩放。
///
/// 不做自动播放：权益是用户正在读的内容，默认静止。
struct PaywallBenefitCarousel: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    private let slides = PaywallBenefitSlide.all
    private static let designSize = CGSize(width: 700, height: 525)

    var body: some View {
        // 4:3 画幅：宽度决定高度，文案按画布一起缩放。
        // 圆点按 HIG 放进卡片内部，收敛在底部居中。
        Color.clear
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .overlay { carousel }
            .overlay(alignment: .bottom) {
                pageDots
                    .padding(.bottom, 1)
            }
    }
}

// MARK: - Carousel Shell

private extension PaywallBenefitCarousel {

    var carousel: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / Self.designSize.width,
                proxy.size.height / Self.designSize.height
            )

            ZStack {
                // 只实例化当前这张：五张画布各含 5–7 张图和多层模糊/阴影，
                // 同时铺出来会让首帧和内存无谓地重。
                PaywallReviewSlide(slide: slides[index])
                    .id(index)
                    .transition(.opacity)
                    .frame(width: Self.designSize.width, height: Self.designSize.height)
                    .scaleEffect(scale, anchor: .bottom)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                    .allowsHitTesting(false)
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: PaywallDS.Radius.carousel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PaywallDS.Radius.carousel, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 28, y: 24)
        .contentShape(RoundedRectangle(cornerRadius: PaywallDS.Radius.carousel, style: .continuous))
        .simultaneousGesture(dragGesture)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(slides[index].title))
        .accessibilityValue(Text("\(index + 1) / \(slides.count) · \(slides[index].subtitle)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                go(to: index + 1)
            case .decrement:
                go(to: index - 1)
            @unknown default:
                break
            }
        }
        .accessibilityIdentifier("paywall-benefit-carousel")
    }
}

// MARK: - Interaction

private extension PaywallBenefitCarousel {

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                let dx = value.translation.width
                if abs(dx) > 42 {
                    go(to: index + (dx < 0 ? 1 : -1))
                }
            }
    }

    func go(to target: Int) {
        let count = slides.count
        guard count > 0 else { return }
        let next = ((target % count) + count) % count
        guard next != index else { return }
        index = next
    }

    var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(slides.indices, id: \.self) { offset in
                Circle()
                    .fill(offset == index ? Color.white : Color.white.opacity(0.26))
                    .frame(width: 6, height: 6)
            }
        }
        // 视觉圆点仍是 6pt，但命中区给到 44pt。
        .frame(height: 44)
        .contentShape(Rectangle())
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                let slot = proxy.size.width / CGFloat(max(slides.count, 1))
                                let tapped = Int(value.location.x / max(slot, 1))
                                go(to: min(max(tapped, 0), slides.count - 1))
                            }
                    )
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: index)
        .accessibilityHidden(true)
    }
}

// MARK: - Review Slide Canvas

/// 700×525 的轮播画布，对应 Quiet Keep HTML 方向稿。
private struct PaywallReviewSlide: View {

    let slide: PaywallBenefitSlide

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black

            visual
                .frame(width: 700, height: 525)

            scrim
                .frame(width: 700, height: 525)

            copy
        }
        .frame(width: 700, height: 525)
        .clipped()
    }

    @ViewBuilder
    private var visual: some View {
        switch slide.visual {
        case .fan:
            PaywallFanVisual(images: slide.images)
        case .slider:
            PaywallSliderVisual()
        case .categories:
            PaywallSimilarVisual(images: slide.images)
        case .board:
            PaywallDateWallVisual(images: slide.images)
        case .share:
            PaywallSharePeekVisual(images: slide.images)
        }
    }

    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0), location: 0.30),
                .init(color: .black.opacity(0.18), location: 0.55),
                .init(color: .black.opacity(0.78), location: 0.78),
                .init(color: .black.opacity(0.96), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(slide.title)
                .font(.system(size: 40, weight: .bold))
                .tracking(-1.2)
                .foregroundStyle(.white)

            Text(slide.subtitle)
                .font(.system(size: 25))
                .tracking(-0.25)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.horizontal, 44)
        .padding(.bottom, 64)
    }
}

// MARK: - 01 · Cover Flow Fan

/// Quiet Keep：五张 Cover Flow。中间 Beach 最清晰，两侧递进缩小、微倾、外缘轻虚。
private struct PaywallFanVisual: View {

    let images: [String]

    private struct Spec {
        let imageIndex: Int
        let x: CGFloat
        let y: CGFloat
        let angle: Double
        let scale: CGFloat
        let width: CGFloat
        let opacity: Double
        let blur: CGFloat
        let z: Double
    }

    /// 对应 HTML：l2 / l1 / hero / r1 / r2（设计坐标，画布 700×525）
    private static let specs: [Spec] = [
        Spec(imageIndex: 0, x: 168, y: 228, angle: -10, scale: 0.78, width: 224, opacity: 0.88, blur: 1.0, z: 1),
        Spec(imageIndex: 1, x: 248, y: 212, angle: -5.5, scale: 0.92, width: 224, opacity: 1.0, blur: 0, z: 2),
        Spec(imageIndex: 2, x: 350, y: 198, angle: 0, scale: 1.0, width: 238, opacity: 1.0, blur: 0, z: 4),
        Spec(imageIndex: 3, x: 452, y: 212, angle: 5.5, scale: 0.92, width: 224, opacity: 1.0, blur: 0, z: 2),
        Spec(imageIndex: 4, x: 532, y: 228, angle: 10, scale: 0.78, width: 224, opacity: 0.88, blur: 1.0, z: 1)
    ]

    var body: some View {
        ZStack {
            ForEach(Array(Self.specs.enumerated()), id: \.offset) { _, spec in
                card(spec)
            }
        }
        .frame(width: 700, height: 525)
    }

    private func card(_ spec: Spec) -> some View {
        let height = spec.width * 4.0 / 3.0
        let name = imageName(at: spec.imageIndex)

        return photo(name, width: spec.width, height: height, radius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(spec.z >= 4 ? 0.16 : 0.08), lineWidth: 1)
            )
            .opacity(spec.opacity)
            .blur(radius: spec.blur)
            .brightness(spec.blur > 0 ? -0.12 : 0)
            .shadow(color: .black.opacity(0.5), radius: spec.z >= 4 ? 22 : 16, y: 20)
            .scaleEffect(spec.scale)
            .rotationEffect(.degrees(spec.angle))
            .position(x: spec.x, y: spec.y)
            .zIndex(spec.z)
    }

    private func imageName(at index: Int) -> String {
        guard images.isEmpty == false else { return "" }
        return images[index % images.count]
    }
}

// MARK: - 02 · Quiet Slider

/// 刻度 20 · 50 · 100 · 200；拇指停在 100。无 Free/Pro 下标、无下划线。
private struct PaywallSliderVisual: View {

    private static let ticks = ["20", "50", "100", "200"]
    private static let activeIndex = 2
    private static let fillFraction: CGFloat = 2.0 / 3.0

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                ForEach(Self.ticks.indices, id: \.self) { index in
                    tick(Self.ticks[index], hot: index == Self.activeIndex)
                    if index < Self.ticks.count - 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 84)
            .padding(.top, 150)

            GeometryReader { proxy in
                let y = proxy.size.height / 2
                let x = proxy.size.width * Self.fillFraction

                Capsule()
                    .fill(Color.white.opacity(0.20))
                    .frame(height: 5)
                    .frame(maxHeight: .infinity)

                Capsule()
                    .fill(PaywallDS.Color.accent)
                    .frame(width: x, height: 5)
                    .frame(maxHeight: .infinity, alignment: .leading)

                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: PaywallDS.Color.accent.opacity(0.18), radius: 6)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 6)
                    .position(x: x, y: y)
            }
            .frame(height: 22)
            .padding(.horizontal, 84)
            .padding(.top, 28)
        }
        .frame(width: 700, height: 525, alignment: .top)
    }

    private func tick(_ value: String, hot: Bool) -> some View {
        Text(value)
            .font(.system(size: hot ? 34 : 22, weight: .bold))
            .tracking(hot ? -1.1 : -0.8)
            .monospacedDigit()
            .foregroundStyle(hot ? Color.white : Color.white.opacity(0.28))
    }
}

// MARK: - 03 · Keep + Similar Stack

/// 左 Keep、右三层相似叠；同图不同裁切，角标 3。
private struct PaywallSimilarVisual: View {

    let images: [String]

    private var hero: String { images.first ?? "PaywallLake" }

    var body: some View {
        ZStack {
            keepCard
                .position(x: 245, y: 210)

            similarStack
                .position(x: 500, y: 230)
        }
        .frame(width: 700, height: 525)
    }

    private var keepCard: some View {
        ZStack(alignment: .topLeading) {
            croppedPhoto(hero, width: 252, height: 336, radius: 16, offset: CGSize(width: -8, height: -18))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 22, y: 20)

            keepBadge
                .padding(10)
        }
        .frame(width: 252, height: 336)
    }

    private var keepBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(PaywallDS.Color.onAccent.opacity(0.55))
                .frame(width: 5, height: 5)
            Text("Keep")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PaywallDS.Color.onAccent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(PaywallDS.Color.accent))
    }

    private var similarStack: some View {
        let w: CGFloat = 200
        let h: CGFloat = 267
        return ZStack {
            croppedPhoto(hero, width: w, height: h, radius: 14, offset: CGSize(width: 28, height: -22))
                .scaleEffect(0.88)
                .rotationEffect(.degrees(8))
                .offset(x: 18, y: 16)
                .opacity(0.28)
                .saturation(0.7)
                .brightness(-0.12)

            croppedPhoto(hero, width: w, height: h, radius: 14, offset: CGSize(width: 16, height: -6))
                .scaleEffect(0.94)
                .rotationEffect(.degrees(4))
                .offset(x: 10, y: 8)
                .opacity(0.5)
                .saturation(0.78)
                .brightness(-0.08)

            ZStack(alignment: .topTrailing) {
                croppedPhoto(hero, width: w, height: h, radius: 14, offset: CGSize(width: 10, height: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.42), radius: 16, y: 14)

                Text("3")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.88))
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    )
                    .padding(8)
            }
            .rotationEffect(.degrees(1.5))
            .opacity(0.88)
            .saturation(0.9)
            .brightness(-0.04)
        }
        .frame(width: w + 40, height: h + 40)
    }
}

// MARK: - 04 · Date Wall

/// 产品日期墙缩略：奶油纸框 + 空日格 + 英文周标。无月份标题。
private struct PaywallDateWallVisual: View {

    let images: [String]

    private static let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    /// nil = blank；数字 = images 下标。4×7，与 HTML 终稿对齐。
    private static let cells: [Int?] = [
        nil, nil, 0, 1, 2, nil, 3,
        4, 5, nil, 6, 7, 8, nil,
        1, 3, 2, nil, 0, 4, 5,
        nil, 6, 8, 1, nil, 3, nil
    ]

    private static let tilts: [Double] = [-1.1, 0.7, -0.5, 1.0]

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(Self.weekdays.indices, id: \.self) { index in
                    Text(Self.weekdays[index])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 4
            ) {
                ForEach(Self.cells.indices, id: \.self) { index in
                    dayCell(Self.cells[index], index: index)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(width: 630)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 5 / 255, green: 5 / 255, blue: 5 / 255))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 28, y: 24)
        )
        .position(x: 350, y: 210)
        .frame(width: 700, height: 525)
    }

    @ViewBuilder
    private func dayCell(_ imageIndex: Int?, index: Int) -> some View {
        let tilt = Self.tilts[index % Self.tilts.count]
        if let imageIndex, images.isEmpty == false {
            Color.clear
                .aspectRatio(100 / 118, contentMode: .fit)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.boardPaperWarm)
                        .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
                }
                .overlay {
                    GeometryReader { proxy in
                        Image(images[imageIndex % images.count])
                            .resizable()
                            .scaledToFill()
                            .frame(
                                width: max(proxy.size.width - 3, 1),
                                height: max(proxy.size.height - 3, 1)
                            )
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 6.5, style: .continuous))
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                    .padding(1.5)
                }
                .rotationEffect(.degrees(tilt))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.boardBlank)
                .aspectRatio(100 / 118, contentMode: .fit)
        }
    }
}

// MARK: - 05 · Share Peek

/// Ticket / Minimal / Color 三卡同尺，轻微 yaw peek；元信息 date-only。
private struct PaywallSharePeekVisual: View {

    let images: [String]

    private var plane: String { images.indices.contains(0) ? images[0] : "PaywallPlane" }
    private var pool: String { images.indices.contains(1) ? images[1] : "PaywallPool" }
    private var lake: String { images.indices.contains(2) ? images[2] : "PaywallLake" }

    private let cardWidth: CGFloat = 210
    private let cardHeight: CGFloat = 280

    var body: some View {
        ZStack {
            ticketCard
                .rotationEffect(.degrees(-5))
                .position(x: 168, y: 210)

            colorCard
                .rotationEffect(.degrees(5))
                .position(x: 532, y: 210)

            minimalCard
                .rotationEffect(.degrees(0))
                .zIndex(2)
                .position(x: 350, y: 200)
        }
        .frame(width: 700, height: 525)
    }

    private var ticketCard: some View {
        ZStack(alignment: .top) {
            Color(red: 133 / 255, green: 81 / 255, blue: 67 / 255)

            VStack(spacing: 0) {
                photo(plane, width: 168, height: 168, radius: 4)
                    .padding(.top, 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT STATION")
                        .font(.system(size: 7, weight: .medium))
                        .tracking(0.4)
                        .foregroundStyle(Color.black.opacity(0.55))
                    Text("2026.10.07")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color(red: 22 / 255, green: 17 / 255, blue: 15 / 255))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer(minLength: 0)

                Text("Poca")
                    .font(.custom("Snell Roundhand", size: 14))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 14)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 12)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 18, y: 18)
    }

    private var minimalCard: some View {
        VStack(spacing: 0) {
            photo(pool, width: cardWidth - 16, height: cardHeight - 52, radius: 3)
                .padding(.top, 8)

            HStack {
                Text("October 7, 2026")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 106 / 255, green: 106 / 255, blue: 112 / 255))
                    .monospacedDigit()
                Spacer(minLength: 0)
                Text("Poca")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 13 / 255, green: 14 / 255, blue: 16 / 255))
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color(red: 244 / 255, green: 245 / 255, blue: 247 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.55), radius: 22, y: 20)
    }

    private var colorCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("POCA COLOR")
                    .font(.custom("AmericanTypewriter-CondensedBold", size: 13))
                    .tracking(0.6)
                Text("October 7, 2026")
                    .font(.custom("AmericanTypewriter-Condensed", size: 9))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight * 0.42)
            .background(Color(red: 49 / 255, green: 75 / 255, blue: 1 / 255))

            photo(lake, width: cardWidth, height: cardHeight * 0.58, radius: 0)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 18, y: 18)
    }
}

// MARK: - Slide Model

private struct PaywallBenefitSlide {
    enum Visual {
        case fan
        case slider
        case categories
        case board
        case share
    }

    let title: String
    let subtitle: String
    let visual: Visual
    let images: [String]

    /// 5 条 Pro 权益：Quiet Keep 画面 + 底部文案。
    static let all: [PaywallBenefitSlide] = [
        PaywallBenefitSlide(
            title: L10n.string("Unlimited cleanup"),
            subtitle: L10n.string("Clean as much as you want. No daily limit."),
            visual: .fan,
            images: ["PaywallCatOrange", "PaywallPool", "PaywallBeach", "PaywallLake", "PaywallFood"]
        ),
        PaywallBenefitSlide(
            title: L10n.string("Bigger review rounds"),
            subtitle: L10n.string("Choose up to 200 photos per round."),
            visual: .slider,
            images: []
        ),
        PaywallBenefitSlide(
            title: L10n.string("All similar groups"),
            subtitle: L10n.string("Keep the best shot, clear the rest"),
            visual: .categories,
            images: ["PaywallLake"]
        ),
        PaywallBenefitSlide(
            title: L10n.string("Your photo history"),
            subtitle: L10n.string("Revisit every photo left from each cleanup."),
            visual: .board,
            images: [
                "PaywallPlane", "PaywallBeach", "PaywallPool", "PaywallLake",
                "PaywallCatOrange", "PaywallFood", "PaywallCove", "PaywallCatGray",
                "PaywallShareBarcelona"
            ]
        ),
        PaywallBenefitSlide(
            title: L10n.string("Every share style"),
            subtitle: L10n.string("Make every card unmistakably yours."),
            visual: .share,
            images: ["PaywallPlane", "PaywallPool", "PaywallLake"]
        )
    ]
}

// MARK: - Photo Helper

private func photo(
    _ name: String,
    width: CGFloat,
    height: CGFloat,
    radius: CGFloat
) -> some View {
    Image(name)
        .resizable()
        .scaledToFill()
        .frame(width: width, height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
}

/// 同图不同裁切：放大后偏移，模拟相似组里略有差别的两张。
private func croppedPhoto(
    _ name: String,
    width: CGFloat,
    height: CGFloat,
    radius: CGFloat,
    offset: CGSize
) -> some View {
    Image(name)
        .resizable()
        .scaledToFill()
        .frame(width: width * 1.28, height: height * 1.28)
        .offset(offset)
        .frame(width: width, height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
}

// MARK: - Plan Section

/// 套餐横排。选中项交回父级（Footer 的 CTA 要用），埋点与清错误由父级在 onSelect 里处理。
struct PaywallPlanSection: View {

    let plans: [PaywallPlan]
    let pricing: PaywallPricing
    @Binding var selectedType: PaywallPlanType
    let isTrialEligible: Bool
    let trialDayCount: Int?
    let onSelect: (PaywallPlanType) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(plans) { plan in
                        planCard(plan)
                            .id(plan.type)
                    }
                }
                .padding(.vertical, 2)
            }
            .contentMargins(.horizontal, PaywallLayout.pageHorizontalPadding, for: .scrollContent)
            .paywallScrollEdgeFade()
            .onChange(of: selectedType) { _, newValue in
                guard plans.contains(where: { $0.type == newValue }) else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func planCard(_ plan: PaywallPlan) -> some View {
        let isSelected = selectedType == plan.type
        let display = pricing.display(for: plan.type)
        let trialText = pricing.planTrialText(
            for: plan.type,
            isTrialEligible: isTrialEligible,
            trialDayCount: trialDayCount
        )
        let noteText = pricing.planNoteText(
            for: plan.type,
            isTrialEligible: isTrialEligible
        )

        return Button {
            select(plan.type)
        } label: {
            planCardLabel(
                plan: plan,
                isSelected: isSelected,
                display: display,
                trialText: trialText,
                noteText: noteText
            )
        }
        .buttonStyle(PaywallPressStyle())
        .accessibilityLabel(Text(plan.name))
        .accessibilityValue(Text("\(display.priceText), \(trialText)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall-plan-\(plan.type.accessibilitySlug)")
    }

    private func planCardLabel(
        plan: PaywallPlan,
        isSelected: Bool,
        display: PlanDisplayPricing,
        trialText: String,
        noteText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            planNameRow(plan: plan, isSelected: isSelected)

            planPriceRow(plan: plan, display: display)
                .padding(.top, 9)

            Text(trialText)
                .font(PaywallDS.Font.skuTrial)
                .foregroundStyle(isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 7)

            Spacer(minLength: 8)

            Text(noteText)
                .font(PaywallDS.Font.skuNote)
                .foregroundStyle(isSelected ? Color.white.opacity(0.48) : Color.white.opacity(0.42))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        // 默认字号下仍是 148pt 的等高卡；Dynamic Type 放大时允许向下生长，不截断。
        .frame(width: 240, alignment: .topLeading)
        .frame(minHeight: 148, alignment: .topLeading)
        .background(cardBackground(isSelected: isSelected))
        .overlay(cardBorder(isSelected: isSelected))
        .shadow(
            color: isSelected ? PaywallDS.Color.planCardShadow : .clear,
            radius: 24,
            y: 10
        )
    }

    private func planNameRow(plan: PaywallPlan, isSelected: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(plan.name)
                .font(PaywallDS.Font.skuName)
                .tracking(0.05)
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            if let badge = badgeText(for: plan.type) {
                Text(badge)
                    .font(PaywallDS.Font.badge)
                    .tracking(0.2)
                    .foregroundStyle(PaywallDS.Color.recommendedBadgeText)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [PaywallDS.Color.accent, PaywallDS.Color.accentDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
            }
        }
    }

    private func planPriceRow(plan: PaywallPlan, display: PlanDisplayPricing) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(display.priceText)
                .font(PaywallDS.Font.skuPrice)
                .tracking(-1.35)
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if plan.type != .lifetime {
                Text(plan.priceCaption)
                    .font(PaywallDS.Font.skuUnit)
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(1)
            }
        }
    }

    /// 年订卡右上角的「早鸟价」胶囊。月订 / 买断不挂徽章。
    private func badgeText(for type: PaywallPlanType) -> String? {
        type == .yearly ? L10n.string("Early bird price") : nil
    }

    private func select(_ type: PaywallPlanType) {
        guard type != selectedType else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
        onSelect(type)

        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            selectedType = type
        }
    }

    @ViewBuilder
    private func cardBackground(isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: PaywallDS.Radius.card, style: .continuous)

        if isSelected {
            shape
                .fill(PaywallDS.Gradient.planSelectedFill)
                .overlay {
                    // 对应 CSS 的 radial-gradient(120% 100% at 18% 0%, white .18, transparent 55%)
                    EllipticalGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.18), location: 0),
                            .init(color: .clear, location: 1)
                        ],
                        center: UnitPoint(x: 0.18, y: 0),
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.62
                    )
                    .clipShape(shape)
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(PaywallDS.Color.planSelectedTopInner)
                        .frame(height: 1)
                        .padding(.horizontal, 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(PaywallDS.Color.planSelectedBottomInner)
                        .frame(height: 1)
                        .padding(.horizontal, 1)
                }
                .clipShape(shape)
        } else {
            shape.fill(
                LinearGradient(
                    colors: [PaywallDS.Color.planCardFillTop, PaywallDS.Color.planCardFillBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    @ViewBuilder
    private func cardBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: PaywallDS.Radius.card, style: .continuous)
            .stroke(
                isSelected ? PaywallDS.Color.planSelectedBorder : PaywallDS.Color.planCardBorder,
                lineWidth: 1
            )
    }
}

// MARK: - Horizontal Scroll Edge Fade

/// iOS 26 用系统软边（渐进模糊）；更低版本退化为 16–18pt 的透明渐变蒙版。
private struct PaywallScrollEdgeFade: ViewModifier {
    private var mask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.045),
                .init(color: .black, location: 0.955),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .scrollEdgeEffectStyle(.soft, for: .horizontal)
                .mask(mask)
        } else {
            content.mask(mask)
        }
    }
}

extension View {
    func paywallScrollEdgeFade() -> some View {
        modifier(PaywallScrollEdgeFade())
    }
}

// MARK: - Footer

/// 固定在底部的购买区。纯展示组件：所有文案由外部算好传入，
/// 因此它不需要知道试用规则，也能脱离 StoreKit 预览。
struct PaywallFooter: View {

    /// 为 nil 时不渲染购买按钮，只保留错误提示与安全声明
    struct CTA {
        let title: String
        let isLoading: Bool
        let isEnabled: Bool
        let action: () -> Void
    }

    let cta: CTA?
    let errorMessage: String?
    /// 续订 / 试用后价格说明。放在 CTA 正下方，保证购买前能看到。
    let subline: String?

    var body: some View {
        VStack(spacing: 10) {
            if let cta {
                purchaseButton(cta)
            }

            if let subline {
                Text(subline)
                    .font(PaywallDS.Font.trust)
                    .foregroundStyle(PaywallDS.Color.textSecondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(PaywallDS.Font.caption2Medium)
                    .foregroundStyle(PaywallDS.Color.errorText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(
            EdgeInsets(
                top: 16,
                leading: PaywallLayout.footerCardHorizontalPadding,
                bottom: 16,
                trailing: PaywallLayout.footerCardHorizontalPadding
            )
        )
        .paywallGlassCard(radius: PaywallDS.Radius.floatingCard)
        .padding(
            EdgeInsets(
                top: 0,
                leading: PaywallDS.Space.xl,
                bottom: PaywallDS.Space.sm,
                trailing: PaywallDS.Space.xl
            )
        )
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    private func purchaseButton(_ cta: CTA) -> some View {
        Button(action: cta.action) {
            ZStack {
                if cta.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(PaywallDS.Color.ctaButtonText)
                } else {
                    Text(cta.title)
                        .font(PaywallDS.Font.cta)
                        .foregroundStyle(PaywallDS.Color.ctaButtonText)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: PaywallDS.Radius.chip, style: .continuous)
                    .fill(PaywallDS.Color.ctaButtonFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: PaywallDS.Radius.chip, style: .continuous)
                            .stroke(PaywallDS.Color.ctaButtonBorder, lineWidth: 1)
                    )
            )
            .shadow(color: PaywallDS.Color.ctaButtonShadow, radius: 16, y: 6)
        }
        .buttonStyle(PaywallPressStyle())
        .opacity(cta.isEnabled ? 1 : 0.5)
        .disabled(cta.isEnabled == false)
        .accessibilityLabel(Text(cta.title))
        .accessibilityIdentifier("paywall-unlock-cta")
    }
}

// MARK: - 套餐标识

extension SubscriptionManager.SubscriptionType {
    /// 用于 UI 测试的 accessibility identifier 片段
    var accessibilitySlug: String {
        switch self {
        case .monthly: return "monthly"
        case .yearly: return "yearly"
        case .lifetime: return "lifetime"
        }
    }
}
