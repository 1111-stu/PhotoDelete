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

/// 五张权益轮播，画面按 `carousel-slides.html` 的 700×680 版复刻：
/// 五张照片扇形、20→200 滑杆、专项分类圆、相纸板、四张分享卡。
/// 整张画布等比缩进 340pt 的卡片，文案随画布一起缩放。
struct PaywallBenefitCarousel: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var isDragging = false

    private let slides = PaywallBenefitSlide.all
    private static let autoPlayInterval: Duration = .seconds(4.8)
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
            .task(id: AutoPlayKey(index: index, isDragging: isDragging)) {
                await autoAdvance()
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
                ForEach(Array(slides.enumerated()), id: \.offset) { offset, slide in
                    PaywallReviewSlide(slide: slide)
                        .frame(width: Self.designSize.width, height: Self.designSize.height)
                        .scaleEffect(scale, anchor: .bottom)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                        .opacity(offset == index ? 1 : 0)
                        .allowsHitTesting(false)
                }
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.38), value: index)
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

    struct AutoPlayKey: Hashable {
        let index: Int
        let isDragging: Bool
    }

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { _ in
                if isDragging == false {
                    isDragging = true
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                if abs(dx) > 42 {
                    go(to: index + (dx < 0 ? 1 : -1))
                }
                isDragging = false
            }
    }

    func go(to target: Int) {
        let count = slides.count
        guard count > 0 else { return }
        let next = ((target % count) + count) % count
        guard next != index else { return }

        if reduceMotion {
            index = next
        } else {
            withAnimation(.easeInOut(duration: 0.38)) {
                index = next
            }
        }
    }

    func autoAdvance() async {
        guard reduceMotion == false,
              isDragging == false,
              UIAccessibility.isVoiceOverRunning == false else {
            return
        }

        try? await Task.sleep(for: Self.autoPlayInterval)
        guard Task.isCancelled == false,
              UIAccessibility.isVoiceOverRunning == false else {
            return
        }
        go(to: index + 1)
    }

    var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(slides.indices, id: \.self) { offset in
                Circle()
                    .fill(offset == index ? Color.white : Color.white.opacity(0.26))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(height: 28)
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

/// 700×680 的轮播画布，和 `carousel-slides.html` 一一对应。
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
            PaywallCategoryVisual()
        case .board:
            PaywallBoardVisual(images: slide.images)
        case .share:
            PaywallShareFanVisual(images: slide.images)
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

// MARK: - 01 · Photo Fan

private struct PaywallFanVisual: View {

    let images: [String]

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [PaywallDS.Color.accent.opacity(0.07), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .position(x: 350, y: 178)
                .blur(radius: 8)

            if images.count >= 5 {
                framedPhoto(images[0], width: 160, height: 220, radius: 22)
                    .saturation(0.72)
                    .opacity(0.38)
                    .blur(radius: 1.4)
                    .rotationEffect(.degrees(-13))
                    .shadow(color: .black.opacity(0.62), radius: 32, y: 30)
                    .position(x: 92, y: 212)

                framedPhoto(images[1], width: 215, height: 285, radius: 22)
                    .saturation(0.88)
                    .opacity(0.72)
                    .blur(radius: 0.4)
                    .rotationEffect(.degrees(-7))
                    .shadow(color: .black.opacity(0.62), radius: 32, y: 30)
                    .position(x: 193.5, y: 212.5)

                framedPhoto(images[2], width: 260, height: 340, radius: 22)
                    .shadow(color: .black.opacity(0.62), radius: 32, y: 30)
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 8)
                    .position(x: 350, y: 196)

                framedPhoto(images[3], width: 215, height: 285, radius: 22)
                    .saturation(0.88)
                    .opacity(0.72)
                    .blur(radius: 0.4)
                    .rotationEffect(.degrees(7))
                    .shadow(color: .black.opacity(0.62), radius: 32, y: 30)
                    .position(x: 506.5, y: 212.5)

                framedPhoto(images[4], width: 160, height: 220, radius: 22)
                    .saturation(0.72)
                    .opacity(0.38)
                    .blur(radius: 1.4)
                    .rotationEffect(.degrees(13))
                    .shadow(color: .black.opacity(0.62), radius: 32, y: 30)
                    .position(x: 608, y: 212)
            }
        }
        .frame(width: 700, height: 525)
    }

    private func framedPhoto(
        _ name: String,
        width: CGFloat,
        height: CGFloat,
        radius: CGFloat
    ) -> some View {
        photo(name, width: width, height: height, radius: radius)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - 02 · 20 → 200 Slider

private struct PaywallSliderVisual: View {

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                tick("20")
                Spacer(minLength: 0)
                tick("50")
                Spacer(minLength: 0)
                tick("100")
                Spacer(minLength: 0)
                selectedTick
            }
            .padding(.horizontal, 84)
            .padding(.top, 112)

            ZStack(alignment: .trailing) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 8)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                PaywallDS.Color.accent.opacity(0.22),
                                PaywallDS.Color.accent
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 8)

                Circle()
                    .fill(PaywallDS.Color.accent)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                    .shadow(color: PaywallDS.Color.accent.opacity(0.5), radius: 21)
                    .offset(x: 22)
            }
            .frame(height: 44)
            .padding(.horizontal, 84)
            .padding(.top, 76)

            HStack {
                Text(L10n.string("Free 20"))
                Spacer(minLength: 0)
                Text(L10n.string("Pro 200"))
            }
            .font(.system(size: 20))
            .foregroundStyle(Color.white.opacity(0.36))
            .padding(.horizontal, 84)
            .padding(.top, 26)
        }
        .frame(width: 700, height: 525, alignment: .top)
    }

    private func tick(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 34, weight: .bold))
            .tracking(-1)
            .foregroundStyle(Color.white.opacity(0.3))
            .monospacedDigit()
    }

    private var selectedTick: some View {
        Text("200")
            .font(.system(size: 38, weight: .bold))
            .tracking(-1.1)
            .monospacedDigit()
            .foregroundStyle(PaywallDS.Color.onAccent)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [
                            Color(red: 248 / 255, green: 203 / 255, blue: 109 / 255),
                            PaywallDS.Color.accentDeep
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.55), lineWidth: 1))
            .shadow(color: PaywallDS.Color.accent.opacity(0.3), radius: 22)
    }
}

