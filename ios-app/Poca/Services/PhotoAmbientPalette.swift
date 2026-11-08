import SwiftUI
import UIKit

/// 照片上/下两个区域的主色，用作整理页的静态氛围底色。
/// 只跟随当前照片变化，不做常驻动画。
struct PhotoAmbientPalette: Equatable {
    let assetID: String
    let top: Color
    let bottom: Color
}

/// 整理页会用到的取色结果。缩略图很小，缓存按 assetID 命中，
/// 反复左右翻页时不会重复遍历像素。
final class PhotoAmbientPaletteCache {
    static let shared = PhotoAmbientPaletteCache()

    private final class Entry {
        let palette: PhotoAmbientPalette
        init(_ palette: PhotoAmbientPalette) { self.palette = palette }
    }

    private let cache = NSCache<NSString, Entry>()

    private init() {
        cache.countLimit = 200
    }

    func palette(for assetID: String) -> PhotoAmbientPalette? {
        cache.object(forKey: assetID as NSString)?.palette
    }

    func store(_ palette: PhotoAmbientPalette) {
        cache.setObject(Entry(palette), forKey: palette.assetID as NSString)
    }
}

enum PhotoAmbientColorExtractor {
    private struct HSL {
        var h: Double
        var s: Double
        var l: Double
    }

    private struct Sample {
        let pixels: [UInt8]
        let width: Int
        let height: Int
    }

    private static let sampleSide = 48

    /// 顶部 46% 和底部 46% 各取一个主色；两端都没有可用的饱和色时返回 nil（背景保持纯黑）。
    static func palette(from image: UIImage, assetID: String) -> PhotoAmbientPalette? {
        guard let sample = samples(from: image) else { return nil }

        let topRows = 0..<max(1, Int(Double(sample.height) * 0.46))
        let bottomRows = min(sample.height - 1, Int(Double(sample.height) * 0.54))..<sample.height

        let top = dominantTone(in: sample, rows: topRows, relaxed: false)
            ?? dominantTone(in: sample, rows: topRows, relaxed: true)
        let bottom = dominantTone(in: sample, rows: bottomRows, relaxed: false)
            ?? dominantTone(in: sample, rows: bottomRows, relaxed: true)

        guard top != nil || bottom != nil else { return nil }
        let resolvedTop = top ?? bottom!
        let resolvedBottom = bottom ?? top!

        return PhotoAmbientPalette(
            assetID: assetID,
            top: glowColor(resolvedTop, lightnessRange: 0.16...0.30),
            bottom: glowColor(resolvedBottom, lightnessRange: 0.12...0.24)
        )
    }

    // MARK: - 采样

    private static func samples(from image: UIImage) -> Sample? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let ratio = image.size.width / image.size.height
        let side = CGFloat(sampleSide)
        let fittedSize: CGSize = if ratio >= 1 {
            CGSize(width: side, height: max(1, side / ratio))
        } else {
            CGSize(width: max(1, side * ratio), height: side)
        }
        let pixelSize = CGSize(
            width: max(1, fittedSize.width.rounded()),
            height: max(1, fittedSize.height.rounded())
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: pixelSize, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: pixelSize))
            // UIImage.draw 会应用 imageOrientation，竖拍照片不会把上下采样成左右。
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
        }

        guard let cgImage = rendered.cgImage else { return nil }
        let width = Int(pixelSize.width)
        let height = Int(pixelSize.height)
        guard width > 0, height > 0 else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Sample(pixels: pixels, width: width, height: height)
    }

    private static func dominantTone(in sample: Sample, rows: Range<Int>, relaxed: Bool) -> HSL? {
        let bucketCount = 1 << 12 // 16 × 16 × 16
        var counts = [Int](repeating: 0, count: bucketCount)
        var cosSums = [Double](repeating: 0, count: bucketCount)
        var sinSums = [Double](repeating: 0, count: bucketCount)
        var satSums = [Double](repeating: 0, count: bucketCount)
        var lightSums = [Double](repeating: 0, count: bucketCount)

        for y in rows {
            let rowStart = y * sample.width * 4
            for x in 0..<sample.width {
                let i = rowStart + x * 4
                let r = Double(sample.pixels[i]) / 255
                let g = Double(sample.pixels[i + 1]) / 255
                let b = Double(sample.pixels[i + 2]) / 255
                let hsl = rgbToHSL(r, g, b)
                if relaxed {
                    // 灰色/近黑/近白一律不参与，避免灰墙给整个页面铺一层灰雾。
                    guard hsl.s >= 0.06, hsl.l >= 0.06, hsl.l <= 0.95 else { continue }
                } else {
                    guard hsl.s >= 0.20, hsl.l >= 0.05, hsl.l <= 0.95 else { continue }
                }

                let key = (Int(sample.pixels[i] >> 4) << 8)
                    | (Int(sample.pixels[i + 1] >> 4) << 4)
                    | Int(sample.pixels[i + 2] >> 4)
                counts[key] += 1
                cosSums[key] += cos(hsl.h * 2 * .pi)
                sinSums[key] += sin(hsl.h * 2 * .pi)
                satSums[key] += hsl.s
                lightSums[key] += hsl.l
            }
        }

        var bestKey = -1
        var bestCount = 0
        var bestSat = 0.0
        for key in 0..<bucketCount where counts[key] > 0 {
            let count = counts[key]
            let meanSat = satSums[key] / Double(count)
            if count > bestCount || (count == bestCount && meanSat > bestSat) {
                bestKey = key
                bestCount = count
                bestSat = meanSat
            }
        }
        guard bestKey >= 0 else { return nil }

        var h = atan2(sinSums[bestKey], cosSums[bestKey]) / (2 * .pi)
        if h < 0 { h += 1 }
        let count = Double(bestCount)
        return HSL(h: h, s: satSums[bestKey] / count, l: lightSums[bestKey] / count)
    }

    // MARK: - 输出颜色

    private static func glowColor(_ hsl: HSL, lightnessRange: ClosedRange<Double>) -> Color {
        let lightness = min(max(hsl.l, lightnessRange.lowerBound), lightnessRange.upperBound)
        let rgb = hslToRGB(HSL(h: hsl.h, s: hsl.s, l: lightness))
        return Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1)
    }

    private static func rgbToHSL(_ r: Double, _ g: Double, _ b: Double) -> HSL {
        let maxValue = max(r, g, b)
        let minValue = min(r, g, b)
        let delta = maxValue - minValue
        let lightness = (maxValue + minValue) / 2
        guard delta > 0 else { return HSL(h: 0, s: 0, l: lightness) }

        let saturation = lightness > 0.5
            ? delta / (2 - maxValue - minValue)
            : delta / (maxValue + minValue)

        let hue: Double
        if maxValue == r {
            hue = (g - b) / delta + (g < b ? 6 : 0)
        } else if maxValue == g {
            hue = (b - r) / delta + 2
        } else {
            hue = (r - g) / delta + 4
        }
        return HSL(h: hue / 6, s: saturation, l: lightness)
    }

    private static func hslToRGB(_ hsl: HSL) -> (r: Double, g: Double, b: Double) {
        let (h, s, l) = (hsl.h, hsl.s, hsl.l)
        func f(_ n: Double) -> Double {
            let k = (n + h * 12).truncatingRemainder(dividingBy: 12)
            let a = s * min(l, 1 - l)
            return l - a * max(-1, min(k - 3, 9 - k, 1))
        }
        return (f(0), f(8), f(4))
    }
}
