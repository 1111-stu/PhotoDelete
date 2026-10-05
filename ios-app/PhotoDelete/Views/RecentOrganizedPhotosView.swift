//
//  RecentOrganizedPhotosView.swift
//  PhotoDelete
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
                PhotoDeleteScreenBackground()

                if items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.string("点按查看大图，长按可再次整理。"))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(PhotoDeleteStyle.secondaryText)

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(items) { item in
                                    gridCell(item)
                                }
                            }
                        }
                        .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle(L10n.string("最近整理"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !items.isEmpty {
                        Button(L10n.string("清空"), role: .destructive) {
                            showingClearConfirmation = true
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(PhotoDeleteStyle.primaryText)
                    }
                    .accessibilityLabel(L10n.string("关闭"))
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
            L10n.string("清空最近整理记录？"),
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.string("清空记录"), role: .destructive) {
                dataManager.clearRecentOrganizedPhotoHistory()
            }
            Button(L10n.string("取消"), role: .cancel) {}
        } message: {
            Text(L10n.string("只会清空本机记录，不会修改照片或待删除列表。"))
        }
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
                Label(L10n.string("再次整理"), systemImage: "arrow.uturn.backward")
            }
        }
        .accessibilityLabel(L10n.string("\(item.record.action.title)，点按查看大图"))
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
        case .kept: return PhotoDeleteStyle.positive
        case .queuedForDeletion: return PhotoDeleteStyle.destructive
        case .favorited, .unfavorited: return PhotoDeleteStyle.favorite
        case .filedToAlbum: return PhotoDeleteStyle.accent
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 34, weight: .medium))
                .foregroundColor(PhotoDeleteStyle.tertiaryText)

            Text(L10n.string("整理过的照片会显示在这里，方便回头修改。"))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(PhotoDeleteStyle.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}
