import XCTest

final class AlbumDialogSnapshotTests: XCTestCase {
    func testCompletionOverlayState() {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "PHOTO_DELETE_UI_TEST": "1",
            "PHOTO_DELETE_UI_TEST_SEED_LIBRARY": "1",
            "PHOTO_DELETE_UI_TEST_APP_LANGUAGE": "en",
            "PHOTO_DELETE_UI_TEST_HAS_COMPLETED_ONBOARDING": "1"
        ]
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 30))
        settingsTab.tap()
        let hideFiled = app.switches.matching(
            NSPredicate(format: "label CONTAINS %@", "Hide filed photos")
        ).firstMatch
        XCTAssertTrue(hideFiled.waitForExistence(timeout: 10))
        if (hideFiled.value as? String) == "1" {
            hideFiled.tap()
        }
        app.tabBars.buttons["Organize"].tap()

        let randomReview = app.buttons["home-random-review"]
        XCTAssertTrue(randomReview.waitForExistence(timeout: 30))
        randomReview.tap()

        let finish = app.buttons["Finish Organizing"]
        XCTAssertTrue(finish.waitForExistence(timeout: 15))
        finish.tap()

        let done = app.buttons["review-completion-primary-button"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Organizing Complete"].exists, "title exists")
        XCTAssertFalse(app.staticTexts["Random Browse"].exists, "source title removed")

        Thread.sleep(forTimeInterval: 0.6)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "review-completion-overlay"
        attachment.lifetime = .keepAlways
        add(attachment)

        let close = app.buttons["review-completion-close"]
        XCTAssertTrue(close.exists)
        close.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 4), "close dismisses overlay")
    }
}