// MARK: - 03 · Category Circles

private struct PaywallCategoryVisual: View {

    var body: some View {
        VStack(spacing: 58) {
            HStack(spacing: 24) {
                item(icon: "square.on.square", label: "Similar category", highlighted: true)
                item(icon: "viewfinder", label: "Screenshots category")
                item(icon: "play.rectangle", label: "Videos category")
                item(icon: "livephoto", label: "Live Photos category")
                item(icon: "square.stack", label: "Bursts category")
            }

            pill
        }
        .frame(width: 700, height: 500)
        .offset(y: -38)
    }

    private func item(
        icon: String,
        label: String,
        highlighted: Bool = false
    ) -> some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 94 / 255, green: 96 / 255, blue: 104 / 255).opacity(0.55),
                                Color(red: 28 / 255, green: 30 / 255, blue: 36 / 255).opacity(0.9)
                            ],
                            center: UnitPoint(x: 0.3, y: 0.25),
                            startRadius: 0,
                            endRadius: 96
                        )
                    )

                Circle()
                    .stroke(
                        highlighted
                            ? PaywallDS.Color.accent.opacity(0.55)
                            : Color.white.opacity(0.18),
                        lineWidth: 1
                    )

                Image(systemName: icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.white)
            }
            .frame(width: 96, height: 96)
            .shadow(
                color: highlighted
                    ? PaywallDS.Color.accent.opacity(0.22)
                    : Color.black.opacity(0.35),
                radius: highlighted ? 18 : 13,
                y: 12
            )

            Text(L10n.key(label))
                .font(.system(size: 18))
                .foregroundStyle(Color.white.opacity(0.52))
                .fixedSize()
        }
    }

    private var pill: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(PaywallDS.Color.accent)
                .frame(width: 6, height: 6)

            HStack(spacing: 4) {
                Text("Pro")
                    .fontWeight(.semibold)
                    .foregroundStyle(PaywallDS.Color.accent)

                Text(L10n.string("unlocks every category"))
                    .foregroundStyle(Color.white.opacity(0.62))
            }
            .font(.system(size: 22))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 13)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}

// MARK: - 04 · Polaroid Board

private struct PaywallBoardVisual: View {

    let images: [String]

    private struct Layout {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let angle: Double
    }

