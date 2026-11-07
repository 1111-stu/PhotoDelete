//
//  CompressionViews.swift
//  Poca
//
//  图片 / 视频压缩：挑选 → 方案 → 执行 → 决断（互斥），历史为次级入口。
//  视觉对齐 Cleanup 浏览页 + FilterSheet + Theme（单琥珀主操作）。
//

import Photos
import SwiftUI

// MARK: - Phase

private enum CompressionScreenPhase {
    case browse
    case running
    case decide
}

// MARK: - Image Compression

struct AdvancedImageCompressionView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var assets: [PHAsset] = []
    @State private var selectedAssetIDs: Set<String> = []
    @State private var compressionPlan: ImageCompressionPlan = .default
    @State private var showingCompressionComparison = false
    @State private var showingHistory = false
    @State private var dismissCompressionResultAfterBatch = false
    @State private var previewAsset: AdvancedPreviewAsset?
    @State private var showBatchConfirm = false
    @State private var compressionOptionsContext: AdvancedImageCompressionOptionsContext?
    @State private var visibleImageLimit = 24
    @State private var isLoadingAssets = false
    @State private var assetLoadGeneration = 0

    private let imageLimitStep = 24

    private var compressionJob: AdvancedImageCompressionJobState {
        dataManager.imageCompressionJob
    }

    private var isCompressing: Bool {
        compressionJob.isCompressing
    }

    private var phase: CompressionScreenPhase {
        if isCompressing { return .running }
        if compressionJob.result != nil { return .decide }
        return .browse
    }

    private var selectedAssets: [PHAsset] {
        compressibleAssets.filter { selectedAssetIDs.contains($0.localIdentifier) }
    }

    private var compressibleAssets: [PHAsset] { assets }

    private var visibleCompressibleAssets: [PHAsset] {
        VisibleListPagination.visibleItems(compressibleAssets, limit: visibleImageLimit)
    }

    private var hasMoreCompressibleAssets: Bool {
        VisibleListPagination.hasMore(totalCount: compressibleAssets.count, limit: visibleImageLimit)
    }

    private var isAllSelected: Bool {
        !visibleCompressibleAssets.isEmpty
            && visibleCompressibleAssets.allSatisfy { selectedAssetIDs.contains($0.localIdentifier) }
    }

    private var librarySizeMB: Double {
        compressibleAssets.reduce(0) { $0 + dataManager.estimatedSizeMB(for: $1) }
    }

    var body: some View {
        ZStack {
            PocaScreenBackground()

            switch phase {
            case .running:
                CompressionRunningView(
                    processedCount: compressionJob.processedCount,
                    totalCount: compressionJob.totalCount,
                    currentProgress: compressionJob.currentProgress,
                    message: compressionJob.message,
                    leaveHint: L10n.string("Keep the app open. Leaving the app may pause compression.")
                )
            case .decide:
                if let result = compressionJob.result {
                    ScrollView {
                        CompressionDecideCard(
                            savedSizeText: result.formattedSavedSize,
                            hasMeaningfulSavings: result.hasMeaningfulSavings,
                            copiesText: result.createdCopiesText,
                            originalSizeText: result.formattedOriginalSize,
                            compressedSizeText: result.formattedCompressedSize,
                            planText: result.plan.title,
                            footnote: result.hasMeaningfulSavings
                                ? L10n.string("Originals are not deleted automatically.")
                                : L10n.string("Compressed images were created, but space savings are limited. Keeping originals is recommended."),
                            failedText: result.failedCount > 0
                                ? String(format: L10n.string("%lld images were not completed"), Int64(result.failedCount))
                                : nil,
                            deleteTitle: L10n.string("Delete Originals"),
                            keepTitle: L10n.string("Keep Originals"),
                            onCompare: showCompressionComparison,
                            onDeleteOriginals: queueOriginalImagesForDeletion,
                            onKeepOriginals: keepOriginalImages,
                            canCompare: !result.createdAssetIdentifiers.isEmpty
                        )
                        .padding(.horizontal, Theme.space5)
                        .padding(.top, Theme.space5)
                        .padding(.bottom, Theme.space8)

                        if let error = compressionJob.errorMessage {
                            Text(error)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.warning)
                                .padding(.horizontal, Theme.space5)
                        }
                    }
                }
            case .browse:
                browseContent
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if phase == .browse, !selectedAssetIDs.isEmpty {
                CompressionBottomBar(
                    title: String(format: L10n.string("Start compressing · %lld"), Int64(selectedAssetIDs.count)),
                    isEnabled: !isCompressing,
                    action: presentCompressionOptions
                )
            }
        }
        .navigationTitle(AdvancedCleanupKind.imageCompression.title)
        .navigationBarTitleDisplayMode(.inline)
        .photoDeletePushedToolbar {
            if phase == .browse {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarTrailing) {
                        historyButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        historyButton
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showBatchConfirm, onDismiss: {
            reloadAssets()
            if dismissCompressionResultAfterBatch {
                dataManager.clearImageCompressionResult()
                dismissCompressionResultAfterBatch = false
            }
        }) {
            BatchConfirmView { deletedAssetIDs in
                dataManager.markImageCompressionOriginalsDeleted(assetIdentifiers: deletedAssetIDs)
            }
            .environmentObject(dataManager)
        }
        .sheet(item: $previewAsset) { item in
            AdvancedAssetPreviewView(
                asset: item.asset,
                photoLibraryManager: dataManager.photoLibraryManager,
                assets: item.assets,
                selectedAssetIDs: $selectedAssetIDs
            )
        }
        .sheet(isPresented: $showingCompressionComparison) {
            if let compressionResult = compressionJob.result {
                AdvancedImageCompressionComparisonSheet(
                    result: compressionResult,
                    photoLibraryManager: dataManager.photoLibraryManager
                )
            }
        }
        .sheet(item: $compressionOptionsContext) { context in
            AdvancedImageCompressionOptionsSheet(
                context: context,
                initialPlan: compressionPlan
            ) { plan, images in
                compressionPlan = plan
                compressSelectedImages(images: images, plan: plan)
            }
            .environmentObject(dataManager)
        }
        .sheet(isPresented: $showingHistory) {
            CompressionImageHistoryBrowser(
                sessions: dataManager.imageCompressionHistoryStore.sessions,
                photoLibraryManager: dataManager.photoLibraryManager,
                onDeleteOriginals: queueCompressedHistoryOriginalImagesForDeletion(session:),
                onPreview: { asset in
                    previewAsset = AdvancedPreviewAsset(asset: asset)
                }
            )
        }
        .task { reloadAssets() }
        .onChange(of: dataManager.imageCompressionHistoryRevision) { _ in
            selectedAssetIDs.removeAll()
            reloadAssets()
            showingCompressionComparison = false
        }
    }

    private var historyButton: some View {
        PocaCircleIconButton(
            systemName: "clock",
            accessibilityLabel: L10n.string("Recent compression history")
        ) {
            showingHistory = true
        }
    }

    @ViewBuilder
    private var browseContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space5) {
                if isLoadingAssets && assets.isEmpty {
                    AdvancedLoadingState(title: L10n.string("Preparing cleanup options"))
                    .padding(.top, Theme.space8)
                } else if assets.isEmpty {
                    AdvancedEmptyState(
                        icon: AdvancedCleanupKind.imageCompression.icon,
                        title: L10n.string("No compressible images found"),
                        subtitle: dataManager.imageCompressionHistoryStore.sessions.isEmpty
                            ? L10n.string("There are no regular images suitable for compression in the current library.")
                            : L10n.string("All shown items are already compressed")
                    )
                    .padding(.top, Theme.space8)
                } else {
                    CompressionBrowseSummary(
                        sizeText: CleanupStatsFormatter.space(librarySizeMB),
                        countText: String(format: L10n.string("%lld images"), Int64(compressibleAssets.count)),
                        hint: L10n.string("Estimated sizes · confirmed after compression"),
                        selectTitle: isAllSelected ? L10n.string("Deselect Shown") : L10n.string("Select Shown"),
                        onToggleSelect: toggleBulkSelection
                    )

                    if let error = compressionJob.errorMessage {
                        Text(error)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.warning)
                    }

                    CompressionAssetGrid(
                        assets: visibleCompressibleAssets,
                        selectedAssetIDs: selectedAssetIDs,
                        columns: 4,
                        photoLibraryManager: dataManager.photoLibraryManager,
                        sizeText: { CleanupStatsFormatter.space(dataManager.estimatedSizeMB(for: $0)) },
                        onToggle: toggleSelection,
                        onPreview: { previewAsset = AdvancedPreviewAsset(asset: $0, assets: visibleCompressibleAssets) },
                        onAppearNearEnd: showMoreCompressibleImagesIfNeeded
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private func reloadAssets() {
        assetLoadGeneration += 1
        let generation = assetLoadGeneration
        isLoadingAssets = true
        dataManager.loadPhotosForAdvancedCleanup(.imageCompression) { loadedAssets in
            guard generation == assetLoadGeneration else { return }
            assets = loadedAssets
            visibleImageLimit = 24
            let loadedIDs = Set(loadedAssets.map(\.localIdentifier))
            selectedAssetIDs = selectedAssetIDs.filter { loadedIDs.contains($0) }
            pruneSelectionToCompressibleAssets()
            isLoadingAssets = false
        }
    }

    private func showMoreCompressibleImages() {
        withAnimation(.easeInOut(duration: 0.18)) {
            visibleImageLimit = VisibleListPagination.advancedLimit(
                totalCount: compressibleAssets.count,
                currentLimit: visibleImageLimit,
                step: imageLimitStep
            )
        }
    }

    private func showMoreCompressibleImagesIfNeeded(currentAsset asset: PHAsset) {
        guard hasMoreCompressibleAssets,
              let index = visibleCompressibleAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }),
              index >= max(visibleCompressibleAssets.count - 6, 0) else { return }
        showMoreCompressibleImages()
    }

    private func toggleSelection(_ asset: PHAsset) {
        guard phase == .browse else { return }
        HapticManager.impact(.light)
        let id = asset.localIdentifier
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
        } else {
            selectedAssetIDs.insert(id)
        }
        dataManager.setImageCompressionError(nil)
    }

    private func toggleBulkSelection() {
        guard phase == .browse else { return }
        HapticManager.impact(.light)
        let visibleIDs = Set(visibleCompressibleAssets.map(\.localIdentifier))
        if isAllSelected {
            selectedAssetIDs.subtract(visibleIDs)
        } else {
            selectedAssetIDs.formUnion(visibleIDs)
        }
        dataManager.setImageCompressionError(nil)
    }

    private func pruneSelectionToCompressibleAssets() {
        let visibleIDs = Set(compressibleAssets.map(\.localIdentifier))
        selectedAssetIDs = selectedAssetIDs.filter { visibleIDs.contains($0) }
    }

    private func presentCompressionOptions() {
        let images = selectedAssets
        guard !images.isEmpty, !isCompressing else { return }
        compressionOptionsContext = AdvancedImageCompressionOptionsContext(assets: images)
    }

    private func compressSelectedImages(images: [PHAsset], plan: ImageCompressionPlan) {
        guard !images.isEmpty, !isCompressing else { return }
        dataManager.clearImageCompressionResult()
        dataManager.startImageCompression(images: images, plan: plan)
    }

    private func showCompressionComparison() {
        guard compressionJob.result?.createdAssetIdentifiers.isEmpty == false else {
            dataManager.setImageCompressionError(L10n.string("The compressed image could not be found right now."))
            return
        }
        showingCompressionComparison = true
    }

    private func queueOriginalImagesForDeletion() {
        guard let compressionResult = compressionJob.result else { return }
        guard compressionResult.hasMeaningfulSavings else {
            dataManager.setImageCompressionError(L10n.string("This did not save much space. Keeping the originals is recommended."))
            return
        }

        let originalIDs = Set(compressionResult.items.map(\.originalAssetIdentifier))
        let fetchedOriginals = PHAsset.fetchAssets(withLocalIdentifiers: Array(originalIDs), options: nil)
        var originalAssets: [PHAsset] = []
        fetchedOriginals.enumerateObjects { asset, _, _ in
            originalAssets.append(asset)
        }
        guard !originalAssets.isEmpty else {
            dataManager.setImageCompressionError(L10n.string("The original image could not be found right now."))
            return
        }

        dataManager.addToDeleteCandidates(originalAssets)
        HapticManager.notify(.warning)
        dismissCompressionResultAfterBatch = true
        showBatchConfirm = true
    }

    private func queueCompressedHistoryOriginalImagesForDeletion(session: ImageCompressionSession) {
        let originalIDs = Set(
            session.items
                .filter { !$0.isOriginalDeleted }
                .map(\.originalAssetIdentifier)
        )
        let fetchedOriginals = PHAsset.fetchAssets(withLocalIdentifiers: Array(originalIDs), options: nil)
        var originalAssets: [PHAsset] = []
        fetchedOriginals.enumerateObjects { asset, _, _ in
            originalAssets.append(asset)
        }
        guard !originalAssets.isEmpty else {
            dataManager.setImageCompressionError(L10n.string("The original image could not be found right now."))
            return
        }

        dataManager.addToDeleteCandidates(originalAssets)
        HapticManager.notify(.warning)
        dismissCompressionResultAfterBatch = false
        showingHistory = false
        showBatchConfirm = true
    }

    private func keepOriginalImages() {
        dataManager.clearImageCompressionResult()
        showingCompressionComparison = false
        selectedAssetIDs.removeAll()
        reloadAssets()
    }
}

