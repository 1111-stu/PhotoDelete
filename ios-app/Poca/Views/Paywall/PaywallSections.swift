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

/// 五张权益轮播，画布 700×525（4:3），对应 5 条 Pro 权益：
/// 无限清理、随机 200、相似组/专项分类、照片墙历史、分享卡样式。
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
            PaywallRoundVisual(images: slide.images)
        case .categories:
            PaywallCategoryVisual(images: slide.images)
        case .board:
            PaywallFilmStripVisual(images: slide.images)
        case .share:
            PaywallShareLineupVisual(images: slide.images)
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

/// 9 张照片的深扇形：中间最大最清晰，向两侧逐级缩小、变暗、虚化。
/// 比 5 张更能表达“无限量”，同时保留一个明确的视觉中心。
private struct PaywallFanVisual: View {

    let images: [String]

    private struct Spec {
        let angle: Double
        let width: CGFloat
        let opacity: Double
        let blur: CGFloat
        let saturation: Double
    }

    private static let specs: [Spec] = [
        Spec(angle: -28, width: 185, opacity: 0.16, blur: 2.4, saturation: 0.60),
        Spec(angle: -21, width: 205, opacity: 0.32, blur: 1.6, saturation: 0.72),
        Spec(angle: -14, width: 225, opacity: 0.55, blur: 0.9, saturation: 0.85),
        Spec(angle: -7, width: 245, opacity: 0.78, blur: 0.35, saturation: 0.94),
        Spec(angle: 0, width: 260, opacity: 1.0, blur: 0, saturation: 1.0),
        Spec(angle: 7, width: 245, opacity: 0.78, blur: 0.35, saturation: 0.94),
        Spec(angle: 14, width: 225, opacity: 0.55, blur: 0.9, saturation: 0.85),
        Spec(angle: 21, width: 205, opacity: 0.32, blur: 1.6, saturation: 0.72),
        Spec(angle: 28, width: 185, opacity: 0.16, blur: 2.4, saturation: 0.60)
    ]

    /// 从外到内绘制，中心最后压在最上层。
    private static let drawOrder = [0, 8, 1, 7, 2, 6, 3, 5, 4]

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [PaywallDS.Color.accent.opacity(0.10), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 210
                    )
                )
                .frame(width: 420, height: 420)
                .position(x: 350, y: 190)
                .blur(radius: 14)

            ForEach(Self.drawOrder, id: \.self) { index in
                card(at: index)
            }
        }
        .frame(width: 700, height: 525)
    }

    private func card(at index: Int) -> some View {
        let spec = Self.specs[index]
        let radians = spec.angle * .pi / 180
        let centerX = 350 + CGFloat(sin(radians)) * 280
        let centerY = 470 - CGFloat(cos(radians)) * 280
        let height = spec.width * 1.307
        let name = images.isEmpty ? "" : images[index % images.count]

        return framedPhoto(name, width: spec.width, height: height, radius: 22)
            .saturation(spec.saturation)
            .opacity(spec.opacity)
            .blur(radius: spec.blur)
            .shadow(color: .black.opacity(0.62), radius: 32, y: 30)
            .rotationEffect(.degrees(spec.angle))
            .position(x: centerX, y: centerY)
            .zIndex(Double(10 - abs(index - 4)))
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

// MARK: - 02 · Round Contact Sheet

/// 一轮最多 200 张：把照片做成接触印样，数字直接压在图面上。
/// 这一页只讲 Pro 的结果，不再出现免费额度刻度。
private struct PaywallRoundVisual: View {

    let images: [String]

    private static let columns = 8
    private static let rows = 4

    var body: some View {
        ZStack {
            sheet

            VStack(spacing: 10) {
                Text("PHOTOS / ROUND")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(4)
                    .foregroundStyle(Color.white.opacity(0.55))

                Text("200")
                    .font(.system(size: 184, weight: .bold))
                    .tracking(-10)
                    .monospacedDigit()
                    .foregroundStyle(PaywallDS.Color.accent)
                    .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
            }
            .offset(y: -58)
        }
        .frame(width: 700, height: 525)
    }

    private var sheet: some View {
        let cellCount = Self.columns * Self.rows
        return ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(red: 17 / 255, green: 16 / 255, blue: 14 / 255))

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(66), spacing: 6), count: Self.columns),
                spacing: 6
            ) {
                ForEach(0..<cellCount, id: \.self) { index in
                    cell(at: index)
                }
            }
            .frame(width: 570, height: 282)

            RadialGradient(
                colors: [
                    Color.black.opacity(0.88),
                    Color.black.opacity(0.72),
                    Color.black.opacity(0.25),
                    Color.clear
                ],
                center: .center,
                startRadius: 30,
                endRadius: 280
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .frame(width: 600, height: 330)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .rotationEffect(.degrees(-2))
        .position(x: 350, y: 177)
        .shadow(color: .black.opacity(0.6), radius: 34, y: 24)
    }

    private func cell(at index: Int) -> some View {
        let name = images.isEmpty ? "" : images[(index * 5 + 3) % images.count]
        return photo(name, width: 66, height: 66, radius: 5)
    }
}

