//
//  PolaroidBoardLayout.swift
//  PhotoDelete
//
//  相纸墙密铺钉板：全部拍立得白边，尺寸只微差，4 列错列压边。
//  逐张的尺寸 / 倾斜 / 夹子按「月 + 日 + variant」定种子，整理掉一天后其余相纸只换位、不变样。
//

import CoreGraphics
import Foundation

struct PolaroidClip: Equatable {
    let colorIndex: Int
    /// 相对相纸顶边中点的水平偏移（设计单位）。
    let offsetX: CGFloat
    /// 叠加在相纸倾斜之上的额外倾斜。
    let rotationDegrees: CGFloat
}

struct PolaroidBoardItem: Identifiable, Equatable {
    let id: String
    let dayOfMonth: Int
    let variant: Int
    let coverAssetID: String?
    let remainingCount: Int
    /// 未旋转相纸框的左上角（设计单位）。
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let rotationDegrees: CGFloat
    let photoAspectRatio: CGFloat
    let zIndex: Double
    let clip: PolaroidClip?
    /// 悬挂晃动的相对刚度（约 0.78...1.05）。
    let hang: CGFloat
}

struct PolaroidBoard: Equatable {
    /// 阅读顺序（新 → 旧）；绘制层级看 `zIndex`。
    let items: [PolaroidBoardItem]
    /// 设计单位；宽恒为 `PolaroidBoardLayout.boardWidth`。
    let height: CGFloat
}

enum PolaroidBoardLayout {
    static let maxPolaroids = 16
    static let boardWidth: CGFloat = 358
    static let inset: CGFloat = 10
    static let frameSide: CGFloat = 5
    static let frameTop: CGFloat = 5
    static let frameBottom: CGFloat = 16
    static let rowPitch: CGFloat = 72
    static let columnPitch3: CGFloat = 88
    static let columnPitch4: CGFloat = 78
    static let clipWidth: CGFloat = 9
    static let clipHeight: CGFloat = 20
    /// 夹子露出相纸顶边的高度。
    static let clipRise: CGFloat = 9
    static let clipColorCount = 6
    /// 剩这么多张以上的天，才在空位里补挂同日另一张。
    static let alternateMinimumRemaining = 6
    static let photoAspectRatios: [CGFloat] = [0.8, 0.85, 1, 1, 1.15, 1.25]

    private static let minPhotoWidth: CGFloat = 55
    private static let photoWidthSpan: CGFloat = 10
    private static let maxRotation: CGFloat = 12
    private static let minRotation: CGFloat = 3
    private static let itemJitter: CGFloat = 9
    /// 相邻列高低差（相对行距）。
    private static let stagger: CGFloat = 0.32
    /// 包围盒可以探出 `inset` 多少。
    private static let edgeHang: CGFloat = 8
    private static let clipJitter: CGFloat = 10
    private static let clipMaxRotation: CGFloat = 14

    /// `days`：当月有待整理照片的日格，顺序不限。
    static func layout(
        year: Int,
        month: Int,
        days: [PendingPhotoWallDayCell]
    ) -> PolaroidBoard {
        let pool = polaroidPool(from: days)
        guard !pool.isEmpty else { return PolaroidBoard(items: [], height: 0) }

        let grid = gridShape(for: pool.count)
        let pitch = columnPitch(for: grid.columns)
        let phases = columnPhases(count: grid.columns, year: year, month: month)
        let firstCenterX = (boardWidth - CGFloat(grid.columns - 1) * pitch) / 2
        let lastRowCount = pool.count - (grid.rows - 1) * grid.columns
        let lastRowShift = CGFloat(grid.columns - lastRowCount) * pitch / 2

        var polaroids = pool.enumerated().map { index, entry in
            var item = makePolaroid(entry, year: year, month: month)
            let row = index / grid.columns
            let column = index % grid.columns
            let shift = row == grid.rows - 1 ? lastRowShift : 0
            item.center = CGPoint(
                x: firstCenterX + CGFloat(column) * pitch + shift + item.jitter.x,
                y: CGFloat(row) * rowPitch + phases[column] + item.height / 2 + item.jitter.y
            )
            item.zIndex = Double(row) * 2 + item.zJitter
            return item
        }

        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for index in polaroids.indices {
            let item = polaroids[index]
            let half = rotatedHalfExtent(of: item)
            polaroids[index].center.x = clamp(
                item.center.x,
                inset + half.width - edgeHang,
                boardWidth - inset - half.width + edgeHang
            )
            minY = min(minY, item.center.y - half.height, clipTop(of: polaroids[index]))
            maxY = max(maxY, item.center.y + half.height)
        }

        let offsetY = inset - minY
        let items = polaroids.map { item in
            PolaroidBoardItem(
                id: "\(year)-\(month)-\(item.entry.day.dayOfMonth)-\(item.entry.variant)",
                dayOfMonth: item.entry.day.dayOfMonth,
                variant: item.entry.variant,
                coverAssetID: item.entry.assetID,
                remainingCount: item.entry.day.remainingCount,
                x: item.center.x - item.width / 2,
                y: item.center.y + offsetY - item.height / 2,
                width: item.width,
                height: item.height,
                rotationDegrees: item.rotationDegrees,
                photoAspectRatio: item.photoAspectRatio,
                zIndex: item.zIndex,
                clip: item.clip,
                hang: item.hang
            )
        }
        return PolaroidBoard(items: items, height: maxY - minY + inset * 2)
    }

