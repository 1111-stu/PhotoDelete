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
            title: L10n.string("To delete"),
            subtitle: L10n.string("Tap thumbnails to select or deselect"),
            assets: assets,
            selectedIDs: $selectedIDs,
            tint: PhotoDeleteStyle.destructive,
            emptyTitle: L10n.string("No Photos Pending Deletion"),
            emptyMessage: L10n.string("Swipe up to place photos here for confirmation."),
            previewAsset: $previewAsset,
            onRemove: { asset in
                dataManager.removeFromDeleteCandidates(asset)
                selectedIDs.remove(asset.localIdentifier)
            },
            onPrimaryAction: { dismiss() },
            primaryTitle: L10n.string("Keep Organizing")
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
            title: L10n.string("Trash"),
            subtitle: L10n.string("\(assets.count) items pending deletion"),
            assets: assets,
            selectedIDs: $selectedIDs,
            tint: PhotoDeleteStyle.destructive,
            emptyTitle: L10n.string("Trash Is Empty"),
            emptyMessage: L10n.string("Photos appear here after you swipe up to add them to the deletion queue."),
            previewAsset: $previewAsset,
            onRemove: { asset in
                dataManager.removeFromDeleteCandidates(asset)
                selectedIDs.remove(asset.localIdentifier)
            },
            onPrimaryAction: { showingDeleteConfirmation = true },
            primaryTitle: L10n.string("Delete \(selectedIDs.count) items")
        )
        .onAppear { selectedIDs = Set(assets.map(\.localIdentifier)) }
        .onChange(of: assets.map(\.localIdentifier)) { _ in
            selectedIDs.formIntersection(Set(assets.map(\.localIdentifier)))
        }
        .confirmationDialog(
            L10n.string("Delete selected photos?"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.string("Confirm Deletion"), role: .destructive) {
                showingBatchConfirm = true
            }
            Button(L10n.string("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("Photos move to Recently Deleted. You can still recover them in the Photos app."))
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
                                Text(L10n.string("Selected \(selectedIDs.count) / \(assets.count)"))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(PhotoDeleteStyle.primaryText)
                                Text(subtitle)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                            }
                            Spacer()
                            Button(selectedIDs.count == assets.count ? L10n.string("Deselect All") : L10n.string("Select All")) {
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
                    Label(L10n.string("Restore"), systemImage: "arrow.uturn.backward")
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
