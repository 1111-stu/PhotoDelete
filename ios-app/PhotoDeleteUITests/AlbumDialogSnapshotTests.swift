import XCTest

final class AlbumDialogSnapshotTests: XCTestCase {
    func testCaptureCreateAlbumDialog() {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "PHOTO_DELETE_UI_TEST": "1",
            "PHOTO_DELETE_UI_TEST_SEED_LIBRARY": "1",
            "PHOTO_DELETE_UI_TEST_APP_LANGUAGE": "en",
            "PHOTO_DELETE_UI_TEST_HAS_COMPLETED_ONBOARDING": "1"
        ]
        app.launch()

        let albumsTab = app.tabBars.buttons["Albums"]
        XCTAssertTrue(albumsTab.waitForExistence(timeout: 30))
        albumsTab.tap()

        let create = app.buttons["Create Album"]
        XCTAssertTrue(create.waitForExistence(timeout: 30))
        create.tap()

        XCTAssertTrue(app.staticTexts["Create New Album"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "create-album-dialog"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
