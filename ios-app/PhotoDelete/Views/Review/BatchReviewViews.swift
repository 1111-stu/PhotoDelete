//
//  BatchReviewViews.swift
//  PhotoDelete
//

import SwiftUI
import AVKit
import CoreLocation
import Photos
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 批量确认视图
struct BatchConfirmView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var previewAsset: CandidatePreviewAsset?
    @State private var completedCelebration: CleanupCelebration?
    @State private var showAchievements = false
    @State private var selectedDeleteIDs: Set<String> = []
    @State private var selectedFavoriteIDs: Set<String> = []
    @State private var hasInitializedSelection = false
    @State private var completedDeletedIDs: Set<String> = []
    @State private var fileSizeEstimatesByAssetID: [String: AssetFileSizeEstimate] = [:]
    @State private var isLoadingFileSizes = false
    let albumInfo: AlbumInfo?
    let onComplete: ((Set<String>) -> Void)?
    private let initialDeleteIDs: Set<String>?
    private let initialFavoriteIDs: Set<String>?
    private let deleteOnly: Bool

    init(
        initialDeleteIDs: Set<String>? = nil,
        initialFavoriteIDs: Set<String>? = nil,
        deleteOnly: Bool = false,
        albumInfo: AlbumInfo? = nil,
        onComplete: ((Set<String>) -> Void)? = nil
    ) {
        self.initialDeleteIDs = initialDeleteIDs
        self.initialFavoriteIDs = initialFavoriteIDs
        self.deleteOnly = deleteOnly
        self.albumInfo = albumInfo
        self.onComplete = onComplete
    }

    private var hasSelectedOperations: Bool {
        dataManager.deleteCandidates.contains { selectedDeleteIDs.contains($0.localIdentifier) }
            || (!deleteOnly && dataManager.favoriteCandidates.contains { selectedFavoriteIDs.contains($0.localIdentifier) })
    }

    var body: some View {
        ZStack {
            PhotoDeleteScreenBackground()

            if let completedCelebration {
                BatchCleanupCompletionView(
                    celebration: completedCelebration,
                    onViewAchievements: { showAchievements = true },
                    onContinue: finishCompletedFlow
                )
            } else {
                let deleteAssets = sortedAssets(Array(dataManager.deleteCandidates))
                let favoriteAssets = deleteOnly ? [] : sortedAssets(Array(dataManager.favoriteCandidates))
                let selectedDeleteAssets = deleteAssets.filter { selectedDeleteIDs.contains($0.localIdentifier) }
                let selectedFavoriteAssets = favoriteAssets.filter { selectedFavoriteIDs.contains($0.localIdentifier) }
                let deletedContentSizeSummary = DeletedContentSizeSummary.make(
                    assetIdentifiers: selectedDeleteAssets.map(\.localIdentifier),
                    estimatesByAssetID: fileSizeEstimatesByAssetID
                )

                confirmationContent(
                    deleteAssets: deleteAssets,
                    favoriteAssets: favoriteAssets,
                    selectedDeleteAssets: selectedDeleteAssets,
                    selectedFavoriteAssets: selectedFavoriteAssets,
                    deletedContentSizeSummary: deletedContentSizeSummary
                )
            }
        }
        .onAppear(perform: selectAllPendingCandidates)
        .task(id: isProcessing) {
            guard !isProcessing else { return }
            await loadDeleteCandidateFileSizes()
        }
        .sheet(item: $previewAsset) { previewAsset in
            CandidatePhotoPreviewView(
                asset: previewAsset.asset,
                photoLibraryManager: dataManager.photoLibraryManager
            )
        }
        .fullScreenCover(isPresented: $showAchievements) {
            NavigationStack {
                CleanupAchievementsView(
                    statsStore: dataManager.cleanupStatsStore,
                    showsDoneButton: true
                )
            }
        }
    }

    private func confirmationContent(
        deleteAssets: [PHAsset],
        favoriteAssets: [PHAsset],
        selectedDeleteAssets: [PHAsset],
        selectedFavoriteAssets: [PHAsset],
        deletedContentSizeSummary: DeletedContentSizeSummary
    ) -> some View {
        let hasVisiblePendingOperations = !deleteAssets.isEmpty || !favoriteAssets.isEmpty
        let showsOnlyDeletions = !deleteAssets.isEmpty && favoriteAssets.isEmpty
        let navigationTitle = showsOnlyDeletions
            ? L10n.string("To Delete · \(selectedDeleteAssets.count)/\(deleteAssets.count)")
            : L10n.string("Confirm Cleanup")

        return NavigationStack {
            ZStack {
                PhotoDeleteScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if hasVisiblePendingOperations {
                            if !deleteAssets.isEmpty {
                                CandidatePreviewSection(
                                    title: showsOnlyDeletions ? nil : L10n.string("To delete"),
                                    assets: deleteAssets,
                                    selectedCount: selectedDeleteAssets.count,
                                    selectedAssetIDs: selectedDeleteIDs,
                                    photoLibraryManager: dataManager.photoLibraryManager,
                                    onPreview: { previewAsset = CandidatePreviewAsset(asset: $0) },
                                    onToggleSelection: toggleDeleteSelection,
                                    onToggleAll: {
                                        selectedDeleteIDs = selectedDeleteAssets.count == deleteAssets.count
                                            ? [] : Set(deleteAssets.map(\.localIdentifier))
                                    },
                                    sizeSummary: AnyView(deletedContentSizeText(deletedContentSizeSummary))
                                )
                            }
                            if !favoriteAssets.isEmpty {
                                CandidatePreviewSection(
                                    title: L10n.string("Favorite"),
                                    assets: favoriteAssets,
                                    selectedCount: selectedFavoriteAssets.count,
                                    selectedAssetIDs: selectedFavoriteIDs,
                                    photoLibraryManager: dataManager.photoLibraryManager,
                                    onPreview: { previewAsset = CandidatePreviewAsset(asset: $0) },
                                    onToggleSelection: toggleFavoriteSelection,
                                    onToggleAll: {
                                        selectedFavoriteIDs = selectedFavoriteAssets.count == favoriteAssets.count
                                            ? [] : Set(favoriteAssets.map(\.localIdentifier))
                                    }
                                )
                            }
                        } else {
                            Text(L10n.string("No pending operations"))
                                .font(.body)
                                .foregroundColor(Theme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(Theme.warning)
                                .accessibilityIdentifier("cleanup-error")
                        }
                    }
                    .frame(maxWidth: 620, alignment: .leading)
                    .padding(.horizontal, Theme.space5)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .disabled(isProcessing)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: cancelOperations) {
                        Label(L10n.string("Back"), systemImage: "chevron.left")
                    }
                    .foregroundStyle(Theme.secondaryText)
                    .disabled(isProcessing)
                    .accessibilityIdentifier("cleanup-back")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 16) {
                    if !deleteAssets.isEmpty {
                        Label(
                            L10n.string("Deleted items move to Recently Deleted, so storage may not be freed immediately."),
                            systemImage: "info.circle"
                        )
                        .font(.footnote)
                        .foregroundColor(Theme.secondaryText)
                        .accessibilityIdentifier("cleanup-consequence")
                    }
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 10) {
                            cancelPendingButton(hasVisiblePendingOperations: hasVisiblePendingOperations)
                            confirmButton
                        }
                    } else {
                        HStack(spacing: 10) {
                            cancelPendingButton(hasVisiblePendingOperations: hasVisiblePendingOperations)
                            confirmButton
                        }
                    }
                }
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
                .modifier(CleanupReviewFooterStyle())
            }
        }
        .interactiveDismissDisabled(isProcessing)
    }

    private var confirmButton: some View {
        Button(action: executeBatchOperations) {
            HStack(spacing: 8) {
                if isProcessing { ProgressView().tint(Theme.destructive) }
                Text(isProcessing ? L10n.string("Running...") : L10n.string("Confirm Cleanup"))
            }
            .frame(maxWidth: .infinity, minHeight: 22)
        }
        .photoDeleteDestructiveButton()
        .disabled(isProcessing || !hasSelectedOperations)
        .accessibilityIdentifier("cleanup-confirm")
    }

    private func cancelPendingButton(hasVisiblePendingOperations: Bool) -> some View {
        Button(action: cancelAllPendingOperations) {
            Text(deleteOnly ? L10n.string("Cancel Pending Deletions") : L10n.string("Cancel All Actions"))
                .frame(maxWidth: .infinity, minHeight: 22)
        }
        .photoDeleteSecondaryButton()
        .disabled(isProcessing || !hasVisiblePendingOperations)
        .accessibilityIdentifier("cleanup-cancel-all")
    }

    private func executeBatchOperations() {
        let deletedAssets = sortedAssets(Array(dataManager.deleteCandidates))
            .filter { selectedDeleteIDs.contains($0.localIdentifier) }
        let favoriteAssets = sortedAssets(Array(dataManager.favoriteCandidates))
            .filter { selectedFavoriteIDs.contains($0.localIdentifier) }

        guard !deletedAssets.isEmpty || !favoriteAssets.isEmpty else {
            dismiss()
            return
        }

        isProcessing = true
        errorMessage = nil
        let estimatedSpaceSaved = dataManager.deletedContentSizeSummary(
            for: deletedAssets
        ).knownSizeMB
        dataManager.executeBatchOperations(
            deleteAssets: deletedAssets,
            favoriteAssets: favoriteAssets
        ) { success, error, celebration in
            DispatchQueue.main.async {
                isProcessing = false
                if success {
                    completedDeletedIDs = Set(deletedAssets.map(\.localIdentifier))
                    completedCelebration = celebration ?? CleanupCelebration(
                        deletedPhotos: deletedAssets.count,
                        favoritedPhotos: favoriteAssets.count,
                        organizedPhotos: deletedAssets.count + favoriteAssets.count,
                        estimatedSpaceSavedMB: estimatedSpaceSaved,
                        totalDeletedPhotos: dataManager.cleanupStatsStore.summary.deletedPhotos,
                        totalSpaceSavedMB: dataManager.cleanupStatsStore.summary.estimatedSpaceSavedMB,
                        currentStreakDays: dataManager.cleanupStatsStore.currentStreakDays,
                        nextAchievementProgress: dataManager.cleanupStatsStore.nextAchievementProgress
                    )
                    playCompletionHaptics()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        dataManager.recordDeletedPhotosFromAlbum(
                            albumID: albumInfo?.id,
                            deletedAssets: deletedAssets
                        )
                    }
                } else {
                    errorMessage = L10n.string("Operation failed. Try again later.")
                }
            }
        }
    }

    private func selectAllPendingCandidates() {
        guard !hasInitializedSelection else { return }
        hasInitializedSelection = true
        let availableDeleteIDs = Set(dataManager.deleteCandidates.map(\.localIdentifier))
        let availableFavoriteIDs = Set(dataManager.favoriteCandidates.map(\.localIdentifier))
        selectedDeleteIDs = initialDeleteIDs.map { $0.intersection(availableDeleteIDs) } ?? availableDeleteIDs
        selectedFavoriteIDs = deleteOnly
            ? []
            : initialFavoriteIDs.map { $0.intersection(availableFavoriteIDs) } ?? availableFavoriteIDs
    }

    @ViewBuilder
    private func deletedContentSizeText(_ summary: DeletedContentSizeSummary) -> some View {
        if summary.totalAssetCount == 0 {
            Text(L10n.string("No items selected"))
        } else if summary.knownAssetCount > 0 {
            VStack(alignment: .leading, spacing: 3) {
                if summary.unknownAssetCount > 0 {
                    Text(L10n.string("Estimated known space to reclaim: about \(CleanupStatsFormatter.fileSize(summary.knownSizeMB))"))
                } else {
                    Text(L10n.string("Estimated space to reclaim: about \(CleanupStatsFormatter.fileSize(summary.knownSizeMB))"))
                }
                if isLoadingFileSizes {
                    Text(
                        L10n.string(
                            "Reading file sizes \(summary.knownAssetCount)/\(summary.totalAssetCount)"
                        )
                    )
                    .font(.caption)
                    .foregroundColor(Theme.secondaryText)
                } else if summary.unknownAssetCount > 0 {
                    Text(L10n.string("Size unavailable for \(summary.unknownAssetCount) items"))
                        .font(.caption)
                        .foregroundColor(Theme.secondaryText)
                }
            }
        } else if isLoadingFileSizes {
            Text(L10n.string("Reading file sizes"))
                .foregroundColor(Theme.secondaryText)
        } else {
            Text(L10n.string("File sizes are currently unavailable"))
                .foregroundColor(Theme.secondaryText)
        }
    }

    private func loadDeleteCandidateFileSizes() async {
        let assets = sortedAssets(Array(dataManager.deleteCandidates))
        guard !assets.isEmpty else { return }

        var accumulatedEstimates: [String: AssetFileSizeEstimate] = [:]
        for asset in assets {
            if let cached = dataManager.cachedAssetFileSizeEstimate(for: asset) {
                accumulatedEstimates[asset.localIdentifier] = cached
            }
        }
        fileSizeEstimatesByAssetID = accumulatedEstimates

        let missingAssets = assets.filter {
            accumulatedEstimates[$0.localIdentifier] == nil
        }
        guard !missingAssets.isEmpty else { return }

        isLoadingFileSizes = true
        defer { isLoadingFileSizes = false }

        var pendingEstimates: [String: AssetFileSizeEstimate] = [:]
        for asset in missingAssets {
            guard !Task.isCancelled else { return }

            let estimate: AssetFileSizeEstimate
            do {
                if asset.mediaType == .video {
                    estimate = try await dataManager.photoLibraryManager.videoFileSizeEstimate(for: asset)
                } else {
                    estimate = try await dataManager.photoLibraryManager.photoFileSizeEstimate(for: asset)
                }
            } catch is CancellationError {
                return
            } catch {
                estimate = AssetFileSizeEstimate(sizeMB: 0, source: .unavailable)
            }

            dataManager.cacheAssetFileSizeEstimate(estimate, for: asset)
            pendingEstimates[asset.localIdentifier] = estimate

            if pendingEstimates.count >= 12 {
                fileSizeEstimatesByAssetID.merge(pendingEstimates) { _, latest in latest }
                pendingEstimates.removeAll(keepingCapacity: true)
            }
        }

        if !pendingEstimates.isEmpty {
            fileSizeEstimatesByAssetID.merge(pendingEstimates) { _, latest in latest }
        }
    }

    private func toggleDeleteSelection(_ asset: PHAsset) {
        HapticManager.impact(.light)
        let id = asset.localIdentifier
        if selectedDeleteIDs.contains(id) {
            selectedDeleteIDs.remove(id)
        } else {
            selectedDeleteIDs.insert(id)
        }
    }

    private func toggleFavoriteSelection(_ asset: PHAsset) {
        HapticManager.impact(.light)
        let id = asset.localIdentifier
        if selectedFavoriteIDs.contains(id) {
            selectedFavoriteIDs.remove(id)
        } else {
            selectedFavoriteIDs.insert(id)
        }
    }

    private func playCompletionHaptics() {
        HapticManager.notify(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            HapticManager.impact(.light)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            HapticManager.impact(.medium)
        }
    }

    private func finishCompletedFlow() {
        onComplete?(completedDeletedIDs)
        dismiss()
    }

    private func cancelOperations() {
        dismiss()
    }

    private func cancelAllPendingOperations() {
        selectedDeleteIDs.removeAll()
        selectedFavoriteIDs.removeAll()
        if deleteOnly {
            for asset in Array(dataManager.deleteCandidates) {
                dataManager.removeFromDeleteCandidates(asset)
            }
        } else {
            dataManager.cancelAllOperations()
        }
        dismiss()
    }

    private func sortedAssets(_ assets: [PHAsset]) -> [PHAsset] {
        assets.sorted { lhs, rhs in
            let lhsDate = lhs.creationDate ?? .distantPast
            let rhsDate = rhs.creationDate ?? .distantPast
            if lhsDate == rhsDate {
                return lhs.localIdentifier < rhs.localIdentifier
            }
            return lhsDate > rhsDate
        }
    }
}

