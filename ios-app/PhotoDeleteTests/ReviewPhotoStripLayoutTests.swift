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

    @Test func activeSlotAddsMarginOnBothSides() {
        #expect(ReviewPhotoStripLayout.slotWidth(isCurrent: false) == ReviewPhotoStripLayout.itemWidth(isCurrent: false))
        #expect(ReviewPhotoStripLayout.slotWidth(isCurrent: true) ==
            ReviewPhotoStripLayout.itemHeight + ReviewPhotoStripLayout.activeExtraMargin * 2)
    }

    @Test func centeringInsetLetsEveryCardReachTheViewportCenter() {
        let viewport: CGFloat = 402
        let inset = ReviewPhotoStripLayout.centeringInset(viewportWidth: viewport)
        #expect(inset == viewport / 2 - ReviewPhotoStripLayout.slotWidth(isCurrent: true) / 2)
        // 当前格刚好居中：首项槽的左缘 + 半个槽宽 = 视口中心。
        #expect(inset + ReviewPhotoStripLayout.slotWidth(isCurrent: true) / 2 == viewport / 2)
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

    @Test func leadingEdgeKeepsFirstPhoto() {
        #expect(centered(offset: 0) == 0)
        #expect(centered(offset: -30) == 0)
    }

    @Test func trailingEdgeKeepsLastPhoto() {
        #expect(centered(offset: 118) == 3)
        #expect(centered(offset: 400) == 3)
    }

    @Test func centerPicksPhotoUnderViewportMiddle() {
        // 宽度 40/60/40/60 + 间距 6：中心 109 落在第三张 [112,152) 之前、第二张 [46,106) 之后。
        #expect(centered(offset: 59) == 2)
        #expect(centered(offset: 56) == 2)
        #expect(centered(offset: 46) == 1)
    }

    @Test func centerAccountsForEdgeInset() {
        let inset: CGFloat = 100
        let viewport: CGFloat = 200
        let widths: [CGFloat] = [
            ReviewPhotoStripLayout.slotWidth(isCurrent: true),
            ReviewPhotoStripLayout.slotWidth(isCurrent: false),
            ReviewPhotoStripLayout.slotWidth(isCurrent: false)
        ]
        let spacing = ReviewPhotoStripLayout.spacing
        func centered(offset: CGFloat) -> Int? {
            ReviewPhotoStripLayout.centeredIndex(
                offset: offset, viewportWidth: viewport, itemWidths: widths, spacing: spacing, edgeInset: inset
            )
        }
        // 取各槽中点对应的滚动偏移，验证命中的就是那一格。
        let firstSlotMid = inset + widths[0] / 2
        let secondSlotMid = inset + widths[0] + spacing + widths[1] / 2
        let thirdSlotMid = inset + widths[0] + spacing + widths[1] + spacing + widths[2] / 2
        #expect(centered(offset: 0) == 0)
        #expect(centered(offset: firstSlotMid - viewport / 2) == 0)
        #expect(centered(offset: secondSlotMid - viewport / 2) == 1)
        #expect(centered(offset: thirdSlotMid - viewport / 2) == 2)
        #expect(centered(offset: 10_000) == 2)
    }

    @Test func contentNarrowerThanViewportCannotScroll() {
        #expect(ReviewPhotoStripLayout.centeredIndex(
            offset: 0, viewportWidth: 400, itemWidths: [40, 60], spacing: 6
        ) == nil)
    }

    @Test func missingLayoutInputsReturnNil() {
        #expect(ReviewPhotoStripLayout.centeredIndex(
            offset: 10, viewportWidth: 100, itemWidths: [], spacing: 6
        ) == nil)
        #expect(ReviewPhotoStripLayout.centeredIndex(
            offset: 10, viewportWidth: 0, itemWidths: [40, 60, 40, 60], spacing: 6
        ) == nil)
    }

    private let widths: [CGFloat] = [40, 60, 40, 60]
    private let spacing: CGFloat = 6
    private let viewport: CGFloat = 100

    private func centered(offset: CGFloat) -> Int? {
        ReviewPhotoStripLayout.centeredIndex(
            offset: offset, viewportWidth: viewport, itemWidths: widths, spacing: spacing
        )
    }
}
