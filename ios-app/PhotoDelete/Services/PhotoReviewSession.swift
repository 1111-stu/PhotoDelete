import Foundation
import Combine
import Photos

/// The local review queue and its progress, independent of card presentation.
final class PhotoReviewSession: ObservableObject {
    @Published private(set) var photos: [PHAsset] = []
    @Published private(set) var allPhotos: [PHAsset] = []
    @Published private(set) var assetIdentifiers: [String] = []
    @Published var currentIndex = 0
    @Published var reviewedIDs: Set<String> = []
    @Published private(set) var loadedCount = 0

    private var paginates = false

    /// Refreshes the source and returns whether its persisted review is complete.
    @discardableResult
    func refresh(
        photos fullPhotos: [PHAsset],
        persistedReviewedIDs: Set<String>,
        usesPersistedReviewedState: Bool,
        preservesSessionReviewedState: Bool,
        savedAssetIdentifier: String?,
        prefersFirstUnreviewedBeforeSavedProgress: Bool,
        paginates: Bool
    ) -> Bool {
        self.paginates = paginates
        let identifiers = fullPhotos.map(\.localIdentifier)
        let sourceIDs = Set(identifiers)
        let persistedIDs = usesPersistedReviewedState ? persistedReviewedIDs : []
        let sourceReviewedIDs = persistedIDs.intersection(sourceIDs)
        let updatedReviewedIDs = preservesSessionReviewedState
            ? reviewedIDs.intersection(sourceIDs).union(sourceReviewedIDs)
            : sourceReviewedIDs
        let targetIndex = preservesSessionReviewedState
            ? min(currentIndex, max(fullPhotos.count - 1, 0))
            : PhotoReviewSessionPaginator.initialTargetIndex(
                assetIdentifiers: identifiers,
                reviewedAssetIdentifiers: persistedIDs,
                savedAssetIdentifier: savedAssetIdentifier,
                prefersFirstUnreviewedBeforeSavedProgress: prefersFirstUnreviewedBeforeSavedProgress
            )
        let initialCount = paginates
            ? PhotoReviewSessionPaginator.initialLoadedCount(totalCount: fullPhotos.count)
            : fullPhotos.count
        let updatedLoadedCount = min(fullPhotos.count, max(initialCount, targetIndex + 1))

        allPhotos = fullPhotos
        assetIdentifiers = identifiers
        reviewedIDs = updatedReviewedIDs
        loadedCount = updatedLoadedCount
        photos = Array(fullPhotos.prefix(updatedLoadedCount))
        currentIndex = min(targetIndex, max(photos.count - 1, 0))

        return usesPersistedReviewedState && !identifiers.isEmpty &&
            identifiers.allSatisfy { updatedReviewedIDs.contains($0) }
    }

    @discardableResult
    func expand(for index: Int, force: Bool = false) -> Bool {
        guard paginates, loadedCount < allPhotos.count else { return false }

        let updatedLoadedCount = force
            ? min(allPhotos.count, loadedCount + PhotoReviewSessionPaginator.defaultPageSize)
            : PhotoReviewSessionPaginator.expandedLoadedCount(
                totalCount: allPhotos.count,
                currentLoadedCount: loadedCount,
                currentIndex: index
            )
        guard updatedLoadedCount > loadedCount else { return false }

        loadedCount = updatedLoadedCount
        photos = Array(allPhotos.prefix(updatedLoadedCount))
        return true
    }

    /// Searches the full source; the caller can expand the loaded page before showing it.
    func nextUnreviewedIndex(after index: Int) -> Int? {
        PhotoReviewSessionDecisionPolicy.nextUnreviewedIndex(
            assetIdentifiers: assetIdentifiers,
            reviewedAssetIdentifiers: reviewedIDs,
            after: index
        )
    }

    /// Searches only the loaded page, preserving incremental review continuation.
    func firstUnreviewedIndex(startingAt index: Int = 0) -> Int? {
        let startIndex = max(index, 0)
        guard startIndex < loadedCount else { return nil }
        return (startIndex..<loadedCount).first { !reviewedIDs.contains(assetIdentifiers[$0]) }
    }
}

