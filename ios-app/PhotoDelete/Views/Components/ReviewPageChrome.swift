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
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.primaryText)
                        .frame(width: 38, height: 38)
                }
                .modifier(ReviewGlassCircleChrome())
                .accessibilityLabel(L10n.string("返回"))
            }
            .frame(width: 116, alignment: .leading)

            Spacer()

            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(PhotoDeleteStyle.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

            Spacer()

            Button(action: onDelete) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.primaryText)
                        .frame(width: 38, height: 38)

                    if deleteCount > 0 {
                        // 颜色只承担"数量"语义：图标中性、角标珊瑚红（>99 显示 99+）。
                        Text(deleteCount > 99 ? "99+" : PhotoDeleteCountFormat.plain(deleteCount))
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Capsule(style: .continuous).fill(PhotoDeleteStyle.destructive))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(PhotoDeleteStyle.reviewCanvas, lineWidth: 2)
                            )
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .modifier(ReviewGlassCircleChrome())
            .disabled(!canDelete)
            .accessibilityIdentifier("review-trash-button")
            .accessibilityLabel(L10n.string("待删除"))
            .accessibilityValue(L10n.string("待删除 \(deleteCount) 张"))
            .frame(width: 116, alignment: .trailing)
        }
        .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(PhotoDeleteStyle.reviewCanvas)
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
            PhotoDeleteStyle.reviewCanvas.opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 54, weight: .medium))
                    .foregroundColor(PhotoDeleteStyle.positive)

                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)

                Text(subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .multilineTextAlignment(.center)

                if showsSessionStats {
                    HStack(spacing: 10) {
                        CompletionStatPill(
                            icon: "trash",
                            value: deleteCount,
                            title: L10n.string("删除"),
                            tint: PhotoDeleteStyle.destructive
                        )
                        CompletionStatPill(
                            icon: "heart",
                            value: favoriteCount,
                            title: L10n.string("收藏"),
                            tint: PhotoDeleteStyle.iconTint(for: "favorite")
                        )

                    }
                }

                HStack(spacing: 12) {
                    if hasUnreviewedPhotos {
                        Button(L10n.string("继续整理")) {
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
            .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
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
                .foregroundColor(PhotoDeleteStyle.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Text(subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(PhotoDeleteStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if showsProgress {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: PhotoDeleteStyle.accent))
                    .clipShape(Capsule(style: .continuous))
            }

            HStack(spacing: 12) {
                Label("\(deleteCount)", systemImage: "trash")
                    .foregroundColor(PhotoDeleteStyle.destructive)
                Label("\(favoriteCount)", systemImage: "heart")
                    .foregroundColor(PhotoDeleteStyle.iconTint(for: "favorite"))
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
                    label: L10n.string("照片详情"),
                    action: onShowDetails
                )
                Spacer(minLength: 0)
                toolButton(
                    icon: "arrow.uturn.backward",
                    label: L10n.string("撤销"),
                    action: onUndo
                )
                Spacer(minLength: 0)
                toolButton(
                    icon: isFavorite ? "heart.fill" : "heart",
                    label: isFavorite ? L10n.string("取消收藏") : L10n.string("收藏"),
                    action: onFavorite
                )
                Spacer(minLength: 0)
                toolButton(
                    icon: isPreparingShare ? "hourglass" : "square.and.arrow.up",
                    label: isPreparingShare ? L10n.string("准备中") : L10n.string("分享"),
                    action: onShare
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .modifier(ReviewGlassCapsuleChrome())
            .shadow(color: PhotoDeleteStyle.floatingShadow, radius: 12, y: 6)

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
                .foregroundColor(PhotoDeleteStyle.primaryText)
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
                    .foregroundColor(PhotoDeleteStyle.primaryButtonText)
                    .frame(width: 46, height: 46)
                    .glassEffect(.regular.tint(PhotoDeleteStyle.accent), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("完成整理"))
        } else {
            Button(action: onFinish) {
                Image(systemName: "archivebox")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(PhotoDeleteStyle.primaryButtonText)
                    .frame(width: 46, height: 46)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [
                                    PhotoDeleteTheme.current.amberGradientTop,
                                    PhotoDeleteTheme.current.amberGradientBottom
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                    .shadow(color: PhotoDeleteStyle.accent.opacity(0.3), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("完成整理"))
        }
    }
}

/// 评审页圆形按钮的液态玻璃 chrome：iOS 26+ 用玻璃圆钮，老系统回落实心圆。
struct ReviewGlassCircleChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            content
                .buttonStyle(.plain)
                .background(Circle().fill(PhotoDeleteStyle.elevatedSurface))
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
                        .fill(PhotoDeleteStyle.surface.opacity(0.9))
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(PhotoDeleteStyle.hairline, lineWidth: PhotoDeleteStyle.Metrics.cardStrokeWidth)
                        }
                }
        }
    }
}