// MARK: - 03 · Category Stacks

/// 五组照片堆，每组三张；首组用琥珀描边点亮。
/// 照片本身就是分类的证据，图标只做角标。
private struct PaywallCategoryVisual: View {

    let images: [String]

    private struct Category {
        let icon: String
        let label: String
        let imageIndex: Int
        let highlighted: Bool
    }

    private static let categories: [Category] = [
        Category(icon: "square.on.square", label: "Similar category", imageIndex: 0, highlighted: true),
        Category(icon: "viewfinder", label: "Screenshots category", imageIndex: 1, highlighted: false),
        Category(icon: "play.rectangle", label: "Videos category", imageIndex: 2, highlighted: false),
        Category(icon: "livephoto", label: "Live Photos category", imageIndex: 3, highlighted: false),
        Category(icon: "square.stack", label: "Bursts category", imageIndex: 4, highlighted: false)
    ]

    private static let positions: [CGFloat] = [80, 225, 370, 515, 660]

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [PaywallDS.Color.accent.opacity(0.14), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 130
                    )
                )
                .frame(width: 260, height: 260)
                .position(x: 80, y: 170)
                .blur(radius: 18)

            ForEach(Self.categories.indices, id: \.self) { index in
                stack(category: Self.categories[index], index: index)
            }
        }
        .frame(width: 700, height: 525)
    }

    private func stack(category: Category, index: Int) -> some View {
        VStack(spacing: 14) {
            ZStack {
                photo(imageName(offset: 2, from: category.imageIndex), width: 110, height: 150, radius: 10)
                    .saturation(0.72)
                    .opacity(0.5)
                    .rotationEffect(.degrees(-9))
                    .offset(x: -13, y: 7)
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 10)

                photo(imageName(offset: 1, from: category.imageIndex), width: 110, height: 150, radius: 10)
                    .saturation(0.85)
                    .opacity(0.78)
                    .rotationEffect(.degrees(-2))
                    .offset(x: -6, y: 3)
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 10)

                photo(imageName(offset: 0, from: category.imageIndex), width: 110, height: 150, radius: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                category.highlighted
                                    ? PaywallDS.Color.accent.opacity(0.95)
                                    : Color.white.opacity(0.08),
                                lineWidth: category.highlighted ? 1.5 : 1
                            )
                    )
                    .shadow(
                        color: category.highlighted
                            ? PaywallDS.Color.accent.opacity(0.22)
                            : Color.black.opacity(0.55),
                        radius: category.highlighted ? 22 : 14,
                        y: 12
                    )
                    .overlay(alignment: .topTrailing) {
                        badge(category.icon)
                            .offset(x: 7, y: -7)
                    }
            }
            .frame(width: 120, height: 160)

            Text(L10n.key(category.label))
                .font(.system(size: 15))
                .foregroundStyle(category.highlighted ? PaywallDS.Color.accent : Color.white.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 130)
        }
        .position(x: Self.positions[index], y: 180)
    }

    private func imageName(offset: Int, from base: Int) -> String {
        guard images.isEmpty == false else { return "" }
        return images[(base + offset) % images.count]
    }

    private func badge(_ icon: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 15 / 255, green: 14 / 255, blue: 12 / 255).opacity(0.9))
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - 04 · Film Strip

