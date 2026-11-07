import Foundation
import Testing
@testable import PhotoDelete

struct ReviewPhotoStripLayoutTests {
    // MARK: - 卡片与槽位（对齐 iOS 原生胶片条：固定竖幅，只有当前格是正方形）

    @Test func normalCardIsFixedPortraitNotPerPhotoAspect() {
        #expect(ReviewPhotoStripLayout.itemAspectRatio(isCurrent: false) == ReviewPhotoStripLayout.itemAspect)
        #expect(ReviewPhotoStripLayout.itemAspectRatio(isCurrent: false) == 2.0 / 3.0)
        #expect(ReviewPhotoStripLayout.itemWidth(isCurrent: false) ==
            ReviewPhotoStripLayout.itemHeight * ReviewPhotoStripLayout.itemAspect)
    }

    @Test func activeCardIsSquareWithTheSameHeight() {
        #expect(ReviewPhotoStripLayout.itemAspectRatio(isCurrent: true) == 1)
        #expect(ReviewPhotoStripLayout.itemWidth(isCurrent: true) == ReviewPhotoStripLayout.itemHeight)
    }

    @Test func slotsAreUniformSoExpandingNeverShiftsScrollContent() {
        #expect(ReviewPhotoStripLayout.slotWidth == ReviewPhotoStripLayout.itemWidth(isCurrent: false))
        #expect(ReviewPhotoStripLayout.pitch == ReviewPhotoStripLayout.slotWidth + ReviewPhotoStripLayout.spacing)
    }

    @Test func centeringInsetLetsEveryCardReachTheViewportCenter() {
        let viewport: CGFloat = 402
        let inset = ReviewPhotoStripLayout.centeringInset(viewportWidth: viewport)
        // 第 i 格的中心 = inset + i × pitch + 半槽；滚动 i × pitch 后正好落在视口中心。
        for index in [0, 1, 7] {
            let center = inset + CGFloat(index) * ReviewPhotoStripLayout.pitch + ReviewPhotoStripLayout.slotWidth / 2
            #expect(abs(center - ReviewPhotoStripLayout.contentOffset(for: index) - viewport / 2) < 0.0001)
        }
    }

    // MARK: - 当前格放大时邻居让位

    @Test func neighborsMoveApartWhileActiveCardStaysPut() {
        let shift = ReviewPhotoStripLayout.neighborShift
        #expect(ReviewPhotoStripLayout.displacement(of: 5, activeIndex: 5) == 0)
        #expect(ReviewPhotoStripLayout.displacement(of: 4, activeIndex: 5) == -shift)
        #expect(ReviewPhotoStripLayout.displacement(of: 0, activeIndex: 5) == -shift)
        #expect(ReviewPhotoStripLayout.displacement(of: 6, activeIndex: 5) == shift)
        #expect(ReviewPhotoStripLayout.displacement(of: 3, activeIndex: nil) == 0)
    }

    @Test func neighborGapEqualsSpacingPlusExtraMargin() {
        // 放大后当前格右缘到右邻左缘的可见间隙 = 原间距 + 隔离留白。
        let activeRightEdge = ReviewPhotoStripLayout.slotWidth / 2 + ReviewPhotoStripLayout.itemWidth(isCurrent: true) / 2
        let neighborLeftEdge = ReviewPhotoStripLayout.pitch + ReviewPhotoStripLayout.neighborShift
        let gap = neighborLeftEdge - activeRightEdge
        #expect(abs(gap - (ReviewPhotoStripLayout.spacing + ReviewPhotoStripLayout.activeExtraMargin)) < 0.0001)
    }

    // MARK: - 边缘模糊渐隐

    @Test func edgeFadeIsClearInTheMiddleAndFullAtTheEdge() {
        #expect(ReviewPhotoStripLayout.edgeFadeProgress(distanceToEdge: 200) == 0)
        #expect(ReviewPhotoStripLayout.edgeFadeProgress(distanceToEdge: ReviewPhotoStripLayout.edgeFadeWidth) == 0)
        #expect(ReviewPhotoStripLayout.edgeFadeProgress(distanceToEdge: 0) == 1)
        #expect(ReviewPhotoStripLayout.edgeFadeProgress(distanceToEdge: -12) == 1)
        let half = ReviewPhotoStripLayout.edgeFadeProgress(distanceToEdge: ReviewPhotoStripLayout.edgeFadeWidth / 2)
        #expect(abs(half - 0.5) < 0.0001)
    }

    // MARK: - 视口中心命中（拖动导轨时的实时切换目标）

    @Test func centeredIndexPicksNearestSlot() {
        let pitch = ReviewPhotoStripLayout.pitch
        #expect(ReviewPhotoStripLayout.centeredIndex(offset: 0, itemCount: 10) == 0)
        #expect(ReviewPhotoStripLayout.centeredIndex(offset: pitch * 0.49, itemCount: 10) == 0)
        #expect(ReviewPhotoStripLayout.centeredIndex(offset: pitch * 0.51, itemCount: 10) == 1)
        #expect(ReviewPhotoStripLayout.centeredIndex(offset: pitch * 3, itemCount: 10) == 3)
    }

    @Test func rubberBandingClampsToFirstAndLastPhoto() {
        #expect(ReviewPhotoStripLayout.centeredIndex(offset: -40, itemCount: 4) == 0)
        #expect(ReviewPhotoStripLayout.centeredIndex(offset: 10_000, itemCount: 4) == 3)
    }

    @Test func emptyStripHasNoCenteredIndex() {
        #expect(ReviewPhotoStripLayout.centeredIndex(offset: 10, itemCount: 0) == nil)
    }

    // MARK: - 松手吸附

    @Test func flingTargetSnapsToNearestSlotCenter() {
        let pitch = ReviewPhotoStripLayout.pitch
        #expect(ReviewPhotoStripLayout.snappedOffset(proposed: pitch * 4.3, itemCount: 20) == pitch * 4)
        #expect(ReviewPhotoStripLayout.snappedOffset(proposed: pitch * 4.7, itemCount: 20) == pitch * 5)
        #expect(ReviewPhotoStripLayout.snappedOffset(proposed: -25, itemCount: 20) == 0)
        #expect(ReviewPhotoStripLayout.snappedOffset(proposed: pitch * 99, itemCount: 20) == pitch * 19)
    }

    @Test func snappingWithoutPhotosKeepsProposedOffset() {
        #expect(ReviewPhotoStripLayout.snappedOffset(proposed: 12, itemCount: 0) == 12)
    }
}