    private static let layouts: [Layout] = [
        Layout(x: 36, y: 60, width: 148, height: 184, angle: -6),
        Layout(x: 172, y: 44, width: 158, height: 196, angle: 3),
        Layout(x: 330, y: 70, width: 144, height: 180, angle: -3),
        Layout(x: 430, y: 52, width: 156, height: 194, angle: 5),
        Layout(x: 78, y: 240, width: 148, height: 184, angle: 4),
        Layout(x: 228, y: 228, width: 158, height: 196, angle: -5),
        Layout(x: 392, y: 244, width: 144, height: 180, angle: 2)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            boardBackground

            ForEach(Array(images.prefix(Self.layouts.count).enumerated()), id: \.offset) { offset, name in
                polaroid(name, layout: Self.layouts[offset], index: offset)
            }
        }
        .frame(width: 600, height: 424)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            Text("2026")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Color(red: 244 / 255, green: 244 / 255, blue: 246 / 255))
                .padding(.top, 18)
                .padding(.leading, 24)
        }
        .shadow(color: .black.opacity(0.55), radius: 30, y: 24)
        .scaleEffect(0.84)
        .position(x: 350, y: 186)
    }

    private var boardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 29 / 255, green: 26 / 255, blue: 22 / 255),
                    Color(red: 14 / 255, green: 13 / 255, blue: 11 / 255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [PaywallDS.Color.accent.opacity(0.09), .clear],
                center: UnitPoint(x: 0.18, y: 0),
                startRadius: 0,
                endRadius: 300
            )
        }
    }

    private func polaroid(_ name: String, layout: Layout, index: Int) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(red: 243 / 255, green: 238 / 255, blue: 226 / 255))
                .shadow(color: .black.opacity(0.42), radius: 15, y: 16)

            photo(
                name,
                width: layout.width - 16,
                height: layout.height - 32,
                radius: 1
            )
            .padding(.top, 8)

            clip(index: index)
                .offset(y: -7)
        }
        .frame(width: layout.width, height: layout.height)
        .rotationEffect(.degrees(layout.angle))
        .position(
            x: layout.x + layout.width / 2,
            y: layout.y + layout.height / 2
        )
    }

    private func clip(index: Int) -> some View {
        let colors: [Color]
        switch index % 3 {
        case 0:
            colors = [
                Color(red: 216 / 255, green: 185 / 255, blue: 138 / 255),
                Color(red: 168 / 255, green: 135 / 255, blue: 92 / 255)
            ]
        case 1:
            colors = [
                Color(red: 201 / 255, green: 166 / 255, blue: 120 / 255),
                Color(red: 150 / 255, green: 118 / 255, blue: 76 / 255)
            ]
        default:
            colors = [
                Color(red: 224 / 255, green: 195 / 255, blue: 154 / 255),
                Color(red: 179 / 255, green: 146 / 255, blue: 95 / 255)
            ]
        }

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .frame(width: 18, height: 13)
            .overlay {
                Rectangle()
                    .fill(Color(red: 60 / 255, green: 40 / 255, blue: 20 / 255).opacity(0.35))
                    .frame(width: 14, height: 0.5)
                    .offset(y: 1)
            }
            .rotationEffect(.degrees(-3))
            .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
    }
}

// MARK: - 05 · Share Card Fan

private struct PaywallShareFanVisual: View {

    let images: [String]

    private var barcelona: String { images.first ?? "PaywallShareBarcelona" }
    private var window: String { images.count > 1 ? images[1] : barcelona }

    var body: some View {
        ZStack {
            originalCard
            minimalFrameCard
            ticketStubCard
            pocaColorCard
        }
        .frame(width: 700, height: 525)
    }

