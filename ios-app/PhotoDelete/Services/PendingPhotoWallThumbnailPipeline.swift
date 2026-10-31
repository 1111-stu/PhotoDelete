//
//  PendingPhotoWallThumbnailPipeline.swift
//  PhotoDelete
//
//  待整理照片墙专用的缩略图管线：资产查找、小图缓存、按显示顺序预取都收在这里。
//  墙面只负责布局和点击，不再逐格查库、逐格发重请求。
//

import Photos
import UIKit

/// 墙面缩略图清晰度：日历格小图优先快，相纸板要看清照片内容。
enum PendingPhotoWallThumbnailQuality: Equatable {
    case fast
    case sharp

    var cacheToken: String {
        switch self {
        case .fast: return "fast"
        case .sharp: return "sharp"
        }
    }

    var requestOptions: PHImageRequestOptions {
        let options = PHImageRequestOptions()
        switch self {
        case .fast:
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
        case .sharp:
            // fastFormat 可能直接返回缓存里更小的缩略图，放大到相纸尺寸会糊。
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
        }
        // 墙面只读本地小图；iCloud 原图留给详情/整理页。
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false
        return options
    }
}

@MainActor
final class PendingPhotoWallThumbnailPipeline: ObservableObject {
    /// 一年墙面最多约 366 张封面；按小图成本估算，600 张 / 48MB 足够覆盖一次完整浏览。
    private static let cacheCountLimit = 600
    private static let cacheCostLimit = 48 * 1024 * 1024
    private static let prefetchBatchSize = 24
    private static let prefetchBatchInterval: Duration = .milliseconds(40)

    private let imageManager = PHCachingImageManager()
    private let imageCache = NSCache<NSString, UIImage>()

    private var assetsByID: [String: PHAsset] = [:]
    private var prefetchAssetIDs: [String] = []
    private var prefetchTargetSize: CGSize = .zero
    private var prefetchTask: Task<Void, Never>?
    private var cachedAssets: [PHAsset] = []
    private var cachedTargetSize: CGSize = .zero

    init() {
        imageCache.countLimit = Self.cacheCountLimit
        imageCache.totalCostLimit = Self.cacheCostLimit
    }

    // MARK: - 资产索引

    /// 由墙面快照的封面集合构建，避免每格 `PHAsset.fetchAssets` 占用主线程。
    func updateAssets(_ assetsByID: [String: PHAsset]) {
        self.assetsByID = assetsByID
    }

    // MARK: - 单格加载

    func cachedImage(
        for assetID: String,
        targetSize: CGSize,
        quality: PendingPhotoWallThumbnailQuality = .fast
    ) -> UIImage? {
        imageCache.object(forKey: cacheKey(for: assetID, targetSize: targetSize, quality: quality))
    }

    @discardableResult
    func load(
        assetID: String,
        targetSize: CGSize,
        quality: PendingPhotoWallThumbnailQuality = .fast,
        completion: @escaping (UIImage?) -> Void
    ) -> PHImageRequestID? {
        let key = cacheKey(for: assetID, targetSize: targetSize, quality: quality)
        if let cached = imageCache.object(forKey: key) {
            completion(cached)
            return nil
        }
        guard let asset = assetsByID[assetID] else {
            completion(nil)
            return nil
        }

        return imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: quality.requestOptions
        ) { [weak self] image, info in
            DispatchQueue.main.async {
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) == true
                guard !isCancelled else { return }
                if let image {
                    self?.imageCache.setObject(
                        image,
                        forKey: key,
                        cost: Self.cacheCost(for: image)
                    )
                }
                completion(image)
            }
        }
    }

    func cancel(_ requestID: PHImageRequestID?) {
        guard let requestID else { return }
        imageManager.cancelImageRequest(requestID)
    }

    // MARK: - 预取

    /// `assetIDs` 按墙面显示顺序传入：先热首屏附近，再分批补后面的月份。
    func prefetch(assetIDs: [String], targetSize: CGSize) {
        guard targetSize.width > 1, !assetIDs.isEmpty else {
            stopPrefetch()
            return
        }
        guard assetIDs != prefetchAssetIDs || targetSize != prefetchTargetSize else { return }

        let assets = assetIDs.compactMap { assetsByID[$0] }
        guard !assets.isEmpty else { return }

        prefetchAssetIDs = assetIDs
        prefetchTargetSize = targetSize
        prefetchTask?.cancel()
        stopCachedImages()

        cachedTargetSize = targetSize
        prefetchTask = Task { [weak self] in
            guard let self else { return }
            var index = 0
            while index < assets.count, !Task.isCancelled {
                let end = min(index + Self.prefetchBatchSize, assets.count)
                let batch = Array(assets[index..<end])
                imageManager.startCachingImages(
                    for: batch,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: PendingPhotoWallThumbnailQuality.fast.requestOptions
                )
                cachedAssets.append(contentsOf: batch)
                index = end
                try? await Task.sleep(for: Self.prefetchBatchInterval)
            }
        }
    }

    /// 离开墙面或切换年份时停掉后台预取，但保留已解码的小图缓存供返回时复用。
    func stopPrefetch() {
        prefetchTask?.cancel()
        prefetchTask = nil
        prefetchAssetIDs = []
        prefetchTargetSize = .zero
        stopCachedImages()
    }

    // MARK: - 私有

    private func stopCachedImages() {
        guard !cachedAssets.isEmpty else { return }
        imageManager.stopCachingImages(
            for: cachedAssets,
            targetSize: cachedTargetSize,
            contentMode: .aspectFill,
            options: PendingPhotoWallThumbnailQuality.fast.requestOptions
        )
        cachedAssets.removeAll(keepingCapacity: true)
        cachedTargetSize = .zero
    }

    private func cacheKey(
        for assetID: String,
        targetSize: CGSize,
        quality: PendingPhotoWallThumbnailQuality
    ) -> NSString {
        let modifiedAt = Int(
            (assetsByID[assetID]?.modificationDate ?? .distantPast).timeIntervalSinceReferenceDate
        )
        return "wall_\(quality.cacheToken)_\(assetID)_\(modifiedAt)_\(Int(targetSize.width))x\(Int(targetSize.height))" as NSString
    }

    private static func cacheCost(for image: UIImage) -> Int {
        let cgImage = image.cgImage
        guard let cgImage else {
            return Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        }
        return cgImage.bytesPerRow * cgImage.height
    }
}
