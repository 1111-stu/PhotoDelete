import SwiftUI
import Photos

/// Swipe review 中暂存的待删除照片。这里只修改本地候选队列，不触碰系统照片库。
struct PendingDeletionView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<String> = []
    @State private var hasInitializedSelection = false
    @State private var previewAsset: CandidatePreviewAsset?

    private var assets: [PHAsset] {
        dataManager.deleteCandidates.sorted { $0.creationDate ?? .distantPast > $1.creationDate ?? .distantPast }
    }

    var body: some View {
        DeletionQueueScreen(
            title: L10n.string("To delete"),
            assets: assets,
            selectedIDs: $selectedIDs,
            emptyTitle: L10n.string("No Photos Pending Deletion"),
            emptyMessage: L10n.string("Swipe up to place photos here for confirmation."),
            previewAsset: $previewAsset,
            onRemove: { asset in
                dataManager.removeFromDeleteCandidates(asset)
                selectedIDs.remove(asset.localIdentifier)
            },
            onPrimaryAction: { dismiss() },
            secondaryTitle: L10n.string("Remove selected from deletion"),
            primaryTitle: L10n.string("Keep Organizing"),
            secondarySystemImage: "arrow.uturn.backward",
            primarySystemImage: "arrow.right",
            primaryRequiresSelection: false,
            showsModalClose: true
        )
        .onAppear {
            guard !hasInitializedSelection else { return }
            hasInitializedSelection = true
            selectedIDs = Set(assets.map(\.localIdentifier))
        }
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
    @State private var hasInitializedSelection = false
    @State private var previewAsset: CandidatePreviewAsset?
    @State private var showingBatchConfirm = false

    private var assets: [PHAsset] {
        dataManager.deleteCandidates.sorted { $0.creationDate ?? .distantPast > $1.creationDate ?? .distantPast }
    }

    var body: some View {
        DeletionQueueScreen(
            title: L10n.string("Trash"),
            assets: assets,
            selectedIDs: $selectedIDs,
            emptyTitle: L10n.string("Trash Is Empty"),
            emptyMessage: L10n.string("Photos appear here after you swipe up to add them to the deletion queue."),
            previewAsset: $previewAsset,
            onRemove: { asset in
                dataManager.removeFromDeleteCandidates(asset)
                selectedIDs.remove(asset.localIdentifier)
            },
            onPrimaryAction: { showingBatchConfirm = true },
            secondaryTitle: L10n.string("Remove selected from deletion"),
            primaryTitle: L10n.string("Delete Selected"),
            secondarySystemImage: "arrow.uturn.backward",
            primarySystemImage: "trash.fill",
            primaryRequiresSelection: true
        )
        .onAppear {
            guard !hasInitializedSelection else { return }
            hasInitializedSelection = true
            selectedIDs = Set(assets.map(\.localIdentifier))
        }
        .onChange(of: assets.map(\.localIdentifier)) { _ in
            selectedIDs.formIntersection(Set(assets.map(\.localIdentifier)))
        }
        .fullScreenCover(isPresented: $showingBatchConfirm) {
            BatchConfirmView(initialDeleteIDs: selectedIDs, deleteOnly: true)
                .environmentObject(dataManager)
        }
    }
}

private struct DeletionQueueScreen: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.photoDeleteTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let title: String
    let assets: [PHAsset]
    @Binding var selectedIDs: Set<String>
    let emptyTitle: String
    let emptyMessage: String
    @Binding var previewAsset: CandidatePreviewAsset?
    let onRemove: (PHAsset) -> Void
    let onPrimaryAction: () -> Void
    let secondaryTitle: String
    let primaryTitle: String
    let secondarySystemImage: String
    let primarySystemImage: String
    let primaryRequiresSelection: Bool
    var showsModalClose: Bool = false

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
                            Text(L10n.string("Selected \(selectedIDs.count) / \(assets.count)"))
                            .font(.title3.weight(.bold))
                                .foregroundColor(PhotoDeleteStyle.primaryText)
                            Spacer()
                            Button(selectedIDs.count == assets.count ? L10n.string("Deselect All") : L10n.string("Select All")) {
                                if selectedIDs.count == assets.count { selectedIDs.removeAll() }
                                else { selectedIDs = Set(assets.map(\.localIdentifier)) }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(PhotoDeleteStyle.accent)
                            .frame(minHeight: 44)
                        }

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(assets, id: \.localIdentifier) { asset in
                                cell(asset)
                            }
                        }
                    }
                    .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if showsModalClose {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Close")) { dismiss() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button {
                    for asset in assets where selectedIDs.contains(asset.localIdentifier) { onRemove(asset) }
                } label: {
                    Label(secondaryTitle, systemImage: secondarySystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CleanupReviewSecondaryButtonStyle())
                .disabled(selectedIDs.isEmpty)

                Button(action: onPrimaryAction) {
                    Label(primaryTitle, systemImage: primarySystemImage)
                        .frame(maxWidth: .infinity)
                }
                .photoDeletePrimaryButton()
                .disabled(primaryRequiresSelection && selectedIDs.isEmpty)
            }
            .modifier(CleanupReviewFooterStyle())
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cell(_ asset: PHAsset) -> some View {
        CleanupReviewAssetCell(
            asset: asset,
            photoLibraryManager: dataManager.photoLibraryManager,
            isSelected: selectedIDs.contains(asset.localIdentifier),
            onPreview: { previewAsset = CandidatePreviewAsset(asset: asset) },
            onToggleSelection: {
                if selectedIDs.contains(asset.localIdentifier) {
                    selectedIDs.remove(asset.localIdentifier)
                } else {
                    selectedIDs.insert(asset.localIdentifier)
                }
            }
        )
    }
}

/// Shared photo selection affordance for the queue and final review.
struct CleanupReviewAssetCell: View {
    @Environment(\.photoDeleteTheme) private var theme
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager
    let isSelected: Bool
    let onPreview: () -> Void
    let onToggleSelection: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onPreview) {
                AlbumAssetThumbnail(
                    assetID: asset.localIdentifier,
                    photoLibraryManager: photoLibraryManager,
                    cornerRadius: PhotoDeleteStyle.Metrics.thumbnailRadius
                )
                .aspectRatio(1, contentMode: .fit)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("View photo larger"))

            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark" : "circle")
                    .font(.system(size: isSelected ? 11 : 18, weight: .bold))
                    .foregroundStyle(isSelected ? theme.primaryAccentOnFill : .white.opacity(0.9))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(isSelected ? theme.primaryAccent : Color.black.opacity(0.34)))
                    .overlay(Circle().stroke(Color.white.opacity(isSelected ? 0.88 : 0.72), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .accessibilityLabel(
                isSelected
                    ? L10n.string("Deselect")
                    : L10n.string("Select")
            )
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("cleanup-selection-\(asset.localIdentifier)")
        }
    }
}

struct CleanupReviewSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.photoDeleteTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(PhotoDeleteStyle.secondaryText)
            .frame(minHeight: 52)
            .background(configuration.isPressed ? theme.surface : theme.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.42)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct CleanupReviewFooterStyle: ViewModifier {
    @Environment(\.photoDeleteTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background {
                theme.backgroundBottom
                    .overlay(alignment: .top) {
                        Rectangle().fill(theme.hairline).frame(height: 1)
                    }
                    .ignoresSafeArea(edges: .bottom)
            }
    }
}
