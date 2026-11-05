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
//  - Emotion：材质本身就是情绪；卡片保持静止（2026-11-01 移除扫光，实测太抢）。
//
//  材质语言沿用 PaywallDS（暖虹彩），但卡片主体仍是 Theme 的暖中性面：
//  设置页只借边缘的一圈彩光，不整页换成付费页的冷调画布。
//
//  打光规则（2026-11-01 定稿）：整张卡只被左上的一盏灯照亮——
//  虹彩边最亮的粉段在左上，球的高光在左上，卡面左上还有一点暖色光池。
//

import SwiftUI

struct ProEntryBanner: View {

    let subscriptionType: SubscriptionManager.SubscriptionType?
    let action: () -> Void

    private let cardRadius: CGFloat = 28
    private let orbSize: CGFloat = 56
    /// 入口是设置页的 hero，不是一条行：给足高度，让材质和留白成立。
    private let preferredHeight: CGFloat = 120

    private var isPro: Bool {
        subscriptionType != nil
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                orb

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.vertical, 22)
            .padding(.leading, 20)
            .padding(.trailing, 18)
            .frame(maxWidth: .infinity, minHeight: preferredHeight, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
            .background(cardMaterial)
            // 边框画在内容之上，和外框保持在同一层。
            .overlay(
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .strokeBorder(rimStyle, lineWidth: isPro ? 1 : 2)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                    .inset(by: 1.5)
                    .strokeBorder(innerBevel, lineWidth: 0.5)
                    .allowsHitTesting(false)
            )
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

// MARK: - Card material

private extension ProEntryBanner {

    /// 四层：外圈虹彩光晕 / 受光的石墨卡面 / 内圈折射 / 顶部倒角。
    /// 卡面不是一块纯色板：上亮下暗，左上还有一点从球体溢出的暖光。
    var cardMaterial: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .stroke(PaywallDS.Gradient.iridescent, lineWidth: 8)
                .blur(radius: 14)
                .opacity(isPro ? 0.14 : 0.55)

            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(Theme.surface)

            // 卡面受光：顶部抬亮、底部沉下去，像一块被左上灯照到的板。
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.040), location: 0),
                    .init(color: .clear, location: 0.42),
                    .init(color: .black.opacity(0.100), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .mask(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))

            // 球体溢出的暖光：中心对准球心（卡宽 14%、卡高 50%），让卡面和材质同源。
            RadialGradient(
                colors: [
                    PaywallDS.Color.iridescentPeach.opacity(isPro ? 0.05 : 0.10),
                    .clear
                ],
                center: UnitPoint(x: 0.14, y: 0.50),
                startRadius: 0,
                endRadius: 130
            )
            .mask(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))

            // 内圈折射：把彩光再往卡面里压 6pt，边框才像一块有厚度的材质，而不是一条描边。
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .strokeBorder(PaywallDS.Gradient.iridescent, lineWidth: 6)
                .blur(radius: 6)
                .opacity(isPro ? 0.10 : 0.30)
                .mask(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        }
    }

    var rimStyle: AnyShapeStyle {
        isPro
            ? AnyShapeStyle(Color.white.opacity(0.14))
            : AnyShapeStyle(PaywallDS.Gradient.iridescent)
    }

    /// 0.5pt 顶部倒角：只在顶边有光，往下迅速消失。
    var innerBevel: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(isPro ? 0.10 : 0.14), location: 0),
                .init(color: .clear, location: 0.35)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 一颗虹彩玻璃珠：底色用三色线性渐变（锥形渐变在小尺寸会露出扇形缝），
    /// 再叠接触阴影、压暗球缘、高光和反光弧，读起来才像玻璃而不是色轮。
    var orb: some View {
        ZStack {
            contactShadow

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            PaywallDS.Color.iridescentPeach,
                            PaywallDS.Color.iridescentPink,
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
                        colors: [Color.white.opacity(0.78), Color.white.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: orbSize * 0.20
                    )
                )
                .frame(width: orbSize * 0.42, height: orbSize * 0.42)
                .offset(x: -orbSize * 0.18, y: -orbSize * 0.21)
                .blur(radius: 1.1)

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
                    .font(.system(size: orbSize * 0.29, weight: .bold))
                    .foregroundStyle(PaywallDS.Color.recommendedBadgeText)
            }
        }
        .frame(width: orbSize, height: orbSize)
        .shadow(color: PaywallDS.Color.iridescentPink.opacity(0.16), radius: 12, y: 2)
        .accessibilityHidden(true)
    }

    /// 接触阴影：把球“放”在卡面上，而不是浮着。
    var contactShadow: some View {
        Circle()
            .fill(Color.black.opacity(0.34))
            .frame(width: orbSize * 0.84, height: orbSize * 0.50)
            .blur(radius: orbSize * 0.15)
            .offset(y: orbSize * 0.36)
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
