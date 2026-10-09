import Foundation

enum AssetQueryEngine {
    static func execute(
        query: AssetQuery,
        assets: [AssetQueryMetadata],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AssetQueryResult {
        let cutoff = query.age.cutoff(now: now, calendar: calendar)
        var seen = Set<String>()
        let matching = assets.filter { asset in
            guard seen.insert(asset.id).inserted else { return false }
            if query.age != .all {
                guard let date = asset.creationDate, let cutoff, date < cutoff else { return false }
            }
            switch query.content {
            case .all: break
            case .photos: guard asset.mediaType == .photo else { return false }
            case .videos: guard asset.mediaType == .video else { return false }
            case .favorites: guard asset.isFavorite else { return false }
            }
            switch query.reviewStatus {
            case .all: break
            case .pending: guard !asset.isReviewed else { return false }
            case .reviewed: guard asset.isReviewed else { return false }
            }
            return true
        }
        let ordered: [AssetQueryMetadata]
        let sections: [AssetQuerySection]
        if query.grouping == .none {
            ordered = matching.sorted { precedes($0, $1, sort: query.sort) }
            sections = ordered.isEmpty ? [] : [.init(id: .ungrouped, assetIDs: ordered.map(\.id))]
        } else {
            let groups = Dictionary(grouping: matching) { asset -> AssetQuerySectionID in
                guard let date = asset.creationDate else { return .undated }
                if query.grouping == .day { return .day(calendar.startOfDay(for: date)) }
                guard let month = calendar.dateInterval(of: .month, for: date)?.start else { return .undated }
                return .month(month)
            }
            let keys = groups.keys.sorted { lhs, rhs in
                switch (lhs.date, rhs.date) {
                case let (left?, right?): return query.sort == .oldestFirst ? left < right : left > right
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return false
                }
            }
            let buckets = keys.map { key in
                (key, groups[key, default: []].sorted { precedes($0, $1, sort: query.sort) })
            }
            sections = buckets.map { .init(id: $0.0, assetIDs: $0.1.map(\.id)) }
            ordered = buckets.flatMap(\.1)
        }
        let pendingIDs = ordered.filter { !$0.isReviewed }.map(\.id)
        let knownSizes = ordered.compactMap { $0.size.knownSizeMB }
        return AssetQueryResult(
            query: query,
            sections: sections,
            assetIDs: ordered.map(\.id),
            pendingIDs: pendingIDs,
            metadataByID: Dictionary(uniqueKeysWithValues: ordered.map { ($0.id, $0) }),
            summary: .init(
                count: ordered.count, pendingCount: pendingIDs.count,
                knownSizeMB: knownSizes.reduce(0, +),
                unknownSizeCount: ordered.count - knownSizes.count
            )
        )
    }

    private static func precedes(_ lhs: AssetQueryMetadata, _ rhs: AssetQueryMetadata, sort: AssetSort) -> Bool {
        if sort == .largestFirst {
            switch (lhs.size.knownSizeMB, rhs.size.knownSizeMB) {
            case let (left?, right?) where left != right: return left > right
            case (_?, nil): return true
            case (nil, _?): return false
            default: break
            }
        }
        switch (lhs.creationDate, rhs.creationDate) {
        case let (left?, right?) where left != right:
            return sort == .oldestFirst ? left < right : left > right
        case (_?, nil): return true
        case (nil, _?): return false
        default: return lhs.id < rhs.id
        }
    }
}
