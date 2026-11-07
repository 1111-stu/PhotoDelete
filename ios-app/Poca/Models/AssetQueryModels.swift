import Foundation

/// Stable, nonlocalized source identifiers. Photos objects stay in the source adapter.
enum AssetCategoryID: String, CaseIterable, Hashable, Sendable {
    case all, unclassified, videos, screenshots, screenRecordings, livePhotos, favorites
}

enum AssetVirtualAlbumID: String, CaseIterable, Hashable, Sendable {
    case all, recents, favorites, screenshots, videos, livePhotos
}

enum AssetAlbumReference: Hashable, Sendable {
    case collection(id: String)
    case virtual(AssetVirtualAlbumID)
}

enum AssetSource: Hashable, Sendable {
    case category(AssetCategoryID)
    case album(AssetAlbumReference)
}

enum AssetContentFilter: String, CaseIterable, Identifiable, Sendable {
    case all, photos, videos, favorites
    var id: String { rawValue }
}

enum AssetAgeFilter: String, CaseIterable, Identifiable, Sendable {
    case all, olderThan15Days, olderThan30Days, olderThan180Days, olderThanOneYear
    var id: String { rawValue }

    func cutoff(now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .all: return nil
        case .olderThan15Days: return calendar.date(byAdding: .day, value: -15, to: today)
        case .olderThan30Days: return calendar.date(byAdding: .day, value: -30, to: today)
        case .olderThan180Days: return calendar.date(byAdding: .day, value: -180, to: today)
        case .olderThanOneYear: return calendar.date(byAdding: .year, value: -1, to: today)
        }
    }
}

enum AssetReviewFilter: String, CaseIterable, Identifiable, Sendable {
    case all, pending, reviewed
    var id: String { rawValue }
}

enum AssetTimeGrouping: String, CaseIterable, Identifiable, Sendable {
    case none, day, month
    var id: String { rawValue }
}

enum AssetSort: String, CaseIterable, Identifiable, Sendable {
    case largestFirst, newestFirst, oldestFirst
    var id: String { rawValue }
}

struct AssetQuery: Equatable, Sendable {
    var source: AssetSource
    var content: AssetContentFilter = .all
    var age: AssetAgeFilter = .all
    var reviewStatus: AssetReviewFilter = .all
    var grouping: AssetTimeGrouping = .none
    var sort: AssetSort = .largestFirst
}

enum AssetQueryMediaType: Sendable {
    case photo, video, other
}

enum AssetQuerySizeState: Equatable, Sendable {
    case pending, loading, knownMB(Double), iCloud, unavailable

    var knownSizeMB: Double? {
        guard case let .knownMB(value) = self, value.isFinite, value >= 0 else { return nil }
        return value
    }

    var isCalculating: Bool {
        self == .pending || self == .loading
    }
}

/// Immutable metadata is the only payload transferred to the background query engine.
struct AssetQueryMetadata: Identifiable, Equatable, Sendable {
    let id: String
    let creationDate: Date?
    let modificationDate: Date?
    let mediaType: AssetQueryMediaType
    let isFavorite: Bool
    let isReviewed: Bool
    let duration: TimeInterval
    var size: AssetQuerySizeState
    /// Metadata-only placeholder shown until the exact size resolves.
    let estimatedSizeMB: Double

    init(
        id: String, creationDate: Date?, modificationDate: Date? = nil,
        mediaType: AssetQueryMediaType = .photo, isFavorite: Bool = false,
        isReviewed: Bool = false, duration: TimeInterval = 0,
        size: AssetQuerySizeState = .pending, estimatedSizeMB: Double = 0
    ) {
        self.id = id
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.mediaType = mediaType
        self.isFavorite = isFavorite
        self.isReviewed = isReviewed
        self.duration = duration
        self.size = size
        self.estimatedSizeMB = estimatedSizeMB
    }
}

enum AssetQuerySectionID: Hashable, Sendable {
    case ungrouped, day(Date), month(Date), undated

    var date: Date? {
        switch self {
        case let .day(date), let .month(date): return date
        case .ungrouped, .undated: return nil
        }
    }
}

struct AssetQuerySection: Identifiable, Equatable, Sendable {
    let id: AssetQuerySectionID
    let assetIDs: [String]
}

struct AssetQuerySummary: Equatable, Sendable {
    let count: Int
    let pendingCount: Int
    let knownSizeMB: Double
    /// Total metadata estimate; the header shows this until exact sizes settle.
    let estimatedSizeMB: Double
    let unknownSizeCount: Int
    var reviewedCount: Int { count - pendingCount }

    init(
        count: Int,
        pendingCount: Int,
        knownSizeMB: Double,
        estimatedSizeMB: Double = 0,
        unknownSizeCount: Int
    ) {
        self.count = count
        self.pendingCount = pendingCount
        self.knownSizeMB = knownSizeMB
        self.estimatedSizeMB = estimatedSizeMB
        self.unknownSizeCount = unknownSizeCount
    }
}

struct AssetQueryResult: Equatable, Sendable {
    let query: AssetQuery
    let sections: [AssetQuerySection]
    let assetIDs: [String]
    let pendingIDs: [String]
    let metadataByID: [String: AssetQueryMetadata]
    let summary: AssetQuerySummary

    var isCalculatingSizes: Bool { metadataByID.values.contains { $0.size.isCalculating } }
}
