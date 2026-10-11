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
    let coverAssetID: String?

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
    private struct DayBucket {
        var remainingCount = 0
        var coverAssetID: String?
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

        // newest-first：先扫到的同日资产作为封面。
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
            bucket.remainingCount += 1
            if bucket.coverAssetID == nil {
                bucket.coverAssetID = asset.localIdentifier
            }
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
                coverAssetID: bucket.coverAssetID
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
}

enum PendingPhotoWallDisplayMode: String, CaseIterable, Identifiable {
    case calendar
    case polaroid

    var id: String { rawValue }
}
