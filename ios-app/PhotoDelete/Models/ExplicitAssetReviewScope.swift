import Foundation

/// A temporary review queue frozen from a browser result, independent of its query.
struct ExplicitAssetReviewScope: Identifiable {
    enum ReviewedPolicy: Equatable {
        case includeAll
        case skipPreviouslyReviewed
    }

    let id: UUID
    let orderedAssetIDs: [String]
    let albumInfo: AlbumInfo?
    let reviewedPolicy: ReviewedPolicy

    init(
        orderedAssetIDs: [String],
        id: UUID = UUID(),
        albumInfo: AlbumInfo? = nil,
        reviewedPolicy: ReviewedPolicy = .includeAll
    ) {
        self.id = id
        var seen: Set<String> = []
        self.orderedAssetIDs = orderedAssetIDs.filter { seen.insert($0).inserted }
        self.albumInfo = albumInfo
        self.reviewedPolicy = reviewedPolicy
    }

    var progressScopeID: String { "explicit:\(id.uuidString)" }

    // Album review deliberately includes assets reviewed elsewhere in the library.
    func usesPersistedReviewedState(hasAlbumContext: Bool) -> Bool {
        albumInfo == nil && !hasAlbumContext && reviewedPolicy == .skipPreviouslyReviewed
    }

    /// Resolves only frozen IDs. Newly discovered assets never join this queue.
    func orderedElements<Element>(
        from elements: [Element],
        retainingAssetIDs: Set<String>? = nil,
        identifier: (Element) -> String
    ) -> [Element] {
        let byID = Dictionary(elements.map { (identifier($0), $0) }, uniquingKeysWith: { _, latest in latest })
        return orderedAssetIDs.compactMap { assetID in
            guard retainingAssetIDs?.contains(assetID) != false else { return nil }
            return byID[assetID]
        }
    }
}
