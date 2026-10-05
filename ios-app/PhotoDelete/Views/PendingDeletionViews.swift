import SwiftUI
import Photos

/// Swipe review 中暂存的待删除照片。这里只修改本地候选队列，不触碰系统照片库。
struct PendingDeletionView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<String> = []
    @State private var previewAsset: CandidatePreviewAsset?

    private var assets: [PHAsset] {
        dataManager.deleteCandidates.sorted { $0.creationDate ?? .distantPast > $1.creationDate ?? .distantPast }
    }

    var body: some View {
        DeletionQueueScreen(
            title: L10n.string("待删除"),
            subtitle: L10n.string("点击缩略图选择或取消选择"),
            assets: assets,
            selectedIDs: $selectedIDs,
            tint: PhotoDeleteStyle.destructive,
            emptyTitle: L10n.string("还没有待删除的照片"),
            emptyMessage: L10n.string("上滑照片后，会先放到这里确认。"),
            previewAsset: $previewAsset,
            onRemove: { asset in
                dataManager.removeFromDeleteCandidates(asset)
                selectedIDs.remove(asset.localIdentifier)
            },
            onPrimaryAction: { dismiss() },
            primaryTitle: L10n.string("继续整理")
        )
        .onAppear { selectedIDs = Set(assets.map(\.localIdentifier)) }
        .onChange(of: assets.map(\.localIdentifier)) { _ in
            selectedIDs.formIntersection(Set(assets.map(\.localIdentifier)))
        }
    }
}

/// 从首页垃圾桶进入的候选处理页。删除动作仍通过 DataManager 的批处理确认。
struct TrashBinView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<String> = []
    @State private var previewAsset: CandidatePreviewAsset?
    @State private var showingDeleteConfirmation = false
    @State private var showingBatchConfirm = false

    private var assets: [PHAsset] {
        dataManager.deleteCandidates.sorted { $0.creationDate ?? .distantPast > $1.creationDate ?? .distantPast }
    }

    var body: some View {
        DeletionQueueScreen(
            title: L10n.string("垃圾桶"),
            subtitle: L10n.string("本次预计删除 (assets.count) 项"),
            assets: assets,
            selectedIDs: $selectedIDs,
            tint: PhotoDeleteStyle.destructive,
            emptyTitle: L10n.string("垃圾桶是空的"),
            emptyMessage: L10n.string("上滑照片加入待删除队列后，会显示在这里。"),
            previewAsset: $previewAsset,
            onRemove: { asset in
                dataManager.removeFromDeleteCandidates(asset)
                selectedIDs.remove(asset.localIdentifier)
            },
            onPrimaryAction: { showingDeleteConfirmation = true },
            primaryTitle: L10n.string("删除 (selectedIDs.count) 项")
        )
        .onAppear { selectedIDs = Set(assets.map(\.localIdentifier)) }
        .onChange(of: assets.map(\.localIdentifier)) { _ in
            selectedIDs.formIntersection(Set(assets.map(\.localIdentifier)))
        }
        .confirmationDialog(
            L10n.string("确认删除所选照片？"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.string("确认删除"), role: .destructive) {
                showingBatchConfirm = true
            }
            Button(L10n.string("取消"), role: .cancel) {}
        } message: {
            Text(L10n.string("照片会进入系统“最近删除”，你仍可在系统照片中恢复。"))
        }
        .fullScreenCover(isPresented: $showingBatchConfirm) {
            BatchConfirmView()
                .environmentObject(dataManager)
        }
    }
}

private struct DeletionQueueScreen: View {
    @EnvironmentObject private var dataManager: DataManager
    let title: String
    let subtitle: String
    let assets: [PHAsset]
    @Binding var selectedIDs: Set<String>
    let tint: Color
    let emptyTitle: String
    let emptyMessage: String
    @Binding var previewAsset: CandidatePreviewAsset?
    let onRemove: (PHAsset) -> Void
    let onPrimaryAction: () -> Void
    let primaryTitle: String

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ZStack {
            PhotoDeleteScreenBackground()
            if assets.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(L10n.string("已选 (selectedIDs.count) / (assets.count)"))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(PhotoDeleteStyle.primaryText)
                                Text(subtitle)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                            }
                            Spacer()
                            Button(selectedIDs.count == assets.count ? L10n.string("取消全选") : L10n.string("全选")) {
                                if selectedIDs.count == assets.count { selectedIDs.removeAll() }
                                else { selectedIDs = Set(assets.map(\.localIdentifier)) }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(PhotoDeleteStyle.accent)
                        }

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(assets, id: \.localIdentifier) { asset in
                                cell(asset)
                            }
                        }
                    }
                    .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 116)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { } label: { EmptyView() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button {
                    for asset in assets where selectedIDs.contains(asset.localIdentifier) { onRemove(asset) }
                } label: {
                    Label(L10n.string("恢复"), systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .photoDeleteSecondaryButton()
                .disabled(selectedIDs.isEmpty)

                Button(action: onPrimaryAction) {
                    Label(primaryTitle, systemImage: "trash.fill")
                        .frame(maxWidth: .infinity)
                }
                .photoDeleteDestructiveButton()
                .disabled(selectedIDs.isEmpty)
            }
            .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .sheet(item: $previewAsset) { item in
            CandidatePhotoPreviewView(asset: item.asset, photoLibraryManager: dataManager.photoLibraryManager)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash.slash")
                .font(.system(size: 42, weight: .medium))
                .foregroundColor(PhotoDeleteStyle.tertiaryText)
            Text(emptyTitle)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.primaryText)
            Text(emptyMessage)
                .font(.system(size: 13))
                .foregroundColor(PhotoDeleteStyle.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private func cell(_ asset: PHAsset) -> some View {
        Button {
            previewAsset = CandidatePreviewAsset(asset: asset)
        } label: {
            AlbumAssetThumbnail(assetID: asset.localIdentifier, photoLibraryManager: dataManager.photoLibraryManager, cornerRadius: 12)
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    Button {
                        if selectedIDs.contains(asset.localIdentifier) { selectedIDs.remove(asset.localIdentifier) }
                        else { selectedIDs.insert(asset.localIdentifier) }
                    } label: {
                        Image(systemName: selectedIDs.contains(asset.localIdentifier) ? "checkmark" : "circle")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(selectedIDs.contains(asset.localIdentifier) ? .black : .white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(selectedIDs.contains(asset.localIdentifier) ? tint : Color.black.opacity(0.52)))
                            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .padding(7)
                }
        }
        .buttonStyle(.plain)
    }
}
