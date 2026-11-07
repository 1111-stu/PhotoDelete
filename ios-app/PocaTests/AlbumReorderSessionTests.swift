//
//  AlbumReorderSessionTests.swift
//  PhotoDeleteTests
//
//  相册拖拽排序的纯逻辑测试：插入位判定、顺序搬移、会话生命周期。
//

import CoreGraphics
import Testing
@testable import PhotoDelete

struct AlbumReorderSessionTests {

    // MARK: - 插入位

    /// 两列网格：三个槽位，拖动点落在哪个格子中心之后。
    private let twoColumnFrames: [CGRect] = [
        CGRect(x: 0, y: 0, width: 100, height: 100),      // 0 左上
        CGRect(x: 110, y: 0, width: 100, height: 100),    // 1 右上
        CGRect(x: 0, y: 110, width: 100, height: 100)     // 2 左下
    ]

    @Test func pointerBeforeEverythingInsertsAtStart() {
        let index = AlbumReorderGeometry.insertionIndex(
            for: CGPoint(x: 10, y: -20),
            itemFrames: twoColumnFrames
        )
        #expect(index == 0)
    }

    @Test func pointerInUpperRowUsesHorizontalCenter() {
        // 第一行左半边 → 还没越过第一个格子中心
        #expect(AlbumReorderGeometry.insertionIndex(for: CGPoint(x: 40, y: 50), itemFrames: twoColumnFrames) == 0)
        // 第一行右半边 → 越过第一个，但没越过第二个
        #expect(AlbumReorderGeometry.insertionIndex(for: CGPoint(x: 70, y: 50), itemFrames: twoColumnFrames) == 1)
        // 越过右上格中心 → 两个都算越过
        #expect(AlbumReorderGeometry.insertionIndex(for: CGPoint(x: 170, y: 50), itemFrames: twoColumnFrames) == 2)
    }

    @Test func pointerBelowARowCountsWholeRow() {
        // 落在第二行左侧：第一行整体算越过，第二行未越过
        #expect(AlbumReorderGeometry.insertionIndex(for: CGPoint(x: 30, y: 150), itemFrames: twoColumnFrames) == 2)
        // 落在第二行右侧：全部越过 → 末尾
        #expect(AlbumReorderGeometry.insertionIndex(for: CGPoint(x: 90, y: 150), itemFrames: twoColumnFrames) == 3)
    }

    @Test func singleColumnListUsesVerticalOrder() {
        let listFrames: [CGRect] = [
            CGRect(x: 0, y: 0, width: 300, height: 60),
            CGRect(x: 0, y: 68, width: 300, height: 60),
            CGRect(x: 0, y: 136, width: 300, height: 60)
        ]
        // 行的左半边：横向中心没过，只看纵向
        #expect(AlbumReorderGeometry.insertionIndex(for: CGPoint(x: 40, y: 30), itemFrames: listFrames) == 0)
        #expect(AlbumReorderGeometry.insertionIndex(for: CGPoint(x: 40, y: 90), itemFrames: listFrames) == 1)
        #expect(AlbumReorderGeometry.insertionIndex(for: CGPoint(x: 40, y: 200), itemFrames: listFrames) == 3)
    }

    @Test func emptyFramesAlwaysZero() {
        #expect(AlbumReorderGeometry.insertionIndex(for: CGPoint(x: 10, y: 10), itemFrames: []) == 0)
    }

    // MARK: - 顺序搬移

    @Test func movingForwardsLandsOnInsertionIndex() {
        #expect(AlbumReorderGeometry.moving(["a", "b", "c", "d"], from: 0, to: 2) == ["b", "c", "a", "d"])
        #expect(AlbumReorderGeometry.moving(["a", "b", "c", "d"], from: 0, to: 3) == ["b", "c", "d", "a"])
    }

    @Test func movingBackwardsKeepsTargetSlot() {
        #expect(AlbumReorderGeometry.moving(["a", "b", "c", "d"], from: 3, to: 0) == ["d", "a", "b", "c"])
        #expect(AlbumReorderGeometry.moving(["a", "b", "c", "d"], from: 2, to: 1) == ["a", "c", "b", "d"])
    }

    @Test func movingToSameIndexChangesNothing() {
        let items = ["a", "b", "c"]
        #expect(AlbumReorderGeometry.moving(items, from: 1, to: 1) == items)
    }

    @Test func movingClampsOutOfRangeIndexAndIgnoresBadSource() {
        #expect(AlbumReorderGeometry.moving(["a", "b"], from: 0, to: 99) == ["b", "a"])
        #expect(AlbumReorderGeometry.moving(["a", "b"], from: 0, to: -5) == ["a", "b"])
        #expect(AlbumReorderGeometry.moving(["a", "b"], from: 9, to: 0) == ["a", "b"])
    }

    // MARK: - 会话

    @Test func armedSessionIgnoresInsertionUntilDragging() {
        var session = AlbumReorderSession()
        session.arm(itemID: "album", index: 2)
        #expect(session.phase == .armed)
        #expect(session.isActive)
        #expect(!session.isDragging)

        // 抬起但未移动：不允许换位
        #expect(session.updateInsertIndex(5) == false)
        #expect(session.insertIndex == 2)
        #expect(!session.hasPendingMove)
    }

    @Test func draggingSessionReportsRealMoves() {
        var session = AlbumReorderSession()
        session.arm(itemID: "album", index: 1)
        session.beginDragging()

        #expect(session.updateInsertIndex(1) == false)   // 原地
        #expect(session.updateInsertIndex(0) == true)
        #expect(session.insertIndex == 0)
        #expect(session.hasPendingMove)
    }

    @Test func armedReleaseHasNoPendingMoveSoItFallsBackToMenu() {
        var session = AlbumReorderSession()
        session.arm(itemID: "album", index: 3)
        // 未 beginDragging 就松手 → 不应提交顺序
        #expect(!session.hasPendingMove)
    }

    @Test func resetClearsEverything() {
        var session = AlbumReorderSession()
        session.arm(itemID: "album", index: 1)
        session.beginDragging()
        _ = session.updateInsertIndex(4)
        session.reset()

        #expect(!session.isActive)
        #expect(session.itemID == nil)
        #expect(session.insertIndex == 0)
        #expect(!session.hasPendingMove)
    }

    @Test func beginDraggingWithoutArmingIsIgnored() {
        var session = AlbumReorderSession()
        session.beginDragging()
        #expect(session.phase == .idle)
    }
}
