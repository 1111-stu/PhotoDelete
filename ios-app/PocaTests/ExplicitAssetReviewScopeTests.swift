import Foundation
import Testing
@testable import Poca

struct ExplicitAssetReviewScopeTests {
    @Test func freezesInputOrderAndDeduplicatesWithoutSorting() {
        let scope = ExplicitAssetReviewScope(orderedAssetIDs: ["large", "small", "large", "medium"])
        #expect(scope.orderedAssetIDs == ["large", "small", "medium"])
        #expect(scope.orderedElements(from: ["medium", "new", "small", "large"], identifier: { $0 }) ==
                ["large", "small", "medium"])
    }

    @Test func removedAssetsStayOutWhenTheSourceLaterContainsThemAgain() {
        let scope = ExplicitAssetReviewScope(orderedAssetIDs: ["a", "b", "c"])
        let firstRefresh = scope.orderedElements(from: ["a", "c", "new"], identifier: { $0 })
        #expect(firstRefresh == ["a", "c"])
        let nextRefresh = scope.orderedElements(
            from: ["new", "c", "b", "a"],
            retainingAssetIDs: Set(firstRefresh),
            identifier: { $0 }
        )
        #expect(nextRefresh == ["a", "c"])
    }

    @Test func sourceRefreshUsesLatestObjectsWithoutChangingOrder() {
        struct Item: Equatable {
            let id: String
            let version: Int
        }
        let scope = ExplicitAssetReviewScope(orderedAssetIDs: ["b", "a"])
        let refreshed = scope.orderedElements(
            from: [Item(id: "a", version: 2), Item(id: "b", version: 3)],
            identifier: \.id
        )
        #expect(refreshed == [Item(id: "b", version: 3), Item(id: "a", version: 2)])
    }

    @Test func independentTemporaryScopesNeverReuseCategoryProgress() {
        let first = ExplicitAssetReviewScope(orderedAssetIDs: ["a"])
        let second = ExplicitAssetReviewScope(orderedAssetIDs: ["a"])
        #expect(first.id != second.id)
        #expect(first.progressScopeID != second.progressScopeID)
        let source = makeSource(explicitScope: first)
        #expect(source.progressScopeID == first.progressScopeID)
        #expect(!source.persistsProgress)
        #expect(!source.usesChronologicalOrder)
    }

    @Test func frozenBrowserQueueIncludesItsExplicitTargetsDespiteGlobalReviewedState() {
        let scope = ExplicitAssetReviewScope(orderedAssetIDs: ["a", "b"])
        #expect(!scope.usesPersistedReviewedState(hasAlbumContext: false))
        #expect(scope.orderedElements(from: ["b", "a"], identifier: { $0 }) == ["a", "b"])
    }

    @Test func albumContextPreservesItsExistingReviewedSemantics() {
        let explicitPolicy = ExplicitAssetReviewScope(orderedAssetIDs: ["a"], reviewedPolicy: .skipPreviouslyReviewed)
        #expect(explicitPolicy.usesPersistedReviewedState(hasAlbumContext: false))
        #expect(!explicitPolicy.usesPersistedReviewedState(hasAlbumContext: true))

        let album = AlbumInfo(id: "album", title: "Album", assetCollection: nil, type: .userCreated)
        let albumScope = ExplicitAssetReviewScope(
            orderedAssetIDs: ["a"], albumInfo: album, reviewedPolicy: .skipPreviouslyReviewed
        )
        #expect(!albumScope.usesPersistedReviewedState(hasAlbumContext: false))
    }

    @Test func oldCategorySourceStillUsesDateOrderAndPersistentProgress() {
        let source = makeSource(explicitScope: nil)
        #expect(source.usesChronologicalOrder)
        #expect(source.persistsProgress)
        #expect(source.progressScopeID == "category:\(PhotoCategory.screenRecordings.rawValue)")
    }

    private func makeSource(explicitScope: ExplicitAssetReviewScope?) -> PhotoReviewSource {
        PhotoReviewSource(
            selectedCategory: .screenRecordings, selectedTimeGroup: nil, selectedAlbumInfo: nil,
            selectedDate: nil, selectedAdvancedTimeScope: nil, selectedAdvancedCleanup: nil,
            selectedLocationGroupID: nil, randomReviewScope: nil, selectedHistoricalToday: false,
            explicitReviewScope: explicitScope
        )
    }
}