enum PhotoReviewSourceReadiness {
    static func isWaiting(
        selectedCategory: PhotoCategory?,
        selectedLocationGroupID: String?,
        hasLoadedAllCategoryPhotos: Bool,
        isPhotoLibraryLoading: Bool,
        isPreparingLibrary: Bool,
        isRestoringLibrarySnapshot: Bool,
        isLoadingLocationGroups: Bool,
        isResolvingLocationTitles: Bool,
        isLoadingAdvancedCleanupQueues: Bool,
        hasLoadedAlbumMembership: Bool,
        isLoadingAlbums: Bool
    ) -> Bool {
        let isLoadingBaseLibrary = isPhotoLibraryLoading || isPreparingLibrary || isRestoringLibrarySnapshot
        if selectedCategory == .all {
            // The all-photos source is published in batches while the initial
            // Photos scan is still running.  A non-empty array is therefore not
            // proof that this source is ready for a review session.
            return !hasLoadedAllCategoryPhotos ||
                isLoadingBaseLibrary ||
                (selectedLocationGroupID != nil && (isLoadingLocationGroups || isResolvingLocationTitles))
        }
        if selectedCategory == .unclassified {
            return isLoadingBaseLibrary || !hasLoadedAlbumMembership || isLoadingAlbums
        }

        return isLoadingBaseLibrary ||
            (selectedLocationGroupID != nil && (isLoadingLocationGroups || isResolvingLocationTitles)) ||
            isLoadingAdvancedCleanupQueues
    }
}

enum PhotoReviewSessionInitializationPolicy {
    static func shouldWaitForSource(
        isRandomReview: Bool,
        hasPhotos: Bool,
        isWaitingForSourceData: Bool,
        requiresCompleteSource: Bool = false,
        isSourceComplete: Bool = true
    ) -> Bool {
        if requiresCompleteSource {
            return !isSourceComplete || isWaitingForSourceData
        }
        return isWaitingForSourceData && (isRandomReview || !hasPhotos)
    }
}

enum PhotoRandomReviewNavigationPolicy {
    static func previousIndex(currentIndex: Int, count: Int, isExcluded: (Int) -> Bool = { _ in false }) -> Int? {
        neighborIndex(currentIndex: currentIndex, count: count, step: -1, isExcluded: isExcluded)
    }

    static func nextIndex(currentIndex: Int, count: Int, isExcluded: (Int) -> Bool = { _ in false }) -> Int? {
        neighborIndex(currentIndex: currentIndex, count: count, step: 1, isExcluded: isExcluded)
    }

    private static func neighborIndex(currentIndex: Int, count: Int, step: Int, isExcluded: (Int) -> Bool) -> Int? {
        guard count > 0, (0..<count).contains(currentIndex) else { return nil }
        var index = currentIndex + step
        while (0..<count).contains(index) {
            if !isExcluded(index) { return index }
            index += step
        }
        return nil
    }
}

enum PhotoReviewSessionReviewedStatePolicy {
    static func usesPersistedReviewedState(
        isAlbumMode: Bool,
        isRandomMemoriesMode: Bool = false
    ) -> Bool {
        !isAlbumMode && !isRandomMemoriesMode
    }

    static func reviewedAssetIdentifiers(
        isAlbumMode: Bool,
        isRandomMemoriesMode: Bool = false,
        persistedReviewedAssetIdentifiers: Set<String>
    ) -> Set<String> {
        usesPersistedReviewedState(
            isAlbumMode: isAlbumMode,
            isRandomMemoriesMode: isRandomMemoriesMode
        ) ? persistedReviewedAssetIdentifiers : []
    }

    static func reviewedCount(
        isAlbumMode: Bool,
        isRandomMemoriesMode: Bool = false,
        persistedReviewedCount: Int
    ) -> Int {
        usesPersistedReviewedState(
            isAlbumMode: isAlbumMode,
            isRandomMemoriesMode: isRandomMemoriesMode
        ) ? persistedReviewedCount : 0
    }

}
