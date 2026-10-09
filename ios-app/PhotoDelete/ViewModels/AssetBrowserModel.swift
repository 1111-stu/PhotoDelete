import Foundation
import Combine
import Photos

@MainActor
final class AssetBrowserModel: ObservableObject {
    @Published var query: AssetQuery {
        didSet {
            guard query != oldValue else { return }
            subscribe(clearResult: query.source != oldValue.source)
        }
    }
    @Published private(set) var result: AssetQueryResult?
    @Published private(set) var assetsByID: [String: PHAsset] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var isCalculatingSizes = false
    @Published private(set) var sourceUnavailable = false

    let defaultQuery: AssetQuery
    private var service: (any AssetQueryServing)?
    private var updatesTask: Task<Void, Never>?
    private var generation = 0
    private var visibleIDs: Set<String> = []
    private var interactionActive = false
    private var isActive = true
    private let sessionID = UUID()

    init(query: AssetQuery, service: (any AssetQueryServing)? = nil) {
        self.query = query
        defaultQuery = query
        self.service = service
    }

    deinit { updatesTask?.cancel() }

    func start(dataManager: DataManager) {
        isActive = true
        if service == nil { service = AssetQueryService(dataManager: dataManager) }
        subscribe(clearResult: result == nil)
    }

    func stop() {
        isActive = false
        interactionActive = false
        service?.setInteractionActive(false, sessionID: sessionID)
        generation += 1
        updatesTask?.cancel()
        updatesTask = nil
        isLoading = false
    }

    func refresh() { subscribe(clearResult: false) }
    func reset() { query = defaultQuery }

    func setVisibleAssetIDs(_ identifiers: Set<String>) {
        visibleIDs = identifiers
        service?.setVisibleAssetIDs(identifiers, sessionID: sessionID)
    }

    func setInteractionActive(_ active: Bool) {
        interactionActive = active
        service?.setInteractionActive(active, sessionID: sessionID)
    }

    private func subscribe(clearResult: Bool) {
        guard isActive, let service else { return }
        generation += 1
        let currentGeneration = generation
        updatesTask?.cancel()
        if clearResult {
            result = nil
            assetsByID = [:]
            sourceUnavailable = false
        }
        isLoading = true
        service.setVisibleAssetIDs(visibleIDs, sessionID: sessionID)
        service.setInteractionActive(interactionActive, sessionID: sessionID)
        let query = query
        let sessionID = sessionID
        updatesTask = Task { [weak self] in
            for await update in service.updates(for: query, sessionID: sessionID) {
                guard !Task.isCancelled, let self, self.generation == currentGeneration else { return }
                self.assetsByID = update.assetsByID
                self.result = update.result
                self.isLoading = false
                self.isCalculatingSizes = update.result.isCalculatingSizes
                self.sourceUnavailable = update.sourceUnavailable
            }
        }
    }
}