/// 35mm 胶片条：8 格照片按月份成对排列，两端溢出画布，暗示还有更多历史。
private struct PaywallFilmStripVisual: View {

    let images: [String]

    private static let months = ["MAY", "JUN", "JUL", "AUG"]

    var body: some View {
        ZStack {
            strip
        }
        .frame(width: 700, height: 525)
        .overlay(alignment: .topLeading) {
            Text("2026")
                .font(.system(size: 18, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(PaywallDS.Color.accent)
                .padding(.top, 26)
                .padding(.leading, 44)
        }
    }

    private var strip: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 20 / 255, green: 17 / 255, blue: 16 / 255))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            sprockets(isTop: true)
            sprockets(isTop: false)
            frames
            monthLabels
        }
        .frame(width: 880, height: 224)
        .rotationEffect(.degrees(-3))
        .position(x: 400, y: 174)
        .shadow(color: .black.opacity(0.65), radius: 32, y: 26)
    }

    private var frames: some View {
        ForEach(0..<8, id: \.self) { index in
            photo(imageName(at: index), width: 78, height: 104, radius: 3)
                .offset(x: 86 + CGFloat(index) * 90, y: 62)
        }
    }

    private var monthLabels: some View {
        ForEach(Self.months.indices, id: \.self) { index in
            Text(Self.months[index])
                .font(.system(size: 14, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.62))
                .offset(x: 86 + CGFloat(index) * 180, y: 34)
        }
    }

    private func sprockets(isTop: Bool) -> some View {
        ForEach(0..<43, id: \.self) { index in
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.14))
                .frame(width: 16, height: 10)
                .offset(x: CGFloat(8 + index * 20), y: isTop ? 6 : 208)
        }
    }

    private func imageName(at index: Int) -> String {
        guard images.isEmpty == false else { return "" }
        return images[index % images.count]
    }
}

// MARK: - 05 · Share Card Lineup

/// 四种分享样式并排：每张卡都完整可见，不再靠重度重叠和虚化制造层次。
private struct PaywallShareLineupVisual: View {

    let images: [String]

    private var barcelona: String { images.first ?? "PaywallShareBarcelona" }
    private var window: String { images.count > 1 ? images[1] : barcelona }

    var body: some View {
        ZStack {
            originalCard
                .scaleEffect(0.86)
                .rotationEffect(.degrees(-6))
                .position(x: 105, y: 200)

            minimalFrameCard
                .scaleEffect(0.86)
                .rotationEffect(.degrees(-2))
                .position(x: 268, y: 185)

            ticketStubCard
                .scaleEffect(0.86)
                .rotationEffect(.degrees(2))
                .position(x: 438, y: 200)

            pocaColorCard
                .scaleEffect(0.82)
                .rotationEffect(.degrees(6))
                .position(x: 605, y: 185)
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

    /// 5 条 Pro 权益，结果导向：不写免费上限，只保留「最多 200 张」一个数字。
    static let all: [PaywallBenefitSlide] = [
        PaywallBenefitSlide(
            title: L10n.string("Unlimited cleanup"),
            subtitle: L10n.string("Clean as much as you want. No daily limit."),
            visual: .fan,
            images: ["PaywallPlane", "PaywallKyoto", "PaywallCove", "PaywallBeach", "PaywallRoad"]
        ),
        PaywallBenefitSlide(
            title: L10n.string("Bigger review rounds"),
            subtitle: L10n.string("Choose up to 200 photos per round."),
            visual: .slider,
            images: []
        ),
        PaywallBenefitSlide(
            title: L10n.string("All similar groups"),
            subtitle: L10n.string("Every duplicate group and every special category."),
            visual: .categories,
            images: []
        ),
        PaywallBenefitSlide(
            title: L10n.string("Your photo history"),
            subtitle: L10n.string("Revisit every photo you kept, month by month."),
            visual: .board,
            images: ["PaywallPlane", "PaywallBeach", "PaywallCatGray", "PaywallLake", "PaywallCove", "PaywallRoad", "PaywallFood"]
        ),
        PaywallBenefitSlide(
            title: L10n.string("Every share style"),
            subtitle: L10n.string("Make every card unmistakably yours."),
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
