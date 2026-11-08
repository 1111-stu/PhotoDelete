import CoreImage
import SwiftUI
import UIKit

/// 整理页的氛围背景：当前照片的低分辨率模糊副本，放大铺满全屏。
/// 保留照片自身的空间色分布（顶部亮、底部暗），多色但来源一致。
struct PhotoAmbientBackdrop {
    let assetID: String
    let image: UIImage
}

final class PhotoAmbientBackdropCache {
    static let shared = PhotoAmbientBackdropCache()

    private final class Entry {
        let image: UIImage
        init(_ image: UIImage) { self.image = image }
    }

    private let cache = NSCache<NSString, Entry>()

    private init() {
        cache.countLimit = 200
    }

    func backdrop(for assetID: String) -> PhotoAmbientBackdrop? {
        guard let image = cache.object(forKey: assetID as NSString)?.image else { return nil }
        return PhotoAmbientBackdrop(assetID: assetID, image: image)
    }

    func store(_ backdrop: PhotoAmbientBackdrop) {
        cache.setObject(Entry(backdrop.image), forKey: backdrop.assetID as NSString)
    }
}

enum PhotoAmbientBackdropRenderer {
    /// 长边 64px 足够表达大色块；再大只是浪费放大后的模糊开销。
    private static let sampleSide: CGFloat = 64
    private static let blurSigma: Double = 8

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// 先把方向应用到缩略图，再做低分辨率高斯模糊；放大后自然成为柔和色场。
    static func make(from image: UIImage) -> UIImage? {
        guard let sample = normalizedSample(from: image),
              let source = CIImage(image: sample) else { return nil }

        let blurred = source
            .clampedToExtent()
            .applyingGaussianBlur(sigma: blurSigma)
            .cropped(to: source.extent)
        guard let cgImage = context.createCGImage(blurred, from: source.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func normalizedSample(from image: UIImage) -> UIImage? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let ratio = image.size.width / image.size.height
        let side = sampleSide
        let size: CGSize = ratio >= 1
            ? CGSize(width: side, height: max(1, side / ratio))
            : CGSize(width: max(1, side * ratio), height: side)
        let pixelSize = CGSize(
            width: max(1, size.width.rounded()),
            height: max(1, size.height.rounded())
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: pixelSize, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: pixelSize))
            // UIImage.draw 会应用 imageOrientation，竖拍照片不会被转成横构图。
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
        }
    }
}
