//
//  PhotoDeleteUITests.swift
//  PhotoDeleteUITests
//
//  Created by jackie xiao on 11/7/25.
//

import Foundation
import XCTest

final class PhotoDeleteUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingFlowCompletesToHome() throws {
        installPhotoLibraryInterruptionMonitor()

        let app = makeApp(completedOnboarding: false)
        app.launch()

        XCTAssertTrue(app.staticTexts["让照片整理变得简单"].waitForExistence(timeout: 10))
        app.buttons["继续"].tap()

        XCTAssertTrue(app.staticTexts["左滑删除，右滑保留"].waitForExistence(timeout: 3))
        app.buttons["继续"].tap()

        XCTAssertTrue(app.staticTexts["找回更多空间"].waitForExistence(timeout: 3))
        app.buttons["继续"].tap()

        XCTAssertTrue(app.staticTexts["照片不会上传"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["整理"].exists)
        app.buttons["选择照片访问权限"].tap()
        _ = allowFullPhotoLibraryAccessIfNeeded(app: app)

        XCTAssertTrue(
            app.tabBars.buttons["整理"].waitForExistence(timeout: 10) ||
                app.staticTexts["需要访问照片库"].waitForExistence(timeout: 2) ||
                app.staticTexts["随机整理"].waitForExistence(timeout: 2) ||
                app.staticTexts["待整理"].waitForExistence(timeout: 2) ||
                app.staticTexts["没有可整理的照片"].waitForExistence(timeout: 2)
        )
    }

    @MainActor
    func testHomeShowsActionableLibraryState() throws {
        let app = makeApp(completedOnboarding: true)
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["整理"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts["需要访问照片库"].exists ||
                app.staticTexts["随机整理"].exists ||
                app.staticTexts["待整理"].exists ||
                app.staticTexts["没有可整理的照片"].exists ||
                app.staticTexts["专项清理"].exists
        )
    }

    @MainActor
    func testProPaywallOffersAnnualAndLifetimePlans() throws {
        let app = makeApp(completedOnboarding: true)
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["整理"].waitForExistence(timeout: 10))
        openSettingsTab(in: app)

        guard let proEntry = waitForHittableButtonLabelContaining(
            in: app,
            substring: "解锁进阶功能",
            timeout: 10
        ) else {
            XCTFail("Expected the OnePhoto Pro settings entry")
            return
        }
        proEntry.tap()

