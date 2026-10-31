import Foundation

enum AssetQueryEngine {
    static func execute(
        query: AssetQuery,
        assets: [AssetQueryMetadata],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AssetQueryResult {
        execute(query: query, assets: assets, now: now, calendar: calendar, checkCancellation: {})
    }

    static func executeCancellable(
        query: AssetQuery,
        assets: [AssetQueryMetadata],
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> AssetQueryResult {
        try execute(query: query, assets: assets, now: now, calendar: calendar) {
            try Task.checkCancellation()
        }
    }

    private static func execute(
        query: AssetQuery,
        assets: [AssetQueryMetadata],
        now: Date,
        calendar: Calendar,
        checkCancellation: () throws -> Void
    ) rethrows -> AssetQueryResult {
        try checkCancellation()
        let cutoff = query.age.cutoff(now: now, calendar: calendar)
        var seen = Set<String>()
        let matching = try assets.filter { asset in
            try checkCancellation()
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
            ordered = try matching.sorted {
                try checkCancellation()
                return precedes($0, $1, sort: query.sort)
            }
            sections = ordered.isEmpty ? [] : [.init(id: .ungrouped, assetIDs: ordered.map(\.id))]
        } else {
            var groups: [AssetQuerySectionID: [AssetQueryMetadata]] = [:]
            for asset in matching {
                try checkCancellation()
                let key: AssetQuerySectionID
                if let date = asset.creationDate {
                    if query.grouping == .day {
                        key = .day(calendar.startOfDay(for: date))
                    } else if let month = calendar.dateInterval(of: .month, for: date)?.start {
                        key = .month(month)
                    } else {
                        key = .undated
                    }
                } else {
                    key = .undated
                }
                groups[key, default: []].append(asset)
            }
            let keys = try groups.keys.sorted { lhs, rhs in
                try checkCancellation()
                switch (lhs.date, rhs.date) {
                case let (left?, right?): return query.sort == .oldestFirst ? left < right : left > right
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return false
                }
            }
            let buckets = try keys.map { key in
                try checkCancellation()
                let sorted = try groups[key, default: []].sorted {
                    try checkCancellation()
                    return precedes($0, $1, sort: query.sort)
                }
                return (key, sorted)
            }
            sections = buckets.map { .init(id: $0.0, assetIDs: $0.1.map(\.id)) }
            ordered = buckets.flatMap(\.1)
        }
        var pendingIDs: [String] = []
        var knownSizeMB = 0.0
        var knownSizeCount = 0
        var estimatedSizeMB = 0.0
        var assetIDs: [String] = []
        var metadataByID: [String: AssetQueryMetadata] = [:]
        for asset in ordered {
            try checkCancellation()
            assetIDs.append(asset.id)
            metadataByID[asset.id] = asset
            estimatedSizeMB += asset.estimatedSizeMB
            if !asset.isReviewed { pendingIDs.append(asset.id) }
            if let size = asset.size.knownSizeMB {
                knownSizeMB += size
                knownSizeCount += 1
            }
        }
        try checkCancellation()
        return AssetQueryResult(
            query: query,
            sections: sections,
            assetIDs: assetIDs,
            pendingIDs: pendingIDs,
            metadataByID: metadataByID,
            summary: .init(
                count: ordered.count, pendingCount: pendingIDs.count,
                knownSizeMB: knownSizeMB,
                estimatedSizeMB: estimatedSizeMB,
                unknownSizeCount: ordered.count - knownSizeCount
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
