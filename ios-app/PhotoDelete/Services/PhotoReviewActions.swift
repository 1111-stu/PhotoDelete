import Foundation
import Combine
import Photos

/// Feedback styles understood by the review screen. Kept independent from SwiftUI colors.
enum PhotoReviewActionFeedbackStyle {
    case neutral
    case positive
    case destructive
    case favorite
    case warning
}

enum PhotoReviewActionHaptic {
    case light
    case medium
    case success
    case error
}

enum PhotoReviewActionEvent {
    case feedback(
        message: String,
        icon: String,
        style: PhotoReviewActionFeedbackStyle,
        showsUndo: Bool,
        duration: TimeInterval
    )
    case restorePosition(asset: PHAsset, preferredIndex: Int, refreshSource: Bool)
    case albumSuccess(title: String)
    case haptic(PhotoReviewActionHaptic)
}

private enum PhotoReviewActionRecord {
    case delete(
        PHAsset,
        originalIndex: Int,
        wasReviewed: Bool,
        wasSessionReviewed: Bool
    )
    case favorite(
        PHAsset,
        originalIndex: Int,
        previousStatus: Bool
    )
    case fileToAlbum(
        PHAsset,
        album: PHAssetCollection,
        albumID: String,
        originalIndex: Int,
        wasReviewed: Bool,
        wasSessionReviewed: Bool,
        filingKey: String
    )
}

/// Coordinates review mutations which outlive the card gesture itself.
///
/// Pending write callbacks retain this service so queued toggles and undo finish
/// even when the user leaves the review screen.
/// The service owns the mutation queues and undo history. Presentation code listens
/// to `events` for toasts, haptics, source refreshes, and position restoration.
@MainActor
final class PhotoReviewActions: ObservableObject {
    @Published private var actionHistory: [PhotoReviewActionRecord] = []
    @Published private var favoriteMutationTargets: [String: Bool] = [:]
    @Published private var queuedFavoriteMutationTargets: [String: Bool] = [:]
    @Published private(set) var albumFilingAssetIDs: Set<String> = []
    @Published private(set) var recentlyFiledAlbumAssetIDs: Set<String> = []
    private var pendingAlbumFilingUndoKeys: Set<String> = []
    private var completedAlbumFilingKeys: Set<String> = []
    @Published private(set) var isUndoInProgress = false
    private var pendingAlbumUndoRefreshSources: [String: Bool] = [:]

    let events = PassthroughSubject<PhotoReviewActionEvent, Never>()

    var canStartAction: Bool {
        PhotoReviewMutationPolicy.canStartAction(
            isUndoInProgress: isUndoInProgress,
            pendingFavoriteMutationCount: favoriteMutationTargets.count
        )
    }

    var deleteActionCount: Int {
        actionHistory.reduce(into: 0) { count, action in
            if case .delete = action { count += 1 }
        }
    }

    var favoriteActionCount: Int {
        var changes: [String: (initial: Bool, current: Bool)] = [:]
        for action in actionHistory {
            guard case .favorite(let asset, _, let previousStatus) = action else { continue }
            let id = asset.localIdentifier
            let target = !previousStatus
            if let existing = changes[id] {
                changes[id] = (existing.initial, target)
            } else {
                changes[id] = (previousStatus, target)
            }
        }
        return changes.values.reduce(into: 0) { count, change in
            if !change.initial && change.current { count += 1 }
        }
    }

    func canStartAction(_ action: SwipeGestureAction) -> Bool {
        if action == .favorite { return !isUndoInProgress }
        return canStartAction
    }

    func isAssetQueuedForDelete(_ asset: PHAsset, dataManager: DataManager) -> Bool {
        dataManager.isInDeleteCandidates(asset)
    }

    func isAssetQueuedForFavorite(_ asset: PHAsset, dataManager: DataManager) -> Bool {
        queuedFavoriteMutationTargets[asset.localIdentifier] != nil ||
            favoriteMutationTargets[asset.localIdentifier] != nil ||
            dataManager.isInFavoriteCandidates(asset)
    }

    func isAssetBeingFiled(_ asset: PHAsset) -> Bool {
        albumFilingAssetIDs.contains(asset.localIdentifier)
    }

    func isAssetRecentlyFiled(_ asset: PHAsset) -> Bool {
        recentlyFiledAlbumAssetIDs.contains(asset.localIdentifier)
    }