    /// ≤4 张最多 3 列；5–8 张 3 列；更多 4 列。
    static func gridShape(for count: Int) -> (rows: Int, columns: Int) {
        guard count > 0 else { return (0, 0) }
        let columns: Int
        if count <= 4 {
            columns = min(count, 3)
        } else if count <= 8 {
            columns = 3
        } else {
            columns = 4
        }
        let rows = (count + columns - 1) / columns
        return (rows, columns)
    }

    static func columnPitch(for columns: Int) -> CGFloat {
        columns <= 3 ? columnPitch3 : columnPitch4
    }

    private struct PoolEntry {
        let day: PendingPhotoWallDayCell
        let assetID: String?
        let variant: Int
    }

    private struct Polaroid {
        let entry: PoolEntry
        let width: CGFloat
        let height: CGFloat
        let photoAspectRatio: CGFloat
        let rotationDegrees: CGFloat
        let jitter: CGPoint
        let zJitter: Double
        let clip: PolaroidClip?
        let hang: CGFloat
        var center: CGPoint = .zero
        var zIndex: Double = 0
    }

    /// 最近的天各一张；不够时，剩得多的天再挂同日另一张（variant=1），同天两张相邻。
    private static func polaroidPool(from days: [PendingPhotoWallDayCell]) -> [PoolEntry] {
        let newestFirst = days.sorted { $0.date > $1.date }
        let primaries = newestFirst.prefix(maxPolaroids).map {
            PoolEntry(day: $0, assetID: $0.coverAssetID, variant: 0)
        }
        let openSlots = maxPolaroids - primaries.count
        guard openSlots > 0 else { return primaries }

        let alternates = newestFirst
            .filter { $0.alternateCoverAssetID != nil && $0.remainingCount >= alternateMinimumRemaining }
            .sorted { ($0.remainingCount, $0.date) > ($1.remainingCount, $1.date) }
            .prefix(openSlots)
            .map { PoolEntry(day: $0, assetID: $0.alternateCoverAssetID, variant: 1) }

        return (primaries + alternates).sorted {
            ($0.day.date, -$0.variant) > ($1.day.date, -$1.variant)
        }
    }

    /// 相邻两列一高一低，避免顶边连成一条线。
    private static func columnPhases(count: Int, year: Int, month: Int) -> [CGFloat] {
        var rng = SeededRNG(seedKey: "columns-\(year)-\(month)")
        let firstDropsLower = rng.next() < 0.5
        return (0..<count).map { column in
            let dropsLower = (column % 2 == 0) == firstDropsLower
            let fraction = dropsLower
                ? stagger * (0.7 + CGFloat(rng.next()) * 0.3)
                : CGFloat(rng.next()) * stagger * 0.35
            return fraction * rowPitch
        }
    }

    private static func makePolaroid(_ entry: PoolEntry, year: Int, month: Int) -> Polaroid {
        var rng = SeededRNG(seedKey: "polaroid-\(year)-\(month)-\(entry.day.dayOfMonth)-\(entry.variant)")
        let photoWidth = minPhotoWidth + CGFloat(rng.next()) * photoWidthSpan
        let aspect = photoAspectRatios[Int(rng.next() * Double(photoAspectRatios.count)) % photoAspectRatios.count]
        let width = photoWidth + frameSide * 2
        let height = photoWidth / aspect + frameTop + frameBottom

        var rotation = CGFloat(rng.next() * 2 - 1) * maxRotation
        if abs(rotation) < minRotation {
            rotation = (rotation >= 0 ? 1 : -1) * (minRotation + CGFloat(rng.next()) * 3.5)
        }
        let jitter = CGPoint(
            x: CGFloat(rng.next() * 2 - 1) * itemJitter,
            y: CGFloat(rng.next() * 2 - 1) * itemJitter
        )
        let clip: PolaroidClip? = rng.next() > 0.12
            ? PolaroidClip(
                colorIndex: Int(rng.next() * Double(clipColorCount)) % clipColorCount,
                offsetX: CGFloat(rng.next() * 2 - 1) * clipJitter,
                rotationDegrees: CGFloat(rng.next() * 2 - 1) * clipMaxRotation
            )
            : nil
        let hang = 0.78 + CGFloat((entry.day.dayOfMonth * 17 + entry.variant * 9) % 11) / 40

        return Polaroid(
            entry: entry,
            width: width,
            height: height,
            photoAspectRatio: aspect,
            rotationDegrees: rotation,
            jitter: jitter,
            zJitter: rng.next() * 0.8,
            clip: clip,
            hang: hang
        )
    }

    private static func rotatedHalfExtent(of item: Polaroid) -> CGSize {
        let radians = item.rotationDegrees * .pi / 180
        let cosine = abs(cos(radians))
        let sine = abs(sin(radians))
        return CGSize(
            width: (item.width * cosine + item.height * sine) / 2,
            height: (item.width * sine + item.height * cosine) / 2
        )
    }

    /// 夹子露在相纸上方，旋转后可能比相纸包围盒更高。
    private static func clipTop(of item: Polaroid) -> CGFloat {
        guard item.clip != nil else {
            return item.center.y - item.height / 2
        }
        let radians = item.rotationDegrees * .pi / 180
        let localY = -item.height / 2 - clipRise
        return item.center.y + (item.clip?.offsetX ?? 0) * sin(radians) + localY * cos(radians)
    }

    private static func clamp(_ value: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(value, lo), max(lo, hi))
    }
}

/// FNV-1a + LCG（32-bit 无符号）。
private struct SeededRNG {
    private var state: UInt32

    init(seedKey: String) {
        var hash: UInt32 = 2166136261
        for byte in seedKey.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16777619
        }
        state = hash
    }

    mutating func next() -> Double {
        state = state &* 1664525 &+ 1013904223
        return Double(state) / 4294967296.0
    }
}
