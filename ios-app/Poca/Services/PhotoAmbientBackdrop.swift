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

    /// 固定 sRGB 工作空间：色阶曲线按“屏幕看到的编码值”计算，白点 0.68 就是 0.68，
    /// 不会被线性空间二次转换后变亮或变暗。
    private static let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let context = CIContext(options: [
        .workingColorSpace: outputColorSpace,
        .outputColorSpace: outputColorSpace
    ])

    /// 先把方向应用到缩略图，再做低分辨率高斯模糊；放大后自然成为柔和色场。
    static func make(from image: UIImage) -> UIImage? {
        guard let sample = normalizedSample(from: image),
              let source = CIImage(image: sample) else { return nil }

        let blurred = source
            .clampedToExtent()
            .applyingGaussianBlur(sigma: blurSigma)
            .cropped(to: source.extent)
        guard let cgImage = context.createCGImage(
            blurred,
            from: source.extent,
            format: .RGBA8,
            colorSpace: outputColorSpace
        ) else { return nil }
        guard let toned = applyHighlightRolloff(to: cgImage) else { return nil }
        return UIImage(cgImage: toned)
    }

    /// 保留中间调，只把高光滚降：白点压到 0.68，白色/冰雪照片不会在背景上发亮刺眼。
    /// 这是明度处理，不是色相偏移——转色相只会让白色发脏。
    ///
    /// 直接在 sRGB 编码值上做逐通道查表，避免 Core Image 色彩空间转换把曲线结果二次线性化。
    private static func applyHighlightRolloff(to cgImage: CGImage) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: outputColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var lookup = [UInt8](repeating: 0, count: 256)
        for index in 0..<256 {
            let value = Double(index) / 255
            let mapped = value * (1 - 0.32 * value * value)
            lookup[index] = UInt8((mapped * 255).rounded())
        }

        for index in stride(from: 0, to: pixels.count, by: 4) {
            pixels[index] = lookup[Int(pixels[index])]
            pixels[index + 1] = lookup[Int(pixels[index + 1])]
            pixels[index + 2] = lookup[Int(pixels[index + 2])]
        }

        return context.makeImage()
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