    @discardableResult
    func markDelete(
        _ asset: PHAsset,
        dataManager: DataManager,
        session: PhotoReviewSession
    ) -> Bool {
        guard canStartAction else { return false }
        guard !dataManager.isInDeleteCandidates(asset) else { return false }

        let originalIndex = session.currentIndex
        let wasReviewed = dataManager.isReviewed(asset)
        let wasSessionReviewed = session.reviewedIDs.contains(asset.localIdentifier)
        _ = dataManager.markReviewed(asset)
        session.reviewedIDs.insert(asset.localIdentifier)
        dataManager.addToDeleteCandidates(asset)
        actionHistory.append(.delete(
            asset,
            originalIndex: originalIndex,
            wasReviewed: wasReviewed,
            wasSessionReviewed: wasSessionReviewed
        ))
        events.send(.haptic(.medium))
        return true
    }

    @discardableResult
    func cancelDelete(
        _ asset: PHAsset,
        at index: Int,
        dataManager: DataManager,
        session: PhotoReviewSession
    ) -> Bool {
        guard dataManager.isInDeleteCandidates(asset) else { return false }
        dataManager.removeFromDeleteCandidates(asset)

        guard let originalAction = removeLatestDeleteAction(for: asset) else { return true }
        dataManager.restoreReviewedState(asset, wasReviewed: originalAction.wasReviewed)
        restoreSessionReviewedState(asset: asset, wasReviewed: originalAction.wasSessionReviewed, session: session)
        events.send(.haptic(.light))
        events.send(.feedback(
            message: L10n.string("Removed from deletion"),
            icon: "xmark.circle.fill",
            style: .neutral,
            showsUndo: false,
            duration: 3
        ))
        events.send(.restorePosition(asset: asset, preferredIndex: index, refreshSource: false))
        return true
    }

    func toggleFavoriteStatus(
        _ asset: PHAsset,
        dataManager: DataManager,
        session: PhotoReviewSession
    ) {
        setFavoriteStatus(
            asset,
            to: !effectiveFavoriteStatus(for: asset, dataManager: dataManager),
            dataManager: dataManager,
            session: session
        )
    }

    func setFavoriteStatus(
        _ asset: PHAsset,
        to targetStatus: Bool,
        dataManager: DataManager,
        session: PhotoReviewSession
    ) {
        let assetID = asset.localIdentifier
        if let inFlightTarget = favoriteMutationTargets[assetID] {
            if targetStatus == inFlightTarget {
                queuedFavoriteMutationTargets.removeValue(forKey: assetID)
            } else {
                queuedFavoriteMutationTargets[assetID] = targetStatus
            }
            return
        }

        let previousStatus = effectiveFavoriteStatus(for: asset, dataManager: dataManager)
        guard previousStatus != targetStatus else { return }
        let originalIndex = session.currentIndex

        if targetStatus, dataManager.isInDeleteCandidates(asset) {
            _ = cancelDelete(asset, at: originalIndex, dataManager: dataManager, session: session)
        }

        favoriteMutationTargets[assetID] = targetStatus
        dataManager.setPhotoFavoriteImmediately(asset, isFavorite: targetStatus) { success in
            self.favoriteMutationTargets.removeValue(forKey: assetID)
            let queuedTarget = self.queuedFavoriteMutationTargets.removeValue(forKey: assetID)

            if success {
                self.actionHistory.append(.favorite(
                    asset,
                    originalIndex: originalIndex,
                    previousStatus: previousStatus
                ))
                self.events.send(.haptic(.success))
                self.events.send(.feedback(
                    message: targetStatus ? L10n.string("Added to Favorites") : L10n.string("Removed from favorites"),
                    icon: targetStatus ? "heart.fill" : "heart.slash",
                    style: .favorite,
                    showsUndo: true,
                    duration: 3
                ))
            } else {
                self.events.send(.haptic(.error))
                self.events.send(.feedback(
                    message: targetStatus
                        ? L10n.string("Couldn't add to favorites. Try again.")
                        : L10n.string("Couldn’t remove from favorites. Try again."),
                    icon: "exclamationmark.triangle",
                    style: .warning,
                    showsUndo: false,
                    duration: 3
                ))
            }

            if let queuedTarget {
                self.setFavoriteStatus(
                    asset,
                    to: queuedTarget,
                    dataManager: dataManager,
                    session: session
                )
            }
        }
    }