private struct BatchCleanupCompletionView: View {
    let celebration: CleanupCelebration
    let onViewAchievements: () -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false
    @State private var progressFill = 0.0
    @State private var celebrationTrigger = 0

    var body: some View {
        ZStack {
            Theme.background.opacity(0.72)
                .ignoresSafeArea()

            VStack {
                Spacer(minLength: 24)

                VStack(spacing: 16) {
                    celebrationVisual
                    completionHeader
                    cleanupSummarySection
                    if AppConstants.achievementsEnabled {
                        progressSnapshotSection
                    }
                    completionActions
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 22)
                .frame(maxWidth: 540)
                .photoDeleteCard()

                Spacer(minLength: 24)
            }
            .padding(.horizontal, Theme.space5)
        }
        .task {
            await startCompletionAnimation()
        }
    }

    @MainActor
    private func startCompletionAnimation() async {
        let targetProgress = min(max(celebration.nextAchievementProgress?.progress ?? 1, 0), 1)
        if reduceMotion {
            animate = true
            progressFill = targetProgress
            return
        }

        animate = false
        progressFill = 0

        try? await Task.sleep(nanoseconds: 80_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.28)) {
            animate = true
        }
        celebrationTrigger += 1

        try? await Task.sleep(nanoseconds: 220_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.58)) {
            progressFill = targetProgress
        }
    }

    private var celebrationVisual: some View {
        ZStack {
            Circle()
                .fill(Theme.warning.opacity(0.14))
                .frame(width: 84, height: 84)
                .scaleEffect(animate ? 1 : 0.86)

            Circle()
                .stroke(Theme.warning.opacity(0.26), lineWidth: 1)
                .frame(width: 70, height: 70)
                .scaleEffect(animate ? 1.04 : 0.9)

            celebrationSymbol
        }
        .frame(height: 108)
        .animation(.easeOut(duration: 0.32), value: animate)
        .accessibilityHidden(true)
    }

    private var partyPopperSymbol: some View {
        Image(systemName: "party.popper.fill")
            .symbolRenderingMode(.multicolor)
            .font(.system(size: 52, weight: .semibold))
            .scaleEffect(animate ? 1 : 0.86)
            .rotationEffect(.degrees(animate ? 0 : -8))
            .opacity(animate ? 1 : 0.86)
    }

    @ViewBuilder
    private var celebrationSymbol: some View {
        if reduceMotion {
            partyPopperSymbol
        } else if #available(iOS 17.0, *) {
            partyPopperSymbol
                .symbolEffect(.bounce, value: celebrationTrigger)
        } else {
            partyPopperSymbol
        }
    }

    private var completionHeader: some View {
        Text(L10n.string("Cleanup Complete"))
            .font(.system(size: 31, weight: .semibold))
            .foregroundColor(Theme.primaryText)
    }

    private var cleanupSummarySection: some View {
        HStack(spacing: 0) {
            summaryItem(
                icon: "trash.fill",
                title: L10n.string("Deleted This Time"),
                value: L10n.shortPhotoCount(celebration.deletedPhotos),
                detail: L10n.string("Deleted content: about \(celebration.formattedSpaceSaved)"),
                tint: Theme.destructive
            )

            Divider()
                .frame(height: 34)
                .background(Theme.hairline)
                .padding(.horizontal, 10)

            summaryItem(
                icon: "chart.bar.fill",
                title: L10n.string("Total Deleted"),
                value: L10n.shortPhotoCount(celebration.totalDeletedPhotos),
                detail: L10n.string("Deleted content: about \(celebration.formattedTotalSpaceSaved)"),
                tint: Theme.accent
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                        .stroke(Theme.cardStroke, lineWidth: 1)
                )
        )
    }

    private func summaryItem(icon: String, title: String, value: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.secondaryText)

                Text(value)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Text(detail)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
            }

            Spacer(minLength: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var completionActions: some View {
        VStack(spacing: 10) {
            if AppConstants.achievementsEnabled {
                Button(action: onViewAchievements) {
                    Label(L10n.string("View Achievements"), systemImage: "seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .photoDeleteSecondaryButton()
            }

            Button(action: onContinue) {
                Text(L10n.string("Keep Organizing"))
            }
            .photoDeletePrimaryButton()
        }
    }

    private var progressSnapshotSection: some View {
        VStack(spacing: 0) {
            if let newestAchievement = celebration.newAchievements.first {
                compactStatusRow(
                    icon: newestAchievement.systemImage,
                    tint: newestAchievement.tint.color,
                    title: String(format: L10n.string("New Badge: %@"), newestAchievement.title),
                    subtitle: newestAchievement.subtitle
                )

                Divider()
                    .padding(.leading, 48)
            }

            compactStatusRow(
                icon: "flame.fill",
                tint: Theme.warning,
                title: L10n.string("\(streakDaysForDisplay)-Day Cleanup Streak"),
                subtitle: L10n.string("Keep the rhythm. Your library will feel lighter.")
            )

            Divider()
                .padding(.leading, 48)

            if let nextAchievementProgress = celebration.nextAchievementProgress {
                nextGoalCard(nextAchievementProgress)
            } else {
                compactStatusRow(
                    icon: "checkmark.seal.fill",
                    tint: Theme.positive,
                    title: L10n.string("All Badges Complete"),
                    subtitle: L10n.string("You can review the full record on the achievements page.")
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(Theme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                        .stroke(Theme.cardStroke, lineWidth: 1)
                )
        )
    }

    private func compactStatusRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            PhotoDeleteIconTile(
                icon: icon,
                tint: tint,
                size: 34,
                cornerRadius: Theme.radiusSm
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer()
        }
        .padding(14)
    }

    private var streakDaysForDisplay: Int {
        max(celebration.currentStreakDays, celebration.organizedPhotos > 0 ? 1 : 0)
    }

    private func nextGoalCard(_ progress: CleanupAchievementProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                PhotoDeleteIconTile(
                    icon: progress.achievement.systemImage,
                    tint: progress.achievement.tint.color,
                    size: 34,
                    cornerRadius: Theme.radiusSm
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("Next goal: \(progress.achievement.title)"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(progress.remainingDescription)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer()

                Text("\(Int((progress.progress * 100).rounded()))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(progress.achievement.tint.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(progress.achievement.tint.color.opacity(0.12))
                    )
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Theme.hairline)

                    Capsule(style: .continuous)
                        .fill(progress.achievement.tint.color)
                        .frame(width: max(0, proxy.size.width * progressFill))
                }
            }
            .frame(height: 7)
        }
        .padding(14)
    }

}

private struct CandidatePreviewSection: View {
    let title: String?
    let assets: [PHAsset]
    let selectedCount: Int
    let selectedAssetIDs: Set<String>
    let photoLibraryManager: PhotoLibraryManager
    let onPreview: (PHAsset) -> Void
    let onToggleSelection: (PHAsset) -> Void
    let onToggleAll: () -> Void
    var sizeSummary: AnyView? = nil
    @State private var visibleAssetLimit = 48

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let assetLimitStep = 48

    private var visibleAssets: [PHAsset] {
        VisibleListPagination.visibleItems(assets, limit: visibleAssetLimit)
    }

    private var hasMoreAssets: Bool {
        VisibleListPagination.hasMore(totalCount: assets.count, limit: visibleAssetLimit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let title {
                    Text("\(title) · \(PhotoDeleteCountFormat.plain(selectedCount))/\(PhotoDeleteCountFormat.plain(assets.count))")
                        .font(.headline)
                        .foregroundColor(Theme.primaryText)
                } else if let sizeSummary {
                    sizeSummary
                        .font(.subheadline)
                        .foregroundColor(Theme.secondaryText)
                        .accessibilityIdentifier("cleanup-size-summary")
                }
                Spacer(minLength: 8)
                Button(selectedCount == assets.count ? L10n.string("Deselect All") : L10n.string("Select All"), action: onToggleAll)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.accent)
                    .frame(minHeight: 44)
                    .fixedSize()
            }
            if title != nil, let sizeSummary {
                sizeSummary
                    .font(.subheadline)
                    .foregroundColor(Theme.secondaryText)
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(visibleAssets, id: \.localIdentifier) { asset in
                    CleanupReviewAssetCell(
                        asset: asset,
                        photoLibraryManager: photoLibraryManager,
                        isSelected: selectedAssetIDs.contains(asset.localIdentifier),
                        onPreview: { onPreview(asset) },
                        onToggleSelection: { onToggleSelection(asset) }
                    )
                }
            }
            if hasMoreAssets {
                Button(action: showMoreAssets) {
                    Label(L10n.string("Show More"), systemImage: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func showMoreAssets() {
        visibleAssetLimit = VisibleListPagination.advancedLimit(
            totalCount: assets.count, currentLimit: visibleAssetLimit, step: assetLimitStep
        )
    }
}

struct CandidatePreviewAsset: Identifiable {
    let asset: PHAsset

    var id: String {
        asset.localIdentifier
    }
}

func photoPreviewTargetSize(for asset: PHAsset, viewport: CGSize, displayScale: CGFloat) -> CGSize {
    let pixelWidth = max(CGFloat(asset.pixelWidth), 1)
    let pixelHeight = max(CGFloat(asset.pixelHeight), 1)
    let assetLongEdge = max(pixelWidth, pixelHeight)
    let viewportLongEdge = max(viewport.width, viewport.height) * displayScale
    let requestedLongEdge = min(max(viewportLongEdge * 2, 1_600), min(assetLongEdge, 3_200))
    let ratio = requestedLongEdge / assetLongEdge

    return CGSize(
        width: max(pixelWidth * ratio, viewport.width * displayScale),
        height: max(pixelHeight * ratio, viewport.height * displayScale)
    )
}

enum CandidateLivePhotoPreviewPolicy {
    static let networkAccessAllowed = true
    static let deliveryMode: PHImageRequestOptionsDeliveryMode = .highQualityFormat

    static func shouldDisplayLivePhoto(isDegraded: Bool) -> Bool {
        !isDegraded
    }
}

struct ZoomablePhotoPreview: UIViewRepresentable {
    let image: UIImage
    var maximumZoomScale: CGFloat = 5

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = maximumZoomScale
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = context.coordinator

        let imageView = context.coordinator.imageView
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        scrollView.maximumZoomScale = maximumZoomScale
        if context.coordinator.image !== image {
            context.coordinator.image = image
            context.coordinator.imageView.image = image
            scrollView.setZoomScale(1, animated: false)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView = UIImageView()
        weak var scrollView: UIScrollView?
        weak var image: UIImage?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }

            let targetScale = min(max(scrollView.minimumZoomScale * 3, 2.5), scrollView.maximumZoomScale)
            let point = recognizer.location(in: imageView)
            let size = CGSize(
                width: scrollView.bounds.width / targetScale,
                height: scrollView.bounds.height / targetScale
            )
            let rect = CGRect(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2,
                width: size.width,
                height: size.height
            )
            scrollView.zoom(to: rect, animated: true)
        }
    }
}

struct PhotoAssetVideoPlayerView: View {
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager
    var autoPlay = true
    var isMuted = true
    var ignoresSafeArea = true
    var allowsPlayerInteraction = false
    var allowsSurfaceTapToRevealControls = true
    var playbackControlsRevealToken: UUID?
    var onScrubbingChanged: (Bool) -> Void = { _ in }

    @State private var player: AVPlayer?
    @State private var requestID: PHImageRequestID?
    @State private var isLoading = true
    @State private var didFail = false
    @State private var loadingAssetIdentifier: String?
    @State private var playbackProgress: Double = 0
    @State private var timeObserverToken: Any?
    @State private var isScrubbingPlayback = false
    @State private var wasPlayingBeforeScrub = false
    @State private var isPlaying = false
    @State private var playbackEndObserver: NSObjectProtocol?
    @State private var showsPlaybackControls = false
    @State private var playbackControlsHideWorkItem: DispatchWorkItem?
    @State private var scrubResumeWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea(edges: ignoresSafeArea ? .all : [])

            if let player {
                ZStack {
                    VideoPlayer(player: player)
                        .ignoresSafeArea(edges: ignoresSafeArea ? .all : [])
                        .allowsHitTesting(allowsPlayerInteraction)

                    if allowsSurfaceTapToRevealControls {
                        VStack(spacing: 0) {
                            VideoPlaybackTapRevealArea {
                                revealPlaybackControls()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            Color.clear
                                .frame(height: VideoPlaybackControlLayout.progressHitHeight)
                                .allowsHitTesting(false)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    if shouldShowPlaybackButton && !isScrubbingPlayback {
                        VideoPlaybackPlayPauseButton(isPlaying: isPlaying) {
                            togglePlayback(for: player)
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.16), value: isScrubbingPlayback)
                    }
                }
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) {
                    VideoPlaybackProgressBar(
                        progress: playbackProgress,
                        onScrub: seekToProgress,
                        onScrubbingChanged: handlePlaybackScrubbingChanged
                    )
                    .zIndex(2)
                    .allowsHitTesting(true)
                }
                .onAppear {
                    if autoPlay {
                        startPlayback(for: player)
                    }
                }
            } else {
                VStack(spacing: 14) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                    } else {
                        Image(systemName: "play.slash")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundColor(Theme.secondaryText)
                    }

                    Text(isLoading ? L10n.string("Loading video") : L10n.string("This video cannot be played"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
        }
        .onAppear(perform: loadPlayer)
        .onChange(of: isMuted) { muted in
            player?.isMuted = muted
        }
        .onChange(of: playbackControlsRevealToken) { token in
            guard token != nil else { return }
            revealPlaybackControls()
        }
        .onDisappear(perform: cleanup)
    }

    private func loadPlayer() {
        guard player == nil, requestID == nil else { return }

        let requestedAssetID = asset.localIdentifier
        loadingAssetIdentifier = requestedAssetID
        isLoading = true
        didFail = false
        playbackProgress = 0
        showsPlaybackControls = false
        cancelPlaybackControlsAutoHide()

        requestID = photoLibraryManager.loadPlayerItem(for: asset) { playerItem in
            guard loadingAssetIdentifier == requestedAssetID else { return }
            requestID = nil
            isLoading = false

            guard let playerItem else {
                didFail = true
                playbackProgress = 0
                return
            }

            let loadedPlayer = AVPlayer(playerItem: playerItem)
            loadedPlayer.isMuted = isMuted
            player = loadedPlayer
            installPlaybackProgressObserver(for: loadedPlayer)
            installPlaybackEndObserver(for: playerItem)
            if autoPlay {
                startPlayback(for: loadedPlayer)
            }
        }
    }

    private func startPlayback(for player: AVPlayer) {
        player.isMuted = isMuted
        player.play()
        isPlaying = true
        schedulePlaybackControlsAutoHideIfNeeded()
    }

    private func pausePlayback(for player: AVPlayer) {
        player.pause()
        isPlaying = false
        setPlaybackControlsVisible(true, autoHide: false)
    }

    private func togglePlayback(for player: AVPlayer) {
        if isPlaying || player.timeControlStatus == .playing {
            pausePlayback(for: player)
            return
        }

        if playbackProgress >= 0.995 {
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            playbackProgress = 0
        }
        startPlayback(for: player)
    }

    private var shouldShowPlaybackButton: Bool {
        VideoPlaybackControlVisibility.shouldShowButton(
            isPlaying: isPlaying,
            controlsVisible: showsPlaybackControls,
            playbackProgress: playbackProgress
        )
    }

    private func revealPlaybackControls() {
        setPlaybackControlsVisible(true, autoHide: isPlaying)
    }

    private func setPlaybackControlsVisible(_ isVisible: Bool, autoHide: Bool) {
        withAnimation(.easeInOut(duration: 0.16)) {
            showsPlaybackControls = isVisible
        }

        if autoHide {
            schedulePlaybackControlsAutoHideIfNeeded()
        } else {
            cancelPlaybackControlsAutoHide()
        }
    }

    private func schedulePlaybackControlsAutoHideIfNeeded(after delay: TimeInterval = 2.0) {
        cancelPlaybackControlsAutoHide()
        guard VideoPlaybackControlVisibility.shouldAutoHideControls(
            isPlaying: isPlaying,
            controlsVisible: showsPlaybackControls
        ) else {
            return
        }

        let workItem = DispatchWorkItem {
            guard isPlaying else { return }
            guard !isScrubbingPlayback else {
                schedulePlaybackControlsAutoHideIfNeeded(after: VideoPlaybackScrubTiming.controlHideRetryDelay)
                return
            }
            withAnimation(.easeInOut(duration: 0.16)) {
                showsPlaybackControls = false
            }
        }
        playbackControlsHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelPlaybackControlsAutoHide() {
        playbackControlsHideWorkItem?.cancel()
        playbackControlsHideWorkItem = nil
    }

    private func installPlaybackProgressObserver(for loadedPlayer: AVPlayer) {
        removePlaybackProgressObserver()
        playbackProgress = 0
        timeObserverToken = loadedPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak loadedPlayer] time in
            guard let currentPlayer = loadedPlayer else { return }
            guard !isScrubbingPlayback else { return }
            guard let duration = VideoPlaybackDurationResolver.playableDuration(
                playerItemDuration: currentPlayer.currentItem?.duration.seconds,
                assetDuration: asset.duration
            ),
                  time.seconds.isFinite else {
                playbackProgress = 0
                return
            }
            playbackProgress = min(max(time.seconds / duration, 0), 1)
        }
    }

    private func removePlaybackProgressObserver() {
        guard let timeObserverToken else { return }
        player?.removeTimeObserver(timeObserverToken)
        self.timeObserverToken = nil
    }

    private func installPlaybackEndObserver(for playerItem: AVPlayerItem) {
        removePlaybackEndObserver()
        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            playbackProgress = 1
            isPlaying = false
            setPlaybackControlsVisible(true, autoHide: false)
        }
    }

    private func removePlaybackEndObserver() {
        guard let playbackEndObserver else { return }
        NotificationCenter.default.removeObserver(playbackEndObserver)
        self.playbackEndObserver = nil
    }

    private func handlePlaybackScrubbingChanged(_ isScrubbing: Bool) {
        guard isScrubbingPlayback != isScrubbing else { return }
        isScrubbingPlayback = isScrubbing
        onScrubbingChanged(isScrubbing)

        if isScrubbing {
            cancelScrubResume()
            setPlaybackControlsVisible(true, autoHide: false)
            wasPlayingBeforeScrub = VideoPlaybackScrubResumePolicy.shouldResumeAfterScrub(
                wasPlayingState: isPlaying,
                playerWasPlaying: player?.timeControlStatus == .playing,
                autoPlayEnabled: autoPlay,
                playbackProgress: playbackProgress
            )
            player?.pause()
            isPlaying = false
        } else if VideoPlaybackScrubResumePolicy.shouldResumeAfterScrub(
            wasPlayingState: wasPlayingBeforeScrub,
            playerWasPlaying: player?.timeControlStatus == .playing,
            autoPlayEnabled: autoPlay,
            playbackProgress: playbackProgress
        ) {
            if let player {
                cancelScrubResume()
                startPlayback(for: player)
                schedulePlaybackControlsAutoHideIfNeeded(after: VideoPlaybackScrubTiming.controlHideAfterResumeDelay)
            }
            wasPlayingBeforeScrub = false
        } else {
            isPlaying = player?.timeControlStatus == .playing
            setPlaybackControlsVisible(true, autoHide: isPlaying)
        }
    }

    private func seekToProgress(_ progress: Double) {
        guard let player,
              let duration = VideoPlaybackDurationResolver.playableDuration(
                playerItemDuration: player.currentItem?.duration.seconds,
                assetDuration: asset.duration
              ) else {
            return
        }

        let clampedProgress = VideoPlaybackProgressMapper.clamped(progress)
        playbackProgress = clampedProgress
        player.seek(
            to: CMTime(seconds: duration * clampedProgress, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        schedulePlaybackResumeAfterScrubSeek()
    }

    private func schedulePlaybackResumeAfterScrubSeek() {
        guard autoPlay, playbackProgress < 0.995 else { return }
        scrubResumeWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            guard autoPlay,
                  playbackProgress < 0.995,
                  let player else {
                return
            }
            if isScrubbingPlayback {
                isScrubbingPlayback = false
                onScrubbingChanged(false)
            }
            wasPlayingBeforeScrub = false
            startPlayback(for: player)
            schedulePlaybackControlsAutoHideIfNeeded(after: VideoPlaybackScrubTiming.controlHideAfterResumeDelay)
            scrubResumeWorkItem = nil
        }
        scrubResumeWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + VideoPlaybackScrubTiming.resumeAfterLastScrubDelay,
            execute: workItem
        )
    }

    private func cancelScrubResume() {
        scrubResumeWorkItem?.cancel()
        scrubResumeWorkItem = nil
    }

    private func cleanup() {
        photoLibraryManager.cancelImageRequest(requestID)
        requestID = nil
        loadingAssetIdentifier = nil
        removePlaybackProgressObserver()
        removePlaybackEndObserver()
        cancelPlaybackControlsAutoHide()
        cancelScrubResume()
        player?.pause()
        player = nil
        playbackProgress = 0
        isPlaying = false
        showsPlaybackControls = false
        if isScrubbingPlayback {
            onScrubbingChanged(false)
        }
        isScrubbingPlayback = false
        wasPlayingBeforeScrub = false
    }
}

enum VideoPlaybackProgressMapper {
    static func clamped(_ progress: Double) -> Double {
        min(max(progress, 0), 1)
    }

    static func progress(locationX: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return clamped(Double(locationX / width))
    }
}

enum VideoPlaybackDurationResolver {
    static func playableDuration(playerItemDuration: Double?, assetDuration: TimeInterval) -> Double? {
        if let playerItemDuration,
           playerItemDuration.isFinite,
           playerItemDuration > 0 {
            return playerItemDuration
        }

        guard assetDuration.isFinite, assetDuration > 0 else { return nil }
        return assetDuration
    }
}

enum VideoPlaybackControlLayout {
    static let progressHitHeight: CGFloat = 54
    static let progressHorizontalPadding: CGFloat = 14

    static func isInProgressHitRegion(point: CGPoint, containerSize: CGSize) -> Bool {
        guard containerSize.width > 0,
              containerSize.height > 0,
              progressHitHeight > 0 else {
            return false
        }

        let progressTop = max(containerSize.height - progressHitHeight, 0)
        return point.x >= 0 &&
            point.x <= containerSize.width &&
            point.y >= progressTop &&
            point.y <= containerSize.height
    }
}

enum VideoPlaybackScrubResumePolicy {
    static func shouldResumeAfterScrub(
        wasPlayingState: Bool,
        playerWasPlaying: Bool,
        autoPlayEnabled: Bool = false,
        playbackProgress: Double = 0
    ) -> Bool {
        wasPlayingState || playerWasPlaying || (autoPlayEnabled && playbackProgress < 0.995)
    }
}

enum VideoPlaybackScrubTiming {
    static let endFallbackDelay: TimeInterval = 0.18
    static let resumeAfterLastScrubDelay: TimeInterval = 0.24
    static let controlHideRetryDelay: TimeInterval = 0.25
    static let controlHideAfterResumeDelay: TimeInterval = 0.45
}

enum VideoPlaybackControlVisibility {
    static func shouldShowButton(isPlaying: Bool, controlsVisible: Bool, playbackProgress: Double) -> Bool {
        controlsVisible || !isPlaying || playbackProgress >= 0.995
    }

    static func shouldAutoHideControls(isPlaying: Bool, controlsVisible: Bool) -> Bool {
        isPlaying && controlsVisible
    }
}

private struct VideoPlaybackPlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                L10n.string(isPlaying ? "Pause video" : "Play video"),
                systemImage: isPlaying ? "pause.fill" : "play.fill"
            )
            .labelStyle(.iconOnly)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 50, height: 50)
            .background(Circle().fill(Color.black.opacity(0.62)))
            .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 1))
            .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .photoDeleteMinimumTapTarget()
        .accessibilityIdentifier("video-playback-toggle-button")
        .accessibilityLabel(L10n.string(isPlaying ? "Pause video" : "Play video"))
    }
}

