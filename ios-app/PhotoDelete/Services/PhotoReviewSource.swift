import Foundation
import Photos

struct PhotoReviewSource {
    let selectedCategory: PhotoCategory?
    let selectedTimeGroup: String?
    let selectedAlbumInfo: AlbumInfo?
    let selectedDate: Date?
    let selectedAdvancedTimeScope: AdvancedTimeScope?
    let selectedAdvancedCleanup: AdvancedCleanupKind?
    let selectedLocationGroupID: String?
    let randomReviewScope: PhotoRandomReviewScope?
    let selectedHistoricalToday: Bool
    var explicitReviewScope: ExplicitAssetReviewScope? = nil

    func photos(
        dataManager: DataManager,
        activeAlbumInfo: AlbumInfo?,
        randomSeed: String,
        hideFiled: Bool,
        batchSizeValue: Int,
        sortOrderValue: String
    ) -> [PHAsset] {
        guard dataManager.photoLibraryManager.hasPhotoLibraryAccess else {
            return []
        }

        let photos: [PHAsset]
        if let explicitReviewScope {
            let result = PHAsset.fetchAssets(withLocalIdentifiers: explicitReviewScope.orderedAssetIDs, options: nil)
            var availableAssets: [PHAsset] = []
            availableAssets.reserveCapacity(result.count)
            result.enumerateObjects { asset, _, _ in availableAssets.append(asset) }
            return explicitReviewScope.orderedElements(from: availableAssets, identifier: \.localIdentifier)
        } else if let randomReviewScope {
            photos = dataManager.makeRandomReviewPhotos(
                for: randomReviewScope,
                seed: randomSeed,
                excludingFiledPhotos: hideFiled,
                limit: PhotoRandomReviewBatchSize.normalized(batchSizeValue).rawValue
            )
        } else if selectedHistoricalToday {
            photos = dataManager.getPhotosForHistoricalToday()
        } else if let albumInfo = activeAlbumInfo {
            photos = dataManager.getPhotosForAlbum(albumInfo)
        } else if let selectedDate, let selectedAdvancedTimeScope {
            photos = dataManager.getPhotosForPeriod(selectedAdvancedTimeScope, containing: selectedDate)
        } else if let selectedDate {
            photos = dataManager.getPhotosForDay(selectedDate)
        } else if let selectedAdvancedCleanup {
            photos = dataManager.getPhotosForAdvancedCleanup(selectedAdvancedCleanup)
        } else if let selectedLocationGroupID {
            photos = dataManager.getPhotosForLocationGroup(selectedLocationGroupID)
        } else if let category = selectedCategory {
            photos = dataManager.getRealPhotos(for: category)
        } else if let timeGroupString = selectedTimeGroup,
                  let timeGroup = TimeGroup.fromIdentifier(timeGroupString) {
            photos = dataManager.getPhotosForTimeGroup(timeGroup)
        } else {
            photos = dataManager.photoLibraryManager.allPhotos
        }

        guard usesChronologicalOrder else { return photos }
        return PhotoReviewSortOrder.normalized(sortOrderValue).apply(
            to: photos,
            date: \.creationDate
        )
    }

    var usesChronologicalOrder: Bool {
        explicitReviewScope == nil && randomReviewScope == nil && selectedAdvancedCleanup == nil
    }

    var persistsProgress: Bool {
        explicitReviewScope == nil && randomReviewScope == nil
    }

    func title(dataManager: DataManager, activeAlbumInfo: AlbumInfo?) -> String {
        if let randomReviewScope {
            return randomReviewScope.title
        } else if selectedHistoricalToday {
            return L10n.string("On This Day")
        } else if let albumInfo = activeAlbumInfo {
            return albumInfo.title
        } else if let selectedDate, let selectedAdvancedTimeScope {
            return ReviewSourceDateFormatter.title(for: selectedAdvancedTimeScope, containing: selectedDate)
        } else if let selectedDate {
            return ReviewSourceDateFormatter.dayTitle.string(from: selectedDate)
        } else if let selectedAdvancedCleanup {
            return selectedAdvancedCleanup.title
        } else if let selectedLocationGroupID {
            return dataManager.locationGroupTitle(for: selectedLocationGroupID) ?? L10n.string("Location")
        } else if let category = selectedCategory {
            return category.title
        } else if let timeGroup = selectedTimeGroup {
            return TimeGroup.fromIdentifier(timeGroup)?.title ?? timeGroup
        } else {
            return PhotoCategory.all.title
        }
    }

    var progressScopeID: String {
        if let explicitReviewScope {
            return explicitReviewScope.progressScopeID
        }
        if let randomReviewScope {
            return "random:\(randomReviewScope.rawValue)"
        }

        if let albumInfo = selectedAlbumInfo {
            return "album:\(albumInfo.id)"
        }

        if let selectedDate, let selectedAdvancedTimeScope {
            let intervalStart = Calendar.current.dateInterval(for: selectedAdvancedTimeScope, containing: selectedDate).start
            return "period:\(selectedAdvancedTimeScope.rawValue):\(Int(intervalStart.timeIntervalSince1970))"
        }

        if selectedHistoricalToday {
            let today = Calendar.current.startOfDay(for: Date())
            return "historicalToday:\(Int(today.timeIntervalSince1970))"
        }

        if let selectedDate {
            let dayStart = Calendar.current.startOfDay(for: selectedDate)
            return "day:\(Int(dayStart.timeIntervalSince1970))"
        }

        if let selectedAdvancedCleanup {
            return "advanced:\(selectedAdvancedCleanup.rawValue)"
        }

        if let selectedLocationGroupID {
            return "location:\(selectedLocationGroupID)"
        }

        if let selectedCategory {
            return "category:\(selectedCategory.rawValue)"
        }

        if let selectedTimeGroup {
            return "timeGroup:\(selectedTimeGroup)"
        }

        return "category:\(PhotoCategory.all.rawValue)"
    }
}

private enum ReviewSourceDateFormatter {
    static func title(for scope: AdvancedTimeScope, containing date: Date) -> String {
        switch scope {
        case .day:
            return dayTitle.string(from: date)
        case .week:
            let components = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return String(
                format: L10n.string("Week %lld of %lld"),
                Int64(components.weekOfYear ?? 0),
                Int64(components.yearForWeekOfYear ?? 0)
            )
        case .month:
            return monthTitle.string(from: date)
        case .year:
            return yearTitle.string(from: date)
        }
    }

    static var dayTitle: DateFormatter {
        AppDateFormatter.configuredFormatter(template: "MMMEd")
    }

    private static var monthTitle: DateFormatter {
        AppDateFormatter.configuredFormatter(template: "yMMM")
    }

    private static var yearTitle: DateFormatter {
        AppDateFormatter.configuredFormatter(template: "y")
    }
}
