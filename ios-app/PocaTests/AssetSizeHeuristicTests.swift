import Photos
import Testing
@testable import Poca

struct AssetSizeHeuristicTests {
    @Test func imageEstimateHasMinimumFloor() {
        #expect(AssetSizeHeuristic.estimateMB(mediaType: .image, pixelWidth: 1, pixelHeight: 1) == 0.8)
    }

    @Test func imageEstimateScalesWithMegapixels() {
        let expected = 4032.0 * 3024.0 / 1_000_000 * 0.55
        let estimate = AssetSizeHeuristic.estimateMB(mediaType: .image, pixelWidth: 4032, pixelHeight: 3024)
        #expect(abs(estimate - expected) < 0.0001)
    }

    @Test func videoEstimateUsesDurationAndClampedBitrate() {
        let megapixels = 1920.0 * 1080.0 / 1_000_000
        let bitrateMbps = min(max(megapixels * 4.2, 2.4), 48)
        let expected = 10.0 * bitrateMbps / 8
        let estimate = AssetSizeHeuristic.estimateMB(
            mediaType: .video,
            pixelWidth: 1920,
            pixelHeight: 1080,
            duration: 10
        )
        #expect(abs(estimate - expected) < 0.0001)
    }

    @Test func videoEstimateHasMinimumFloor() {
        #expect(AssetSizeHeuristic.estimateMB(mediaType: .video, pixelWidth: 1, pixelHeight: 1) == 1.5)
    }

    @Test func livePhotoAddsMotionComponentToStill() {
        let still = AssetSizeHeuristic.estimateMB(mediaType: .image, pixelWidth: 4032, pixelHeight: 3024)
        let live = AssetSizeHeuristic.estimateMB(
            mediaType: .image,
            pixelWidth: 4032,
            pixelHeight: 3024,
            isLivePhoto: true
        )
        #expect(abs(live - (still + AssetSizeHeuristic.livePhotoMotionMB)) < 0.0001)
    }

    @Test func livePhotoTakesPrecedenceOverScreenshotFlag() {
        let live = AssetSizeHeuristic.estimateMB(
            mediaType: .image,
            pixelWidth: 1290,
            pixelHeight: 2796,
            isLivePhoto: true,
            isScreenshot: true
        )
        let expected = AssetSizeHeuristic.imageEstimateMB(pixelWidth: 1290, pixelHeight: 2796) +
            AssetSizeHeuristic.livePhotoMotionMB
        #expect(abs(live - expected) < 0.0001)
    }

    @Test func screenshotUsesItsOwnScale() {
        let screenshot = AssetSizeHeuristic.estimateMB(
            mediaType: .image,
            pixelWidth: 1290,
            pixelHeight: 2796,
            isScreenshot: true
        )
        let expected = AssetSizeHeuristic.imageEstimateMB(pixelWidth: 1290, pixelHeight: 2796) *
            AssetSizeHeuristic.screenshotScale
        #expect(abs(screenshot - expected) < 0.0001)
    }

    @Test func summaryTotalAddsAllCategories() {
        let summary = SpecialCleanupSizeSummary(screenshotsMB: 120, livePhotosMB: 80, videosMB: 400)
        #expect(summary.totalMB == 600)
    }
}