// MARK: - Video Compression

struct AdvancedVideoCompressionView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var assets: [PHAsset] = []
    @State private var orderedAssets: [PHAsset] = []
    @State private var videoSizeEstimatesByAssetID: [String: VideoFileSizeEstimate] = [:]
    @State private var selectedAssetIDs: Set<String> = []
    @State private var compressionPlan: VideoCompressionPlan = .default
    @State private var showingCompressionComparison = false
    @State private var showingHistory = false
    @State private var dismissCompressionResultAfterBatch = false
    @State private var previewAsset: AdvancedPreviewAsset?
    @State private var showBatchConfirm = false
    @State private var compressionOptionsContext: AdvancedVideoCompressionOptionsContext?
    @State private var sizeLoadingTask: Task<Void, Never>?
    @State private var visibleVideoLimit = 40
    @State private var isLoadingAssets = false
    @State private var isLoadingVideoSizes = false
    @State private var assetLoadGeneration = 0
    @State private var sizeLoadGeneration = 0
    @State private var processedVideoAssetIDs: Set<String> = []

    private let videoLimitStep = 40
    private let videoSizeUpdateBatchSize = 8

    private var compressionJob: AdvancedVideoCompressionJobState {
        dataManager.videoCompressionJob
    }

    private var isCompressing: Bool {
        compressionJob.isCompressing
    }

    private var phase: CompressionScreenPhase {
        if isCompressing { return .running }
        if compressionJob.result != nil { return .decide }
        return .browse
    }

    private var selectedAssets: [PHAsset] {
        compressibleAssets.filter { selectedAssetIDs.contains($0.localIdentifier) }
    }

    private var compressibleAssets: [PHAsset] {
        orderedAssets.filter { !processedVideoAssetIDs.contains($0.localIdentifier) }
    }

    private var visibleCompressibleAssets: [PHAsset] {
        VisibleListPagination.visibleItems(compressibleAssets, limit: visibleVideoLimit)
    }

    private var hasMoreCompressibleAssets: Bool {
        VisibleListPagination.hasMore(totalCount: compressibleAssets.count, limit: visibleVideoLimit)
    }

    private var isAllSelected: Bool {
        !visibleCompressibleAssets.isEmpty
            && visibleCompressibleAssets.allSatisfy { selectedAssetIDs.contains($0.localIdentifier) }
    }

    private var reliableVideoSizeMBByAssetID: [String: Double] {
        videoSizeEstimatesByAssetID.reduce(into: [String: Double]()) { result, pair in
            guard pair.value.isReliable else { return }
            result[pair.key] = pair.value.sizeMB
        }
    }

    private var iCloudVideoCount: Int {
        compressibleAssets.reduce(0) { partial, asset in
            videoSizeEstimatesByAssetID[asset.localIdentifier]?.source == .iCloud ? partial + 1 : partial
        }
    }

    private var librarySizeMB: Double {
        compressibleAssets.reduce(0) {
            $0 + (reliableSizeMB(for: $1) ?? dataManager.estimatedSizeMB(for: $1))
        }
    }

    var body: some View {
        ZStack {
            PocaScreenBackground()

            switch phase {
            case .running:
                CompressionRunningView(
                    processedCount: compressionJob.processedCount,
                    totalCount: compressionJob.totalCount,
                    currentProgress: compressionJob.currentProgress,
                    message: compressionJob.message,
                    leaveHint: L10n.string("Keep the app open. Leaving the app may pause compression.")
                )
            case .decide:
                if let result = compressionJob.result {
                    ScrollView {
                        CompressionDecideCard(
                            savedSizeText: result.formattedSavedSize,
                            hasMeaningfulSavings: result.hasMeaningfulSavings,
                            copiesText: result.createdCopiesText,
                            originalSizeText: result.formattedOriginalSize,
                            compressedSizeText: result.formattedCompressedSize,
                            planText: result.plan.title,
                            footnote: result.hasMeaningfulSavings
                                ? L10n.string("Originals are not deleted automatically.")
                                : L10n.string("A compressed video was created, but space savings are small. Keep the original for now."),
                            failedText: result.failedCount > 0
                                ? String(format: L10n.string("%lld videos did not finish"), Int64(result.failedCount))
                                : nil,
                            deleteTitle: L10n.string("Delete Originals"),
                            keepTitle: L10n.string("Keep Originals"),
                            onCompare: showCompressionComparison,
                            onDeleteOriginals: queueOriginalVideosForDeletion,
                            onKeepOriginals: keepOriginalVideos,
                            canCompare: !result.createdAssetIdentifiers.isEmpty
                        )
                        .padding(.horizontal, Theme.space5)
                        .padding(.top, Theme.space5)
                        .padding(.bottom, Theme.space8)

                        if let error = compressionJob.errorMessage {
                            Text(error)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.warning)
                                .padding(.horizontal, Theme.space5)
                        }
                    }
                }
            case .browse:
                browseContent
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if phase == .browse, !selectedAssetIDs.isEmpty {
                CompressionBottomBar(
                    title: String(format: L10n.string("Start compressing · %lld"), Int64(selectedAssetIDs.count)),
                    isEnabled: !isCompressing,
                    action: presentCompressionOptions
                )
            }
        }
        .navigationTitle(AdvancedCleanupKind.videoCompression.title)
        .navigationBarTitleDisplayMode(.inline)
        .photoDeletePushedToolbar {
            if phase == .browse {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarTrailing) {
                        historyButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        historyButton
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showBatchConfirm, onDismiss: {
            reloadAssets()
            if dismissCompressionResultAfterBatch {
                dataManager.clearVideoCompressionResult()
                dismissCompressionResultAfterBatch = false
            }
        }) {
            BatchConfirmView { deletedAssetIDs in
                dataManager.markVideoCompressionOriginalsDeleted(assetIdentifiers: deletedAssetIDs)
            }
            .environmentObject(dataManager)
        }
        .sheet(item: $previewAsset) { item in
            AdvancedAssetPreviewView(
                asset: item.asset,
                photoLibraryManager: dataManager.photoLibraryManager,
                assets: item.assets,
                selectedAssetIDs: $selectedAssetIDs
            )
        }
        .sheet(isPresented: $showingCompressionComparison) {
            if let compressionResult = compressionJob.result {
                AdvancedVideoCompressionComparisonSheet(
                    result: compressionResult,
                    photoLibraryManager: dataManager.photoLibraryManager
                )
            }
        }
        .sheet(item: $compressionOptionsContext) { context in
            AdvancedVideoCompressionOptionsSheet(
                context: context,
                initialPlan: compressionPlan,
                knownOriginalSizeMBByAssetID: reliableVideoSizeMBByAssetID
            ) { plan, videos in
                compressionPlan = plan
                compressSelectedVideos(videos: videos, plan: plan)
            }
            .environmentObject(dataManager)
        }
        .sheet(isPresented: $showingHistory) {
            CompressionVideoHistoryBrowser(
                sessions: dataManager.videoCompressionHistoryStore.sessions,
                photoLibraryManager: dataManager.photoLibraryManager,
                onDeleteOriginals: queueCompressedHistoryOriginalVideosForDeletion(session:),
                onPreview: { asset in
                    previewAsset = AdvancedPreviewAsset(asset: asset)
                }
            )
        }
        .task { reloadAssets() }
        .onChange(of: dataManager.videoCompressionHistoryRevision) { _ in
            selectedAssetIDs.removeAll()
            refreshProcessedVideoAssetIDs()
            reloadAssets()
            showingCompressionComparison = false
        }
        .onDisappear {
            sizeLoadingTask?.cancel()
        }
    }

    private var historyButton: some View {
        PocaCircleIconButton(
            systemName: "clock",
            accessibilityLabel: L10n.string("Recent compression history")
        ) {
            showingHistory = true
        }
    }

    @ViewBuilder
    private var browseContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space5) {
                if isLoadingAssets && assets.isEmpty {
                    AdvancedLoadingState(title: L10n.string("Preparing cleanup options"))
                    .padding(.top, Theme.space8)
                } else if assets.isEmpty {
                    AdvancedEmptyState(
                        icon: AdvancedCleanupKind.videoCompression.icon,
                        title: L10n.string("No videos to compress"),
                        subtitle: L10n.string("There are no videos to compress in the current library.")
                    )
                    .padding(.top, Theme.space8)
                } else if compressibleAssets.isEmpty {
                    AdvancedEmptyState(
                        icon: "checkmark.circle",
                        title: L10n.string("No videos need compression"),
                        subtitle: L10n.string("Finished videos stay in recent compression history.")
                    )
                    .padding(.top, Theme.space8)
                } else {
                    CompressionBrowseSummary(
                        sizeText: CleanupStatsFormatter.space(librarySizeMB),
                        countText: String(format: L10n.string("%lld items"), Int64(compressibleAssets.count)),
                        hint: iCloudHint,
                        selectTitle: isAllSelected ? L10n.string("Deselect Shown") : L10n.string("Select Shown"),
                        onToggleSelect: toggleBulkSelection
                    )

                    if let error = compressionJob.errorMessage {
                        Text(error)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.warning)
                    }

                    CompressionAssetGrid(
                        assets: visibleCompressibleAssets,
                        selectedAssetIDs: selectedAssetIDs,
                        columns: 3,
                        photoLibraryManager: dataManager.photoLibraryManager,
                        sizeText: displaySizeText,
                        badgeSystemImage: { asset in
                            videoSizeEstimatesByAssetID[asset.localIdentifier]?.source == .iCloud
                                ? "icloud.and.arrow.down"
                                : nil
                        },
                        onToggle: toggleSelection,
                        onPreview: { previewAsset = AdvancedPreviewAsset(asset: $0, assets: visibleCompressibleAssets) },
                        onAppearNearEnd: showMoreCompressibleVideosIfNeeded
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private var iCloudHint: String {
        if !isLoadingAssets, !isLoadingVideoSizes, iCloudVideoCount > 0 {
            return String(format: L10n.string("%lld videos in iCloud"), Int64(iCloudVideoCount))
        }
        return L10n.string("Estimated sizes · confirmed after compression")
    }

    private func reloadAssets() {
        assetLoadGeneration += 1
        let generation = assetLoadGeneration
        isLoadingAssets = true
        refreshProcessedVideoAssetIDs()
        dataManager.loadPhotosForAdvancedCleanup(.videoCompression) { loadedAssets in
            guard generation == assetLoadGeneration else { return }
            applyLoadedAssets(loadedAssets)
        }
    }

    private func applyLoadedAssets(_ loadedAssets: [PHAsset]) {
        assets = loadedAssets
        visibleVideoLimit = 40
        let loadedIDs = Set(loadedAssets.map(\.localIdentifier))
        selectedAssetIDs = selectedAssetIDs.filter { loadedIDs.contains($0) }
        pruneSelectionToCompressibleAssets()
        seedCachedVideoSizeEstimates(for: loadedAssets)
        refreshOrderedAssets()
        isLoadingAssets = false
        loadVideoSizesForVisiblePendingVideos()
    }

    private func refreshProcessedVideoAssetIDs() {
        processedVideoAssetIDs = Self.makeProcessedVideoAssetIDs(
            from: dataManager.videoCompressionHistoryStore.sessions
        )
    }

    private static func makeProcessedVideoAssetIDs(
        from sessions: [VideoCompressionSession]
    ) -> Set<String> {
        var ids: Set<String> = []
        for session in sessions {
            for item in session.items {
                ids.insert(item.originalAssetIdentifier)
                if let createdAssetIdentifier = item.createdAssetIdentifier {
                    ids.insert(createdAssetIdentifier)
                }
            }
        }
        return ids
    }

    private func displaySizeText(for asset: PHAsset) -> String {
        guard let estimate = videoSizeEstimatesByAssetID[asset.localIdentifier] else {
            return L10n.string("Calculating")
        }
        switch estimate.source {
        case .assetResource:
            return CleanupStatsFormatter.space(estimate.sizeMB)
        case .iCloud:
            return L10n.string("Needs download")
        case .unavailable:
            return L10n.string("Checked when compressing")
        }
    }

    private func reliableSizeMB(for asset: PHAsset) -> Double? {
        guard let estimate = videoSizeEstimatesByAssetID[asset.localIdentifier],
              estimate.isReliable else { return nil }
        return estimate.sizeMB
    }

    private func videoSizeFirstOrder(_ lhs: PHAsset, _ rhs: PHAsset) -> Bool {
        let lhsRank = videoSizeSortRank(for: lhs)
        let rhsRank = videoSizeSortRank(for: rhs)
        if lhsRank.priority != rhsRank.priority { return lhsRank.priority < rhsRank.priority }
        if lhsRank.sizeMB != rhsRank.sizeMB { return lhsRank.sizeMB > rhsRank.sizeMB }
        let lhsDate = lhs.creationDate ?? .distantPast
        let rhsDate = rhs.creationDate ?? .distantPast
        if lhsDate != rhsDate { return lhsDate > rhsDate }
        return lhs.localIdentifier < rhs.localIdentifier
    }

    private func videoSizeSortRank(for asset: PHAsset) -> (priority: Int, sizeMB: Double) {
        guard let estimate = videoSizeEstimatesByAssetID[asset.localIdentifier] else {
            return (priority: 1, sizeMB: dataManager.estimatedSizeMB(for: asset))
        }
        guard estimate.isReliable else {
            return (priority: 1, sizeMB: dataManager.estimatedSizeMB(for: asset))
        }
        return (priority: 0, sizeMB: estimate.sizeMB)
    }

    private func seedCachedVideoSizeEstimates(for loadedAssets: [PHAsset]) {
        for asset in loadedAssets {
            guard let cached = dataManager.cachedVideoFileSizeEstimate(for: asset) else { continue }
            videoSizeEstimatesByAssetID[asset.localIdentifier] = cached
        }
    }

    private func applyVideoSizeEstimates(
        _ estimatesByAssetID: [String: VideoFileSizeEstimate],
        generation: Int
    ) {
        guard generation == sizeLoadGeneration, !estimatesByAssetID.isEmpty else { return }
        for (assetID, estimate) in estimatesByAssetID {
            dataManager.cacheVideoFileSizeEstimate(estimate, forAssetIdentifier: assetID)
            videoSizeEstimatesByAssetID[assetID] = estimate
        }
        refreshOrderedAssets()
    }

    private func refreshOrderedAssets() {
        orderedAssets = assets.sorted(by: videoSizeFirstOrder)
    }

    private func loadVideoSizes(for loadedAssets: [PHAsset]) {
        sizeLoadingTask?.cancel()
        sizeLoadGeneration += 1
        let generation = sizeLoadGeneration
        guard !loadedAssets.isEmpty else {
            isLoadingVideoSizes = false
            return
        }
        isLoadingVideoSizes = true
        sizeLoadingTask = Task {
            var pendingEstimates: [String: VideoFileSizeEstimate] = [:]
            for asset in loadedAssets {
                if Task.isCancelled { break }
                let alreadyLoaded = await MainActor.run {
                    guard generation == sizeLoadGeneration else { return true }
                    if let cached = dataManager.cachedVideoFileSizeEstimate(for: asset) {
                        videoSizeEstimatesByAssetID[asset.localIdentifier] = cached
                        return true
                    }
                    return videoSizeEstimatesByAssetID[asset.localIdentifier] != nil
                }
                if alreadyLoaded { continue }

                do {
                    let estimate = try await dataManager.photoLibraryManager.videoFileSizeEstimate(for: asset)
                    pendingEstimates[asset.localIdentifier] = estimate
                    if pendingEstimates.count >= videoSizeUpdateBatchSize {
                        let estimatesToApply = pendingEstimates
                        pendingEstimates.removeAll()
                        await MainActor.run {
                            applyVideoSizeEstimates(estimatesToApply, generation: generation)
                        }
                    }
                } catch {
                    continue
                }
            }
            if !pendingEstimates.isEmpty {
                let estimatesToApply = pendingEstimates
                await MainActor.run {
                    applyVideoSizeEstimates(estimatesToApply, generation: generation)
                }
            }
            await MainActor.run {
                guard generation == sizeLoadGeneration else { return }
                isLoadingVideoSizes = false
            }
        }
    }

    private func showMoreCompressibleVideos() {
        withAnimation(.easeInOut(duration: 0.18)) {
            visibleVideoLimit = VisibleListPagination.advancedLimit(
                totalCount: compressibleAssets.count,
                currentLimit: visibleVideoLimit,
                step: videoLimitStep
            )
        }
        loadVideoSizesForVisiblePendingVideos()
    }

    private func loadVideoSizesForVisiblePendingVideos() {
        loadVideoSizes(for: visibleCompressibleAssets)
    }

    private func showMoreCompressibleVideosIfNeeded(currentAsset asset: PHAsset) {
        guard hasMoreCompressibleAssets,
              let index = visibleCompressibleAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }),
              index >= max(visibleCompressibleAssets.count - 6, 0) else { return }
        showMoreCompressibleVideos()
    }

    private func toggleSelection(_ asset: PHAsset) {
        guard phase == .browse else { return }
        HapticManager.impact(.light)
        let id = asset.localIdentifier
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
        } else {
            selectedAssetIDs.insert(id)
        }
        dataManager.setVideoCompressionError(nil)
    }

    private func toggleBulkSelection() {
        guard phase == .browse else { return }
        HapticManager.impact(.light)
        let visibleIDs = Set(visibleCompressibleAssets.map(\.localIdentifier))
        if isAllSelected {
            selectedAssetIDs.subtract(visibleIDs)
        } else {
            selectedAssetIDs.formUnion(visibleIDs)
        }
        dataManager.setVideoCompressionError(nil)
    }

    private func pruneSelectionToCompressibleAssets() {
        let visibleIDs = Set(compressibleAssets.map(\.localIdentifier))
        selectedAssetIDs = selectedAssetIDs.filter { visibleIDs.contains($0) }
    }

    private func presentCompressionOptions() {
        let videos = selectedAssets
        guard !videos.isEmpty, !isCompressing else { return }
        compressionOptionsContext = AdvancedVideoCompressionOptionsContext(assets: videos)
    }

    private func compressSelectedVideos(videos: [PHAsset], plan: VideoCompressionPlan) {
        guard !videos.isEmpty, !isCompressing else { return }
        dataManager.clearVideoCompressionResult()
        dataManager.startVideoCompression(videos: videos, plan: plan)
    }

    private func showCompressionComparison() {
        guard compressionJob.result?.createdAssetIdentifiers.isEmpty == false else {
            dataManager.setVideoCompressionError(L10n.string("The compressed video cannot be found right now."))
            return
        }
        showingCompressionComparison = true
    }

    private func queueOriginalVideosForDeletion() {
        guard let compressionResult = compressionJob.result else { return }
        guard compressionResult.hasMeaningfulSavings else {
            dataManager.setVideoCompressionError(L10n.string("This did not noticeably reduce space, so keep the original for now."))
            return
        }

        let originalIDs = Set(compressionResult.items.map(\.originalAssetIdentifier))
        let fetchedOriginals = PHAsset.fetchAssets(withLocalIdentifiers: Array(originalIDs), options: nil)
        var originalAssets: [PHAsset] = []
        fetchedOriginals.enumerateObjects { asset, _, _ in
            originalAssets.append(asset)
        }
        guard !originalAssets.isEmpty else {
            dataManager.setVideoCompressionError(L10n.string("The original video cannot be found right now."))
            return
        }

        dataManager.addToDeleteCandidates(originalAssets)
        HapticManager.notify(.warning)
        dismissCompressionResultAfterBatch = true
        showBatchConfirm = true
    }

    private func queueCompressedHistoryOriginalVideosForDeletion(session: VideoCompressionSession) {
        let originalIDs = Set(
            session.items
                .filter { !$0.isOriginalDeleted }
                .map(\.originalAssetIdentifier)
        )
        let fetchedOriginals = PHAsset.fetchAssets(withLocalIdentifiers: Array(originalIDs), options: nil)
        var originalAssets: [PHAsset] = []
        fetchedOriginals.enumerateObjects { asset, _, _ in
            originalAssets.append(asset)
        }
        guard !originalAssets.isEmpty else {
            dataManager.setVideoCompressionError(L10n.string("The original video cannot be found right now."))
            return
        }

        dataManager.addToDeleteCandidates(originalAssets)
        HapticManager.notify(.warning)
        dismissCompressionResultAfterBatch = false
        showingHistory = false
        showBatchConfirm = true
    }

    private func keepOriginalVideos() {
        dataManager.clearVideoCompressionResult()
        showingCompressionComparison = false
        selectedAssetIDs.removeAll()
        reloadAssets()
    }
}

