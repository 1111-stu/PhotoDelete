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
                PocaCircleIconButton(
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

            PocaCircleIconButton(
                systemName: "archivebox",
                accessibilityLabel: L10n.string("Trash"),
                accessibilityIdentifier: "review-trash-button",
                isEnabled: canDelete,
                action: onDelete
            ) {
                if deleteCount > 0 {
                    PocaCountBadge(count: deleteCount)
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

/// 本轮结算：汇报本次待删 / 本次收藏 / 垃圾桶共计。
/// 「完成」离开整理；点遮罩关闭弹窗并留在本轮（误触可回）。
struct ReviewCompletionOverlay: View {
    let sessionDeleteCount: Int
    let sessionFavoriteCount: Int
    let collectionBinCount: Int
    let onDismiss: () -> Void
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.black.opacity(0.42)
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .accessibilityLabel(L10n.string("Close"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: Text(L10n.string("Close"))) {
                onDismiss()
            }

            VStack(alignment: .leading, spacing: 22) {
                Text(L10n.string("Organizing Complete"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 44)

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
                        title: L10n.string("Trash total"),
                        value: collectionBinCount
                    )
                }

                Button(L10n.string("Done")) {
                    onFinish()
                }
                .photoDeletePrimaryButton()
                .accessibilityIdentifier("review-completion-primary-button")
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 22)
            .background {
                RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                    .fill(Theme.elevatedSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                            .stroke(Theme.hairline, lineWidth: Theme.stroke)
                    }
            }
            .shadow(color: Theme.floatingShadow, radius: 18, y: 10)
            // 挡住点击穿透到遮罩，避免点卡片也关闭。
            .contentShape(Rectangle())
            .overlay(alignment: .topTrailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .frame(width: 32, height: 32)
                        .background { PocaGlassCircleBackground() }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .padding(.trailing, 6)
                .accessibilityLabel(Text(L10n.string("Close")))
                .accessibilityIdentifier("review-completion-close")
            }
            .padding(.horizontal, Theme.space5)
            .frame(maxWidth: 400)
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
            Text(PocaCountFormat.plain(value))
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
                Label {
                    Text(PocaCountFormat.plain(deleteCount))
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "trash")
                }
                .foregroundColor(Theme.destructive)

                Label {
                    Text(PocaCountFormat.plain(favoriteCount))
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "heart")
                }
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
    let showsDayWallButton: Bool
    let canOpenDayWall: Bool
    let onShowDetails: () -> Void
    let onUndo: () -> Void
    let onFavorite: () -> Void
    let onShare: () -> Void
    let onFinish: () -> Void
    let onShowDayWall: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            shareButton

            // 中间胶囊：收藏 / 详情 / 撤回（「回到那天」开关打开时追加一个）。
            Spacer(minLength: 0)
            HStack(spacing: showsDayWallButton ? 8 : 12) {
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
                if showsDayWallButton {
                    toolButton(
                        icon: "calendar.day.timeline.left",
                        label: L10n.string("Photos from this day"),
                        isEnabled: canOpenDayWall,
                        action: onShowDayWall
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .modifier(ReviewGlassCapsuleChrome())
            .shadow(color: Theme.floatingShadow, radius: 12, y: 6)

            // 终点动作保持独立成珠：液态玻璃「完成整理」→ 本轮结算。
            Spacer(minLength: 0)
            finishButton
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .disabled(!canPerformAction)
        .opacity(canPerformAction ? 1 : 0.45)
    }

    /// 工具按钮：图标保持统一白色 + 加粗 rounded；状态只用形状（heart / heart.fill）表达。
    private func toolButton(
        icon: String,
        label: String,
        isEnabled: Bool = true,
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
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
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

// ReviewGlassCircleChrome / ReviewGlassCapsuleChrome → Components/PocaGlassChrome.swift