private struct VideoPlaybackTapRevealArea: View {
    let action: () -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { action() }, including: .gesture)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("photo-asset-video-player")
            .accessibilityLabel(L10n.string("Video Preview"))
            .accessibilityAddTraits(.isButton)
    }
}

private struct VideoPlaybackProgressBar: View {
    let progress: Double
    let onScrub: (Double) -> Void
    let onScrubbingChanged: (Bool) -> Void

    @State private var scrubbingProgress: Double?

    private var displayedProgress: Double {
        VideoPlaybackProgressMapper.clamped(scrubbingProgress ?? progress)
    }

    var body: some View {
        VideoPlaybackSlider(
            progress: displayedProgress,
            onScrub: updateScrubProgress,
            onScrubbingChanged: handleSliderEditingChanged
        )
        .frame(height: VideoPlaybackControlLayout.progressHitHeight)
        .padding(.horizontal, VideoPlaybackControlLayout.progressHorizontalPadding)
        .background(
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.46)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.string("Video Preview"))
        .accessibilityValue(L10n.percent(Int(displayedProgress * 100)))
        .accessibilityIdentifier("video-playback-progress-bar")
    }

    private func updateScrubProgress(_ progress: Double) {
        let clampedProgress = VideoPlaybackProgressMapper.clamped(progress)
        if scrubbingProgress == nil {
            onScrubbingChanged(true)
        }
        scrubbingProgress = clampedProgress
        onScrub(clampedProgress)
    }

    private func handleSliderEditingChanged(_ isEditing: Bool) {
        if isEditing {
            if scrubbingProgress == nil {
                onScrubbingChanged(true)
            }
            return
        }

        if let scrubbingProgress {
            onScrub(scrubbingProgress)
        }
        scrubbingProgress = nil
        onScrubbingChanged(false)
    }
}