// MARK: - Shared chrome

private struct CompressionBrowseSummary: View {
    let sizeText: String
    let countText: String
    let hint: String
    let selectTitle: String
    let onToggleSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(sizeText)
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                    .foregroundStyle(Theme.primaryText)
                Spacer(minLength: 8)
                Text(countText)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(hint)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button(selectTitle, action: onToggleSelect)
                .font(.caption.weight(.semibold))
                .tint(Theme.accent)

            Theme.hairline
                .frame(height: 1)
                .padding(.top, 6)
        }
        .padding(.horizontal, 4)
    }
}

private struct CompressionAssetGrid: View {
    let assets: [PHAsset]
    let selectedAssetIDs: Set<String>
    let columns: Int
    let photoLibraryManager: PhotoLibraryManager
    let sizeText: (PHAsset) -> String
    var badgeSystemImage: ((PHAsset) -> String?)? = nil
    let onToggle: (PHAsset) -> Void
    let onPreview: (PHAsset) -> Void
    let onAppearNearEnd: (PHAsset) -> Void

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns),
            spacing: 10
        ) {
            ForEach(assets, id: \.localIdentifier) { asset in
                CompressionAssetCell(
                    asset: asset,
                    isSelected: selectedAssetIDs.contains(asset.localIdentifier),
                    sizeText: sizeText(asset),
                    badgeSystemImage: badgeSystemImage?(asset),
                    photoLibraryManager: photoLibraryManager,
                    onToggle: { onToggle(asset) },
                    onPreview: { onPreview(asset) }
                )
                .onAppear { onAppearNearEnd(asset) }
            }
        }
    }
}

