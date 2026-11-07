import Foundation
import Photos
import Testing
@testable import PhotoDelete

struct LivePhotoFileSizeEstimateTests {
    @Test func selectsEditedLivePhotoResourcesWhenPresent() {
        let selection = LivePhotoSizeResourceSelection.select(types: [
            .photo,
            .pairedVideo,
            .fullSizePhoto,
            .fullSizePairedVideo,
            .adjustmentData
        ])
        #expect(selection.photoType == .fullSizePhoto)
        #expect(selection.videoType == .fullSizePairedVideo)
    }

    @Test func fallsBackToOriginalLivePhotoResources() {
        let selection = LivePhotoSizeResourceSelection.select(types: [
            .photo,
            .pairedVideo
        ])
        #expect(selection.photoType == .photo)
        #expect(selection.videoType == .pairedVideo)
    }

    @Test func toleratesMissingPairedVideoComponent() {
        let selection = LivePhotoSizeResourceSelection.select(types: [.photo])
        #expect(selection.photoType == .photo)
        #expect(selection.videoType == nil)
    }

    @Test func sumsStillAndMotionComponents() {
        let estimate = LivePhotoFileSizeAggregation.combine(
            photoSizeMB: 2.5,
            videoSizeMB: 4.0,
            anyComponentInCloud: false
        )
        #expect(estimate.source == .assetResource)
        #expect(estimate.sizeMB == 6.5)
        #expect(estimate.isReliable)
    }

    @Test func keepsPartialComponentWhenOtherMissing() {
        let photoOnly = LivePhotoFileSizeAggregation.combine(
            photoSizeMB: 1.25,
            videoSizeMB: nil,
            anyComponentInCloud: true
        )
        #expect(photoOnly.source == .assetResource)
        #expect(photoOnly.sizeMB == 1.25)

        let videoOnly = LivePhotoFileSizeAggregation.combine(
            photoSizeMB: nil,
            videoSizeMB: 3.0,
            anyComponentInCloud: false
        )
        #expect(videoOnly.source == .assetResource)
        #expect(videoOnly.sizeMB == 3.0)
    }

    @Test func marksUnavailableOrICloudWhenNoComponentMeasured() {
        let unavailable = LivePhotoFileSizeAggregation.combine(
            photoSizeMB: nil,
            videoSizeMB: nil,
            anyComponentInCloud: false
        )
        #expect(unavailable.source == .unavailable)
        #expect(!unavailable.isReliable)

        let cloud = LivePhotoFileSizeAggregation.combine(
            photoSizeMB: nil,
            videoSizeMB: nil,
            anyComponentInCloud: true
        )
        #expect(cloud.source == .iCloud)
        #expect(!cloud.isReliable)
    }

    @Test func ignoresNonFiniteComponentSizes() {
        let estimate = LivePhotoFileSizeAggregation.combine(
            photoSizeMB: .infinity,
            videoSizeMB: 2.0,
            anyComponentInCloud: false
        )
        #expect(estimate.source == .assetResource)
        #expect(estimate.sizeMB == 2.0)
    }
}