#if canImport(UIKit)
private struct VideoPlaybackSlider: UIViewRepresentable {
    let progress: Double
    let onScrub: (Double) -> Void
    let onScrubbingChanged: (Bool) -> Void

    func makeUIView(context: Context) -> UISlider {
        let slider = ScrubbableSlider(frame: .zero)
        slider.accessibilityIdentifier = "video-playback-slider"
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.isContinuous = true
        slider.minimumTrackTintColor = UIColor(Theme.accent)
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.28)
        slider.setThumbImage(Self.thumbImage(diameter: 20), for: .normal)
        slider.setThumbImage(Self.thumbImage(diameter: 24), for: .highlighted)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.touchDown(_:)), for: .touchDown)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.touchEnded(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )

        slider.value = Float(VideoPlaybackProgressMapper.clamped(progress))
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        context.coordinator.parent = self
        slider.minimumTrackTintColor = UIColor(Theme.accent)
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.28)

        guard !slider.isTracking else { return }
        slider.value = Float(VideoPlaybackProgressMapper.clamped(progress))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    static func dismantleUIView(_ slider: UISlider, coordinator: Coordinator) {
        coordinator.forceEndScrubbing()
    }

    private static func thumbImage(diameter: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: 1),
                blur: 4,
                color: UIColor.black.withAlphaComponent(0.28).cgColor
            )
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
        }
    }

    private final class ScrubbableSlider: UISlider {
        private let minimumTouchHeight: CGFloat = 54

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            let verticalInset = max(0, (minimumTouchHeight - bounds.height) / 2)
            return bounds.insetBy(dx: 0, dy: -verticalInset).contains(point)
        }

        override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            updateValue(for: touch)
            sendActions(for: .touchDown)
            sendActions(for: .valueChanged)
            return true
        }

        override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            updateValue(for: touch)
            sendActions(for: .valueChanged)
            return true
        }

        override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            if let touch {
                updateValue(for: touch)
                sendActions(for: .valueChanged)
            }
            sendActions(for: .touchUpInside)
            super.endTracking(touch, with: event)
        }

        override func cancelTracking(with event: UIEvent?) {
            sendActions(for: .touchCancel)
            super.cancelTracking(with: event)
        }

        private func updateValue(for touch: UITouch) {
            let progress = VideoPlaybackProgressMapper.progress(
                locationX: touch.location(in: self).x,
                width: bounds.width
            )
            value = Float(progress)
        }
    }

    final class Coordinator: NSObject {
        var parent: VideoPlaybackSlider
        private var isScrubbing = false
        private var scrubEndFallbackWorkItem: DispatchWorkItem?

        init(parent: VideoPlaybackSlider) {
            self.parent = parent
        }

        @objc func touchDown(_ slider: UISlider) {
            beginScrubbing()
            parent.onScrub(Double(slider.value))
        }

        @objc func valueChanged(_ slider: UISlider) {
            beginScrubbing()
            scheduleScrubEndFallback()
            parent.onScrub(Double(slider.value))
        }

        @objc func touchEnded(_ slider: UISlider) {
            parent.onScrub(Double(slider.value))
            endScrubbing()
        }

        private func beginScrubbing() {
            guard !isScrubbing else { return }
            isScrubbing = true
            parent.onScrubbingChanged(true)
        }

        private func endScrubbing() {
            scrubEndFallbackWorkItem?.cancel()
            scrubEndFallbackWorkItem = nil
            guard isScrubbing else { return }
            isScrubbing = false
            parent.onScrubbingChanged(false)
        }

        func forceEndScrubbing() {
            endScrubbing()
        }

        private func scheduleScrubEndFallback() {
            scrubEndFallbackWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.endScrubbing()
            }
            scrubEndFallbackWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + VideoPlaybackScrubTiming.endFallbackDelay, execute: workItem)
        }
    }
}
#endif

