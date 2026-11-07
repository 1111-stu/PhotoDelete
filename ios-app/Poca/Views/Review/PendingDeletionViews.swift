import SwiftUI
import Photos

/// Swipe review 中暂存的待删除照片。这里只修改本地候选队列，不触碰系统照片库。
struct PendingDeletionView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    /// 与首页垃圾桶一致：默认不选，先点选 / 全选再移出或删除。
    @State private var selectedIDs: Set<String> = []
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
            emptyMessage: L10n.string("Photos you mark for deletion are collected here. Clean them up whenever you're ready."),
            onRemove: { asset in
                dataManager.removeFromDeleteCandidates(asset)
                selectedIDs.remove(asset.localIdentifier)
            },
            onPrimaryAction: { showingBatchConfirm = true },
            secondaryTitle: L10n.string("Remove selected from deletion"),
            primaryTitle: L10n.string("Delete Selected"),
            secondarySystemImage: "arrow.uturn.backward",
            primarySystemImage: "trash.fill",
            primaryRequiresSelection: true,
            showsModalClose: true,
            primaryIsDestructive: true
        )
        .onChange(of: assets.map(\.localIdentifier)) { _ in
            selectedIDs.formIntersection(Set(assets.map(\.localIdentifier)))
        }
        .fullScreenCover(isPresented: $showingBatchConfirm) {
            BatchConfirmView(initialDeleteIDs: selectedIDs, deleteOnly: true)
                .environmentObject(dataManager)
        }
    }
}

