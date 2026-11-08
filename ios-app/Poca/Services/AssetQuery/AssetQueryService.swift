import Foundation
import Combine
import Photos
import UIKit

/// Photos references never cross the main actor; the result itself is a Sendable value.
@MainActor
struct AssetQueryUpdate {
    let result: AssetQueryResult
    let assetsByID: [String: PHAsset]
    let sourceUnavailable: Bool
}

@MainActor
protocol AssetQueryServing: AnyObject {
    func updates(for query: AssetQuery, sessionID: UUID) -> AsyncStream<AssetQueryUpdate>
    func setVisibleAssetIDs(_ identifiers: Set<String>, sessionID: UUID)
    func setInteractionActive(_ active: Bool, sessionID: UUID)
}

extension AssetQueryServing {
    func updates(for query: AssetQuery) -> AsyncStream<AssetQueryUpdate> { updates(for: query, sessionID: UUID()) }
    func setVisibleAssetIDs(_ identifiers: Set<String>, sessionID: UUID) {}
    func setInteractionActive(_ active: Bool, sessionID: UUID) {}
}

/// A shared service can have multiple independent subscriptions. Query and
/// cancellation belong to subscriptions, while size work and the existing cache are shared.
@MainActor
final class AssetQueryService: AssetQueryServing {
    private let dataManager: DataManager
    private let resolver: any AssetSourceResolving
    private let sizeLoader: AssetSizeLoader
    private var sessions: [UUID: AssetQuerySubscription] = [:]
    private var preferences: [UUID: (visibleIDs: Set<String>, interactionActive: Bool)] = [:]

    init(
        dataManager: DataManager,
        resolver: (any AssetSourceResolving)? = nil,
        sizeLoader: AssetSizeLoader? = nil
    ) {
        self.dataManager = dataManager
        self.resolver = resolver ?? AssetSourceResolver(dataManager: dataManager)
        self.sizeLoader = sizeLoader ?? .shared
    }

    func updates(for query: AssetQuery, sessionID: UUID) -> AsyncStream<AssetQueryUpdate> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let session = AssetQuerySubscription(
                sessionID: sessionID, query: query, dataManager: dataManager, resolver: resolver,
                sizeLoader: sizeLoader, continuation: continuation
            )
            session.visibleIDs = preferences[sessionID]?.visibleIDs ?? []
            session.interactionActive = preferences[sessionID]?.interactionActive ?? false
            sessions[id] = session
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.sessions.removeValue(forKey: id)?.stop()
                    if !self.sessions.values.contains(where: { $0.sessionID == sessionID }) {
                        self.preferences.removeValue(forKey: sessionID)
                    }
                }
            }
            session.start()
        }
    }

    func setVisibleAssetIDs(_ identifiers: Set<String>, sessionID: UUID) {
        preferences[sessionID] = (identifiers, preferences[sessionID]?.interactionActive ?? false)
        for session in sessions.values where session.sessionID == sessionID { session.visibleIDs = identifiers }
    }

    func setInteractionActive(_ active: Bool, sessionID: UUID) {
        preferences[sessionID] = (preferences[sessionID]?.visibleIDs ?? [], active)
        for session in sessions.values where session.sessionID == sessionID {
            session.interactionActive = active
            if !active { session.publishSizes() }
        }
    }
}

@MainActor
private final class AssetQuerySubscription {
    let sessionID: UUID
    let query: AssetQuery
    var visibleIDs: Set<String> = []
    var interactionActive = false
    private let dataManager: DataManager
    private let resolver: any AssetSourceResolving
    private let sizeLoader: AssetSizeLoader
    private let continuation: AsyncStream<AssetQueryUpdate>.Continuation
    private var cancellables: Set<AnyCancellable> = []
    private var buildTask: Task<Void, Never>?
    private var settlementTask: Task<Void, Never>?
    private var sizeTask: Task<Void, Never>?
    private var generation = 0
    private var assetsByID: [String: PHAsset] = [:]
    private var metadata: [AssetQueryMetadata] = []
    private var metadataIndexByID: [String: Int] = [:]
    private var sizeByID: [String: (version: Date?, state: AssetQuerySizeState)] = [:]
    private var lastResult: AssetQueryResult?
    private var sourceUnavailable = false
    private var stopped = false

    init(
        sessionID: UUID, query: AssetQuery, dataManager: DataManager, resolver: any AssetSourceResolving,
        sizeLoader: AssetSizeLoader, continuation: AsyncStream<AssetQueryUpdate>.Continuation
    ) {
        self.query = query
        self.sessionID = sessionID
        self.dataManager = dataManager
        self.resolver = resolver
        self.sizeLoader = sizeLoader
        self.continuation = continuation
    }

