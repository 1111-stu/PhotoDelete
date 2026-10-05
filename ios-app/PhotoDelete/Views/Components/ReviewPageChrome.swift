import SwiftUI

struct ReviewNavigationHeader: View {
    let title: String
    let subtitle: String
    let deleteCount: Int
    let canDelete: Bool
    let onBack: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Button(action: onBack) {
                        ZStack {
                            Circle()
                                .fill(PhotoDeleteStyle.elevatedSurface)
                                .frame(width: 40, height: 40)

                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(PhotoDeleteStyle.primaryText)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string("返回"))
                }
                .frame(width: 116, alignment: .leading)

                Spacer()

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

                Spacer()

                Button(action: onDelete) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "trash")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(PhotoDeleteStyle.destructive)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(PhotoDeleteStyle.destructive.opacity(0.12)))

                        if deleteCount > 0 {
                            Text(deleteCount.formatted(.number.grouping(.automatic)))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 5)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Capsule(style: .continuous).fill(PhotoDeleteStyle.destructive))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(PhotoDeleteStyle.reviewCanvas, lineWidth: 2)
                                )
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canDelete)
                .accessibilityIdentifier("review-trash-button")
                .accessibilityLabel(L10n.string("待删除"))
                .accessibilityValue(L10n.string("待删除 \(deleteCount) 张"))
                .frame(width: 116, alignment: .trailing)
            }
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
    let deleteCount: Int
    let onUndo: () -> Void
    let onFavorite: () -> Void
    let onShare: () -> Void
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            ActionButton(icon: "arrow.uturn.backward", title: "撤销", color: PhotoDeleteStyle.secondaryText, style: .quiet) {
                onUndo()

            }
            Spacer(minLength: 0)
            ActionButton(
                icon: isFavorite ? "heart.slash" : "heart",
                title: isFavorite ? "取消收藏" : "收藏",
                color: PhotoDeleteStyle.iconTint(for: "favorite")
            ) {
                onFavorite()

            }
            Spacer(minLength: 0)
            ActionButton(
                icon: isPreparingShare ? "hourglass" : "square.and.arrow.up",
                title: isPreparingShare ? "准备中" : "分享",
                color: PhotoDeleteStyle.accent
            ) {
                onShare()

            }
            Spacer(minLength: 0)
            ActionButton(
                icon: "checkmark",
                title: "完成整理",
                color: PhotoDeleteStyle.positive,
                style: .solid,
                badgeText: deleteCount > 0 ? deleteCount.formatted(.number.grouping(.automatic)) : nil
            ) {
                onFinish()

            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            Capsule(style: .continuous)
                .fill(PhotoDeleteStyle.surface.opacity(0.9))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(PhotoDeleteStyle.hairline, lineWidth: PhotoDeleteStyle.Metrics.cardStrokeWidth)
                }
        }
        .shadow(color: PhotoDeleteStyle.floatingShadow, radius: 12, y: 6)
        .padding(.horizontal, 18)
        .disabled(!canPerformAction)
        .opacity(canPerformAction ? 1 : 0.45)
    }
}