/// 从首页垃圾桶进入的候选处理页。删除动作仍通过 DataManager 的批处理确认。
struct TrashBinView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    /// 与整理中待删除一致：默认不选，先点选 / 全选再移出或删除。
    @State private var selectedIDs: Set<String> = []
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
            emptyMessage: L10n.string("Photos you mark for deletion are collected here. Clean them up whenever you're ready."),
            onRemove: { asset in
                dataManager.removeFromDeleteCandidates(asset)
                selectedIDs.remove(asset.localIdentifier)
            },
            onPrimaryAction: { showingBatchConfirm = true },
            secondaryTitle: L10n.string("Remove selected from deletion"),
            primaryTitle: L10n.string("Delete Selected"),
            secondarySystemImage: "arrow.uturn.backward",
            primarySystemImage: "trash.fill",
            primaryRequiresSelection: true,
            primaryIsDestructive: true
        )
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
    @Environment(\.dismiss) private var dismiss
    let title: String
    let assets: [PHAsset]
    @Binding var selectedIDs: Set<String>
    let emptyTitle: String
    let emptyMessage: String
    let onRemove: (PHAsset) -> Void
    let onPrimaryAction: () -> Void
    let secondaryTitle: String
    let primaryTitle: String
    let secondarySystemImage: String
    let primarySystemImage: String
    let primaryRequiresSelection: Bool
    var showsModalClose: Bool = false
    /// 垃圾桶「删除所选」用 destructive；整理中「继续整理」用琥珀 primary。
    var primaryIsDestructive: Bool = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ZStack {
            PocaScreenBackground()
            if assets.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(L10n.string("Selected \(selectedIDs.count) / \(assets.count)"))
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                                .foregroundColor(Theme.primaryText)
                            Spacer()
                            Button(selectedIDs.count == assets.count ? L10n.string("Deselect All") : L10n.string("Select All")) {
                                if selectedIDs.count == assets.count { selectedIDs.removeAll() }
                                else { selectedIDs = Set(assets.map(\.localIdentifier)) }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.secondaryText)
                            .frame(minHeight: 44)
                        }

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(assets, id: \.localIdentifier) { asset in
                                cell(asset)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.space5)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // 返回/关闭固定在左，页面名靠右，避免左侧控件 + 居中标题的失衡。
        .photoDeletePushedToolbar {
            if #available(iOS 26.0, *) {
                if showsModalClose {
                    ToolbarItem(placement: .topBarLeading) {
                        modalCloseButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    titleLabel
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                if showsModalClose {
                    ToolbarItem(placement: .topBarLeading) {
                        modalCloseButton
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    titleLabel
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // 整理中 / 首页垃圾桶共用左右双钮：左=移出，右=主操作（继续整理或删除所选）。
            dualActionFooter
                .modifier(CleanupReviewFooterStyle())
        }
    }

    /// 页面名放在导航栏右侧；左侧只保留返回/关闭，形成左右分区。
    private var titleLabel: some View {
        Text(title)
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(Theme.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .accessibilityAddTraits(.isHeader)
    }

    private var modalCloseButton: some View {
        PocaCircleIconButton(
            systemName: "xmark",
            accessibilityLabel: L10n.string("Close"),
            action: { dismiss() }
        )
    }

    private var dualActionFooter: some View {
        HStack(spacing: 10) {
            Button(action: removeSelected) {
                Label(secondaryTitle, systemImage: secondarySystemImage)
                    .frame(maxWidth: .infinity)
            }
            .photoDeleteSecondaryButton()
            .disabled(selectedIDs.isEmpty)

            Group {
                if primaryIsDestructive {
                    Button(action: onPrimaryAction) {
                        Label(primaryTitle, systemImage: primarySystemImage)
                            .frame(maxWidth: .infinity)
                    }
                    .photoDeleteDestructiveButton()
                } else {
                    Button(action: onPrimaryAction) {
                        Label(primaryTitle, systemImage: primarySystemImage)
                            .frame(maxWidth: .infinity)
                    }
                    .photoDeletePrimaryButton()
                }
            }
            .disabled(primaryRequiresSelection && selectedIDs.isEmpty)
        }
    }

    private func removeSelected() {
        for asset in assets where selectedIDs.contains(asset.localIdentifier) {
            onRemove(asset)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash.slash")
                .font(.system(size: 42, weight: .medium))
                .foregroundColor(Theme.tertiaryText)
            Text(emptyTitle)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(Theme.primaryText)
            Text(emptyMessage)
                .font(.system(size: 13))
                .foregroundColor(Theme.secondaryText)
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
            onToggleSelection: {
                if selectedIDs.contains(asset.localIdentifier) {
                    selectedIDs.remove(asset.localIdentifier)
                } else {
                    selectedIDs.insert(asset.localIdentifier)
                }
            },
            selectsOnTap: true
        )
    }
}

/// Shared photo selection affordance for the queue and final review.
struct CleanupReviewAssetCell: View {
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager
    let isSelected: Bool
    var onPreview: (() -> Void)? = nil
    let onToggleSelection: () -> Void
    /// 待删除 / 垃圾桶：点整卡切换选中。批确认页仍点图预览、点角标切换。
    var selectsOnTap: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: primaryAction) {
                AlbumAssetThumbnail(
                    assetID: asset.localIdentifier,
                    photoLibraryManager: photoLibraryManager,
                    cornerRadius: Theme.radiusSm
                )
                .aspectRatio(1, contentMode: .fit)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(primaryAccessibilityLabel)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("cleanup-selection-\(asset.localIdentifier)")

            if selectsOnTap {
                selectionBadge
                    .padding(8)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            } else {
                Button(action: onToggleSelection) {
                    selectionBadge
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .accessibilityLabel(
                    isSelected
                        ? L10n.string("Deselect")
                        : L10n.string("Select")
                )
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private func primaryAction() {
        if selectsOnTap {
            onToggleSelection()
        } else {
            onPreview?()
        }
    }

    private var primaryAccessibilityLabel: String {
        if selectsOnTap {
            return isSelected ? L10n.string("Deselect") : L10n.string("Select")
        }
        return L10n.string("View photo larger")
    }

    /// 单层 SF Symbol：未选细圈，已选实心勾——避免圆套圆。
    @ViewBuilder
    private var selectionBadge: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Theme.onAccent, Theme.accent)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.72))
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
        }
    }
}

struct CleanupReviewFooterStyle: ViewModifier {

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Theme.space5)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background {
                Theme.background
                    .overlay(alignment: .top) {
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                    }
                    .ignoresSafeArea(edges: .bottom)
            }
    }
}