        XCTAssertTrue(app.staticTexts["OnePhoto Pro"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "年度 Pro")).firstMatch.waitForExistence(timeout: 10))
        let lifetimePlan = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "永久 Pro")).firstMatch
        XCTAssertTrue(lifetimePlan.waitForExistence(timeout: 10))
        sleep(2)
        let paywallScreenshot = XCTAttachment(screenshot: app.screenshot())
        paywallScreenshot.name = "OnePhoto Pro Paywall"
        paywallScreenshot.lifetime = .keepAlways
        add(paywallScreenshot)
        lifetimePlan.tap()
        XCTAssertNotNil(waitForAnyElementLabelContaining(in: app, substring: "解锁永久 Pro", timeout: 5))
        XCTAssertTrue(app.buttons["恢复购买"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["supporter-privacy-policy-link"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["supporter-terms-of-use-link"].exists)
    }

    @MainActor
    func testSeededAlbumsTabAndReviewAlbumFilingShortcut() throws {
        installPhotoLibraryInterruptionMonitor(allowDeletionConfirmation: true)

        let app = makeApp(completedOnboarding: true, seedLibrary: true)
        app.launch()
        _ = allowFullPhotoLibraryAccessIfNeeded(app: app)
        dismissMarketingSystemPrompts(app: app, allowDeletionConfirmation: true)

        if app.state != .runningForeground {
            app.activate()
        }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !waitForHomeReady(in: app, language: "zh-Hans", timeout: 30) {
            app.terminate()
            app.launch()
            _ = allowFullPhotoLibraryAccessIfNeeded(app: app)
            dismissMarketingSystemPrompts(app: app, allowDeletionConfirmation: true)
        }
        XCTAssertTrue(waitForHomeReady(in: app, language: "zh-Hans", timeout: 30))

        let albumTitles = ["旅行照片", "周末海边", "城市漫步", "宠物照片"]
        openAlbumsTab(in: app)
        XCTAssertTrue(app.staticTexts["旅行照片"].waitForExistence(timeout: 60))

        var baselineCounts: [String: Int] = [:]
        for title in albumTitles {
            guard let albumButton = waitForButtonLabelPrefix(in: app, prefix: title, timeout: 20) else {
                XCTFail("Expected the seeded album row for \(title)")
                return
            }
            guard let count = photoCount(fromAlbumRowLabel: albumButton.label) else {
                XCTFail("Expected a photo count in the \(title) album row: \(albumButton.label)")
                return
            }
            baselineCounts[title] = count
        }

        openOrganizeTab(in: app)
        guard let startCleanupButton = waitForFirstExistingButton(
            in: app,
            labels: ["随机整理", "home-random-review"],
            timeout: 30
        ) else {
            XCTFail("Expected a review entry button after seeded library load")
            return
        }
        startCleanupButton.tap()

        let doneButton = firstExistingButton(in: app, labels: ["完成整理", "完成"])
        XCTAssertTrue(doneButton.waitForExistence(timeout: 30))

        let dismissHintButton = app.buttons["知道了"]
        if dismissHintButton.exists, dismissHintButton.isHittable {
            dismissHintButton.tap()
        }

        var attemptedAlbumTitles: [String] = []
        var successfulFilingTitles: Set<String> = []
        for title in albumTitles {
            let filed = fileCurrentReviewPhoto(into: title, in: app)
            if !filed && app.buttons["归类到 \(title)"].exists == false && app.staticTexts["放进哪个相册?"].exists == false {
                continue
            }
            attemptedAlbumTitles.append(title)
            if filed {
                successfulFilingTitles.insert(title)
            }

            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: 5),
                "The app must remain in the foreground after filing into \(title)"
            )
            XCTAssertNotNil(
                waitForReviewDoneButton(in: app, timeout: 5),
                "The review controls should remain interactive after filing into \(title)"
            )
        }

        XCTAssertFalse(
            attemptedAlbumTitles.isEmpty,
            "Expected at least one writable album shortcut path to be available"
        )
        guard let targetAlbumTitle = attemptedAlbumTitles.first(where: { successfulFilingTitles.contains($0) })
                ?? attemptedAlbumTitles.first else {
            return
        }

        openAlbumsTab(in: app)
        var finalCounts: [String: Int] = [:]
        for title in albumTitles {
            guard let albumButton = waitForButtonLabelPrefix(in: app, prefix: title, timeout: 20) else {
                XCTFail("Expected the album row for \(title) after filing")
                return
            }
            guard let count = photoCount(fromAlbumRowLabel: albumButton.label) else {
                XCTFail("Expected a photo count in the updated \(title) album row: \(albumButton.label)")
                return
            }
            finalCounts[title] = count
            XCTAssertGreaterThanOrEqual(
                count,
                baselineCounts[title] ?? 0,
                "A repeated filing must not reduce the \(title) album count"
            )
            if successfulFilingTitles.contains(title) {
                XCTAssertGreaterThanOrEqual(
                    count,
                    (baselineCounts[title] ?? 0) + 1,
                    "The \(title) album count should reflect its successful filing"
                )
            }
        }
        XCTAssertEqual(finalCounts.count, albumTitles.count)

        XCTAssertNotNil(waitForStaticTextLabel(in: app, label: targetAlbumTitle, timeout: 10))
        guard let targetAlbumButton = waitForButtonLabelPrefix(in: app, prefix: targetAlbumTitle, timeout: 10) else {
            XCTFail("Expected the target album after filing")
            return
        }
        targetAlbumButton.tap()

        let organizeAlbum = app.descendants(matching: .any)["album-start-review"]
        XCTAssertTrue(organizeAlbum.waitForExistence(timeout: 10))
        organizeAlbum.tap()

        let reviewCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "review-photo-card"))
            .firstMatch
        XCTAssertTrue(reviewCard.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["整理完成！"].waitForExistence(timeout: 1))
    }

    @MainActor
    func testReviewAlbumShortcutsLoadWithoutOpeningAlbumsTab() throws {
        installPhotoLibraryInterruptionMonitor(allowDeletionConfirmation: true)

        let app = makeApp(completedOnboarding: true, seedLibrary: true)
        app.launch()
        _ = allowFullPhotoLibraryAccessIfNeeded(app: app)

        if app.state != .runningForeground {
            app.activate()
        }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !waitForHomeReady(in: app, language: "zh-Hans", timeout: 30) {
            app.terminate()
            app.launch()
            _ = allowFullPhotoLibraryAccessIfNeeded(app: app)
        }
        XCTAssertTrue(waitForHomeReady(in: app, language: "zh-Hans", timeout: 30))

        openOrganizeTab(in: app)
        guard let startCleanupButton = waitForFirstExistingButton(
            in: app,
            labels: ["随机整理", "home-random-review", "Random"],
            timeout: 30
        ) else {
            XCTFail("Expected a review entry button after seeded library load")
            return
        }
        startCleanupButton.tap()

        let doneButton = firstExistingButton(in: app, labels: ["完成整理", "完成"])
        XCTAssertTrue(doneButton.waitForExistence(timeout: 30))

        let dismissHintButton = app.buttons["知道了"]
        if dismissHintButton.exists, dismissHintButton.isHittable {
            dismissHintButton.tap()
        }

        dragCardDown(in: app)

        XCTAssertTrue(app.staticTexts["放进哪个相册?"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts["快捷相册"].exists || app.staticTexts["暂未添加快捷相册"].exists
        )
        XCTAssertNotNil(
            waitForHittableButtonLabelContaining(in: app, substring: "归类到 ", timeout: 15),
            "Album filing should list albums without opening the albums tab"
        )
    }

    @MainActor
    func testCleanupConfirmationSelectionAndReturn() throws {
        try verifyCleanupConfirmation(appearance: "dark")
    }

    @MainActor
    func testCleanupConfirmationLightAppearance() throws {
        try verifyCleanupConfirmation(appearance: "light")
    }

    @MainActor
    private func verifyCleanupConfirmation(appearance: String) throws {
        installPhotoLibraryInterruptionMonitor()
        let app = makeApp(completedOnboarding: true, seedLibrary: true)
        app.launchEnvironment[AppLaunchEnvironmentKey.appAppearance] = appearance
        app.launch()
        _ = allowFullPhotoLibraryAccessIfNeeded(app: app)
        dismissMarketingSystemPrompts(app: app)
        XCTAssertTrue(waitForHomeReady(in: app, language: "zh-Hans", timeout: 30))
        app.buttons["home-random-review"].tap()
        XCTAssertNotNil(waitForReviewDoneButton(in: app, timeout: 30))
        if app.buttons["知道了"].exists { app.buttons["知道了"].tap() }
        dragCardUp(in: app)
        try XCTUnwrap(waitForReviewDoneButton(in: app, timeout: 10)).tap()
        XCTAssertTrue(app.buttons["cleanup-confirm"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["待删除 · 1/1"].exists)
        XCTAssertTrue(app.buttons["取消全选"].exists, "The approved layout retains the toggle for a single item.")
        let size = app.descendants(matching: .any)["cleanup-size-summary"].firstMatch
        let toggle = app.buttons["取消全选"]
        XCTAssertTrue(size.exists)
        XCTAssertGreaterThan(toggle.frame.minX, size.frame.minX)
        XCTAssertLessThan(abs(toggle.frame.midY - size.frame.midY), 28,
                          "Size and selection toggle should share one row.")
        app.buttons["取消全选"].tap()
        XCTAssertTrue(app.navigationBars["待删除 · 0/1"].exists)
        XCTAssertTrue(app.staticTexts["未选择项目"].exists)
        XCTAssertFalse(app.buttons["cleanup-confirm"].isEnabled)
        app.buttons["全选"].tap()
        let output = ProcessInfo.processInfo.environment["PHOTO_DELETE_REVIEW_CAPTURE_DIR"] ?? "/tmp/photodelete-cleanup-review"
        let directory = URL(fileURLWithPath: output, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try capture("cleanup-single-\(appearance)", in: directory, app: app)
        app.buttons["cleanup-back"].tap()
        dragCardUp(in: app)
        dragCardUp(in: app)
        dragCardUp(in: app)
        try XCTUnwrap(waitForReviewDoneButton(in: app, timeout: 10)).tap()

        let confirm = app.buttons["cleanup-confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertTrue(confirm.isEnabled)
        XCTAssertTrue(app.buttons["cleanup-back"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertTrue(app.navigationBars["待删除 · 4/4"].exists)
        let cancel = app.buttons["cleanup-cancel-all"]
        let consequence = app.descendants(matching: .any)["cleanup-consequence"].firstMatch
        XCTAssertLessThan(cancel.frame.maxX, confirm.frame.minX)
        XCTAssertEqual(cancel.frame.minY, confirm.frame.minY, accuracy: 2)
        XCTAssertEqual(cancel.frame.height, confirm.frame.height, accuracy: 2)
        XCTAssertLessThan(consequence.frame.maxY, confirm.frame.minY)
        let selections = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "cleanup-selection-"))
        XCTAssertEqual(selections.count, 4)
        selections.element(boundBy: 0).tap()
        XCTAssertTrue(confirm.isEnabled, "Remaining selected items still permit confirmation.")
        app.buttons["放大查看照片"].firstMatch.tap()
        XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 10))
        app.buttons["关闭"].tap()
        XCTAssertEqual(selections.matching(NSPredicate(format: "label == %@", "选择")).count, 1,
                       "Preview must preserve the deselected item.")
        app.buttons["全选"].tap()
        app.buttons["取消全选"].tap()
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["全选"].tap()

        try capture("cleanup-confirmation-\(appearance)", in: directory, app: app)
        app.buttons["cleanup-back"].tap()
        XCTAssertNotNil(waitForReviewDoneButton(in: app, timeout: 10))
        try XCTUnwrap(waitForReviewDoneButton(in: app, timeout: 10)).tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertEqual(selections.count, 4, "Returning must preserve pending operations.")
        app.buttons["cleanup-cancel-all"].tap()
        XCTAssertNotNil(waitForReviewDoneButton(in: app, timeout: 10))
        try XCTUnwrap(waitForReviewDoneButton(in: app, timeout: 10)).tap()
        XCTAssertTrue(waitForHomeReady(in: app, language: "zh-Hans", timeout: 15),
                      "Finishing after cancel all must return home without another confirmation.")
        XCTAssertFalse(confirm.exists)
    }

    @MainActor
    func testRandomReviewSkipsDeletedPhotosAndSupportsVerticalGestures() throws {
        installPhotoLibraryInterruptionMonitor(allowDeletionConfirmation: true)
        let app = makeApp(completedOnboarding: true, seedLibrary: true)
        app.launch()
        _ = allowFullPhotoLibraryAccessIfNeeded(app: app)
        dismissMarketingSystemPrompts(app: app, allowDeletionConfirmation: true)
        XCTAssertTrue(waitForHomeReady(in: app, language: "zh-Hans", timeout: 30))

        let randomReview = app.buttons["home-random-review"]
        XCTAssertTrue(randomReview.waitForExistence(timeout: 30))
        randomReview.tap()
        XCTAssertNotNil(waitForReviewDoneButton(in: app, timeout: 30))
        let dismissHintButton = app.buttons["知道了"]
        if dismissHintButton.exists, dismissHintButton.isHittable {
            dismissHintButton.tap()
        }

        func isAtPosition(_ position: Int) -> Bool {
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "\(position) / "))
                .firstMatch.waitForExistence(timeout: 5)
        }

        XCTAssertTrue(isAtPosition(1))
        let firstCard = app.descendants(matching: .any).matching(identifier: "review-photo-card").firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        let initialFrame = firstCard.frame
        let shortDragStart = firstCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        shortDragStart.press(forDuration: 0.15, thenDragTo: shortDragStart.withOffset(CGVector(dx: 0, dy: -18)))
        XCTAssertTrue(isAtPosition(1), "A short upward drag must keep the current photo.")
        let restoredFrame = firstCard.frame
        XCTAssertEqual(restoredFrame.minX, initialFrame.minX, accuracy: 1)
        XCTAssertEqual(restoredFrame.minY, initialFrame.minY, accuracy: 1)
        XCTAssertEqual(restoredFrame.width, initialFrame.width, accuracy: 1)
        XCTAssertEqual(restoredFrame.height, initialFrame.height, accuracy: 1)

        dragCardLeft(in: app)
        XCTAssertTrue(isAtPosition(2))
        dragCardUp(in: app)
        XCTAssertTrue(isAtPosition(3))
        let trashButton = app.buttons["review-trash-button"]
        XCTAssertEqual(trashButton.value as? String, "待删除 1 张")

        dragCardRight(in: app)
        XCTAssertTrue(isAtPosition(1), "Previous navigation must skip the deleted second photo.")
        dragCardLeft(in: app)
        XCTAssertTrue(isAtPosition(3), "Next navigation must skip the deleted second photo.")
        XCTAssertEqual(trashButton.value as? String, "待删除 1 张")

        app.buttons["撤销"].tap()
        XCTAssertTrue(isAtPosition(2), "Undo must restore the deleted photo at its original position.")
        XCTAssertEqual(trashButton.value as? String, "待删除 0 张")
        dragCardUp(in: app)
        XCTAssertTrue(isAtPosition(3))
        XCTAssertEqual(trashButton.value as? String, "待删除 1 张")

        dragCardDown(in: app)
        XCTAssertTrue(app.staticTexts["放进哪个相册?"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testSeededReviewCanRapidlyFileSeveralPhotosAcrossWritableAlbums() throws {
        installPhotoLibraryInterruptionMonitor(allowDeletionConfirmation: true)

        let app = makeApp(completedOnboarding: true, seedLibrary: true)
        app.launch()
        _ = allowFullPhotoLibraryAccessIfNeeded(app: app)
        dismissMarketingSystemPrompts(app: app, allowDeletionConfirmation: true)

        if app.state != .runningForeground {
            app.activate()
        }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !waitForHomeReady(in: app, language: "zh-Hans", timeout: 30) {
            app.terminate()
            app.launch()
            _ = allowFullPhotoLibraryAccessIfNeeded(app: app)
            dismissMarketingSystemPrompts(app: app, allowDeletionConfirmation: true)
        }
        XCTAssertTrue(waitForHomeReady(in: app, language: "zh-Hans", timeout: 30))

        let albumTitles = ["旅行照片", "周末海边", "城市漫步", "宠物照片"]
        openAlbumsTab(in: app)
        var baselineCounts: [String: Int] = [:]
        for title in albumTitles {
            guard let albumButton = waitForButtonLabelPrefix(in: app, prefix: title, timeout: 20) else {
                XCTFail("Expected the seeded album row for \(title)")
                return
            }
            guard let count = photoCount(fromAlbumRowLabel: albumButton.label) else {
                XCTFail("Expected a photo count in the \(title) album row: \(albumButton.label)")
                return
            }
            baselineCounts[title] = count
        }

        openOrganizeTab(in: app)
        // Anchor this regression to the dedicated all-photos card. A generic
        // "开始整理" match can accidentally land on a time-group entry when
        // the home screen is populated with today's/this week's groups.
        guard let startCleanupButton = waitForAllPhotosReviewEntry(in: app, timeout: 30) else {
            XCTFail("Expected the explicit all-photos review entry after seeded library load")
            return
        }
        startCleanupButton.tap()

        let doneButton = firstExistingButton(in: app, labels: ["完成整理", "完成"])
        XCTAssertTrue(doneButton.waitForExistence(timeout: 30))

        let dismissHintButton = app.buttons["知道了"]
        if dismissHintButton.exists, dismissHintButton.isHittable {
            dismissHintButton.tap()
        }

        // Each filing advances to the next card immediately while the Photos
        // write is queued. Use a different writable album for every tap so the
        // loop exercises four consecutive writes. A seeded asset can already
        // belong to its target album when the simulator is reused, so the
        // final count reconciliation below is intentionally no-op-safe.
        var completedFilings = 0
        for title in albumTitles {
            XCTAssertTrue(
                fileCurrentReviewPhoto(into: title, in: app),
                "Expected to file the current photo into \(title)"
            )
            XCTAssertTrue(
                app.wait(for: .runningForeground, timeout: 2),
                "The review must stay in the foreground after filing into \(title)"
            )
            XCTAssertTrue(
                waitForReviewDoneButton(in: app, timeout: 5) != nil,
                "The review controls should remain interactive after filing into \(title)"
            )
            completedFilings += 1
        }

        XCTAssertEqual(completedFilings, albumTitles.count, "Expected all four consecutive filing actions to complete")

        // Four filings advance onto the next review card. Exercise a
        // non-album action there, then restore the original favorite state so
        // this seeded-library regression leaves no pending operation behind.
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 5),
            "The app must remain in the foreground after the four-card filing burst"
        )
        let nextReviewCard = app.descendants(matching: .any)["review-photo-card"]
        XCTAssertTrue(
            nextReviewCard.waitForExistence(timeout: 5),
            "The next review card should remain visible after the four-card filing burst"
        )
        XCTAssertTrue(
            verifyFavoriteToggleRoundTrip(in: app),
            "The next review card should support a favorite toggle without leaving review"
        )
        XCTAssertNotNil(
            waitForReviewDoneButton(in: app, timeout: 5),
            "The review completion control should remain interactive after the favorite round trip"
        )

        // Return to Albums only after the four taps. Poll the rows until their
        // count snapshots stop falling below the baseline; this is the single
        // reconciliation wait for the queued Photos writes and is safe when a
        // filing was already a member of its target album.
        openAlbumsTab(in: app)
        var finalCounts: [String: Int] = [:]
        let reconciliationDeadline = Date().addingTimeInterval(20)
        while Date() < reconciliationDeadline {
            var observedCounts: [String: Int] = [:]
            var rowsReady = true
            for title in albumTitles {
                guard let albumButton = waitForButtonLabelPrefix(in: app, prefix: title, timeout: 2),
                      let count = photoCount(fromAlbumRowLabel: albumButton.label) else {
                    rowsReady = false
                    break
                }
                observedCounts[title] = count
            }

            if rowsReady,
               observedCounts.count == albumTitles.count,
               albumTitles.allSatisfy({ observedCounts[$0, default: 0] >= (baselineCounts[$0] ?? 0) }) {
                finalCounts = observedCounts
                break
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }

        XCTAssertEqual(
            finalCounts.count,
            albumTitles.count,
            "Expected all album rows to reconcile after the filing burst"
        )
        for title in albumTitles {
            guard let count = finalCounts[title] else { continue }
            XCTAssertGreaterThanOrEqual(
                count,
                baselineCounts[title] ?? 0,
                "A repeated filing must not reduce the \(title) album count"
            )
        }
    }

    @MainActor
    func testFavoriteButtonTogglesFavoriteStatus() throws {
        installPhotoLibraryInterruptionMonitor(allowDeletionConfirmation: true)

        let app = makeApp(completedOnboarding: true, seedLibrary: true)
        app.launch()
        _ = allowFullPhotoLibraryAccessIfNeeded(app: app)

        if app.state != .runningForeground {
            app.activate()
        }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(waitForHomeReady(in: app, language: "zh-Hans", timeout: 30))

        openOrganizeTab(in: app)
        guard let startCleanupButton = waitForFirstExistingButton(
            in: app,
            labels: ["随机整理", "home-random-review"],
            timeout: 30
        ) else {
            XCTFail("Expected a review entry button after seeded library load")
            return
        }
        startCleanupButton.tap()

        if let existingUnfavoriteButton = waitForHittableButton(in: app, label: "取消收藏", timeout: 3) {
            existingUnfavoriteButton.tap()
            XCTAssertTrue(
                app.staticTexts["已取消收藏"].waitForExistence(timeout: 10),
                "Expected test setup favorite mutation to finish"
            )
            XCTAssertNotNil(
                waitForHittableButton(in: app, label: "收藏", timeout: 10),
                "Expected test setup to normalize the current photo to unfavorited"
            )
        }

        guard let favoriteButton = waitForHittableButton(in: app, label: "收藏", timeout: 30) else {
            XCTFail("Expected a favorite button in review")
            return
        }
        favoriteButton.tap()

        guard waitForHittableButton(in: app, label: "取消收藏", timeout: 10) != nil else {
            XCTFail("Expected the favorite button to become an unfavorite button")
            return
        }
        app.buttons["取消收藏"].tap()

        guard waitForHittableButton(in: app, label: "收藏", timeout: 10) != nil else {
            XCTFail("Expected the second favorite tap to remove the favorite")
            return
        }
    }

    @MainActor
    func testSimilarPhotoPreviewCanMarkCurrentAssetForDeletion() throws {
        installPhotoLibraryInterruptionMonitor(allowDeletionConfirmation: true)

        let app = makeApp(completedOnboarding: true, seedLibrary: true, supporterTrialActive: true)
        app.launch()
        _ = allowFullPhotoLibraryAccessIfNeeded(app: app)

        if app.state != .runningForeground {
            app.activate()
        }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !waitForHomeReady(in: app, language: "zh-Hans", timeout: 30) {
            app.terminate()
            app.launch()
            _ = allowFullPhotoLibraryAccessIfNeeded(app: app)
        }
        XCTAssertTrue(waitForHomeReady(in: app, language: "zh-Hans", timeout: 30))

        openAlbumsTab(in: app)
        XCTAssertTrue(app.staticTexts["旅行照片"].waitForExistence(timeout: 60))

        openOrganizeTab(in: app)
        guard let similarPhotosButton = waitForButtonLabelPrefix(
            in: app,
            prefix: "相似与重复",
            timeout: 60,
            excluding: "0 项"
        ) else {
            XCTFail("Expected a non-empty unlocked similar photos cleanup entry")
            return
        }
        similarPhotosButton.tap()

        XCTAssertTrue(app.staticTexts["相似照片"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["严格"].exists)
        XCTAssertFalse(app.buttons["标准"].exists)
        XCTAssertFalse(app.buttons["宽泛"].exists)
        XCTAssertFalse(app.progressIndicators["similar-photo-analysis-progress"].exists)
        XCTAssertTrue(app.buttons["保留首张"].waitForExistence(timeout: 30))

        guard let previewButton = waitForHittableButton(in: app, label: "预览", timeout: 30) else {
            XCTFail("Expected a similar-photo group preview button")
            return
        }
        previewButton.tap()

        let selectionToggleByID = app.descendants(matching: .any)["advanced-preview-delete-selection-toggle"]
        let selectionToggleByLabel = app.descendants(matching: .any)["加入待删除"]
        XCTAssertTrue(
            selectionToggleByID.waitForExistence(timeout: 10) ||
                selectionToggleByLabel.waitForExistence(timeout: 2)
        )
        XCTAssertNotNil(waitForAnyElementLabelContaining(in: app, substring: "1 /", timeout: 5))

        let selectionToggle = selectionToggleByID.exists ? selectionToggleByID : selectionToggleByLabel
        selectionToggle.tap()
        XCTAssertTrue(
            app.staticTexts["已加入待删除"].waitForExistence(timeout: 5) ||
                app.descendants(matching: .any)
                    .matching(NSPredicate(format: "label BEGINSWITH %@", "已加入待删除"))
                    .firstMatch.exists
        )
    }

    private func waitForAnyElementToExist(
        _ elements: [XCUIElement],
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if elements.contains(where: \.exists) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return elements.contains(where: \.exists)
    }

    @MainActor
    func testInlineVideoScrubberDoesNotBlockPlaybackControlsOrCardSwipe() throws {
        installPhotoLibraryInterruptionMonitor(allowDeletionConfirmation: true)

        let app = makeApp(completedOnboarding: true, seedLibrary: true)
        app.launch()
        _ = allowFullPhotoLibraryAccessIfNeeded(app: app)

        if app.state != .runningForeground {
            app.activate()
        }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        if !waitForHomeReady(in: app, language: "zh-Hans", timeout: 30) {
            app.terminate()
            app.launch()
            _ = allowFullPhotoLibraryAccessIfNeeded(app: app)
        }
        XCTAssertTrue(waitForHomeReady(in: app, language: "zh-Hans", timeout: 30))

        openOrganizeTab(in: app)
        guard let videosButton = waitForButtonLabelPrefix(
            in: app,
            prefix: "视频",
            timeout: 30
        ) else {
            XCTFail("Expected a videos entry after seeded library load")
            return
        }
        videosButton.tap()

        let doneButton = firstExistingButton(in: app, labels: ["完成整理", "完成"])
        XCTAssertTrue(doneButton.waitForExistence(timeout: 30))

        let dismissHintButton = app.buttons["知道了"]
        if dismissHintButton.exists, dismissHintButton.isHittable {
            dismissHintButton.tap()
        }

        guard let videoPlayer = waitForInlineVideoPlayer(in: app, timeout: 20) else {
            XCTFail("Expected seeded video to appear in review")
            return
        }

        app.coordinate(withNormalizedOffset: normalizedOffset(for: videoPlayer, dx: 0.5, dy: 0.5, in: app)).tap()
        let playbackButton = app.buttons["video-playback-toggle-button"]
        XCTAssertTrue(playbackButton.waitForExistence(timeout: 5))
        let playButton = app.buttons["播放视频"]
        if playButton.exists, playButton.isHittable {
            playButton.tap()
        }

        let progressSlider = app.sliders["video-playback-slider"]
        XCTAssertTrue(progressSlider.waitForExistence(timeout: 5))
        let scrubStart = progressSlider.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.5))
        let scrubEnd = progressSlider.coordinate(withNormalizedOffset: CGVector(dx: 0.36, dy: 0.5))
        scrubStart.press(forDuration: 0.15, thenDragTo: scrubEnd)
        XCTAssertTrue(
            waitForElementToDisappear(playbackButton, timeout: 5),
            "Playback controls should auto-hide after scrubbing when the video resumes playback."
        )

        let upStart = videoPlayer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
        let upEnd = videoPlayer.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.18))
        upStart.press(forDuration: 0.15, thenDragTo: upEnd)

        let deleteQueued = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "待删除 1 张"),
            object: app.buttons["review-trash-button"]
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [deleteQueued], timeout: 5),
            .completed,
            "Swipe up from the video body should stage it for deletion."
        )
    }

    @MainActor
    func testInlineVideoCanOpenFullPreviewWithPlaybackControls() throws {
        installPhotoLibraryInterruptionMonitor(allowDeletionConfirmation: true)

        let app = makeApp(completedOnboarding: true, seedLibrary: true)
        app.launch()
        _ = allowFullPhotoLibraryAccessIfNeeded(app: app)

        if app.state != .runningForeground {
            app.activate()
        }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(waitForHomeReady(in: app, language: "zh-Hans", timeout: 30))

        openOrganizeTab(in: app)
        guard let videosButton = waitForButtonLabelPrefix(in: app, prefix: "视频", timeout: 30) else {
            XCTFail("Expected a videos entry after seeded library load")
            return
        }
        videosButton.tap()

        let doneButton = firstExistingButton(in: app, labels: ["完成整理", "完成"])
        XCTAssertTrue(doneButton.waitForExistence(timeout: 30))

        let dismissHintButton = app.buttons["知道了"]
        if dismissHintButton.exists, dismissHintButton.isHittable {
            dismissHintButton.tap()
        }

        guard waitForInlineVideoPlayer(in: app, timeout: 20) != nil else {
            XCTFail("Expected seeded video to appear in review")
            return
        }

        let expandButton = app.buttons["video-full-preview-button"]
        XCTAssertTrue(expandButton.waitForExistence(timeout: 8))
        expandButton.tap()

        XCTAssertTrue(app.navigationBars["视频预览"].waitForExistence(timeout: 8))
        let previewPlayer = app.buttons.matching(identifier: "photo-asset-video-player").firstMatch
        XCTAssertTrue(previewPlayer.waitForExistence(timeout: 12))
        previewPlayer.tap()

        let playbackButton = app.buttons.matching(identifier: "video-playback-toggle-button").firstMatch
        XCTAssertTrue(playbackButton.waitForExistence(timeout: 5))
        let progressSlider = app.sliders.matching(identifier: "video-playback-slider").firstMatch
        XCTAssertTrue(progressSlider.waitForExistence(timeout: 5))

        playbackButton.tap()
        let playButton = app.buttons.matching(NSPredicate(format: "label == %@", "播放视频")).firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: 5))
        playButton.tap()

        let scrubStart = progressSlider.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        let scrubEnd = progressSlider.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.5))
        scrubStart.press(forDuration: 0.15, thenDragTo: scrubEnd)

        let closeButton = app.buttons["关闭"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()
        XCTAssertTrue(doneButton.waitForExistence(timeout: 8))
    }

    @MainActor
    func testSettingsTabShowsCoreControls() throws {
        let app = makeApp(completedOnboarding: true)
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        openSettingsTab(in: app)

        XCTAssertTrue(app.staticTexts["偏好设置"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["数据与权限"].exists)
        XCTAssertTrue(app.staticTexts["关于与支持"].exists)
        XCTAssertTrue(app.staticTexts["照片访问权限"].exists)
        XCTAssertTrue(app.staticTexts["触感反馈"].exists)
        XCTAssertTrue(app.staticTexts["给删图评分"].exists)
        XCTAssertTrue(app.staticTexts["邮件反馈"].exists)
        XCTAssertTrue(app.staticTexts["隐私说明"].exists)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["更多 App"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["One Apps Studio"].waitForExistence(timeout: 2))
        let catalogEntry = app.descendants(matching: .any)["settings-oneapps-catalog-entry"]
        if !catalogEntry.waitForExistence(timeout: 1) {
            app.swipeUp()
        }
        XCTAssertTrue(catalogEntry.waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["微信反馈"].exists)
        XCTAssertFalse(app.staticTexts["MVP 教程"].exists)
        XCTAssertFalse(app.staticTexts["创作理念"].exists)
    }

    @MainActor
    func testGestureSettingsShowsHapticFeedbackToggle() throws {
        let app = makeApp(completedOnboarding: true)
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        openSettingsTab(in: app)

        var gestureSettingsButton = waitForHittableButtonLabelContaining(in: app, substring: "手势与播放", timeout: 2)
        for _ in 0..<3 where gestureSettingsButton == nil {
            app.swipeUp()
            gestureSettingsButton = waitForHittableButtonLabelContaining(in: app, substring: "手势与播放", timeout: 2)
        }
        guard let gestureSettingsButton else {
            XCTFail("Expected gesture settings row")
            return
        }
        gestureSettingsButton.tap()

        XCTAssertTrue(app.navigationBars["手势与播放"].waitForExistence(timeout: 3))
        let randomReviewBatchSizeSetting = app.descendants(matching: .any)["random-review-batch-size-setting"]
        XCTAssertTrue(randomReviewBatchSizeSetting.waitForExistence(timeout: 3))
        XCTAssertTrue(String(describing: randomReviewBatchSizeSetting.value).contains("50"))
        var hapticFeedbackTitle = waitForStaticTextLabel(in: app, label: "触感反馈", timeout: 2)
        for _ in 0..<3 where hapticFeedbackTitle == nil {
            app.swipeUp()
            hapticFeedbackTitle = waitForStaticTextLabel(in: app, label: "触感反馈", timeout: 2)
        }
        XCTAssertNotNil(hapticFeedbackTitle)
        XCTAssertTrue(app.staticTexts["滑动、撤销和归类时提供轻微反馈"].exists)
    }

    @MainActor
    func testSettingsKeepsWeChatOutOfFeedbackSectionOutsideSimplifiedChinese() throws {
        let app = makeApp(completedOnboarding: true, appLanguage: "en")
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        openSettingsTab(in: app)

        XCTAssertTrue(app.staticTexts["Preferences"].waitForExistence(timeout: 5))
        // Settings rows expose their title as a button accessibility label.
        for _ in 0..<3 where !app.buttons["Privacy Notes"].isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["Rate OnePhoto"].exists)
        let emailFeedback = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Email Feedback")).firstMatch
        XCTAssertTrue(emailFeedback.isHittable)
        XCTAssertTrue(app.buttons["Privacy Notes"].isHittable)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "微信反馈")).firstMatch.exists)
    }

    @MainActor
    func testAdvancedTabUpdatesAfterLanguageChangeInSettings() throws {
        let app = makeApp(completedOnboarding: true)
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        openSettingsTab(in: app)

        var languageButton = waitForHittableButtonLabelContaining(in: app, substring: "语言", timeout: 2) ??
            waitForHittableButtonLabelContaining(in: app, substring: "Language", timeout: 2)
        for _ in 0..<3 where languageButton == nil {
            app.swipeUp()
            languageButton = waitForHittableButtonLabelContaining(in: app, substring: "语言", timeout: 2) ??
                waitForHittableButtonLabelContaining(in: app, substring: "Language", timeout: 2)
        }
        guard let languageButton else {
            XCTFail("Expected language settings row")
            return
        }
        languageButton.tap()

        guard let englishButton = waitForHittableButton(in: app, label: "English", timeout: 5) else {
            XCTFail("Expected English language option")
            return
        }
        englishButton.tap()

        guard let doneButton = waitForFirstExistingButton(in: app, labels: ["Done", "完成"], timeout: 5) else {
            XCTFail("Expected language settings done button")
            return
        }
        doneButton.tap()

        openOrganizeTab(in: app)

        XCTAssertTrue(app.staticTexts["Special cleanup"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["专项清理"].exists)
    }

    @MainActor
    func testMarketingCaptureLatestUI() throws {
        let environment = ProcessInfo.processInfo.environment
        let captureDirectoryValue = environment["PHOTO_DELETE_MARKETING_CAPTURE_DIR"] ??
            environment["TEST_RUNNER_PHOTO_DELETE_MARKETING_CAPTURE_DIR"]
        guard let captureDirectory = captureDirectoryValue,
              !captureDirectory.isEmpty else {
            throw XCTSkip("Set PHOTO_DELETE_MARKETING_CAPTURE_DIR to export marketing UI captures.")
        }
        let appLanguage = environment["PHOTO_DELETE_MARKETING_APP_LANGUAGE"] ??
            environment["TEST_RUNNER_PHOTO_DELETE_MARKETING_APP_LANGUAGE"] ??
            "zh-Hans"
        let shouldSeedLibrary = (environment["PHOTO_DELETE_MARKETING_SEED_LIBRARY"] ??
            environment["TEST_RUNNER_PHOTO_DELETE_MARKETING_SEED_LIBRARY"] ??
            "1") != "0"

        installPhotoLibraryInterruptionMonitor(allowDeletionConfirmation: true)

        let outputDirectory = URL(fileURLWithPath: captureDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let app = makeApp(
            completedOnboarding: true,
            appLanguage: appLanguage,
            seedLibrary: shouldSeedLibrary,
            supporterTrialActive: true
        )
        app.launch()
        _ = allowFullPhotoLibraryAccessIfNeeded(app: app)
        if !waitForHomeReady(in: app, language: appLanguage, timeout: 30) {
            app.terminate()
            app.launch()
            _ = allowFullPhotoLibraryAccessIfNeeded(app: app)
        }

        XCTAssertTrue(waitForHomeReady(in: app, language: appLanguage, timeout: 30))
        sleep(2)
        dismissMarketingSystemPrompts(app: app, allowDeletionConfirmation: true)
        XCTAssertTrue(waitForHomeReady(in: app, language: appLanguage, timeout: 15))
        try capture("01-home", in: outputDirectory, app: app)

        openAlbumsTab(in: app)
        let expectedAlbumTitle = appLanguage.hasPrefix("en") ? "Travel Photos" : "旅行照片"
        let hasLocalizedSeedAlbum = app.staticTexts[expectedAlbumTitle].waitForExistence(
            timeout: shouldSeedLibrary ? 60 : 5
        )
        if hasLocalizedSeedAlbum {
            try capture("05-albums-real", in: outputDirectory, app: app)
        } else {
            XCTAssertTrue(
                appLanguage.hasPrefix("en") && !shouldSeedLibrary &&
                    app.staticTexts["4 albums"].exists,
                "Expected localized seeded albums or a reusable existing English album capture"
            )
        }

        openOrganizeTab(in: app)
        XCTAssertTrue(waitForHomeReady(in: app, language: appLanguage, timeout: 15))

        let startCleanupButton = firstExistingButton(
            in: app,
            labels: ["随机整理", "home-random-review"]
        )
        XCTAssertTrue(startCleanupButton.waitForExistence(timeout: 10))
        startCleanupButton.tap()

        let doneButton = firstExistingButton(in: app, labels: ["完成整理", "Finish Organizing", "完成", "Done"])
        XCTAssertTrue(doneButton.waitForExistence(timeout: 30))
        sleep(2)
        try capture("02-review-card", in: outputDirectory, app: app)

        dragCardDown(in: app)
        if app.staticTexts["放进哪个相册?"].waitForExistence(timeout: 5) {
            sleep(1)
            try capture("03-album-filing-sheet", in: outputDirectory, app: app)
            app.swipeDown()
        }

        dragCardUp(in: app)

        ensurePendingDeleteCandidateForMarketing(in: app)

        let finishButton = firstExistingButton(in: app, labels: ["完成整理", "Finish Organizing", "完成", "Done"])
        if finishButton.waitForExistence(timeout: 3) {
            finishButton.tap()
            _ = app.staticTexts["确认删除"].waitForExistence(timeout: 5) ||
                app.staticTexts["Confirm Deletion"].waitForExistence(timeout: 5)
            sleep(1)
            try capture("04-finish-or-confirm", in: outputDirectory, app: app)
        }

        let cancelAllActionsButton = firstExistingButton(
            in: app,
            labels: ["取消所有操作", "Cancel All Actions"]
        )
        if cancelAllActionsButton.waitForExistence(timeout: 5) {
            cancelAllActionsButton.tap()
            XCTAssertTrue(waitForElementToDisappear(cancelAllActionsButton, timeout: 5))
        }
        navigateBack(in: app)

        openOrganizeTab(in: app)
        let focusedCleanupTitle = appLanguage.hasPrefix("en") ? "Special cleanup" : "专项清理"
        XCTAssertTrue(app.staticTexts[focusedCleanupTitle].waitForExistence(timeout: 60))
        sleep(3)
        try capture("06-advanced-dashboard", in: outputDirectory, app: app)

        let similarPhotosPrefix = appLanguage.hasPrefix("en") ? "Similar" : "相似与重复"
        guard let similarPhotosButton = waitForButtonLabelPrefix(
            in: app,
            prefix: similarPhotosPrefix,
            timeout: 60,
            excluding: appLanguage.hasPrefix("en") ? "0 items" : "0 项"
        ) else {
            XCTFail("Expected a non-empty similar photos cleanup entry for marketing capture")
            return
        }
        similarPhotosButton.tap()
        let similarPhotosTitle = appLanguage.hasPrefix("en") ? "Similar Photos" : "相似照片"
        XCTAssertTrue(app.staticTexts[similarPhotosTitle].waitForExistence(timeout: 10))
        sleep(2)
        try capture("07-similar-photos", in: outputDirectory, app: app)

        navigateBack(in: app)
        XCTAssertTrue(app.staticTexts[focusedCleanupTitle].waitForExistence(timeout: 10))

        let screenRecordingsPrefix = appLanguage.hasPrefix("en") ? "Screen Recordings" : "录屏"
        guard let screenRecordingsButton = waitForButtonLabelPrefix(
            in: app,
            prefix: screenRecordingsPrefix,
            timeout: 30,
            excluding: appLanguage.hasPrefix("en") ? "0 items" : "0 项"
        ) else {
            XCTFail("Expected a non-empty screen recordings cleanup entry for marketing capture")
            return
        }
        screenRecordingsButton.tap()
        XCTAssertTrue(app.staticTexts[screenRecordingsPrefix].waitForExistence(timeout: 10))
        sleep(2)
        try capture("08-screen-recordings", in: outputDirectory, app: app)
    }

    @MainActor
    func testMarketingCaptureSettingsAndPrivacy() throws {
        let environment = ProcessInfo.processInfo.environment
        let captureDirectoryValue = environment["PHOTO_DELETE_MARKETING_CAPTURE_DIR"] ??
            environment["TEST_RUNNER_PHOTO_DELETE_MARKETING_CAPTURE_DIR"]
        guard let captureDirectory = captureDirectoryValue,
              !captureDirectory.isEmpty else {
            throw XCTSkip("Set PHOTO_DELETE_MARKETING_CAPTURE_DIR to export marketing UI captures.")
        }
        let appLanguage = environment["PHOTO_DELETE_MARKETING_APP_LANGUAGE"] ??
            environment["TEST_RUNNER_PHOTO_DELETE_MARKETING_APP_LANGUAGE"] ??
            "zh-Hans"

        let outputDirectory = URL(fileURLWithPath: captureDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let app = makeApp(
            completedOnboarding: true,
            appLanguage: appLanguage,
            seedLibrary: false,
            supporterTrialActive: true
        )
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        openStatsTab(in: app)
        let statsUsageTitle = appLanguage.hasPrefix("en") ? "Usage stats" : "使用统计"
        let historyTitle = appLanguage.hasPrefix("en") ? "Cleanup History" : "清理历史"
        XCTAssertTrue(app.staticTexts[statsUsageTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[historyTitle].waitForExistence(timeout: 10))
        sleep(2)
        try capture("09-stats", in: outputDirectory, app: app)

        openSettingsTab(in: app)
        let privacyTitle = appLanguage.hasPrefix("en") ? "Privacy Notes" : "隐私说明"
        var privacyButton = waitForHittableButton(in: app, label: privacyTitle, timeout: 2)
        for _ in 0..<5 where privacyButton == nil {
            app.swipeUp()
            privacyButton = waitForHittableButton(in: app, label: privacyTitle, timeout: 2)
        }
        guard let privacyButton else {
            XCTFail("Expected privacy entry for marketing capture")
            return
        }
        privacyButton.tap()
        XCTAssertTrue(app.staticTexts[privacyTitle].waitForExistence(timeout: 10))
        sleep(2)
        try capture("10-privacy", in: outputDirectory, app: app)
    }

    private func makeApp(
        completedOnboarding: Bool,
        appLanguage: String = "zh-Hans",
        seedLibrary: Bool = false,
        supporterTrialActive: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = [
            AppLaunchEnvironmentKey.isUITest: "1",
            AppLaunchEnvironmentKey.appLanguage: appLanguage,
            AppLaunchEnvironmentKey.appAppearance: "light",
            AppLaunchEnvironmentKey.seedLibrary: seedLibrary ? "1" : "0",
            AppLaunchEnvironmentKey.hasCompletedOnboarding: completedOnboarding ? "1" : "0",
            AppLaunchEnvironmentKey.hasSeenIntro: completedOnboarding ? "1" : "0",
            AppLaunchEnvironmentKey.supporterTrialActive: supporterTrialActive ? "1" : "0"
        ]
        if seedLibrary {
            app.launchArguments += ["-photoDeleteRandomReviewHideFiledPhotos", "NO"]
        }
        return app
    }

    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func openStatsTab(in app: XCUIApplication) {
        openOrganizeTab(in: app)
        let homeStats = app.descendants(matching: .any)["home-stats-entry"]
        if homeStats.waitForExistence(timeout: 5), homeStats.isHittable {
            homeStats.tap()
            return
        }
        openSettingsTab(in: app)
        let statsEntry = app.descendants(matching: .any)["settings-stats-entry"]
        for _ in 0..<6 {
            if statsEntry.exists, statsEntry.isHittable {
                statsEntry.tap()
                return
            }
            app.swipeUp()
        }
        _ = tapFirstExistingButton(in: app, labels: ["使用统计", "Usage stats"], timeout: 5)
    }

    @MainActor
    private func openSettingsTab(in app: XCUIApplication) {
        tapTabItem(in: app, labels: ["设置", "Settings"], fallbackOffset: CGVector(dx: 0.88, dy: 0.96))
    }

    @MainActor
    private func openOrganizeTab(in app: XCUIApplication) {
        tapTabItem(in: app, labels: ["整理", "Organize"], fallbackOffset: CGVector(dx: 0.13, dy: 0.96))
    }

    @MainActor
    private func openAdvancedTab(in app: XCUIApplication) {
        tapTabItem(in: app, labels: ["进阶", "Advanced"], fallbackOffset: CGVector(dx: 0.63, dy: 0.96))
    }

    @MainActor
    private func openAlbumsTab(in app: XCUIApplication) {
        returnToTabRootIfNeeded(in: app)
        tapTabItem(in: app, labels: ["相册", "Albums"], fallbackOffset: CGVector(dx: 0.5, dy: 0.96))
    }

    @MainActor
    private func tapTabItem(in app: XCUIApplication, labels: [String], fallbackOffset: CGVector) {
        for label in labels {
            let predicate = NSPredicate(format: "label == %@ OR identifier == %@", label, label)
            let tabBarButton = app.tabBars.buttons.matching(predicate).firstMatch
            if tabBarButton.waitForExistence(timeout: 1), tabBarButton.isHittable {
                tapHittableElement(tabBarButton)
                return
            }
        }

        for label in labels {
            let predicate = NSPredicate(format: "label == %@ OR identifier == %@", label, label)
            let button = app.buttons.matching(predicate).firstMatch
            if button.waitForExistence(timeout: 1), button.isHittable {
                tapHittableElement(button)
                return
            }
        }

        for label in labels {
            let predicate = NSPredicate(format: "label == %@ OR identifier == %@", label, label)
            let element = app.descendants(matching: .any).matching(predicate).firstMatch
            if element.waitForExistence(timeout: 1), element.isHittable {
                tapHittableElement(element)
                return
            }
        }

        app.coordinate(withNormalizedOffset: fallbackOffset).tap()
    }

    @MainActor
    private func returnToTabRootIfNeeded(in app: XCUIApplication) {
        let backButton = app.buttons.matching(
            NSPredicate(format: "label == %@ OR identifier == %@", "向左", "arrow.left")
        ).firstMatch
        guard backButton.waitForExistence(timeout: 1), backButton.isHittable else { return }
        tapHittableElement(backButton)
    }

    @MainActor
    private func navigateBack(in app: XCUIApplication) {
        let navigationBarBackButton = app.navigationBars.buttons.element(boundBy: 0)
        if navigationBarBackButton.waitForExistence(timeout: 2), navigationBarBackButton.isHittable {
            navigationBarBackButton.tap()
            return
        }

        let fallbackBackButton = app.buttons.matching(
            NSPredicate(
                format: "label IN %@ OR identifier IN %@",
                ["返回", "Back", "向左", "arrow.left"],
                ["返回", "Back", "向左", "arrow.left"]
            )
        ).firstMatch
        if fallbackBackButton.waitForExistence(timeout: 2), fallbackBackButton.isHittable {
            fallbackBackButton.tap()
        }
    }

    @MainActor
    private func tapHittableElement(_ element: XCUIElement) {
        element.tap()
    }

    @MainActor
    private func drag(in app: XCUIApplication, from start: CGVector, to end: CGVector) {
        let startCoordinate = app.coordinate(withNormalizedOffset: start)
        let endCoordinate = app.coordinate(withNormalizedOffset: end)
        startCoordinate.press(forDuration: 0.15, thenDragTo: endCoordinate)
    }

    @MainActor
    private func normalizedOffset(for element: XCUIElement, dx: CGFloat, dy: CGFloat, in app: XCUIApplication) -> CGVector {
        let frame = element.frame
        guard app.frame.width > 0, app.frame.height > 0 else {
            return CGVector(dx: dx, dy: dy)
        }
        return CGVector(
            dx: (frame.minX + frame.width * dx) / app.frame.width,
            dy: (frame.minY + frame.height * dy) / app.frame.height
        )
    }

    @MainActor
    private func waitForReviewDoneButton(in app: XCUIApplication, timeout: TimeInterval) -> XCUIElement? {
        let labels = ["完成整理", "Finish Organizing", "完成", "Done"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let button = labels.compactMap({ label -> XCUIElement? in
                let button = app.buttons[label]
                return button.exists && button.isHittable ? button : nil
            }).first {
                return button
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return nil
    }

    @MainActor
    @discardableResult
    private func fileCurrentReviewPhoto(into title: String, in app: XCUIApplication) -> Bool {
        if !app.staticTexts["放进哪个相册?"].exists {
            dragCardDown(in: app)
            guard app.staticTexts["放进哪个相册?"].waitForExistence(timeout: 8) else { return false }
        }

        guard let albumButton = waitForHittableButton(in: app, label: "归类到 \(title)", timeout: 8) else {
            return false
        }
        albumButton.tap()

        let filed = waitForAnyElementLabelContaining(
            in: app,
            substring: "已归类到 \(title)",
            timeout: 6
        ) != nil
        let continueButton = firstExistingButton(in: app, labels: ["完成并继续", "Done and Continue"])
        guard continueButton.waitForExistence(timeout: 5), continueButton.isHittable else { return false }
        continueButton.tap()
        return filed
    }

    @MainActor
    private func dragCardUp(in app: XCUIApplication) {
        if usesWideMarketingLayout(app) {
            drag(in: app, from: CGVector(dx: 0.52, dy: 0.72), to: CGVector(dx: 0.68, dy: 0.28))
        } else {
            drag(in: app, from: CGVector(dx: 0.5, dy: 0.62), to: CGVector(dx: 0.72, dy: 0.22))
        }
    }

    @MainActor
    private func dragCardLeft(in app: XCUIApplication) {
        if usesWideMarketingLayout(app) {
            drag(in: app, from: CGVector(dx: 0.52, dy: 0.58), to: CGVector(dx: 0.16, dy: 0.58))
        } else {
            drag(in: app, from: CGVector(dx: 0.76, dy: 0.48), to: CGVector(dx: 0.18, dy: 0.48))
        }
    }

    @MainActor
    private func dragCardRight(in app: XCUIApplication) {
        if usesWideMarketingLayout(app) {
            drag(in: app, from: CGVector(dx: 0.22, dy: 0.58), to: CGVector(dx: 0.58, dy: 0.58))
        } else {
            drag(in: app, from: CGVector(dx: 0.24, dy: 0.48), to: CGVector(dx: 0.82, dy: 0.48))
        }
    }

    @MainActor
    private func dragCardDown(in app: XCUIApplication) {
        drag(in: app, from: CGVector(dx: 0.5, dy: 0.34), to: CGVector(dx: 0.5, dy: 0.72))
    }

    private func usesWideMarketingLayout(_ app: XCUIApplication) -> Bool {
        app.frame.width >= 800
    }

    @MainActor
    private func ensurePendingDeleteCandidateForMarketing(in app: XCUIApplication) {
        guard usesWideMarketingLayout(app) else { return }

        let deleteButton = firstExistingButton(in: app, labels: ["待删除", "To delete", "删除", "Delete"])
        if deleteButton.waitForExistence(timeout: 2), deleteButton.isHittable {
            deleteButton.tap()
            sleep(1)
        }
    }

    @MainActor
    private func skipLeadingNonMarketingMedia(in app: XCUIApplication) {
        let skipButton = firstExistingButton(in: app, labels: ["跳过", "Skip"])
        guard skipButton.waitForExistence(timeout: 5) else { return }

        for _ in 0..<15 where skipButton.exists && skipButton.isHittable {
            skipButton.tap()
            usleep(140_000)
        }

        sleep(1)
    }

    @MainActor
    private func capture(_ name: String, in directory: URL, app: XCUIApplication) throws {
        dismissMarketingSystemPrompts(app: app)
        let screenshot = XCUIScreen.main.screenshot()
        let outputURL = directory.appendingPathComponent("\(name).png")
        try screenshot.pngRepresentation.write(to: outputURL, options: .atomic)
        add(XCTAttachment(screenshot: screenshot))
    }

    private func firstExistingButton(in app: XCUIApplication, labels: [String]) -> XCUIElement {
        for label in labels {
            let button = app.buttons[label]
            if button.exists { return button }
        }
        return app.buttons[labels[0]]
    }

    @MainActor
    private func waitForHittableButton(in app: XCUIApplication, label: String, timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        let predicate = NSPredicate(format: "label == %@", label)
        while Date() < deadline {
            let buttons = app.buttons.matching(predicate).allElementsBoundByIndex
            if let button = buttons.first(where: { $0.exists && $0.isHittable }) {
                return button
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return nil
    }

    @MainActor
    private func waitForHittableButtonLabelContaining(in app: XCUIApplication, substring: String, timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        let predicate = NSPredicate(format: "label CONTAINS %@", substring)
        while Date() < deadline {
            let buttons = app.buttons.matching(predicate).allElementsBoundByIndex
            if let button = buttons.first(where: { $0.exists && $0.isHittable }) {
                return button
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return nil
    }

    @MainActor
    private func waitForStaticTextLabel(in app: XCUIApplication, label: String, timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        let predicate = NSPredicate(format: "label == %@", label)
        while Date() < deadline {
            let texts = app.staticTexts.matching(predicate).allElementsBoundByIndex
            if let text = texts.first(where: { $0.exists }) {
                return text
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return nil
    }

    @MainActor
    private func waitForStaticTextLabelPrefix(in app: XCUIApplication, prefix: String, timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        let predicate = NSPredicate(format: "label BEGINSWITH %@", prefix)
        while Date() < deadline {
            let texts = app.staticTexts.matching(predicate).allElementsBoundByIndex
            if let text = texts.first(where: { $0.exists }) {
                return text
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return nil
    }

    @MainActor
    private func waitForAnyElementLabelContaining(in app: XCUIApplication, substring: String, timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        let predicate = NSPredicate(format: "label CONTAINS %@", substring)
        while Date() < deadline {
            let elements = app.descendants(matching: .any).matching(predicate).allElementsBoundByIndex
            if let element = elements.first(where: { $0.exists }) {
                return element
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return nil
    }

    @MainActor
    private func waitForButtonLabel(in app: XCUIApplication, label: String, timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        let predicate = NSPredicate(format: "label == %@", label)
        while Date() < deadline {
            let buttons = app.buttons.matching(predicate).allElementsBoundByIndex
            if let button = buttons.first(where: { $0.exists }) {
                return button
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return nil
    }

    @MainActor
    private func waitForButtonLabelPrefix(
        in app: XCUIApplication,
        prefix: String,
        timeout: TimeInterval,
        excluding excludedLabelFragment: String? = nil
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        let predicate = NSPredicate(format: "label BEGINSWITH %@", prefix)
        var swipeAttempts = 0

        while Date() < deadline {
            let buttons = app.buttons.matching(predicate).allElementsBoundByIndex
            if let button = buttons.first(where: { button in
                guard button.exists && button.isHittable else { return false }
                if let excludedLabelFragment {
                    return !button.label.contains(excludedLabelFragment)
                }
                return true
            }) {
                return button
            }

            if swipeAttempts < 4 {
                app.swipeUp()
                swipeAttempts += 1
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }

        return nil
    }

    private func photoCount(fromAlbumRowLabel label: String) -> Int? {
        let pattern = "(\\d+)\\s*张照片"
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: label,
                  range: NSRange(location: 0, length: label.utf16.count)
              ),
              let range = Range(match.range(at: 1), in: label) else {
            return nil
        }
        return Int(label[range])
    }

    @MainActor
    private func waitForInlineVideoPlayer(in app: XCUIApplication, timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        let videoPlayer = app.descendants(matching: .any)["photo-asset-video-player"]
        let skipButton = firstExistingButton(in: app, labels: ["跳过", "Skip"])

        while Date() < deadline {
            if videoPlayer.exists {
                return videoPlayer
            }

            if skipButton.exists, skipButton.isHittable {
                skipButton.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            } else {
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
        }

        return videoPlayer.exists ? videoPlayer : nil
    }

    @MainActor
    private func waitForFirstExistingButton(in app: XCUIApplication, labels: [String], timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for label in labels {
                let button = app.buttons[label]
                if button.exists {
                    return button
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return nil
    }

    @MainActor
    private func waitForAllPhotosReviewEntry(in app: XCUIApplication, timeout: TimeInterval) -> XCUIElement? {
        let identifier = app.descendants(matching: .any)["home-random-review"]
        if identifier.waitForExistence(timeout: timeout), identifier.isHittable {
            return identifier
        }
        return waitForHittableButton(in: app, label: "随机整理", timeout: 2)
    }

    @MainActor
    private func verifyFavoriteToggleRoundTrip(in app: XCUIApplication) -> Bool {
        let wasFavorite = waitForHittableButton(in: app, label: "取消收藏", timeout: 5) != nil

        if wasFavorite {
            guard let unfavoriteButton = waitForHittableButton(in: app, label: "取消收藏", timeout: 5) else {
                return false
            }
            unfavoriteButton.tap()
            guard waitForAnyElementLabelContaining(in: app, substring: "已取消收藏", timeout: 10) != nil else {
                return false
            }
            guard waitForHittableButton(in: app, label: "收藏", timeout: 10) != nil else {
                return false
            }

            guard let restoreFavoriteButton = waitForHittableButton(in: app, label: "收藏", timeout: 5) else {
                return false
            }
            restoreFavoriteButton.tap()
            guard waitForAnyElementLabelContaining(in: app, substring: "已加入收藏", timeout: 10) != nil else {
                return false
            }
            return waitForHittableButton(in: app, label: "取消收藏", timeout: 10) != nil
        }

        guard let favoriteButton = waitForHittableButton(in: app, label: "收藏", timeout: 10) else {
            return false
        }
        favoriteButton.tap()
        guard waitForAnyElementLabelContaining(in: app, substring: "已加入收藏", timeout: 10) != nil else {
            return false
        }
        guard waitForHittableButton(in: app, label: "取消收藏", timeout: 10) != nil else {
            return false
        }

        guard let restoreUnfavoriteButton = waitForHittableButton(in: app, label: "取消收藏", timeout: 5) else {
            return false
        }
        restoreUnfavoriteButton.tap()
        guard waitForAnyElementLabelContaining(in: app, substring: "已取消收藏", timeout: 10) != nil else {
            return false
        }
        return waitForHittableButton(in: app, label: "收藏", timeout: 10) != nil
    }

    @MainActor
    private func allowFullPhotoLibraryAccessIfNeeded(app: XCUIApplication) -> Bool {
        // Permission handling must not tap a library's unrelated Continue button.
        let didInteract = false

        let labels = ["允许完全访问", "允许访问所有照片", "Allow Full Access", "Allow Full Access to Photos"]
        if tapFirstExistingButton(in: app, labels: labels, timeout: 2) {
            sleep(1)
            return true
        }

        let writeLabels = ["允许删除", "Allow Delete Access", "Allow Deletion"]
        if tapFirstExistingButton(in: app, labels: writeLabels, timeout: 2) {
            sleep(1)
            return true
        }

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if tapFirstExistingButton(in: springboard, labels: labels, timeout: 2) {
            sleep(1)
            return true
        }
        if tapFirstExistingButton(in: springboard, labels: writeLabels, timeout: 2) {
            sleep(1)
            return true
        }

        return didInteract
    }

    @MainActor
    private func dismissMarketingSystemPrompts(app: XCUIApplication, allowDeletionConfirmation: Bool = false) {
        var labels = [
            "允许完全访问",
            "允许访问所有照片",
            "允许",
            "允许删除",
            "Allow Full Access",
            "Allow Full Access to Photos",
            "Allow"
        ]
        if allowDeletionConfirmation {
            labels += ["删除", "Delete"]
        }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        for _ in 0..<5 {
            var didTap = tapFirstExistingButton(in: app, labels: labels, timeout: 1)
            didTap = tapFirstExistingButton(in: springboard, labels: labels, timeout: 1) || didTap
            if !didTap { return }
            sleep(1)
        }
    }

    private func installPhotoLibraryInterruptionMonitor(allowDeletionConfirmation: Bool = false) {
        addUIInterruptionMonitor(withDescription: "Photo library access") { alert in
            var labels = [
                "允许完全访问",
                "允许访问所有照片",
                "允许",
                "允许删除",
                "Allow Full Access",
                "Allow Full Access to Photos",
                "Allow"
            ]
            if allowDeletionConfirmation {
                labels += ["删除", "Delete"]
            }
            for label in labels {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }

            var denyLabels = ["不允许", "Don’t Allow", "Don't Allow", "取消", "Cancel"]
            if !allowDeletionConfirmation {
                denyLabels += ["删除", "Delete"]
            }
            for button in alert.buttons.allElementsBoundByIndex {
                let label = button.label
                guard button.exists, !label.isEmpty, !denyLabels.contains(label) else { continue }
                button.tap()
                return true
            }

            return false
        }
    }

    @MainActor
    private func tapFirstExistingButton(in app: XCUIApplication, labels: [String], timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label IN %@ OR identifier IN %@", labels, labels)
        let button = app.buttons.matching(predicate).firstMatch
        if button.waitForExistence(timeout: timeout) {
            button.tap()
            return true
        }
        return false
    }

    @MainActor
    private func waitForHomeReady(in app: XCUIApplication, language: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let labels = language.hasPrefix("en")
            ? ["To review", "Special cleanup", "Random Review", "By time period"]
            : ["待整理", "专项清理", "随机整理", "按时间段开始"]

        while Date() < deadline {
            if app.descendants(matching: .any)["review-photo-card"].exists {
                navigateBack(in: app)
            }
            for label in labels where app.staticTexts[label].exists || app.buttons[label].exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }

        return false
    }

    // TEMP: 底栏 52 + 无遮罩 截图，跑完即删。
    @MainActor
    func testZZZScratchReviewChromeCapture() throws {
        installPhotoLibraryInterruptionMonitor(allowDeletionConfirmation: true)
        let app = makeApp(completedOnboarding: true, appLanguage: "zh-Hans", seedLibrary: true, supporterTrialActive: true)
        app.launch()
        _ = allowFullPhotoLibraryAccessIfNeeded(app: app)
        dismissMarketingSystemPrompts(app: app, allowDeletionConfirmation: true)
        XCTAssertTrue(waitForHomeReady(in: app, language: "zh-Hans", timeout: 30))
        let entry = app.buttons["home-random-review"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertNotNil(waitForReviewDoneButton(in: app, timeout: 30))
        let hint = app.buttons["知道了"]
        if hint.exists, hint.isHittable { hint.tap() }
        sleep(2)
        let dir = URL(fileURLWithPath: "/tmp/pd-measure", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try capture("review", in: dir, app: app)
    }

    @MainActor
    func testZZZScratchAlbumsHeaderCapture() throws {
        installPhotoLibraryInterruptionMonitor(allowDeletionConfirmation: true)
        let app = makeApp(completedOnboarding: true, appLanguage: "zh-Hans", seedLibrary: false, supporterTrialActive: true)
        app.launch()
        _ = allowFullPhotoLibraryAccessIfNeeded(app: app)
        dismissMarketingSystemPrompts(app: app, allowDeletionConfirmation: true)
        XCTAssertTrue(waitForHomeReady(in: app, language: "zh-Hans", timeout: 30))
        openAlbumsTab(in: app)
        sleep(3)
        let dir = URL(fileURLWithPath: "/tmp/pd-albums", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try capture("albums-header", in: dir, app: app)
    }
}

private enum AppLaunchEnvironmentKey {
    static let isUITest = "PHOTO_DELETE_UI_TEST"
    static let appLanguage = "PHOTO_DELETE_UI_TEST_APP_LANGUAGE"
    static let appAppearance = "PHOTO_DELETE_UI_TEST_APP_APPEARANCE"
    static let seedLibrary = "PHOTO_DELETE_UI_TEST_SEED_LIBRARY"
    static let hasCompletedOnboarding = "PHOTO_DELETE_UI_TEST_HAS_COMPLETED_ONBOARDING"
    static let hasSeenIntro = "PHOTO_DELETE_UI_TEST_HAS_SEEN_INTRO"
    static let supporterTrialActive = "PHOTO_DELETE_UI_TEST_SUPPORTER_TRIAL_ACTIVE"
}
