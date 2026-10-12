import XCTest

final class AlbumLongPressTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoversMenuAndContinuousDrag() {
        verifyMenuAndContinuousDrag(style: "Covers")
    }

    func testCompactMenuAndContinuousDrag() {
        verifyMenuAndContinuousDrag(style: "Compact")
    }

    func testListMenuAndContinuousDrag() {
        verifyMenuAndContinuousDrag(style: "List")
    }

    func testFavoritesEntryIsBesideDisplayAndShowsEmptyStateWithoutFavorites() {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "PHOTO_DELETE_UI_TEST": "1",
            "PHOTO_DELETE_UI_TEST_SEED_LIBRARY": "1",
            "PHOTO_DELETE_UI_TEST_APP_LANGUAGE": "en",
            "PHOTO_DELETE_UI_TEST_HAS_COMPLETED_ONBOARDING": "1"
        ]
        app.launch()
        app.tabBars.buttons["Albums"].tap()

        let favoritesEntry = app.buttons["album-favorites-entry"]
        XCTAssertTrue(favoritesEntry.waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["album-display-style"].exists)
        favoritesEntry.tap()
        XCTAssertTrue(app.staticTexts["No Favorites Yet"].waitForExistence(timeout: 5))
    }

    private func verifyMenuAndContinuousDrag(style: String) {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "PHOTO_DELETE_UI_TEST": "1",
            "PHOTO_DELETE_UI_TEST_SEED_LIBRARY": "1",
            "PHOTO_DELETE_UI_TEST_APP_LANGUAGE": "en",
            "PHOTO_DELETE_UI_TEST_HAS_COMPLETED_ONBOARDING": "1"
        ]
        app.launch()
        app.tabBars.buttons["Albums"].tap()

        let items = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "album-item-"))
        XCTAssertTrue(items.firstMatch.waitForExistence(timeout: 30))
        app.buttons["album-display-style"].tap()
        app.buttons[style].tap()
        app.buttons["Close"].tap()

        let source = items.element(boundBy: 0)
        let sourceID = source.identifier
        let originalPosition = source.value as? String
        source.press(forDuration: 1.5)

        // A stationary release leaves the already-open menu usable and does not reorder.
        XCTAssertTrue(app.staticTexts["Hold and drag to reorder"].waitForExistence(timeout: 3))
        XCTAssertEqual(source.value as? String, originalPosition)
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Album"].waitForExistence(timeout: 3))
        app.navigationBars["Edit Album"].buttons["Cancel"].tap()

        let target = items.element(boundBy: 1)
        let start = source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        let end = target.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.8))
        // One uninterrupted touch: hold for the menu, drag through it, then release.
        // The long hold at each end also makes both states observable in simulator recordings.
        start.press(forDuration: 2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 1.5)

        XCTAssertFalse(app.staticTexts["Hold and drag to reorder"].exists)
        let moved = app.buttons[sourceID]
        XCTAssertTrue(moved.waitForExistence(timeout: 3))
        let savedPosition = moved.value as? String
        XCTAssertNotEqual(savedPosition, originalPosition)

        // Relaunch without the test-default reset to verify the saved order.
        app.terminate()
        app.launchEnvironment = [:]
        app.launch()
        app.tabBars.buttons["Albums"].tap()
        XCTAssertTrue(app.buttons[sourceID].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons[sourceID].value as? String, savedPosition)

        // A normal tap must still open the album rather than arm another reorder.
        app.buttons[sourceID].tap()
        XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Hold and drag to reorder"].exists)
    }
}