private struct CompressionAssetCell: View {
    let asset: PHAsset
    let isSelected: Bool
    let sizeText: String
    let badgeSystemImage: String?
    let photoLibraryManager: PhotoLibraryManager
    let onToggle: () -> Void
    let onPreview: () -> Void

    var body: some View {
        Button(action: onPreview) {
            AlbumAssetThumbnail(
                assetID: asset.localIdentifier,
                photoLibraryManager: photoLibraryManager,
                emptyIcon: asset.mediaType == .video ? "video" : "photo"
            )
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 4) {
                    if let badgeSystemImage {
                        Image(systemName: badgeSystemImage)
                            .font(.system(size: 9, weight: .bold))
                    }
                    Text(sizeText)
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(Color.white.opacity(0.92))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.45), in: Capsule())
                .padding(6)
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                        .stroke(Theme.accent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        isSelected ? Theme.onAccent : Color.white.opacity(0.92),
                        isSelected ? Theme.accent : Color.black.opacity(0.35)
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? L10n.string("Deselect Shown") : L10n.string("Select Shown"))
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct CompressionBottomBar: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .photoDeletePrimaryButton()
        .disabled(!isEnabled)
        .padding(.horizontal, Theme.space5)
        .padding(.vertical, 12)
        .background(Theme.background)
    }
}

