import Foundation
import Photos

/// Metadata-only size estimates shared by period summaries and cleanup queues.
///
/// This path never reads asset resources: every input already lives on `PHAsset`.
/// Exact sizes stay in `AssetSizeLoader` / the asset browser.
enum AssetSizeHeuristic {
    /// Live Photos carry a paired motion clip that metadata cannot size.
    /// Metadata-only estimates add this component so live photos are not
    /// mistaken for stills; tune after comparing against exact browser totals.
    static let livePhotoMotionMB: Double = 3.0

    /// Screenshots mix PNG and HEIC; keep one knob instead of scattering factors.
    static let screenshotScale: Double = 1.0

    static func estimateMB(for asset: PHAsset) -> Double {
        estimateMB(
            mediaType: asset.mediaType,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            duration: asset.duration,
            isLivePhoto: asset.mediaSubtypes.contains(.photoLive),
            isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot)
        )
    }

    static func estimateMB(
        mediaType: PHAssetMediaType,
        pixelWidth: Int,
        pixelHeight: Int,
        duration: TimeInterval = 0,
        isLivePhoto: Bool = false,
        isScreenshot: Bool = false
    ) -> Double {
        if mediaType == .video {
            return videoEstimateMB(pixelWidth: pixelWidth, pixelHeight: pixelHeight, duration: duration)
        }

        let stillMB = imageEstimateMB(pixelWidth: pixelWidth, pixelHeight: pixelHeight)
        if isLivePhoto {
            return stillMB + livePhotoMotionMB
        }
        if isScreenshot {
            return stillMB * screenshotScale
        }
        return stillMB
    }

    static func imageEstimateMB(pixelWidth: Int, pixelHeight: Int) -> Double {
        let megapixels = Double(pixelWidth) * Double(pixelHeight) / 1_000_000
        return max(megapixels * 0.55, 0.8)
    }

    static func videoEstimateMB(pixelWidth: Int, pixelHeight: Int, duration: TimeInterval) -> Double {
        let megapixels = Double(pixelWidth) * Double(pixelHeight) / 1_000_000
        let seconds = max(duration, 1)
        let bitrateMbps = min(max(megapixels * 4.2, 2.4), 48)
        return max(seconds * bitrateMbps / 8, 1.5)
    }
}
