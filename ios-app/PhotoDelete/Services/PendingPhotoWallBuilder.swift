//
//  PendingPhotoWallBuilder.swift
//  PhotoDelete
//
//  待整理照片墙：从相册资产构建「年 → 月 → 日封面」纯数据，无视图依赖。
//

import Foundation
import Photos

struct PendingPhotoWallDayCell: Identifiable, Equatable, Hashable {
    let date: Date
    let remainingCount: Int
    /// 当天最新的非截屏；整天只有截屏才用截屏。
    let coverAssetID: String?
    /// 当天最旧的另一张非截屏，相纸墙补位用；和封面隔得远，少撞连拍。
    var alternateCoverAssetID: String? = nil

    var id: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    var dayOfMonth: Int {
        Calendar.current.component(.day, from: date)
    }
}

struct PendingPhotoWallMonth: Identifiable, Equatable {
    let monthStart: Date
    let remainingCount: Int
    /// 有待整理照片的日格（按 day-of-month）。
    let daysWithPhotos: [Int: PendingPhotoWallDayCell]

    var id: String {
        let components = Calendar.current.dateComponents([.year, .month], from: monthStart)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    var year: Int {
        Calendar.current.component(.year, from: monthStart)
    }

    var month: Int {
        Calendar.current.component(.month, from: monthStart)
    }
}

struct PendingPhotoWallYearOption: Identifiable, Equatable, Hashable {
    let year: Int
    let remainingCount: Int

    var id: Int { year }
}

struct PendingPhotoWallSnapshot: Equatable {
    let years: [PendingPhotoWallYearOption]
    let months: [PendingPhotoWallMonth]
    let selectedYear: Int
    let totalPendingInLibrary: Int

    var isSelectedYearEmpty: Bool { months.isEmpty }
    var isLibraryEmpty: Bool { totalPendingInLibrary == 0 }
}

enum PendingPhotoWallBuilder {
    struct DayBucket {
        private(set) var remainingCount = 0
        private var firstAssetID: String?
        private var newestPhotoID: String?
        private var oldestPhotoID: String?

        /// 按 newest-first 顺序喂入同一天的待整理资产。
        mutating func add(assetID: String, isScreenshot: Bool) {
            remainingCount += 1
            if firstAssetID == nil {
                firstAssetID = assetID
            }
            guard !isScreenshot else { return }
            if newestPhotoID == nil {
                newestPhotoID = assetID
            }
            oldestPhotoID = assetID
        }

        var coverAssetID: String? { newestPhotoID ?? firstAssetID }

        var alternateCoverAssetID: String? {
            guard let oldestPhotoID, oldestPhotoID != newestPhotoID else { return nil }
            return oldestPhotoID
        }
    }

    /// 与 period summary 一致：reviewed / 收集箱 / 收藏候选 / 系统收藏 都算已整理。
    static func isOrganized(
        asset: PHAsset,
        reviewedIDs: Set<String>,
        deleteCandidateIDs: Set<String>,
        favoriteCandidateIDs: Set<String>
    ) -> Bool {
        let id = asset.localIdentifier
        return reviewedIDs.contains(id)
            || deleteCandidateIDs.contains(id)
            || favoriteCandidateIDs.contains(id)
            || asset.isFavorite
    }

