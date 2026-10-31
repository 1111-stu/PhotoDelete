//
//  ProEntryBanner.swift
//  PhotoDelete
//
//  设置页顶部的 Pro 入口卡。
//
//  减法原则（A / M / C / E 各留一个承载物）：
//  - Attention：唯一焦点是材质边缘的虹彩，不再同时放纹章、徽章、胶囊抢注意力。
//  - Meaning：只出现一次身份词（OnePhoto Pro）；权益只留一行。
//  - Contrast：行动暗示只留一个箭头，卡片本身是唯一的点击面。
//  - Emotion：只有一种动效——一道慢速镜面扫光；已解锁时连这道光也收起。
//
//  材质语言沿用 PaywallDS（樱粉系虹彩），但卡片主体仍是 Theme 的暖中性面：
//  设置页只借边缘的一圈彩光，不整页换成付费页的冷调画布。
//

import SwiftUI

struct ProEntryBanner: View {

    let subscriptionType: SubscriptionManager.SubscriptionType?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardRadius: CGFloat = 28
    private let orbSize: CGFloat = 44

    private var isPro: Bool {
        subscriptionType != nil
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                orb

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(subtitle)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardMaterial)
            .contentShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        }
        .buttonStyle(ProEntryPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(subtitle))
        .accessibilityHint(Text(accessibilityHint))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("settings-pro-entry")
    }
}

// MARK: - Material

private extension ProEntryBanner {

    /// 三层材质：外圈虹彩光晕 / 石墨卡面 / 1.5pt 虹彩描边。
    /// 光晕只负责“看起来有厚度”，不再往卡片里加第二层渐变底。
    var cardMaterial: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .stroke(PaywallDS.Gradient.iridescent, lineWidth: 8)
                .blur(radius: 14)
                .opacity(isPro ? 0.14 : 0.55)

            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(Theme.surface)

            // 内圈折射：把彩光再往卡面里压 6pt，边框才像一块有厚度的材质，而不是一条描边。
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .strokeBorder(PaywallDS.Gradient.iridescent, lineWidth: 6)
                .blur(radius: 6)
                .opacity(isPro ? 0.10 : 0.30)
                .mask(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))

            specularSweep
                .mask(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))

            // 未解锁＝虹彩边，是“邀请”；已解锁＝回归安静的白发丝边，是“状态”。
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .strokeBorder(rimStyle, lineWidth: isPro ? 1 : 2)
        }
    }

    var rimStyle: AnyShapeStyle {
        isPro
            ? AnyShapeStyle(Color.white.opacity(0.14))
            : AnyShapeStyle(PaywallDS.Gradient.iridescent)
    }

    /// 一颗虹彩玻璃珠：把“彩色材质”集中在一点，替代皇冠 + PRO 徽章两种身份暗示。
    /// 用三色线性渐变做球体底色（锥形渐变在 44pt 里会在圆心显出扇形缝），
    /// 再叠左上高光和右下压暗，读起来才像玻璃珠而不是色轮。
    var orb: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            PaywallDS.Color.iridescentPink,
                            PaywallDS.Color.iridescentLavender,
                            PaywallDS.Color.iridescentMint
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.clear, Color.black.opacity(0.34)],
                        center: UnitPoint(x: 0.32, y: 0.28),
                        startRadius: orbSize * 0.18,
                        endRadius: orbSize * 0.60
                    )
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.75), Color.white.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: orbSize * 0.22
                    )
                )
                .frame(width: orbSize * 0.46, height: orbSize * 0.46)
                .offset(x: -orbSize * 0.17, y: -orbSize * 0.20)
                .blur(radius: 1.2)

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )

            if isPro {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PaywallDS.Color.recommendedBadgeText)
            }
        }
        .frame(width: orbSize, height: orbSize)
        .shadow(color: PaywallDS.Color.iridescentPink.opacity(0.28), radius: 14, y: 3)
        .accessibilityHidden(true)
    }
}

// MARK: - Specular sweep

private extension ProEntryBanner {

    /// 9 秒循环里扫过约 3.8 秒，其余时间静止。
    /// 已解锁（isPro）时完全收起：扫光是“邀请购买”的语汇，不是常驻装饰。
    @ViewBuilder
    var specularSweep: some View {
        if !isPro && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                GeometryReader { proxy in
                    let size = proxy.size
                    let cycle: Double = 9
                    let phase = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: cycle) / cycle
                    let sweep = min(phase / 0.42, 1)
                    let bandWidth = size.width * 0.55

                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0), location: 0),
                            .init(color: .white.opacity(0.10), location: 0.5),
                            .init(color: .white.opacity(0), location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: bandWidth, height: size.height * 2)
                    .rotationEffect(.degrees(18))
                    .offset(
                        x: -bandWidth + sweep * (size.width + bandWidth),
                        y: -size.height * 0.5
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Copy

private extension ProEntryBanner {

    var title: String {
        switch subscriptionType {
        case .quarterly:
            return L10n.string("Quarterly Pro Active")
        case .yearly:
            return L10n.string("Annual Pro Active")
        case .lifetime:
            return L10n.string("Lifetime Pro Unlocked")
        case nil:
            return L10n.string("OnePhoto Pro")
        }
    }

    var subtitle: String {
        switch subscriptionType {
        case .quarterly, .yearly:
            return L10n.string("View subscription status and plan features")
        case .lifetime:
            return L10n.string("View purchase info and feature differences")
        case nil:
            return L10n.string("Timeline · Compression · Similar photos")
        }
    }

    var accessibilityHint: String {
        isPro
            ? L10n.string("View purchase info and feature differences")
            : L10n.string("View Annual and Lifetime Pro plans")
    }
}

// MARK: - Press feedback

private struct ProEntryPressStyle: ButtonStyle {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

#Preview("Settings Pro Entry") {
    VStack(spacing: 20) {
        ProEntryBanner(subscriptionType: nil) {}
        ProEntryBanner(subscriptionType: .yearly) {}
    }
    .padding(.horizontal, Theme.space5)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.background)
    .preferredColorScheme(.dark)
}