private struct CompressionRunningView: View {
    let processedCount: Int
    let totalCount: Int
    let currentProgress: Double
    let message: String?
    let leaveHint: String

    private var combinedProgress: Double {
        guard totalCount > 0 else { return 0 }
        return min((Double(processedCount) + min(max(currentProgress, 0), 1)) / Double(totalCount), 1)
    }

    var body: some View {
        VStack(spacing: Theme.space4) {
            Spacer()

            Text(String(format: L10n.string("Compressing %lld/%lld"), Int64(processedCount), Int64(totalCount)))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.primaryText)

            ProgressView(value: combinedProgress)
                .tint(Theme.primaryText.opacity(0.55))
                .padding(.horizontal, Theme.space8)

            if let message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.space6)
            }

            Text(leaveHint)
                .font(.caption)
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.space6)
                .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CompressionDecideCard: View {
    let savedSizeText: String
    let hasMeaningfulSavings: Bool
    let copiesText: String
    let originalSizeText: String
    let compressedSizeText: String
    let planText: String
    let footnote: String
    let failedText: String?
    let deleteTitle: String
    let keepTitle: String
    let onCompare: () -> Void
    let onDeleteOriginals: () -> Void
    let onKeepOriginals: () -> Void
    let canCompare: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space4) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.string("Can Save"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)

                Text(savedSizeText)
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(hasMeaningfulSavings ? Theme.accent : Theme.secondaryText)

                Text(copiesText)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }

            HStack(spacing: 0) {
                Text("\(originalSizeText)  →  \(compressedSizeText)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.primaryText)
                Spacer(minLength: 8)
                Text(planText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(footnote)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let failedText {
                Text(failedText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.warning)
            }

            VStack(spacing: 10) {
                // 主路径 = 决断；对比降为次级。
                Button(action: onKeepOriginals) {
                    Text(keepTitle)
                        .frame(maxWidth: .infinity)
                }
                .photoDeletePrimaryButton()

                Button(action: onDeleteOriginals) {
                    Text(deleteTitle)
                        .frame(maxWidth: .infinity)
                }
                .photoDeleteDestructiveButton()
                .disabled(!hasMeaningfulSavings)

                Button(action: onCompare) {
                    Text(L10n.string("Compare"))
                        .frame(maxWidth: .infinity)
                }
                .photoDeleteSecondaryButton()
                .disabled(!canCompare)
            }
            .padding(.top, 4)
        }
        .padding(Theme.space4)
        .photoDeleteCard()
    }
}