    static func build(
        photos: [PHAsset],
        reviewedIDs: Set<String>,
        deleteCandidateIDs: Set<String>,
        favoriteCandidateIDs: Set<String>,
        selectedYear: Int?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PendingPhotoWallSnapshot {
        var dayBuckets: [Date: DayBucket] = [:]
        var pendingByYear: [Int: Int] = [:]
        var yearsWithLibraryPhotos = Set<Int>()
        var libraryPending = 0

        // newest-first：同日最新的非截屏做封面，见 `DayBucket`。
        // 年份列表含「库里有照片的年份」（含已清空），不只剩待整理的年。
        for asset in photos {
            guard let creationDate = asset.creationDate else { continue }
            let dayStart = calendar.startOfDay(for: creationDate)
            let year = calendar.component(.year, from: dayStart)
            yearsWithLibraryPhotos.insert(year)

            guard !isOrganized(
                asset: asset,
                reviewedIDs: reviewedIDs,
                deleteCandidateIDs: deleteCandidateIDs,
                favoriteCandidateIDs: favoriteCandidateIDs
            ) else { continue }

            libraryPending += 1
            pendingByYear[year, default: 0] += 1

            var bucket = dayBuckets[dayStart] ?? DayBucket()
            bucket.add(
                assetID: asset.localIdentifier,
                isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot)
            )
            dayBuckets[dayStart] = bucket
        }

        let years = yearsWithLibraryPhotos.sorted(by: >).map { year in
            PendingPhotoWallYearOption(year: year, remainingCount: pendingByYear[year] ?? 0)
        }

        let resolvedYear: Int = {
            if let selectedYear, yearsWithLibraryPhotos.contains(selectedYear) {
                return selectedYear
            }
            if let firstPending = pendingByYear.keys.sorted(by: >).first {
                return firstPending
            }
            if let first = years.first?.year { return first }
            return calendar.component(.year, from: now)
        }()

        var monthBuckets: [Date: (remaining: Int, days: [Int: PendingPhotoWallDayCell])] = [:]
        for (dayStart, bucket) in dayBuckets {
            guard calendar.component(.year, from: dayStart) == resolvedYear else { continue }
            let monthStart = calendar.dateInterval(for: .month, containing: dayStart).start
            var entry = monthBuckets[monthStart] ?? (0, [:])
            let day = calendar.component(.day, from: dayStart)
            entry.remaining += bucket.remainingCount
            entry.days[day] = PendingPhotoWallDayCell(
                date: dayStart,
                remainingCount: bucket.remainingCount,
                coverAssetID: bucket.coverAssetID,
                alternateCoverAssetID: bucket.alternateCoverAssetID
            )
            monthBuckets[monthStart] = entry
        }

        let months = monthBuckets.keys.sorted(by: >).compactMap { monthStart -> PendingPhotoWallMonth? in
            guard let entry = monthBuckets[monthStart], entry.remaining > 0 else { return nil }
            return PendingPhotoWallMonth(
                monthStart: monthStart,
                remainingCount: entry.remaining,
                daysWithPhotos: entry.days
            )
        }

        return PendingPhotoWallSnapshot(
            years: years,
            months: months,
            selectedYear: resolvedYear,
            totalPendingInLibrary: libraryPending
        )
    }

    /// 墙面缩略图索引：`orderedCoverIDs` 用于按显示顺序预取，`assetIDs` 含相纸板补位图。
    static func thumbnailPlan(for snapshot: PendingPhotoWallSnapshot) -> PendingPhotoWallThumbnailPlan {
        var orderedCoverIDs: [String] = []
        var seenCoverIDs = Set<String>()
        var assetIDs = Set<String>()

        for month in snapshot.months {
            let days = month.daysWithPhotos.values.sorted { $0.date > $1.date }
            for day in days {
                if let cover = day.coverAssetID {
                    assetIDs.insert(cover)
                    if seenCoverIDs.insert(cover).inserted {
                        orderedCoverIDs.append(cover)
                    }
                }
                if let alternate = day.alternateCoverAssetID {
                    assetIDs.insert(alternate)
                }
            }
        }

        return PendingPhotoWallThumbnailPlan(
            orderedCoverIDs: orderedCoverIDs,
            assetIDs: assetIDs
        )
    }

    /// 从全库资产中只取墙面需要的对象，构建 ID → PHAsset 索引，供缩略图管线直接使用。
    static func thumbnailAssets(
        in photos: [PHAsset],
        matching assetIDs: Set<String>
    ) -> [String: PHAsset] {
        guard !assetIDs.isEmpty else { return [:] }

        var assetsByID: [String: PHAsset] = [:]
        assetsByID.reserveCapacity(assetIDs.count)
        for photo in photos {
            let identifier = photo.localIdentifier
            guard assetIDs.contains(identifier) else { continue }
            assetsByID[identifier] = photo
        }
        return assetsByID
    }
}

struct PendingPhotoWallThumbnailPlan: Equatable {
    /// 按墙面显示顺序（月新→旧、日新→旧）的封面，用于预取。
    let orderedCoverIDs: [String]
    /// 墙面可能显示的所有缩略图（含相纸板补位图）。
    let assetIDs: Set<String>
}

enum PendingPhotoWallDisplayMode: String, CaseIterable, Identifiable {
    case calendar
    case polaroid

    var id: String { rawValue }
}
