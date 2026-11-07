import Foundation
import Photos

/// Picks the Live Photo resource pair used for public size estimation.
struct LivePhotoSizeResourceSelection: Equatable {
    let photoType: PHAssetResourceType?
    let videoType: PHAssetResourceType?

    static func select(types: [PHAssetResourceType]) -> LivePhotoSizeResourceSelection {
        let photo: PHAssetResourceType?
        if types.contains(.fullSizePhoto) {
            photo = .fullSizePhoto
        } else if types.contains(.photo) {
            photo = .photo
        } else {
            photo = nil
        }

        let video: PHAssetResourceType?
        if types.contains(.fullSizePairedVideo) {
            video = .fullSizePairedVideo
        } else if types.contains(.pairedVideo) {
            video = .pairedVideo
        } else {
            video = nil
        }

        return LivePhotoSizeResourceSelection(photoType: photo, videoType: video)
    }

    static func select(from resources: [PHAssetResource]) -> (photo: PHAssetResource?, video: PHAssetResource?) {
        let selection = select(types: resources.map(\.type))
        let photo = selection.photoType.flatMap { type in resources.first { $0.type == type } }
        let video = selection.videoType.flatMap { type in resources.first { $0.type == type } }
        return (photo, video)
    }
}

/// Combines measured Live Photo components into one estimate without private APIs.
enum LivePhotoFileSizeAggregation {
    static func combine(
        photoSizeMB: Double?,
        videoSizeMB: Double?,
        anyComponentInCloud: Bool
    ) -> AssetFileSizeEstimate {
        let parts = [photoSizeMB, videoSizeMB]
            .compactMap { $0 }
            .filter { $0.isFinite && $0 >= 0 }
        if !parts.isEmpty {
            return AssetFileSizeEstimate(
                sizeMB: parts.reduce(0, +),
                source: .assetResource
            )
        }
        return AssetFileSizeEstimate(
            sizeMB: 0,
            source: anyComponentInCloud ? .iCloud : .unavailable
        )
    }
}
