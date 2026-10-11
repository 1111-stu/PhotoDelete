import SwiftUI

struct ReviewNavigationHeader: View {
    let title: String
    let deleteCount: Int
    let canDelete: Bool
    let onBack: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.primaryText)
                        .frame(width: 52, height: 52)
                }
                .modifier(ReviewGlassCircleChrome())
                .accessibilityLabel(L10n.string("Back"))
            }
            .frame(width: 116, alignment: .leading)

            Spacer()

            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Theme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

            Spacer()

            Button(action: onDelete) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "trash")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.primaryText)
                        .frame(width: 52, height: 52)

                    if deleteCount > 0 {
                        // 颜色只承担"数量"语义：图标中性、角标珊瑚红（>99 显示 99+）。
                        Text(deleteCount > 99 ? "99+" : PhotoDeleteCountFormat.plain(deleteCount))
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Capsule(style: .continuous).fill(Theme.destructive))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Theme.reviewCanvas, lineWidth: 2)
                            )
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .modifier(ReviewGlassCircleChrome())
            .disabled(!canDelete)
            .accessibilityIdentifier("review-trash-button")
            .accessibilityLabel(L10n.string("To delete"))
            .accessibilityValue(L10n.string("\(deleteCount) to delete"))
            .frame(width: 116, alignment: .trailing)
        }
        .padding(.horizontal, Theme.screenHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Theme.reviewCanvas)
    }
}

struct ReviewCompletionOverlay: View {
    let title: String
    let subtitle: String
    let hasUnreviewedPhotos: Bool
    let primaryActionTitle: String
    let showsSessionStats: Bool
    let deleteCount: Int
    let favoriteCount: Int
    let onContinue: () -> Void
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            Theme.reviewCanvas.opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundColor(Theme.positive)

                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Theme.primaryText)

                Text(subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .multilineTextAlignment(.center)

                if showsSessionStats {
                    HStack(spacing: 10) {
                        CompletionStatPill(
                            icon: "trash",
                            value: deleteCount,
                            title: L10n.string("Delete"),
                            tint: Theme.destructive
                        )
                        CompletionStatPill(
                            icon: "heart",
                            value: favoriteCount,
                            title: L10n.string("Favorite"),
                            tint: Theme.iconTint(for: "favorite")
                        )

                    }
                }

                HStack(spacing: 12) {
                    if hasUnreviewedPhotos {
                        Button(L10n.string("Keep Organizing")) {
                            onContinue()
                        }
                        .photoDeleteSecondaryButton()
                    }

                    Button(primaryActionTitle) {
                        onFinish()
                    }
                    .photoDeletePrimaryButton()
                    .accessibilityIdentifier("review-completion-primary-button")

                }
            }
            .padding(24)
            .photoDeleteCard()
            .padding(.horizontal, Theme.screenHorizontalPadding)
        }
        .transition(.opacity)
    }
}

struct ReviewSessionSummaryPanel: View {
    let title: String
    let subtitle: String
    let showsProgress: Bool
    let progress: Double
    let deleteCount: Int
    let favoriteCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Theme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Text(subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if showsProgress {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: Theme.accent))
                    .clipShape(Capsule(style: .continuous))
            }

            HStack(spacing: 12) {
                Label("\(deleteCount)", systemImage: "trash")
                    .foregroundColor(Theme.destructive)
                Label("\(favoriteCount)", systemImage: "heart")
                    .foregroundColor(Theme.iconTint(for: "favorite"))
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .padding(16)
        .photoDeleteCard()
    }
}

struct ReviewActionToolbar: View {
    let isFavorite: Bool
    let canPerformAction: Bool
    let isPreparingShare: Bool
    let onShowDetails: () -> Void
    let onUndo: () -> Void
    let onFavorite: () -> Void
    let onShare: () -> Void
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // 四枚纯图标工具：详情 / 撤销 / 收藏 / 分享（名称靠 VoiceOver 标签；状态只用形状表达）
            HStack(spacing: 0) {
                toolButton(
                    icon: "info.circle",
                    label: L10n.string("Photo Details"),
                    action: onShowDetails
                )
                Spacer(minLength: 0)
                toolButton(
                    icon: "arrow.uturn.backward",
                    label: L10n.string("Undo"),
                    action: onUndo
                )
                Spacer(minLength: 0)
                toolButton(
                    icon: isFavorite ? "heart.fill" : "heart",
                    label: isFavorite ? L10n.string("Unfavorite") : L10n.string("Favorite"),
                    action: onFavorite
                )
                Spacer(minLength: 0)
                toolButton(
                    icon: isPreparingShare ? "hourglass" : "square.and.arrow.up",
                    label: isPreparingShare ? L10n.string("Preparing") : L10n.string("Share"),
                    action: onShare
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .modifier(ReviewGlassCapsuleChrome())
            .shadow(color: Theme.floatingShadow, radius: 12, y: 6)

            // 终点动作独立成珠：琥珀玻璃「完成整理」（待删数字由头部角标承担）
            finishButton
        }
        .padding(.horizontal, 18)
        .disabled(!canPerformAction)
        .opacity(canPerformAction ? 1 : 0.45)
    }

    /// 工具按钮：图标保持统一白色 + 加粗 rounded；状态只用形状（heart / heart.fill）表达。
    private func toolButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(Theme.primaryText)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var finishButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: onFinish) {
                Image(systemName: "archivebox")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.onAccent)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular.tint(Theme.accent), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("Finish Organizing"))
        } else {
            Button(action: onFinish) {
                Image(systemName: "archivebox")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.onAccent)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [
                                    Theme.amberGradientTop,
                                    Theme.amberGradientBottom
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                    .shadow(color: Theme.accent.opacity(0.3), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("Finish Organizing"))
        }
    }
}

/// 评审页圆形按钮的液态玻璃 chrome：iOS 26+ 用玻璃圆钮，老系统回落实心圆。
struct ReviewGlassCircleChrome: ViewModifier {
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

/// 评审页底栏的液态玻璃胶囊 chrome：iOS 26+ 用玻璃，老系统回落 surface 实心胶囊。
struct ReviewGlassCapsuleChrome: ViewModifier {
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
                                .stroke(Theme.hairline, lineWidth: Theme.Metrics.cardStrokeWidth)
                        }
                }
        }
    }
}
