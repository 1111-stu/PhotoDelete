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
                PhotoDeleteCircleIconButton(
                    systemName: "arrow.left",
                    accessibilityLabel: L10n.string("Back"),
                    action: onBack
                )
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

            PhotoDeleteCircleIconButton(
                systemName: "archivebox",
                accessibilityLabel: L10n.string("Collection bin"),
                accessibilityIdentifier: "review-trash-button",
                isEnabled: canDelete,
                action: onDelete
            ) {
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
                        .accessibilityHidden(true)
                }
            }
            .accessibilityValue(L10n.string("\(deleteCount) to delete"))
            .frame(width: 116, alignment: .trailing)
        }
        .padding(.horizontal, Theme.space5)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Theme.reviewCanvas)
    }
}

/// 本轮结算：汇报本次待删 / 本次收藏 / 收集箱共计。
/// 「完成」离开整理；点遮罩关闭弹窗并留在本轮（误触可回）。
struct ReviewCompletionOverlay: View {
    let sourceTitle: String
    let itemCount: Int
    let sessionDeleteCount: Int
    let sessionFavoriteCount: Int
    let collectionBinCount: Int
    let onDismiss: () -> Void
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
                .accessibilityLabel(L10n.string("Close"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: Text(L10n.string("Close"))) {
                    onDismiss()
                }

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center, spacing: 10) {
                    Text(sourceTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(String(format: L10n.string("%lld items"), Int64(itemCount)))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .monospacedDigit()
                    PhotoDeleteCircleIconButton(
                        systemName: "xmark",
                        accessibilityLabel: L10n.string("Close"),
                        accessibilityIdentifier: "review-completion-close",
                        action: onDismiss
                    )
                }

                VStack(spacing: 16) {
                    completionStatRow(
                        tint: Theme.destructive,
                        title: L10n.string("Marked for deletion this round"),
                        value: sessionDeleteCount
                    )
                    completionStatRow(
                        tint: Theme.iconTint(for: "favorite"),
                        title: L10n.string("Favorited this round"),
                        value: sessionFavoriteCount
                    )
                    completionStatRow(
                        tint: Theme.accent,
                        title: L10n.string("Collection bin total"),
                        value: collectionBinCount
                    )
                }

                Button(L10n.string("Done")) {
                    onFinish()
                }
                .photoDeletePrimaryButton()
                .accessibilityIdentifier("review-completion-primary-button")
            }
            .padding(22)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                    .fill(Theme.elevatedSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                            .stroke(Theme.hairline, lineWidth: Theme.stroke)
                    }
            }
            .shadow(color: Theme.floatingShadow, radius: 18, y: 10)
            .padding(.horizontal, Theme.space5)
            // 挡住点击穿透到遮罩，避免点卡片也关闭。
            .contentShape(Rectangle())
        }
        .transition(.opacity)
    }

    private func completionStatRow(tint: Color, title: String, value: Int) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.primaryText)
            Spacer(minLength: 12)
            Text(PhotoDeleteCountFormat.plain(value))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
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
        HStack(alignment: .center, spacing: 16) {
            shareButton

            // 中间胶囊固定承载三个高频动作：收藏 / 详情 / 撤回。
            HStack(spacing: 0) {
                toolButton(
                    icon: isFavorite ? "heart.fill" : "heart",
                    label: isFavorite ? L10n.string("Unfavorite") : L10n.string("Favorite"),
                    action: onFavorite
                )
                toolButton(
                    icon: "info.circle",
                    label: L10n.string("Photo Details"),
                    action: onShowDetails
                )
                toolButton(
                    icon: "arrow.uturn.backward",
                    label: L10n.string("Undo"),
                    action: onUndo
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .modifier(ReviewGlassCapsuleChrome())
            .shadow(color: Theme.floatingShadow, radius: 12, y: 6)

            // 终点动作保持独立成珠：液态玻璃「完成整理」→ 本轮结算。
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
                .font(.system(size: Theme.textSizeLg, weight: .bold, design: .rounded))
                .foregroundColor(Theme.primaryText)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var shareButton: some View {
        Button(action: onShare) {
            Image(systemName: isPreparingShare ? "hourglass" : "square.and.arrow.up")
                .font(.system(size: Theme.textSizeChromeIcon, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .frame(width: Theme.sizeChrome, height: Theme.sizeChrome)
        }
        .modifier(ReviewGlassCircleChrome())
        .buttonStyle(.plain)
        .shadow(color: Theme.floatingShadow, radius: 12, y: 6)
        .accessibilityLabel(L10n.string(isPreparingShare ? "Preparing" : "Share"))
    }

    private var finishButton: some View {
        Button(action: onFinish) {
            Image(systemName: "checkmark")
                .font(.system(size: Theme.textSizeLg, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .frame(width: Theme.sizeChrome, height: Theme.sizeChrome)
        }
        .modifier(ReviewGlassCircleChrome())
        .buttonStyle(.plain)
        .shadow(color: Theme.floatingShadow, radius: 12, y: 6)
        .accessibilityLabel(L10n.string("Finish Organizing"))
    }
}

// ReviewGlassCircleChrome / ReviewGlassCapsuleChrome → Components/PhotoDeleteGlassChrome.swift
