import CoreGraphics
import Foundation
import SwiftUI
import UIKit

enum ShareCardTemplate: String, CaseIterable, Identifiable {
    case minimalFrame
    case ticketStub
    case colorwork
    case original

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimalFrame: return L10n.string("Minimal Frame")
        case .ticketStub: return L10n.string("Ticket Stub")
        case .colorwork: return L10n.string("Colorwork")
        case .original: return L10n.string("Original Photo")
        }
    }

    var designSize: CGSize {
        switch self {
        case .minimalFrame: return CGSize(width: 1200, height: 1840)
        case .ticketStub, .colorwork: return CGSize(width: 1200, height: 1600)
        case .original: return .zero
        }
    }

    var showsCardChrome: Bool {
        self != .original
    }

    static func normalized(_ raw: String?) -> ShareCardTemplate {
        ShareCardTemplate(rawValue: raw ?? "") ?? .minimalFrame
    }
}

struct ShareCardTicketPalette: Identifiable, Equatable, Hashable {
    let id: String
    let nameKey: String
    let mat: Color
    let stub: Color

    var name: String { L10n.key(nameKey) }

    static let all: [ShareCardTicketPalette] = [
        .init(id: "clay", nameKey: "Clay", mat: Color(hex: 0x855143), stub: Color(hex: 0xB87D6D)),
        .init(id: "wine", nameKey: "Wine", mat: Color(hex: 0x6B3A42), stub: Color(hex: 0x9A646C)),
        .init(id: "ochre", nameKey: "Ochre", mat: Color(hex: 0x8A6A32), stub: Color(hex: 0xB8945A)),
        .init(id: "olive", nameKey: "Olive", mat: Color(hex: 0x4A5232), stub: Color(hex: 0x7A8258)),
        .init(id: "forest", nameKey: "Forest", mat: Color(hex: 0x2F4A3C), stub: Color(hex: 0x5A7A68)),
        .init(id: "ink", nameKey: "Ink Blue", mat: Color(hex: 0x2C3A4A), stub: Color(hex: 0x5A6E82)),
        .init(id: "slate", nameKey: "Slate", mat: Color(hex: 0x4A4A52), stub: Color(hex: 0x7A7A84)),
        .init(id: "dust", nameKey: "Dust Rose", mat: Color(hex: 0x7A5558), stub: Color(hex: 0xA8888A)),
    ]

    static let `default` = all[0]

    static func normalized(_ raw: String?) -> ShareCardTicketPalette {
        all.first(where: { $0.id == raw }) ?? .default
    }
}

struct ShareCardMeta: Equatable {
    var hasDate: Bool
    var hasLocation: Bool
    var showDate: Bool
    var showLocation: Bool
    var dateFull: String
    var dateYear: String
    var dateMonthDay: String
    var location: String
    var signature: String
    var barcodeSeed: String
    var colorworkTitle: String
    var blockColor: Color

    var displaysDate: Bool { hasDate && showDate }
    var displaysLocation: Bool { hasLocation && showLocation }

    /// 票根站名：地点 → 日期 → 品牌签名。
    var ticketStationName: String {
        if displaysLocation { return location }
        if displaysDate { return "\(dateYear).\(dateMonthDay)" }
        return signature
    }

    var ticketShowsDateColumns: Bool {
        displaysDate && displaysLocation
    }

    static func make(
        creationDate: Date?,
        locationTitle: String?,
        barcodeSeed: String,
        showDate: Bool,
        showLocation: Bool,
        blockColor: Color = ShareCardColorExtraction.fallbackBlock
    ) -> ShareCardMeta {
        let hasDate = creationDate != nil
        let hasLocation = !(locationTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let date = creationDate ?? Date()
        return ShareCardMeta(
            hasDate: hasDate,
            hasLocation: hasLocation,
            showDate: showDate,
            showLocation: showLocation,
            dateFull: AppDateFormatter.string(from: date, template: "yMMMd"),
            dateYear: AppDateFormatter.string(from: date, template: "yyyy"),
            dateMonthDay: AppDateFormatter.string(from: date, template: "MM.dd"),
            location: locationTitle ?? "",
            signature: L10n.string("See You Again"),
            barcodeSeed: barcodeSeed,
            colorworkTitle: "Color Walk",
            blockColor: blockColor
        )
    }
}

enum ShareCardColorExtraction {
    static let fallbackBlock = Color(hex: 0x314B01)

    static func blockColor(from image: UIImage?) -> Color {
        guard let image, let cgImage = image.cgImage else { return fallbackBlock }
        let n = 32
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: n * n * 4)
        guard let ctx = CGContext(
            data: &pixels,
            width: n,
            height: n,
            bitsPerComponent: 8,
            bytesPerRow: n * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return fallbackBlock
        }
        ctx.interpolationQuality = .low
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: n, height: n))

        var sx = 0.0, sy = 0.0, sw = 0.0, sl = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[i]) / 255
            let g = Double(pixels[i + 1]) / 255
            let b = Double(pixels[i + 2]) / 255
            let hsl = rgbToHSL(r, g, b)
            let w = hsl.s * hsl.s + 1e-4
            sx += cos(hsl.h * 2 * .pi) * w
            sy += sin(hsl.h * 2 * .pi) * w
            sl += hsl.l * w
            sw += w
        }
        guard sw > 0 else { return fallbackBlock }
        var h = atan2(sy, sx) / (2 * .pi)
        if h < 0 { h += 1 }
        return Color(hsl: (h, 0.75, 0.19))
    }

    private static func rgbToHSL(_ r: Double, _ g: Double, _ b: Double) -> (h: Double, s: Double, l: Double) {
        let maxV = max(r, g, b)
        let minV = min(r, g, b)
        let l = (maxV + minV) / 2
        if maxV == minV { return (0, 0, l) }
        let d = maxV - minV
        let s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
        var h: Double
        if maxV == r {
            h = (g - b) / d + (g < b ? 6 : 0)
        } else if maxV == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        return (h / 6, s, l)
    }
}

private extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    init(hsl: (h: Double, s: Double, l: Double)) {
        let (h, s, l) = hsl
        func f(_ n: Double) -> Double {
            let k = (n + h * 12).truncatingRemainder(dividingBy: 12)
            let a = s * min(l, 1 - l)
            return l - a * max(-1, min(k - 3, 9 - k, 1))
        }
        self.init(.sRGB, red: f(0), green: f(8), blue: f(4), opacity: 1)
    }
}
