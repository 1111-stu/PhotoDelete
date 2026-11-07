//
//  RecentOrganizedPhotosView.swift
//  Poca
//

import SwiftUI
import Photos

/// 「最近整理」独立模块：整理过 / 待删除 / 已收藏照片的网格回看。
///
/// - 入口：首页右上角按钮（sheet 呈现，布局对齐设计参考：标题 + 关闭 + 三列网格）。
/// - 交互：点按查看大图；长按「再次整理」（移出待删除并回到整理列表，走 contextMenu 不占网格）。
/// - 视觉：遵循 style.md——复用相册页的方形缩略图（`AlbumAssetThumbnail`），状态角标按语义色
///   （保留 = success、待删除 = danger、收藏 = favorite），其余文字走 primary/secondary/tertiary。
struct RecentOrganizedPhotosView: View {
    @ObservedObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    @State private var previewAsset: CandidatePreviewAsset?
    @State private var showingClearConfirmation = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var items: [RecentOrganizedPhotoItem] {
        dataManager.recentOrganizedPhotoItems()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PocaScreenBackground()

                if items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.string("Tap to preview, touch and hold to organize again."))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Theme.secondaryText)

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(items) { item in
                                    gridCell(item)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.space5)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle(L10n.string("Recently Organized"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !items.isEmpty {
                        Button(L10n.string("Clear"), role: .destructive) {
                            showingClearConfirmation = true
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                }
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarTrailing) {
                        recentOrganizedCloseButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        recentOrganizedCloseButton
                    }
                }
            }
        }
        .sheet(item: $previewAsset) { item in
            CandidatePhotoPreviewView(
                asset: item.asset,
                photoLibraryManager: dataManager.photoLibraryManager
            )
        }
        .confirmationDialog(
            L10n.string("Clear recent organization history?"),
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.string("Clear History"), role: .destructive) {
                dataManager.clearRecentOrganizedPhotoHistory()
            }
            Button(L10n.string("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("This clears only local history and won’t change photos or pending deletion."))
        }
    }

    private var recentOrganizedCloseButton: some View {
        PocaCircleIconButton(
            systemName: "xmark",
            accessibilityLabel: L10n.string("Close"),
            action: { dismiss() }
        )
    }

    // MARK: - 网格

    private func gridCell(_ item: RecentOrganizedPhotoItem) -> some View {
        Button {
            previewAsset = CandidatePreviewAsset(asset: item.asset)
        } label: {
            AlbumAssetThumbnail(
                assetID: item.asset.localIdentifier,
                photoLibraryManager: dataManager.photoLibraryManager,
                cornerRadius: 12
            )
            .overlay(alignment: .bottomTrailing) {
                statusBadge(for: item.record.action)
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                HapticManager.impact(.light)
                dataManager.reopenForOrganizing(item.asset)
            } label: {
                Label(L10n.string("Organize Again"), systemImage: "arrow.uturn.backward")
            }
        }
        .accessibilityLabel(L10n.string("\(item.record.action.title), tap to view full size"))
    }

    private func statusBadge(for action: RecentOrganizedPhotoAction) -> some View {
        Image(systemName: badgeIcon(for: action))
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(badgeTint(for: action))
            .frame(width: 22, height: 22)
            .background(Circle().fill(Color.black.opacity(0.55)))
            .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .accessibilityHidden(true)
    }

    private func badgeIcon(for action: RecentOrganizedPhotoAction) -> String {
        switch action {
        case .kept: return "checkmark"
        case .queuedForDeletion: return "trash.fill"
        case .favorited: return "heart.fill"
        case .unfavorited: return "heart.slash.fill"
        case .filedToAlbum: return "folder.fill"
        }
    }

    private func badgeTint(for action: RecentOrganizedPhotoAction) -> Color {
        switch action {
        case .kept: return Theme.positive
        case .queuedForDeletion: return Theme.destructive
        case .favorited, .unfavorited: return Theme.favorite
        case .filedToAlbum: return Theme.accent
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.space3) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 34, weight: .medium))
                .foregroundColor(Theme.tertiaryText)

            Text(L10n.string("Recently organized photos appear here so you can revise them."))
                .font(.system(size: Theme.textSizeSm, weight: .regular))
                .foregroundColor(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.space8)
    }
}