struct CandidatePhotoPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager
    var locationTitle: String? = nil

    @State private var image: UIImage?
    @State private var livePhoto: PHLivePhoto?
    @State private var isLoading = true
    @State private var imageRequestID: PHImageRequestID?
    @State private var livePhotoRequestID: PHImageRequestID?
    @State private var failedToLoadLivePhoto = false
    @State private var sharePayload: PhotoSharePayload?
    @State private var sharePreparationTask: Task<Void, Never>?
    @State private var isPreparingShare = false
    @State private var showShareError = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        previewMedia(in: geometry.size)
                            .frame(height: previewMediaHeight(in: geometry.size))

                        PhotoAssetDetailsPanel(
                            asset: asset,
                            photoLibraryManager: photoLibraryManager,
                            locationTitle: locationTitle
                        )
                        .padding(.horizontal, Theme.space5)
                        .padding(.top, 18)
                        .padding(.bottom, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
                .background(Theme.background.ignoresSafeArea())
                .onAppear {
                    if isLivePhotoAsset {
                        loadImage(in: geometry.size)
                        loadLivePhoto(in: geometry.size)
                    } else if asset.mediaType != .video {
                        loadImage(in: geometry.size)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: prepareShare) {
                        Group {
                            if isPreparingShare {
                                ProgressView()
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .frame(width: 44, height: 44)
                    }
                    .disabled(isPreparingShare)
                    .accessibilityLabel(L10n.string("Share"))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Close")) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $sharePayload, onDismiss: cleanupSharePayload) { payload in
            SystemShareSheet(activityItems: [payload.fileURL])
        }
        .alert(L10n.string("Operation failed. Try again later."), isPresented: $showShareError) {
            Button(L10n.string("Got it"), role: .cancel) {}
        }
        .onDisappear {
            photoLibraryManager.cancelImageRequest(imageRequestID)
            photoLibraryManager.cancelImageRequest(livePhotoRequestID)
            sharePreparationTask?.cancel()
            sharePreparationTask = nil
            isPreparingShare = false
        }
    }

    @ViewBuilder
    private func previewMedia(in size: CGSize) -> some View {
        ZStack {
            Theme.background

            if asset.mediaType == .video {
                PhotoAssetVideoPlayerView(
                    asset: asset,
                    photoLibraryManager: photoLibraryManager,
                    ignoresSafeArea: false
                )
            } else if isLivePhotoAsset {
                if let livePhoto {
                    LivePhotoPreviewRepresentable(
                        livePhoto: livePhoto,
                        contentIdentifier: asset.localIdentifier
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel(L10n.string("Live Photos"))
                } else if let image {
                    ZoomablePhotoPreview(image: image)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel(L10n.string("Enlarged photo"))
                } else {
                    loadingContent
                }
            } else if let image {
                ZoomablePhotoPreview(image: image)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(L10n.string("Enlarged photo"))
            } else {
                loadingContent
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(asset.mediaType == .video ? 1 : 0.08))
    }

    private func previewMediaHeight(in size: CGSize) -> CGFloat {
        min(max(size.height * 0.82, 420), size.height * 0.88)
    }

    private var isLivePhotoAsset: Bool {
        photoLibraryManager.isLivePhoto(asset)
    }

    private var navigationTitle: String {
        if asset.mediaType == .video {
            return L10n.string("Video Preview")
        }
        if isLivePhotoAsset {
            return L10n.string("Live Photos")
        }
        return L10n.string("Photo Preview")
    }

    private var loadingContent: some View {
        VStack(spacing: 14) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(Theme.secondaryText)
            }

            Text(isLoading ? L10n.string("Reading Photos") : L10n.string("Unable to load this photo"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.secondaryText)
        }
    }

    private func loadLivePhoto(in size: CGSize) {
        guard livePhotoRequestID == nil, livePhoto == nil, !failedToLoadLivePhoto else { return }
        isLoading = true
        let targetSize = photoPreviewTargetSize(for: asset, viewport: size, displayScale: displayScale)

        livePhotoRequestID = photoLibraryManager.loadLivePhotoResult(
            for: asset,
            size: targetSize,
            networkAccessAllowed: CandidateLivePhotoPreviewPolicy.networkAccessAllowed,
            deliveryMode: CandidateLivePhotoPreviewPolicy.deliveryMode
        ) { result in
            if let loadedLivePhoto = result.livePhoto,
               CandidateLivePhotoPreviewPolicy.shouldDisplayLivePhoto(isDegraded: result.isDegraded) {
                livePhoto = loadedLivePhoto
                isLoading = false
            } else if result.isFinal {
                failedToLoadLivePhoto = true
                isLoading = image == nil
            }

            if result.isFinal {
                livePhotoRequestID = nil
            }
        }
    }

    private func loadImage(in size: CGSize) {
        guard imageRequestID == nil, image == nil else { return }
        isLoading = true
        let targetSize = photoPreviewTargetSize(for: asset, viewport: size, displayScale: displayScale)

        imageRequestID = photoLibraryManager.loadHighQualityPreview(
            for: asset,
            size: targetSize,
            networkAccessAllowed: true
        ) { loadedImage in
            image = loadedImage
            isLoading = false
            imageRequestID = nil
        }
    }

    private func prepareShare() {
        guard !isPreparingShare else { return }

        isPreparingShare = true
        sharePreparationTask?.cancel()
        sharePreparationTask = Task {
            do {
                let payload = try await photoLibraryManager.prepareSharePayload(for: asset)
                guard !Task.isCancelled else {
                    payload.cleanup()
                    return
                }
                await MainActor.run {
                    sharePayload = payload
                    isPreparingShare = false
                    sharePreparationTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    isPreparingShare = false
                    sharePreparationTask = nil
                }
            } catch {
                await MainActor.run {
                    isPreparingShare = false
                    sharePreparationTask = nil
                    showShareError = true
                }
            }
        }
    }

    private func cleanupSharePayload() {
        sharePayload?.cleanup()
        sharePayload = nil
    }
}

private struct PhotoAssetDetailsPanel: View {
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager
    var locationTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.accent)

                Text(L10n.string("Photo Info"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
            }

            VStack(spacing: 0) {
                detailRow(label: L10n.string("Captured"), value: captureDateText, icon: "calendar")
                if let locationText {
                    detailDivider
                    detailRow(label: L10n.string("Location"), value: locationText, icon: "location")
                }
                if let modificationDateText {
                    detailDivider
                    detailRow(label: L10n.string("Modified"), value: modificationDateText, icon: "clock.arrow.circlepath")
                }
                if let sourceText {
                    detailDivider
                    detailRow(label: L10n.string("Library Source"), value: sourceText, icon: "photo.stack")
                }
                if let originalFilenameText {
                    detailDivider
                    detailRow(label: L10n.string("Original Filename"), value: originalFilenameText, icon: "doc.text")
                }
                Divider().background(Theme.hairline).padding(.leading, 44)
                detailRow(label: L10n.string("Type"), value: mediaTypeText, icon: mediaTypeIcon)
                Divider().background(Theme.hairline).padding(.leading, 44)
                detailRow(label: L10n.string("Dimensions"), value: pixelSizeText, icon: "aspectratio")
                Divider().background(Theme.hairline).padding(.leading, 44)
                detailRow(label: L10n.string("Orientation"), value: orientationText, icon: "rectangle")

                if asset.mediaType == .video {
                    Divider().background(Theme.hairline).padding(.leading, 44)
                    detailRow(label: L10n.string("Duration"), value: durationText, icon: "clock")
                }

                if asset.isFavorite {
                    Divider().background(Theme.hairline).padding(.leading, 44)
                    detailRow(label: L10n.string("Status"), value: L10n.string("Already favorite"), icon: "heart.fill")
                }
            }
            .photoDeleteCard()
        }
        .accessibilityElement(children: .contain)
    }

    private var detailDivider: some View {
        Divider().background(Theme.hairline).padding(.leading, 44)
    }

    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            PhotoDeleteIconTile(icon: icon, tint: Theme.accent, size: 32, cornerRadius: Theme.radiusSm)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.tertiaryText)

                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var captureDateText: String {
        PhotoAssetMetadataFormatter.detailCaptureDate(for: asset.creationDate)
    }

    private var locationText: String? {
        PhotoAssetMetadataFormatter.optionalLocationText(
            locationTitle: locationTitle,
            coordinate: asset.location?.coordinate
        )
    }

    private var modificationDateText: String? {
        guard let modificationDate = asset.modificationDate else { return nil }
        return AppDateFormatter.string(from: modificationDate, dateStyle: .medium, timeStyle: .short)
    }

    private var sourceText: String? {
        PhotoAssetSourceFormatter.sourceDescription(for: asset.sourceType)
    }

    private var originalFilenameText: String? {
        PhotoAssetSourceFormatter.originalFilename(for: asset)
    }

    private var mediaTypeText: String {
        if asset.mediaType == .video {
            return L10n.string("Videos")
        }
        if photoLibraryManager.isLivePhoto(asset) {
            return L10n.string("Live Photos")
        }
        if photoLibraryManager.isScreenshot(asset) {
            return L10n.string("Screenshots")
        }
        return L10n.string("Photos")
    }

    private var mediaTypeIcon: String {
        if asset.mediaType == .video { return "video" }
        if photoLibraryManager.isLivePhoto(asset) { return "livephoto" }
        if photoLibraryManager.isScreenshot(asset) { return "camera.viewfinder" }
        return "photo"
    }

    private var pixelSizeText: String {
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else {
            return L10n.string("Unknown")
        }
        return "\(asset.pixelWidth) × \(asset.pixelHeight)"
    }

    private var orientationText: String {
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else {
            return L10n.string("Unknown")
        }
        if asset.pixelWidth > asset.pixelHeight {
            return L10n.string("Landscape")
        }
        if asset.pixelHeight > asset.pixelWidth {
            return L10n.string("Portrait")
        }
        return L10n.string("Square")
    }

    private var durationText: String {
        let totalSeconds = max(Int(asset.duration.rounded()), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct LivePhotoPreviewRepresentable: UIViewRepresentable {
    let livePhoto: PHLivePhoto
    let contentIdentifier: String
    var autoPlay = true
    var isMuted = true
    var playbackStyle: PHLivePhotoViewPlaybackStyle = .full
    var playbackTrigger = 0
    var contentMode: UIView.ContentMode = .scaleAspectFit

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = contentMode
        view.isMuted = isMuted
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        let shouldStartPlayback = context.coordinator.playbackRequestState.shouldStartPlayback(
            contentIdentifier: contentIdentifier,
            autoPlay: autoPlay,
            playbackTrigger: playbackTrigger
        )
        context.coordinator.autoPlay = autoPlay
        context.coordinator.playbackStyle = playbackStyle
        context.coordinator.isDismantled = false
        uiView.contentMode = contentMode
        uiView.isMuted = isMuted

        if !autoPlay {
            context.coordinator.stopPlayback(in: uiView)
        }

        if context.coordinator.displayedLivePhoto !== livePhoto {
            context.coordinator.displayedLivePhoto = livePhoto
            uiView.livePhoto = livePhoto
        }

        if shouldStartPlayback {
            context.coordinator.startPlayback(in: uiView, delay: 0.12)
        }
    }

    static func dismantleUIView(_ uiView: PHLivePhotoView, coordinator: Coordinator) {
        coordinator.isDismantled = true
        coordinator.cancelPendingPlayback()
        uiView.delegate = nil
        uiView.stopPlayback()
        uiView.livePhoto = nil
        coordinator.displayedLivePhoto = nil
    }

    final class Coordinator: NSObject, PHLivePhotoViewDelegate {
        weak var displayedLivePhoto: PHLivePhoto?
        var autoPlay = false
        var playbackStyle: PHLivePhotoViewPlaybackStyle = .full
        var playbackRequestState = LivePhotoPlaybackRequestState()
        var isPlaying = false
        var isDismantled = false
        private var pendingPlaybackToken: UUID?

        func startPlayback(in view: PHLivePhotoView, delay: TimeInterval) {
            guard autoPlay else { return }
            let playbackToken = UUID()
            pendingPlaybackToken = playbackToken
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak view] in
                guard let self,
                      let view,
                      self.pendingPlaybackToken == playbackToken,
                      self.autoPlay,
                      !self.isDismantled,
                      view.livePhoto != nil else { return }
                self.pendingPlaybackToken = nil
                view.stopPlayback()
                view.startPlayback(with: self.playbackStyle)
                self.isPlaying = true
            }
        }

        func cancelPendingPlayback() {
            pendingPlaybackToken = nil
        }

        func stopPlayback(in view: PHLivePhotoView) {
            cancelPendingPlayback()
            view.stopPlayback()
            isPlaying = false
        }

        func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
            isPlaying = true
        }

        func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
            isPlaying = false
        }
    }
}