    private var originalCard: some View {
        ZStack {
            Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
            photo(barcelona, width: 180, height: 250, radius: 4)
        }
        .frame(width: 180, height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .opacity(0.4)
        .blur(radius: 1.2)
        .saturation(0.75)
        .rotationEffect(.degrees(-14))
        .position(x: 122, y: 237)
    }

    private var minimalFrameCard: some View {
        VStack(spacing: 0) {
            photo(barcelona, width: 176, height: 232, radius: 1.5)

            VStack(alignment: .leading, spacing: 3) {
                Text("October 7, 2026")
                    .font(.system(size: 5.2))
                    .foregroundStyle(Color(red: 106 / 255, green: 106 / 255, blue: 112 / 255))
                    .monospacedDigit()

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("巴塞罗那·海岸")
                        .font(.system(size: 7.4, weight: .semibold))
                        .foregroundStyle(Color(red: 13 / 255, green: 14 / 255, blue: 16 / 255))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("Poca")
                        .font(.system(size: 7.1, weight: .semibold))
                        .foregroundStyle(Color(red: 13 / 255, green: 14 / 255, blue: 16 / 255))
                }
            }
            .padding(.top, 9)
            .padding(.horizontal, 3)
            .frame(height: 45, alignment: .top)
        }
        .padding(7)
        .frame(width: 190, height: 291)
        .background(Color(red: 244 / 255, green: 245 / 255, blue: 247 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: .black.opacity(0.62), radius: 25, y: 22)
        .rotationEffect(.degrees(-7))
        .position(x: 191, y: 229.5)
    }

    private var ticketStubCard: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 133 / 255, green: 81 / 255, blue: 67 / 255)

            ticket
                .offset(x: 45, y: 39)

