import Testing
import Foundation
import Combine
import Photos
@testable import PhotoDelete

struct AssetQueryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func query() -> AssetQuery { .init(source: .category(.screenRecordings)) }

    @Test func ageFilterUsesStrictLocalCalendarBoundary() {
        let now = date(2026, 3, 20, hour: 18)
        let cutoff = calendar.date(byAdding: .day, value: -15, to: calendar.startOfDay(for: now))!
        var query = query()
        query.age = .olderThan15Days
        let assets: [AssetQueryMetadata] = [
            .init(id: "before", creationDate: cutoff.addingTimeInterval(-1)),
            .init(id: "at", creationDate: cutoff),
            .init(id: "after", creationDate: cutoff.addingTimeInterval(1)),
            .init(id: "nil", creationDate: nil)
        ]
        let result = AssetQueryEngine.execute(query: query, assets: assets, now: now, calendar: calendar)
        #expect(result.assetIDs == ["before"])
        #expect(query.age.cutoff(now: now, calendar: calendar) == date(2026, 3, 5))
    }

    @Test func yearFilterUsesCalendarYearAcrossLeapDay() {
        let now = date(2025, 3, 1, hour: 12)
        #expect(AssetAgeFilter.olderThanOneYear.cutoff(now: now, calendar: calendar) == date(2024, 3, 1))
        #expect(AssetAgeFilter.olderThan180Days.cutoff(now: now, calendar: calendar) == calendar.date(byAdding: .day, value: -180, to: calendar.startOfDay(for: now)))
    }

    @Test func capacitySortKeepsUnknownSeparateAndHasStableTies() {
        let when = date(2026, 1, 1)
        let assets: [AssetQueryMetadata] = [
            .init(id: "unknown", creationDate: date(2026, 2, 1), size: .iCloud),
            .init(id: "b", creationDate: when, size: .knownMB(20)),
            .init(id: "a", creationDate: when, size: .knownMB(20)),
            .init(id: "zero", creationDate: nil, size: .knownMB(0)),
            .init(id: "invalid", creationDate: nil, size: .knownMB(.nan))
        ]
        let result = AssetQueryEngine.execute(query: query(), assets: assets)
        #expect(result.assetIDs == ["a", "b", "zero", "unknown", "invalid"])
        #expect(result.summary.knownSizeMB == 40)
        #expect(result.summary.unknownSizeCount == 2)
    }

    @Test func largestFirstUsesEstimatesWhileExactSizesArePending() {
        let assets: [AssetQueryMetadata] = [
            .init(id: "pending-large", creationDate: date(2026, 1, 1), estimatedSizeMB: 30),
            .init(id: "known", creationDate: date(2026, 1, 2), size: .knownMB(10)),
            .init(id: "pending-small", creationDate: date(2026, 1, 3), estimatedSizeMB: 5)
        ]
        let result = AssetQueryEngine.execute(query: query(), assets: assets)
        #expect(result.assetIDs == ["pending-large", "known", "pending-small"])
    }

    @Test func estimatedSizesCoverPendingAssetsUntilExactSizesSettle() {
        let assets: [AssetQueryMetadata] = [
            .init(id: "pending", creationDate: nil, size: .pending, estimatedSizeMB: 12),
            .init(id: "known", creationDate: nil, size: .knownMB(8), estimatedSizeMB: 10)
        ]
        let result = AssetQueryEngine.execute(query: query(), assets: assets)
        #expect(result.summary.estimatedSizeMB == 22)
        #expect(result.summary.knownSizeMB == 8)
        #expect(result.isCalculatingSizes)
    }

    @Test func dateSortDoesNotDependOnInputOrderAndUndatedAlwaysLast() {
        let assets: [AssetQueryMetadata] = [
            .init(id: "nil", creationDate: nil),
            .init(id: "old", creationDate: date(2025, 1, 1)),
            .init(id: "new", creationDate: date(2026, 1, 1))
        ]
        var query = query()
        query.sort = .newestFirst
        #expect(AssetQueryEngine.execute(query: query, assets: assets).assetIDs == ["new", "old", "nil"])
        query.sort = .oldestFirst
        #expect(AssetQueryEngine.execute(query: query, assets: assets).assetIDs == ["old", "new", "nil"])
    }

    @Test func groupOrderFlatteningAndSummaryAgree() {
        let assets: [AssetQueryMetadata] = [
            .init(id: "old", creationDate: date(2025, 1, 1), isReviewed: true, size: .knownMB(8)),
            .init(id: "new-small", creationDate: date(2026, 1, 1), size: .knownMB(2)),
            .init(id: "new-large", creationDate: date(2026, 1, 2), size: .knownMB(4)),
            .init(id: "nil", creationDate: nil, size: .unavailable)
        ]
        var query = query()
        query.grouping = .month
        let result = AssetQueryEngine.execute(query: query, assets: assets, calendar: calendar)
        #expect(result.assetIDs == ["new-large", "new-small", "old", "nil"])
        #expect(result.sections.flatMap(\.assetIDs) == result.assetIDs)
        #expect(result.sections.last?.id == .undated)
        #expect(result.pendingIDs == ["new-large", "new-small", "nil"])
        #expect(result.summary == .init(count: 4, pendingCount: 3, knownSizeMB: 14, unknownSizeCount: 1))
        query.sort = .oldestFirst
        let oldest = AssetQueryEngine.execute(query: query, assets: assets, calendar: calendar)
        #expect(oldest.assetIDs == ["old", "new-small", "new-large", "nil"])
        #expect(oldest.sections.last?.id == .undated)
        query.grouping = .day
        #expect(AssetQueryEngine.execute(query: query, assets: assets, calendar: calendar).sections.count == 4)
    }

    @Test func reviewAndContentFiltersComposeWithoutChangingAlbumPolicy() {
        let assets: [AssetQueryMetadata] = [
            .init(id: "photo", creationDate: nil, mediaType: .photo, isFavorite: true, isReviewed: true),
            .init(id: "reviewed-video", creationDate: nil, mediaType: .video, isReviewed: true),
            .init(id: "pending-video", creationDate: nil, mediaType: .video)
        ]
        var query = AssetQuery(source: .album(.collection(id: "stable-album")))
        query.content = .videos
        let all = AssetQueryEngine.execute(query: query, assets: assets)
        #expect(all.assetIDs == ["pending-video", "reviewed-video"])
        #expect(all.pendingIDs == ["pending-video"])
        // Consumers can choose all IDs for album review, or pending IDs for special cleanup.
        query.reviewStatus = .reviewed
        #expect(AssetQueryEngine.execute(query: query, assets: assets).assetIDs == ["reviewed-video"])
        query.content = .favorites
        #expect(AssetQueryEngine.execute(query: query, assets: assets).assetIDs == ["photo"])
        query.content = .photos
        query.reviewStatus = .pending
        #expect(AssetQueryEngine.execute(query: query, assets: assets).summary.count == 0)
    }

    @Test func duplicateIDsCannotInflateStatistics() {
        let asset = AssetQueryMetadata(id: "same", creationDate: nil, size: .knownMB(4))
        let result = AssetQueryEngine.execute(query: query(), assets: [asset, asset])
        #expect(result.assetIDs == ["same"])
        #expect(result.summary.knownSizeMB == 4)
    }

    @Test func cancelledQueryThrowsWhileNonthrowingQueryRemainsUsable() async throws {
        let query = query()
        let assets = [AssetQueryMetadata(id: "asset", creationDate: nil, size: .knownMB(4))]
        let task = Task.detached {
            // Synchronize on cancellation before entering the engine, avoiding
            // a race where a tiny query finishes before the caller cancels it.
            while !Task.isCancelled { await Task.yield() }
            let expected = AssetQueryEngine.execute(query: query, assets: assets)
            #expect(expected.assetIDs == ["asset"])
            #expect(expected.summary.knownSizeMB == 4)
            return try AssetQueryEngine.executeCancellable(query: query, assets: assets)
        }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("A cancelled query returned a result")
        } catch is CancellationError {
            // Expected: the nonthrowing entry point above still returned the
            // complete result while the opt-in cancellable one rejects work.
        } catch {
            Issue.record("Expected CancellationError, received \(error)")
        }
    }

    @Test @MainActor func sourceAdaptersPreserveStableCategoryAndAlbumIdentity() {
        #expect(AssetSourceResolver.photoCategory(for: .screenRecordings) == .screenRecordings)
        #expect(AssetSourceResolver.photoCategory(for: .unclassified) == .unclassified)
        #expect(AssetSourceResolver.albumType(for: .recents) == .recents)
        let album = AlbumInfo(id: "virtual-old-title", title: "Localized Favorites", assetCollection: nil, type: .favorites)
        #expect(AssetSourceResolver.reference(for: album) == .virtual(.favorites))
        let unresolved = AlbumInfo(id: "persisted-user-id", title: "User Title", assetCollection: nil, type: .userCreated)
        #expect(AssetSourceResolver.reference(for: unresolved) == .collection(id: "persisted-user-id"))
        #expect(AssetSizeLoader.state(for: .init(sizeMB: 0, source: .iCloud)) == .iCloud)
        #expect(AssetSizeLoader.state(for: .init(sizeMB: 0, source: .unavailable)) == .unavailable)
    }

    @Test @MainActor func serviceSubscriptionsResolveIndependentSources() async {
        let resolver = EmptyAssetQueryResolver()
        let service = AssetQueryService(dataManager: DataManager(), resolver: resolver)
        let category = AssetQuery(source: .category(.videos))
        let album = AssetQuery(source: .album(.collection(id: "album-id")))
        let categoryStream = service.updates(for: category)
        let albumStream = service.updates(for: album)
        let categoryTask = Task<AssetQueryUpdate?, Never> { for await value in categoryStream { return value }; return nil }
        let albumTask = Task<AssetQueryUpdate?, Never> { for await value in albumStream { return value }; return nil }
        let categoryValue = await categoryTask.value
        let albumValue = await albumTask.value
        #expect(categoryValue?.result.query.source == category.source)
        #expect(albumValue?.result.query.source == album.source)
        #expect(resolver.sources.contains(category.source))
        #expect(resolver.sources.contains(album.source))
        #expect(categoryValue?.sourceUnavailable == false)
        #expect(albumValue?.sourceUnavailable == true)
    }

    @Test @MainActor func browserModelsKeepQueriesAndCancellationIndependent() async {
        let service = TestAssetQueryService()
        let first = AssetBrowserModel(query: query(), service: service)
        let second = AssetBrowserModel(query: .init(source: .album(.virtual(.favorites))), service: service)
        first.refresh()
        second.refresh()
        await service.waitForSubscriptions(2)
        first.query.age = .olderThan30Days
        await service.waitForSubscriptions(3)
        #expect(second.query.age == .all)
        #expect(first.query.age == .olderThan30Days)
        first.stop()
        first.query.sort = .oldestFirst
        first.refresh()
        #expect(service.subscriptionCount == 3)
        let resultTask = Task {
            for await result in second.$result.values where result != nil { return result }
            return nil
        }
        await Task.yield()
        service.publish(source: second.query.source)
        let result = await resultTask.value
        #expect(result?.query.source == second.query.source)
        first.setVisibleAssetIDs(["first-visible"])
        second.setVisibleAssetIDs(["second-visible"])
        #expect(service.visiblePreferences.values.contains(["first-visible"]))
        #expect(service.visiblePreferences.values.contains(["second-visible"]))
        #expect(service.visiblePreferences.count == 2)
        second.stop()
    }
}