// MARK: - Options

struct AdvancedImageCompressionOptionsContext: Identifiable {
    let id = UUID()
    let assets: [PHAsset]
    var count: Int { assets.count }
}

struct AdvancedVideoCompressionOptionsContext: Identifiable {
    let id = UUID()
    let assets: [PHAsset]
    var count: Int { assets.count }
}

struct AdvancedImageCompressionOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager

    let context: AdvancedImageCompressionOptionsContext
    let onStart: (ImageCompressionPlan, [PHAsset]) -> Void
    @State private var plan: ImageCompressionPlan

    init(
        context: AdvancedImageCompressionOptionsContext,
        initialPlan: ImageCompressionPlan,
        onStart: @escaping (ImageCompressionPlan, [PHAsset]) -> Void
    ) {
        self.context = context
        self.onStart = onStart
        _plan = State(initialValue: initialPlan)
    }

    private var visibleEstimate: ImageCompressionEstimate {
        dataManager.estimatedImageCompressionEstimate(for: context.assets, plan: plan)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.space5) {
                    compressionEstimateHeader(
                        savedText: CleanupStatsFormatter.space(visibleEstimate.estimatedSavedMidMB),
                        pathText: String(
                            format: L10n.string("About %@ → %@"),
                            visibleEstimate.formattedOriginalSize,
                            CleanupStatsFormatter.space(visibleEstimate.estimatedCompressedMidMB)
                        )
                    )

                    FilterSheetSection(title: L10n.string("Quality")) {
                        FilterGlassSegmentedControl(
                            options: ImageCompressionQuality.allCases.map {
                                FilterSegmentOption(value: $0, title: $0.compactTitle)
                            },
                            selection: $plan.quality
                        )
                    }

                    FilterSheetSection(title: L10n.string("Dimensions")) {
                        FilterGlassSegmentedControl(
                            options: ImageCompressionSize.allCases.map {
                                FilterSegmentOption(value: $0, title: compactImageSizeTitle($0))
                            },
                            selection: $plan.size
                        )
                    }

                    Text(L10n.string("Originals are not deleted automatically."))
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(Theme.space5)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L10n.string("Compression plan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                FilterSheetPlainToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Cancel")) { dismiss() }
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    let selectedPlan = plan
                    let selectedAssets = context.assets
                    dismiss()
                    onStart(selectedPlan, selectedAssets)
                } label: {
                    Text(String(format: L10n.string("Start compressing · %lld"), Int64(context.count)))
                        .frame(maxWidth: .infinity)
                }
                .photoDeletePrimaryButton()
                .padding(.horizontal, Theme.space5)
                .padding(.vertical, 12)
                .background(Theme.background.opacity(0.94))
            }
        }
    }

    private func compactImageSizeTitle(_ size: ImageCompressionSize) -> String {
        switch size {
        case .original: return L10n.string("Original")
        case .automatic: return L10n.string("Auto")
        case .large: return L10n.string("2400 px")
        case .medium: return L10n.string("1600 px")
        }
    }
}

struct AdvancedVideoCompressionOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataManager: DataManager

    let context: AdvancedVideoCompressionOptionsContext
    let knownOriginalSizeMBByAssetID: [String: Double]
    let onStart: (VideoCompressionPlan, [PHAsset]) -> Void
    @State private var plan: VideoCompressionPlan

    init(
        context: AdvancedVideoCompressionOptionsContext,
        initialPlan: VideoCompressionPlan,
        knownOriginalSizeMBByAssetID: [String: Double],
        onStart: @escaping (VideoCompressionPlan, [PHAsset]) -> Void
    ) {
        self.context = context
        self.knownOriginalSizeMBByAssetID = knownOriginalSizeMBByAssetID
        self.onStart = onStart
        _plan = State(initialValue: initialPlan)
    }

    private var visibleEstimate: VideoCompressionEstimate? {
        let hasReliable = context.assets.allSatisfy { knownOriginalSizeMBByAssetID[$0.localIdentifier] != nil }
        guard hasReliable else { return nil }
        return dataManager.estimatedVideoCompressionEstimate(
            for: context.assets,
            plan: plan,
            knownOriginalSizeMBByAssetID: knownOriginalSizeMBByAssetID
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.space5) {
                    if let visibleEstimate {
                        compressionEstimateHeader(
                            savedText: CleanupStatsFormatter.space(visibleEstimate.estimatedSavedMidMB),
                            pathText: String(
                                format: L10n.string("About %@ → %@"),
                                visibleEstimate.formattedOriginalSize,
                                CleanupStatsFormatter.space(visibleEstimate.estimatedCompressedMidMB)
                            )
                        )
                    } else {
                        Text(L10n.string("Actual size checked when compressing"))
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }

                    FilterSheetSection(title: L10n.string("Quality")) {
                        FilterGlassSegmentedControl(
                            options: VideoCompressionQuality.allCases.map {
                                FilterSegmentOption(value: $0, title: $0.compactTitle)
                            },
                            selection: $plan.quality
                        )
                    }

                    FilterSheetSection(title: L10n.string("Resolution")) {
                        FilterGlassSegmentedControl(
                            options: VideoCompressionResolution.allCases.map {
                                FilterSegmentOption(value: $0, title: compactResolutionTitle($0))
                            },
                            selection: $plan.resolution
                        )
                    }

                    Text(L10n.string("Originals are not deleted automatically."))
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(Theme.space5)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L10n.string("Compression plan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                FilterSheetPlainToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("Cancel")) { dismiss() }
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    let selectedPlan = plan
                    let selectedAssets = context.assets
                    dismiss()
                    onStart(selectedPlan, selectedAssets)
                } label: {
                    Text(String(format: L10n.string("Start compressing · %lld"), Int64(context.count)))
                        .frame(maxWidth: .infinity)
                }
                .photoDeletePrimaryButton()
                .padding(.horizontal, Theme.space5)
                .padding(.vertical, 12)
                .background(Theme.background.opacity(0.94))
            }
        }
    }

    private func compactResolutionTitle(_ resolution: VideoCompressionResolution) -> String {
        switch resolution {
        case .original: return L10n.string("Original")
        case .automatic: return L10n.string("Auto")
        case .p1080: return L10n.string("1080p")
        case .p720: return L10n.string("720p")
        }
    }
}

private func compressionEstimateHeader(savedText: String, pathText: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.string("Estimated saved"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(savedText)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
        }

        Text(pathText)
            .font(.caption)
            .foregroundStyle(Theme.secondaryText)
    }
}

// MARK: - Progress / iCloud (also used by Advanced hub)

struct AdvancedVideoCompressionProgressCard: View {
    let processedCount: Int
    let totalCount: Int
    let currentProgress: Double
    let message: String?

    private var combinedProgress: Double {
        guard totalCount > 0 else { return 0 }
        return min((Double(processedCount) + min(max(currentProgress, 0), 1)) / Double(totalCount), 1)
    }

    var body: some View {
        HStack(spacing: 12) {
            ProgressView(value: combinedProgress)
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.primaryText.opacity(0.55)))
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: L10n.string("Compressing %lld/%lld"), Int64(processedCount), Int64(totalCount)))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)

                Text(message ?? L10n.string("Compressing video"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .photoDeleteCard()
    }
}

struct AdvancedVideoCompressionICloudInfoCard: View {
    let count: Int
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(format: L10n.string("%lld videos in iCloud"), Int64(count)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(14)
            .photoDeleteCard()
        }
        .buttonStyle(.plain)
    }
}
