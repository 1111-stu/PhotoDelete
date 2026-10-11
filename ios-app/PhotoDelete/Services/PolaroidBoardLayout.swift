//
//  PolaroidBoardLayout.swift
//  PhotoDelete
//
//  相纸墙确定性撒布（与 designs/photo-wall-prototype.html 同种子算法）。
//

import CoreGraphics
import Foundation

struct PolaroidBoardItem: Identifiable, Equatable {
    let id: String
    let dayOfMonth: Int
    let variant: Int
    let coverAssetID: String?
    let remainingCount: Int
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let rotationDegrees: CGFloat
    let photoAspectRatio: CGFloat
}

enum PolaroidBoardLayout {
    static let maxPolaroids = 15
    static let boardWidth: CGFloat = 358
    static let boardHeight: CGFloat = 310
    static let inset: CGFloat = 5
    static let columns = 5
    static let rows = 3
    private static let aspectRatios: [CGFloat] = [0.75, 0.8, 1, 1, 1.33, 1.5]

    /// `days`：按日倒序（新→旧）的待整理日格。
    static func layout(
        year: Int,
        month: Int,
        days: [PendingPhotoWallDayCell]
    ) -> [PolaroidBoardItem] {
        let pool = polaroidPool(from: days)
        guard !pool.isEmpty else { return [] }

        var rng = SeededRNG(seedKey: "board-\(year)-\(month)")
        let cellWidth = boardWidth / CGFloat(columns)
        let cellHeight = boardHeight / CGFloat(rows)
        var cells = Array(0..<(columns * rows))
        for i in stride(from: cells.count - 1, through: 1, by: -1) {
            let j = Int(rng.next() * Double(i + 1))
            cells.swapAt(i, j)
        }

        return pool.enumerated().map { index, entry in
            let aspect = aspectRatios[Int(rng.next() * Double(aspectRatios.count)) % aspectRatios.count]
            let photoW = 50 + CGFloat(rng.next()) * 26
            let photoH = photoW / aspect
            let width = photoW + 8
            let height = photoH + 17
            var rot = CGFloat(rng.next() * 2 - 1) * 13
            if abs(rot) < 3 {
                rot = (rot >= 0 ? 1 : -1) * (3 + CGFloat(rng.next()) * 3.5)
            }

            let cell = cells[index % cells.count]
            let cx = (CGFloat(cell % columns) + 0.5) * cellWidth
            let cy = (CGFloat(cell / columns) + 0.5) * cellHeight
            let rad = rot * .pi / 180
            let aabbW = width * abs(cos(rad)) + height * abs(sin(rad))
            let aabbH = width * abs(sin(rad)) + height * abs(cos(rad))
            let padX = (aabbW - width) / 2
            let padY = (aabbH - height) / 2
            let x = clamp(
                cx + CGFloat(rng.next() * 2 - 1) * cellWidth * 0.26 - width / 2,
                inset + padX,
                boardWidth - inset - aabbW + padX
            )
            let y = clamp(
                cy + CGFloat(rng.next() * 2 - 1) * cellHeight * 0.26 - height / 2,
                inset + padY,
                boardHeight - inset - aabbH + padY
            )

            return PolaroidBoardItem(
                id: "\(year)-\(month)-\(entry.day.dayOfMonth)-\(entry.variant)",
                dayOfMonth: entry.day.dayOfMonth,
                variant: entry.variant,
                coverAssetID: entry.day.coverAssetID,
                remainingCount: entry.day.remainingCount,
                x: x,
                y: y,
                width: width,
                height: height,
                rotationDegrees: rot,
                photoAspectRatio: aspect
            )
        }
    }

    private struct PoolEntry {
        let day: PendingPhotoWallDayCell
        let variant: Int
    }

    /// 最近的天各一张；不够 15 时，剩余多的天再补一张（variant=1）。
    private static func polaroidPool(from days: [PendingPhotoWallDayCell]) -> [PoolEntry] {
        let sorted = days.sorted { $0.date > $1.date }
        var pool = sorted.map { PoolEntry(day: $0, variant: 0) }
        for day in sorted {
            if pool.count >= maxPolaroids { break }
            if day.remainingCount >= 20 {
                pool.append(PoolEntry(day: day, variant: 1))
            }
        }
        if pool.count > maxPolaroids {
            pool = Array(pool.prefix(maxPolaroids))
        }
        return pool
    }

    private static func clamp(_ value: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(value, lo), max(lo, hi))
    }
}

/// FNV-1a + LCG，与原型 `seededRng` 同构（32-bit 无符号）。
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