            Text("Poca")
                .font(.custom("Snell Roundhand", size: 8))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 10)
                .padding(.bottom, 8)
        }
        .frame(width: 210, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: .black.opacity(0.62), radius: 25, y: 22)
        .rotationEffect(.degrees(7))
        .position(x: 539, y: 224)
    }

    private var ticket: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white)

            photo(window, width: 112, height: 145, radius: 3)
                .offset(x: 3.7, y: 3.7)

            Rectangle()
                .fill(Color(red: 184 / 255, green: 125 / 255, blue: 109 / 255))
                .frame(width: 119, height: 48)
                .offset(y: 153)

            dottedLine(width: 119, dash: [4, 3], lineWidth: 1.2, color: .black.opacity(0.5))
                .offset(y: 153)

            stubText
                .offset(x: 10, y: 5)

            barcode
                .offset(x: 95, y: 157)

            Circle()
                .fill(Color(red: 133 / 255, green: 81 / 255, blue: 67 / 255))
                .frame(width: 7, height: 7)
                .offset(x: -3.5, y: 149.5)

            Circle()
                .fill(Color(red: 133 / 255, green: 81 / 255, blue: 67 / 255))
                .frame(width: 7, height: 7)
                .offset(x: 115.5, y: 149.5)
        }
        .frame(width: 119, height: 201)
    }

    private var stubText: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NEXT STATION")
                .font(.system(size: 3.5, weight: .medium))
                .tracking(0.3)
                .foregroundStyle(Color(red: 22 / 255, green: 17 / 255, blue: 15 / 255).opacity(0.72))

            Text("东京·羽田")
                .font(.system(size: 7, weight: .bold))
                .tracking(-0.07)
                .foregroundStyle(Color(red: 22 / 255, green: 17 / 255, blue: 15 / 255))
                .padding(.top, 2)

            dottedLine(width: 72, dash: [2, 2], lineWidth: 0.5, color: .black.opacity(0.5))
                .padding(.top, 14)

            HStack(spacing: 12) {
                smallColumn(label: "YEAR", value: "2026")
                smallColumn(label: "DATE", value: "10.07")
            }
            .padding(.top, 5)
        }
    }

    private func smallColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 3, weight: .medium))
                .tracking(0.42)
                .foregroundStyle(Color(red: 22 / 255, green: 17 / 255, blue: 15 / 255).opacity(0.72))

            Text(value)
                .font(.system(size: 5, weight: .bold))
                .foregroundStyle(Color(red: 22 / 255, green: 17 / 255, blue: 15 / 255))
                .monospacedDigit()
        }
    }

    private var barcode: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(.white)

            HStack(spacing: 1) {
                ForEach(Array([2.0, 1.0, 2.0, 1.0, 3.0, 1.0, 2.0].enumerated()), id: \.offset) { _, barWidth in
                    Rectangle()
                        .fill(.black)
                        .frame(width: barWidth, height: 28)
                }
            }
            .padding(.top, 2)
        }
        .frame(width: 18, height: 37)
    }

    private var pocaColorCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("POCA COLOR")
                    .font(.custom("AmericanTypewriter-CondensedBold", size: 10.7))
                    .tracking(0.5)

                Text("October 7, 2026")
                    .font(.custom("AmericanTypewriter-Condensed", size: 6.1))
                    .padding(.top, 4)

                Text("巴塞罗那·海岸")
                    .font(.custom("AmericanTypewriter-Condensed", size: 5.4))
                    .opacity(0.88)
                    .padding(.top, 2)
            }
            .foregroundStyle(.white)
            .frame(width: 230, height: 153.5)
            .background(Color(red: 49 / 255, green: 75 / 255, blue: 1 / 255))

            photo(barcelona, width: 230, height: 153.5, radius: 0)
        }
        .frame(width: 230, height: 307)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: .black.opacity(0.62), radius: 25, y: 22)
        .position(x: 350, y: 201.5)
    }

    private func dottedLine(
        width: CGFloat,
        dash: [CGFloat],
        lineWidth: CGFloat,
        color: Color
    ) -> some View {
        Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: width, y: 0))
        }
        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, dash: dash))
        .frame(width: width, height: lineWidth)
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

    static let all: [PaywallBenefitSlide] = [
        PaywallBenefitSlide(
            title: L10n.string("Unlimited cleanup"),
            subtitle: L10n.string("Free clears 100 photos a day. Pro has no limit."),
            visual: .fan,
            images: ["PaywallKyoto", "PaywallCove", "PaywallPlane", "PaywallBeach", "PaywallRoad"]
        ),
        PaywallBenefitSlide(
            title: L10n.string("Random Review"),
            subtitle: L10n.string("200 per round, up from 20."),
            visual: .slider,
            images: []
        ),
        PaywallBenefitSlide(
            title: L10n.string("Special categories"),
            subtitle: L10n.string("Screenshots, videos, Live Photos and more — all unlocked with Pro."),
            visual: .categories,
            images: []
        ),
        PaywallBenefitSlide(
            title: L10n.string("Photo wall & history"),
            subtitle: L10n.string("Revisit every photo left from each cleanup."),
            visual: .board,
            images: ["PaywallPlane", "PaywallBeach", "PaywallKyoto", "PaywallCove", "PaywallRoad", "PaywallPool", "PaywallFood"]
        ),
        PaywallBenefitSlide(
            title: L10n.string("Share card styles"),
            subtitle: L10n.string("Original and Minimal Frame are free. Two more unlock."),
            visual: .share,
            images: ["PaywallShareBarcelona", "PaywallShareWindow"]
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
                HStack(spacing: 10) {
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
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    Text(plan.name)
                        .font(PaywallDS.Font.skuName)
                        .tracking(0.05)
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.58))
                        .lineLimit(1)

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

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(display.priceText)
                        .font(PaywallDS.Font.skuPrice)
                        .tracking(-1.35)
                        .monospacedDigit()
                        .foregroundStyle(Color.white)

                    if plan.type != .lifetime {
                        Text(plan.priceCaption)
                            .font(PaywallDS.Font.skuUnit)
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                }
                .padding(.top, 9)

                Text(trialText)
                    .font(PaywallDS.Font.skuTrial)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.46))
                    .lineLimit(1)
                    .padding(.top, 7)

                Spacer(minLength: 8)

                Text(noteText)
                    .font(PaywallDS.Font.skuNote)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.48) : Color.white.opacity(0.42))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(14)
            .frame(width: 240, height: 148, alignment: .topLeading)
            .background(cardBackground(isSelected: isSelected))
            .overlay(cardBorder(isSelected: isSelected))
            .shadow(
                color: isSelected ? PaywallDS.Color.planCardShadow : .clear,
                radius: 24,
                y: 10
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(plan.name))
        .accessibilityValue(Text("\(display.priceText), \(trialText)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall-plan-\(plan.type.accessibilitySlug)")
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

    var body: some View {
        VStack(spacing: 12) {
            if let cta {
                purchaseButton(cta)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(PaywallDS.Font.caption2Medium)
                    .foregroundStyle(PaywallDS.Color.errorText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            trustRow
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
            .frame(height: 56)
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
        .buttonStyle(.plain)
        .opacity(cta.isEnabled ? 1 : 0.5)
        .disabled(cta.isEnabled == false)
        .accessibilityLabel(Text(cta.title))
        .accessibilityIdentifier("paywall-unlock-cta")
    }

    private var trustRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock")
                .font(.system(size: 11, weight: .semibold))
                .accessibilityHidden(true)

            Text(L10n.string("Apple Pay · Cancel anytime"))
                .font(PaywallDS.Font.trust)
        }
        .foregroundStyle(PaywallDS.Color.textSecondary.opacity(0.8))
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
