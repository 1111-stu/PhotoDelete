import Foundation
import Photos

/// Shared local-only size work. Requests are serialized to avoid retaining
/// multiple full image Data buffers, and cancelled only after the last caller leaves.
@MainActor
final class AssetSizeLoader {
    static let shared = AssetSizeLoader()

    private struct Key: Hashable {
        let managerID: ObjectIdentifier
        let assetID: String
        let modificationDate: Date?
    }

    private final class Request {
        let asset: PHAsset
        let dataManager: DataManager
        var waiters: [UUID: CheckedContinuation<AssetQuerySizeState, Error>] = [:]
        var task: Task<Void, Never>?

        init(asset: PHAsset, dataManager: DataManager) {
            self.asset = asset
            self.dataManager = dataManager
        }
    }

    private var requests: [Key: Request] = [:]
    private var queue: [Key] = []
    private var activeKey: Key?

    func estimate(for asset: PHAsset, dataManager: DataManager) async throws -> AssetQuerySizeState {
        try Task.checkCancellation()
        if let estimate = dataManager.cachedAssetFileSizeEstimate(for: asset), estimate.isReliable {
            return Self.state(for: estimate)
        }
        let key = Key(managerID: ObjectIdentifier(dataManager), assetID: asset.localIdentifier, modificationDate: asset.modificationDate)
        let caller = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                let request: Request
                if let existing = requests[key] {
                    request = existing
                } else {
                    request = Request(asset: asset, dataManager: dataManager)
                    requests[key] = request
                    queue.append(key)
                }
                request.waiters[caller] = continuation
                startNextIfNeeded()
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(caller: caller, key: key) }
        }
    }

    static func state(for estimate: AssetFileSizeEstimate) -> AssetQuerySizeState {
        switch estimate.source {
        case .assetResource:
            guard estimate.sizeMB.isFinite, estimate.sizeMB >= 0 else { return .unavailable }
            return .knownMB(estimate.sizeMB)
        case .iCloud: return .iCloud
        case .unavailable: return .unavailable
        }
    }

    private func startNextIfNeeded() {
        guard activeKey == nil else { return }
        while !queue.isEmpty {
            let key = queue.removeFirst()
            guard let request = requests[key], !request.waiters.isEmpty else { continue }
            activeKey = key
            request.task = Task { [weak self, request] in
                guard let self else { return }
                let result: Result<AssetQuerySizeState, Error>
                do {
                    let estimate: AssetFileSizeEstimate
                    if request.asset.mediaType == .video {
                        estimate = try await request.dataManager.photoLibraryManager.videoFileSizeEstimate(for: request.asset)
                    } else if request.asset.mediaType == .image {
                        estimate = try await request.dataManager.photoLibraryManager.photoFileSizeEstimate(for: request.asset)
                    } else {
                        estimate = .init(sizeMB: 0, source: .unavailable)
                    }
                    try Task.checkCancellation()
                    // Never let an old in-flight response poison a newer version's cache.
                    if request.asset.modificationDate == key.modificationDate {
                        request.dataManager.cacheAssetFileSizeEstimate(estimate, for: request.asset)
                    }
                    result = .success(Self.state(for: estimate))
                } catch {
                    result = .failure(error)
                }
                self.finish(key: key, request: request, result: result)
            }
            return
        }
    }

    private func finish(key: Key, request: Request, result: Result<AssetQuerySizeState, Error>) {
        // A cancelled operation may finish after another caller requeued the same key.
        if requests[key] === request { requests.removeValue(forKey: key) }
        if activeKey == key { activeKey = nil }
        request.task = nil
        let waiters = Array(request.waiters.values)
        request.waiters.removeAll()
        for waiter in waiters { waiter.resume(with: result) }
        startNextIfNeeded()
    }

    private func cancel(caller: UUID, key: Key) {
        guard let request = requests[key], let waiter = request.waiters.removeValue(forKey: caller) else { return }
        waiter.resume(throwing: CancellationError())
        guard request.waiters.isEmpty else { return }
        if request.task != nil {
            // Keep the active slot occupied until Photos acknowledges cancellation.
            requests.removeValue(forKey: key)
            request.task?.cancel()
        } else {
            requests.removeValue(forKey: key)
            queue.removeAll { $0 == key }
        }
    }
}
