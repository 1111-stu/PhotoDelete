//
//  AlbumReorderSession.swift
//  PhotoDelete
//
//  相册拖拽排序的状态机与几何计算。视图只负责把手势、坐标系与几何喂进来，
//  摆放判定与顺序变更全部在这里完成，方便单测。
//

import CoreGraphics
import Foundation

/// 一次长按拖拽排序的生命周期。
/// `armed` = 长按已抬起但手指还没移动（此时松手是原菜单），`dragging` = 已经开始换位。
struct AlbumReorderSession: Equatable {
    enum Phase: Equatable {
        case idle
        case armed
        case dragging
    }

    private(set) var phase: Phase = .idle
    private(set) var itemID: String?
    private(set) var sourceIndex: Int = 0
    private(set) var insertIndex: Int = 0

    var isActive: Bool { phase != .idle }
    var isDragging: Bool { phase == .dragging }

    /// 松手时是否需要提交：拖拽过，且落点不是原位置。
    var hasPendingMove: Bool { phase == .dragging && insertIndex != sourceIndex }

    mutating func arm(itemID: String, index: Int) {
        self.itemID = itemID
        self.sourceIndex = index
        self.insertIndex = index
        self.phase = .armed
    }

    mutating func beginDragging() {
        guard phase == .armed else { return }
        phase = .dragging
    }

    /// 更新插入位，返回是否发生变化（视图据此决定要不要做让位动画与触觉）。
    @discardableResult
    mutating func updateInsertIndex(_ index: Int) -> Bool {
        guard phase == .dragging, index != insertIndex else { return false }
        insertIndex = index
        return true
    }

    mutating func reset() {
        phase = .idle
        itemID = nil
        sourceIndex = 0
        insertIndex = 0
    }
}

/// 拖动落点的几何判定。
enum AlbumReorderGeometry {
    /// 拖动点越过了哪些格子的中心 → 插入位。
    ///
    /// `itemFrames` 必须**排除被拿起的那一格**，并按当前显示顺序排列；
    /// 用按下时刻的槽位（而不是动画中的实时 frame）计算，避免让位动画把自己喂回去。
    static func insertionIndex(for point: CGPoint, itemFrames: [CGRect]) -> Int {
        var index = 0
        for frame in itemFrames {
            let passed = point.y > frame.maxY || (point.y > frame.minY && point.x > frame.midX)
            if passed { index += 1 }
        }
        return index
    }

    /// 把 `from` 位置的元素搬到插入位 `insertIndex`（语义与 `insertionIndex` 一致：
    /// 先移除再插入，因此 `insertIndex` 是「移除后」的下标）。
    static func moving<T>(_ items: [T], from: Int, to insertIndex: Int) -> [T] {
        guard items.indices.contains(from) else { return items }
        var next = items
        let item = next.remove(at: from)
        next.insert(item, at: min(max(insertIndex, 0), next.count))
        return next
    }
}