@MainActor
private final class EmptyAssetQueryResolver: AssetSourceResolving {
    var sources: [AssetSource] = []
    func resolve(_ source: AssetSource) async -> AssetSourceResolution {
        sources.append(source)
        if case .album = source { return .init(assets: [], isUnavailable: true) }
        return .init(assets: [], isUnavailable: false)
    }
}

@MainActor
private final class TestAssetQueryService: AssetQueryServing {
    private var continuations: [AssetSource: (AssetQuery, AsyncStream<AssetQueryUpdate>.Continuation)] = [:]
    private var subscriptionWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private(set) var subscriptionCount = 0
    private(set) var visiblePreferences: [UUID: Set<String>] = [:]

    func updates(for query: AssetQuery, sessionID: UUID) -> AsyncStream<AssetQueryUpdate> {
        AsyncStream { continuation in
            continuations[query.source] = (query, continuation)
            subscriptionCount += 1
            let ready = subscriptionWaiters.filter { subscriptionCount >= $0.0 }
            subscriptionWaiters.removeAll { subscriptionCount >= $0.0 }
            ready.forEach { $0.1.resume() }
        }
    }

    func setVisibleAssetIDs(_ identifiers: Set<String>, sessionID: UUID) { visiblePreferences[sessionID] = identifiers }

    func waitForSubscriptions(_ count: Int) async {
        guard subscriptionCount < count else { return }
        await withCheckedContinuation { subscriptionWaiters.append((count, $0)) }
    }

    func publish(source: AssetSource) {
        guard let (query, continuation) = continuations[source] else { return }
        let result = AssetQueryEngine.execute(query: query, assets: [])
        continuation.yield(.init(result: result, assetsByID: [:], sourceUnavailable: false))
    }
}