    func start() {
        // Observe published revisions and values; never replace either Photos callback.
        let changes: [AnyPublisher<Void, Never>] = [
            dataManager.$assetLibraryRevision.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            dataManager.$reviewedAssetIDs.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            dataManager.photoLibraryManager.$favorites.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            dataManager.$systemAlbums.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            dataManager.$userAlbums.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            dataManager.$albumMemberAssetIDs.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            dataManager.photoLibraryManager.$authorizationStatus.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification).map { _ in () }.eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification).map { _ in () }.eraseToAnyPublisher()
        ]
        Publishers.MergeMany(changes)
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.reloadSource() }
            .store(in: &cancellables)
        reloadSource()
    }

    func stop() {
        stopped = true
        generation += 1
        buildTask?.cancel()
        settlementTask?.cancel()
        sizeTask?.cancel()
        cancellables.removeAll()
        continuation.finish()
    }

    private func reloadSource() {
        guard !stopped else { return }
        generation += 1
        let currentGeneration = generation
        buildTask?.cancel()
        settlementTask?.cancel()
        sizeTask?.cancel()
        buildTask = Task { [weak self] in
            guard let self else { return }
            let resolution = await self.resolver.resolve(self.query.source)
            guard !Task.isCancelled, self.generation == currentGeneration, !self.stopped else { return }
            self.applySource(resolution)
            guard let result = await self.calculate(), !Task.isCancelled,
                  self.generation == currentGeneration, !self.stopped else { return }
            self.publish(result, preserveOrder: false)
            self.loadSizes(result: result, generation: currentGeneration)
        }
    }

    private func applySource(_ resolution: AssetSourceResolution) {
        settlementTask?.cancel()
        sourceUnavailable = resolution.isUnavailable
        assetsByID = Dictionary(resolution.assets.map { ($0.localIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        let currentAssets = resolution.assets
        sizeByID = sizeByID.filter {
            assetsByID[$0.key]?.modificationDate == $0.value.version &&
                assetsByID[$0.key] != nil && $0.value.state.knownSizeMB != nil
        }
        let reviewed = dataManager.completedAssetIDsForReview
        metadata = currentAssets.map { asset in
            let size: AssetQuerySizeState
            if let cached = dataManager.cachedAssetFileSizeEstimate(for: asset), cached.isReliable {
                size = AssetSizeLoader.state(for: cached)
            } else {
                size = sizeByID[asset.localIdentifier]?.state ?? .pending
            }
            return .init(
                id: asset.localIdentifier, creationDate: asset.creationDate,
                modificationDate: asset.modificationDate,
                mediaType: asset.mediaType == .video ? .video : (asset.mediaType == .image ? .photo : .other),
                isFavorite: asset.isFavorite, isReviewed: reviewed.contains(asset.localIdentifier),
                duration: asset.duration, size: size,
                estimatedSizeMB: AssetSizeHeuristic.estimateMB(for: asset)
            )
        }
        metadataIndexByID = Dictionary(metadata.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { first, _ in first })
    }

    private func calculate() async -> AssetQueryResult? {
        let snapshot = metadata
        let query = query
        let now = Date()
        let calendar = Calendar.current
        let work = Task.detached(priority: .userInitiated) {
            try AssetQueryEngine.executeCancellable(query: query, assets: snapshot, now: now, calendar: calendar)
        }
        return await withTaskCancellationHandler {
            do {
                let result = try await work.value
                return Task.isCancelled ? nil : result
            } catch {
                return nil
            }
        } onCancel: { work.cancel() }
    }

    private func loadSizes(result: AssetQueryResult, generation currentGeneration: Int) {
        let matchingIDs = Set(result.assetIDs)
        sizeTask = Task { [weak self] in
            guard let self else { return }
            let remaining = result.assetIDs.filter { result.metadataByID[$0]?.size.isCalculating == true }
            var processed = Set<String>()
            var cursor = 0
            var lastPublish = Date()
            while processed.count < remaining.count, !Task.isCancelled, self.generation == currentGeneration {
                while cursor < remaining.count, processed.contains(remaining[cursor]) { cursor += 1 }
                let visible = self.visibleIDs.first { id in matchingIDs.contains(id) && !processed.contains(id) && result.metadataByID[id]?.size.isCalculating == true }
                guard let id = visible ?? (cursor < remaining.count ? remaining[cursor] : nil) else { break }
                processed.insert(id)
                guard matchingIDs.contains(id), let asset = self.assetsByID[id] else { continue }
                let state: AssetQuerySizeState
                do {
                    state = try await self.sizeLoader.estimate(for: asset, dataManager: self.dataManager)
                } catch is CancellationError {
                    return
                } catch {
                    state = .unavailable
                }
                guard !Task.isCancelled, self.generation == currentGeneration else { return }
                self.sizeByID[id] = (asset.modificationDate, state)
                if let index = self.metadataIndexByID[id] { self.metadata[index].size = state }
                settlementTask?.cancel()
                if Date().timeIntervalSince(lastPublish) >= 0.4 {
                    guard let updated = await self.calculate(), !Task.isCancelled,
                          self.generation == currentGeneration else { return }
                    // Size-only updates must never reshuffle the grid; keep the
                    // first-frame order and replace size labels in place.
                    self.publish(updated, preserveOrder: true)
                    lastPublish = Date()
                }
            }
            guard let updated = await self.calculate(), !Task.isCancelled,
                  self.generation == currentGeneration else { return }
            self.publish(updated, preserveOrder: true)
        }
    }

    func publishSizes() {
        guard !stopped, lastResult != nil else { return }
        let currentGeneration = generation
        settlementTask?.cancel()
        settlementTask = Task { [weak self] in
            guard let self, let result = await self.calculate(), !Task.isCancelled,
                  self.generation == currentGeneration else { return }
            self.publish(result, preserveOrder: true)
        }
    }

    private func publish(_ result: AssetQueryResult, preserveOrder: Bool) {
        let next: AssetQueryResult
        if preserveOrder, let previous = lastResult, Set(previous.assetIDs) == Set(result.assetIDs) {
            next = .init(
                query: result.query, sections: previous.sections, assetIDs: previous.assetIDs,
                pendingIDs: previous.assetIDs.filter { result.metadataByID[$0]?.isReviewed == false },
                metadataByID: result.metadataByID, summary: result.summary
            )
        } else {
            next = result
        }
        lastResult = next
        continuation.yield(.init(result: next, assetsByID: assetsByID, sourceUnavailable: sourceUnavailable))
    }
}
