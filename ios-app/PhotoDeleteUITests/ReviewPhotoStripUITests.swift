import XCTest

/// 相册整理页底部胶片导轨：固定竖幅、当前格正方形，拖动导轨实时切换大图，松手吸附居中。
final class ReviewPhotoStripUITests: XCTestCase {
    private let stripIdentifier = "review-photo-strip"
    private let stripItemIdentifierPrefix = "review-photo-strip-item-"
    private let seedAlbumTitle = "Filmstrip Test"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFilmstripKeepsAspectRatiosAndSwitchesPhotoByDragging() {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "PHOTO_DELETE_UI_TEST": "1",
            "PHOTO_DELETE_UI_TEST_SEED_LIBRARY": "1",
            "PHOTO_DELETE_UI_TEST_APP_LANGUAGE": "en",
            "PHOTO_DELETE_UI_TEST_HAS_COMPLETED_ONBOARDING": "1"
        ]
        app.launch()

        openFilmstripAlbumReview(app)

        let strip = app.descendants(matching: .any)[stripIdentifier]
        XCTAssertTrue(strip.waitForExistence(timeout: 10))

        // 固定比例：所有格等高；普通格是同一个 2:3 竖幅，只有当前格变成正方形（两侧多留 11pt）。
        let items = visibleStripItems(app)
        XCTAssertGreaterThanOrEqual(items.count, 4, "导轨应同时展示多张缩略图")
        let heights = items.map(\.frame.height)
        XCTAssertLessThanOrEqual(
            (heights.max() ?? 0) - (heights.min() ?? 0), 1,
            "所有格应等高，实际高度：\(heights)"
        )

        let selectedBefore = selectedStripItemIndex(app)
        XCTAssertNotNil(selectedBefore, "导轨应有且仅有一个当前项")
        let selectedItem = items.first(where: \.isSelected)
        let normalItems = items.filter { !$0.isSelected }
        XCTAssertFalse(normalItems.isEmpty, "应有普通格可供对比")
        let normalWidths = normalItems.map(\.frame.width)
        XCTAssertLessThanOrEqual(
            (normalWidths.max() ?? 0) - (normalWidths.min() ?? 0), 1,
            "普通格宽高比固定，宽度应一致，实际宽度：\(normalWidths)"
        )
        if let selectedItem {
            XCTAssertEqual(selectedItem.frame.height, heights.first ?? 0, accuracy: 1, "当前格与普通格等高")
            // 当前格是正方形卡片（可能含两侧 11pt 留白），一定明显宽于固定 2:3 的普通格。
            XCTAssertGreaterThan(
                selectedItem.frame.width, (normalWidths.max() ?? 0) * 1.4,
                "当前格应变成正方形，实际宽度：\(selectedItem.frame.width)"
            )
        }

        attachScreenshot(app, name: "strip-entry")

        // 拖动导轨（不是点按）：内容左移，大图实时跟随前进。
        let progressBefore = progressTitle(app)

        let start = strip.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5))
        let end = strip.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)

        let selectedAfterScrub = waitForStripSelectionChange(from: selectedBefore, in: app)
        XCTAssertNotNil(selectedAfterScrub, "拖动导轨应切换当前照片")
        XCTAssertGreaterThan(
            selectedAfterScrub ?? -1, selectedBefore ?? 0,
            "向左拖动导轨应前进到后面的照片"
        )
        XCTAssertNotEqual(progressTitle(app), progressBefore, "大图应跟随导轨切换")

        attachScreenshot(app, name: "strip-after-scrub")

        // 停手后吸附：当前项精确落在视口中央（不再停在两格之间）。
        waitForSettle()
        let settledItem = stripItem(app, index: selectedAfterScrub ?? 0)
        XCTAssertNotNil(settledItem)
        if let settledItem {
            let offset = abs(settledItem.frame.midX - strip.frame.midX)
            XCTAssertLessThanOrEqual(offset, 2, "当前项应吸附居中，实际偏差 \(offset)pt")
        }

        // 点按相邻缩略图 = 直接跳转。
        let tapTarget = selectedItemIndexWithOffset(app, from: selectedAfterScrub ?? 0, by: 1)
        XCTAssertNotNil(tapTarget, "当前项右侧应有可点按的缩略图")
        if let tapTarget {
            stripItem(app, index: tapTarget)?.tap()
            let selectedAfterTap = waitForStripSelectionChange(from: selectedAfterScrub, in: app)
            XCTAssertEqual(selectedAfterTap, tapTarget, "点按缩略图应跳转到该照片")
        }

        attachScreenshot(app, name: "strip-after-tap")
    }

    // MARK: - Navigation

    private func openFilmstripAlbumReview(_ app: XCUIApplication) {
        app.tabBars.buttons["Albums"].tap()

        let album = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", seedAlbumTitle))
            .firstMatch
        XCTAssertTrue(album.waitForExistence(timeout: 30))
        album.tap()

        let firstAsset = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "album-browser-asset-"))
            .firstMatch
        XCTAssertTrue(firstAsset.waitForExistence(timeout: 20))
        firstAsset.tap()
    }

    // MARK: - Strip queries

    private func visibleStripItems(_ app: XCUIApplication) -> [XCUIElement] {
        app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", stripItemIdentifierPrefix))
            .allElementsBoundByIndex
    }

    private func stripItem(_ app: XCUIApplication, index: Int) -> XCUIElement? {
        let identifier = "\(stripItemIdentifierPrefix)\(index)"
        return visibleStripItems(app).first { $0.identifier == identifier }
    }

    private func selectedStripItemIndex(_ app: XCUIApplication) -> Int? {
        guard let selected = visibleStripItems(app).first(where: \.isSelected) else { return nil }
        return Int(selected.identifier.dropFirst(stripItemIdentifierPrefix.count))
    }

    private func selectedItemIndexWithOffset(
        _ app: XCUIApplication,
        from index: Int,
        by offset: Int
    ) -> Int? {
        stripItem(app, index: index + offset).map { _ in index + offset }
    }

    private func waitForStripSelectionChange(
        from previous: Int?,
        in app: XCUIApplication
    ) -> Int? {
        // 拖动中当前格不放大（没有选中项），要等到松手后新的选中项稳定出现。
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                guard let current = self.selectedStripItemIndex(app) else { return false }
                return current != previous
            },
            object: nil
        )
        _ = XCTWaiter().wait(for: [expectation], timeout: 5)
        return selectedStripItemIndex(app)
    }

    private func progressTitle(_ app: XCUIApplication) -> String? {
        let title = app.staticTexts
            .matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+ / [0-9]+$"))
            .firstMatch
        return title.exists ? title.label : nil
    }

    // MARK: - Helpers

    private func waitForSettle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