    func effectiveFavoriteStatus(for asset: PHAsset, dataManager: DataManager) -> Bool {
        if let queuedTarget = queuedFavoriteMutationTargets[asset.localIdentifier] {
            return queuedTarget
        }
        if let target = favoriteMutationTargets[asset.localIdentifier] {
            return target
        }
        return dataManager.photoLibraryManager.isFavorite(asset)
    }

    @discardableResult
    func fileToAlbum(
        _ asset: PHAsset,
        albumInfo: AlbumInfo,
        dataManager: DataManager,
        session: PhotoReviewSession
    ) -> Bool {
        guard canStartAction else { return false }
        guard let currentAlbum = dataManager.cachedUserAlbumInfo(for: albumInfo),
              currentAlbum.type == .userCreated,
              let collection = currentAlbum.assetCollection,
              collection.canPerform(.addContent) else {
            events.send(.feedback(
                message: L10n.string("Could not add to this album"),
                icon: "exclamationmark.triangle",
                style: .warning,
                showsUndo: false,
                duration: 3
            ))
            return false
        }

        let assetID = asset.localIdentifier
        guard !albumFilingAssetIDs.contains(assetID) else { return false }

        let originalIndex = session.photos.firstIndex { $0.localIdentifier == assetID } ?? session.currentIndex
        let filingKey = UUID().uuidString
        albumFilingAssetIDs.insert(assetID)
        recentlyFiledAlbumAssetIDs.remove(assetID)

        let wasSessionReviewed = session.reviewedIDs.contains(assetID)
        let wasReviewed = dataManager.isReviewed(asset)
        _ = dataManager.markReviewed(asset)
        session.reviewedIDs.insert(assetID)
        actionHistory.append(.fileToAlbum(
            asset,
            album: collection,
            albumID: currentAlbum.id,
            originalIndex: originalIndex,
            wasReviewed: wasReviewed,
            wasSessionReviewed: wasSessionReviewed,
            filingKey: filingKey
        ))
        events.send(.haptic(.light))

        dataManager.addPhotoToAlbum(asset, album: collection) { success, didInsert in
            self.albumFilingAssetIDs.remove(assetID)

            if success, didInsert {
                if self.pendingAlbumFilingUndoKeys.contains(filingKey) {
                    dataManager.removePhotoFromAlbum(asset, album: collection) { removeSuccess in
                        self.completeAlbumUndo(
                            asset: asset,
                            preferredIndex: originalIndex,
                            action: .fileToAlbum(
                                asset,
                                album: collection,
                                albumID: currentAlbum.id,
                                originalIndex: originalIndex,
                                wasReviewed: wasReviewed,
                                wasSessionReviewed: wasSessionReviewed,
                                filingKey: filingKey
                            ),
                            success: removeSuccess,
                            dataManager: dataManager,
                            session: session,
                            refreshSource: self.pendingAlbumUndoRefreshSources.removeValue(forKey: filingKey) ?? false
                        )
                    }
                    return
                }

                self.completedAlbumFilingKeys.insert(filingKey)
                self.recentlyFiledAlbumAssetIDs.insert(assetID)
                dataManager.recordRecentOrganizedPhoto(asset, action: .filedToAlbum)
                self.events.send(.albumSuccess(title: currentAlbum.title))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.recentlyFiledAlbumAssetIDs.remove(assetID)
                }
            } else if success {
                // The asset was already in the album. It is still reviewed, but there
                // is no successful insert that can be undone.
                let wasUndoRequested = self.pendingAlbumFilingUndoKeys.remove(filingKey) != nil
                let refreshSource = self.pendingAlbumUndoRefreshSources.removeValue(forKey: filingKey) ?? false
                self.removeAction(filingKey: filingKey)
                if wasUndoRequested {
                    self.restoreReviewState(
                        asset: asset,
                        wasReviewed: wasReviewed,
                        wasSessionReviewed: wasSessionReviewed,
                        dataManager: dataManager,
                        session: session
                    )
                    self.finishUndo()
                    self.events.send(.restorePosition(asset: asset, preferredIndex: originalIndex, refreshSource: refreshSource))
                }
            } else {
                let wasUndoRequested = self.pendingAlbumFilingUndoKeys.remove(filingKey) != nil
                let refreshSource = self.pendingAlbumUndoRefreshSources.removeValue(forKey: filingKey) ?? false
                self.removeAction(filingKey: filingKey)
                self.restoreReviewState(
                    asset: asset,
                    wasReviewed: wasReviewed,
                    wasSessionReviewed: wasSessionReviewed,
                    dataManager: dataManager,
                    session: session
                )
                if wasUndoRequested {
                    self.finishUndo()
                    self.events.send(.restorePosition(asset: asset, preferredIndex: originalIndex, refreshSource: refreshSource))
                } else {
                    self.events.send(.haptic(.error))
                    self.events.send(.feedback(
                        message: L10n.string("Could not add to the album. Try again."),
                        icon: "exclamationmark.triangle",
                        style: .warning,
                        showsUndo: false,
                        duration: 3
                    ))
                    self.events.send(.restorePosition(asset: asset, preferredIndex: originalIndex, refreshSource: false))
                }
            }
        }
        return true
    }

    func undo(
        dataManager: DataManager,
        session: PhotoReviewSession,
        refreshesAfterFavoriteUndo: Bool,
        refreshesAfterAlbumRemoval: Bool
    ) {
        guard !isUndoInProgress, favoriteMutationTargets.isEmpty else { return }
        guard let action = actionHistory.popLast() else {
            events.send(.haptic(.light))
            events.send(.feedback(
                message: L10n.string("Nothing to undo"),
                icon: "arrow.uturn.backward",
                style: .neutral,
                showsUndo: false,
                duration: 3
            ))
            return
        }

        isUndoInProgress = true
        switch action {
        case .delete(let asset, let originalIndex, let wasReviewed, let wasSessionReviewed):
            dataManager.removeFromDeleteCandidates(asset)
            restoreReviewState(
                asset: asset,
                wasReviewed: wasReviewed,
                wasSessionReviewed: wasSessionReviewed,
                dataManager: dataManager,
                session: session
            )
            finishUndo()
            events.send(.haptic(.success))
            events.send(.feedback(
                message: L10n.string("Undid the last action"),
                icon: "arrow.uturn.backward",
                style: .positive,
                showsUndo: false,
                duration: 3
            ))
            events.send(.restorePosition(asset: asset, preferredIndex: originalIndex, refreshSource: false))

        case .favorite(let asset, let originalIndex, let previousStatus):
            favoriteMutationTargets[asset.localIdentifier] = previousStatus
            dataManager.setPhotoFavoriteImmediately(asset, isFavorite: previousStatus) { success in
                self.favoriteMutationTargets.removeValue(forKey: asset.localIdentifier)
                if success {
                    self.finishUndo()
                    self.events.send(.haptic(.success))
                    self.events.send(.feedback(
                        message: L10n.string("Undid the last action"),
                        icon: "arrow.uturn.backward",
                        style: .positive,
                        showsUndo: false,
                        duration: 3
                    ))
                    self.events.send(.restorePosition(
                        asset: asset,
                        preferredIndex: originalIndex,
                        refreshSource: refreshesAfterFavoriteUndo
                    ))
                } else {
                    self.actionHistory.append(action)
                    self.finishUndo()
                    self.events.send(.haptic(.error))
                    self.events.send(.feedback(
                        message: L10n.string("Couldn’t undo. Try again."),
                        icon: "exclamationmark.triangle",
                        style: .warning,
                        showsUndo: false,
                        duration: 3
                    ))
                }
            }

        case .fileToAlbum(
            let asset,
            let collection,
            let albumID,
            let originalIndex,
            let wasReviewed,
            let wasSessionReviewed,
            let filingKey
        ):
            pendingAlbumFilingUndoKeys.insert(filingKey)
            pendingAlbumUndoRefreshSources[filingKey] = refreshesAfterAlbumRemoval

            if completedAlbumFilingKeys.remove(filingKey) != nil {
                dataManager.removePhotoFromAlbum(asset, album: collection) { success in
                    self.completeAlbumUndo(
                        asset: asset,
                        preferredIndex: originalIndex,
                        action: .fileToAlbum(
                            asset,
                            album: collection,
                            albumID: albumID,
                            originalIndex: originalIndex,
                            wasReviewed: wasReviewed,
                            wasSessionReviewed: wasSessionReviewed,
                            filingKey: filingKey
                        ),
                        success: success,
                        dataManager: dataManager,
                        session: session,
                        refreshSource: refreshesAfterAlbumRemoval
                    )
                }
            }
            // If addPhotoToAlbum is still in flight, its completion consumes the
            // pending key and immediately performs the compensating removal.
            else if !albumFilingAssetIDs.contains(asset.localIdentifier) {
                pendingAlbumFilingUndoKeys.remove(filingKey)
                pendingAlbumUndoRefreshSources.removeValue(forKey: filingKey)
                restoreReviewState(
                    asset: asset,
                    wasReviewed: wasReviewed,
                    wasSessionReviewed: wasSessionReviewed,
                    dataManager: dataManager,
                    session: session
                )
                finishUndo()
                events.send(.restorePosition(asset: asset, preferredIndex: originalIndex, refreshSource: false))
            }
        }
    }

    private func completeAlbumUndo(
        asset: PHAsset,
        preferredIndex: Int,
        action: PhotoReviewActionRecord,
        success: Bool,
        dataManager: DataManager,
        session: PhotoReviewSession,
        refreshSource: Bool
    ) {
        let filingKey: String
        let wasReviewed: Bool
        let wasSessionReviewed: Bool
        if case .fileToAlbum(_, _, _, _, let storedWasReviewed, let storedWasSessionReviewed, let key) = action {
            filingKey = key
            wasReviewed = storedWasReviewed
            wasSessionReviewed = storedWasSessionReviewed
        } else {
            return
        }

        pendingAlbumFilingUndoKeys.remove(filingKey)
        pendingAlbumUndoRefreshSources.removeValue(forKey: filingKey)
        if success {
            dataManager.removeRecentOrganizedPhotoRecord(for: asset)
            restoreReviewState(
                asset: asset,
                wasReviewed: wasReviewed,
                wasSessionReviewed: wasSessionReviewed,
                dataManager: dataManager,
                session: session
            )
            finishUndo()
            events.send(.haptic(.success))
            events.send(.feedback(
                message: L10n.string("Undid the last action"),
                icon: "arrow.uturn.backward",
                style: .positive,
                showsUndo: false,
                duration: 3
            ))
            events.send(.restorePosition(asset: asset, preferredIndex: preferredIndex, refreshSource: refreshSource))
        } else {
            completedAlbumFilingKeys.insert(filingKey)
            actionHistory.append(action)
            finishUndo()
            events.send(.haptic(.error))
            events.send(.feedback(
                message: L10n.string("Could not remove from the album. Try again."),
                icon: "exclamationmark.triangle",
                style: .warning,
                showsUndo: false,
                duration: 3
            ))
        }
    }

    private func removeLatestDeleteAction(for asset: PHAsset) -> (
        originalIndex: Int,
        wasReviewed: Bool,
        wasSessionReviewed: Bool
    )? {
        guard let index = actionHistory.lastIndex(where: { action in
            if case .delete(let actionAsset, _, _, _) = action {
                return actionAsset.localIdentifier == asset.localIdentifier
            }
            return false
        }) else { return nil }

        guard case .delete(_, let originalIndex, let wasReviewed, let wasSessionReviewed) = actionHistory.remove(at: index) else {
            return nil
        }
        return (originalIndex, wasReviewed, wasSessionReviewed)
    }

    private func removeAction(filingKey: String) {
        guard let index = actionHistory.lastIndex(where: { action in
            if case .fileToAlbum(_, _, _, _, _, _, let key) = action { return key == filingKey }
            return false
        }) else { return }
        actionHistory.remove(at: index)
    }

    private func restoreReviewState(
        asset: PHAsset,
        wasReviewed: Bool,
        wasSessionReviewed: Bool,
        dataManager: DataManager,
        session: PhotoReviewSession
    ) {
        dataManager.restoreReviewedState(asset, wasReviewed: wasReviewed)
        restoreSessionReviewedState(asset: asset, wasReviewed: wasSessionReviewed, session: session)
    }

    private func restoreSessionReviewedState(
        asset: PHAsset,
        wasReviewed: Bool,
        session: PhotoReviewSession
    ) {
        if wasReviewed {
            session.reviewedIDs.insert(asset.localIdentifier)
        } else {
            session.reviewedIDs.remove(asset.localIdentifier)
        }
    }

    private func finishUndo() {
        isUndoInProgress = false
    }
}
