import CoreImage
import SwiftUI
import UIKit

/// 设计坐标下的分享卡；预览用 scaleEffect，出图用 ImageRenderer 同树直出。
struct ShareCardView: View {
    let template: ShareCardTemplate
    let photo: UIImage?
    let meta: ShareCardMeta
    var palette: ShareCardTicketPalette = .default

    var body: some View {
        switch template {
        case .minimalFrame:
            MinimalFrameCard(photo: photo, meta: meta)
                .frame(width: 1200, height: 1840)
        case .ticketStub:
            TicketStubCard(photo: photo, meta: meta, palette: palette)
                .frame(width: 1200, height: 1600)
        case .colorwork:
            ColorworkCard(photo: photo, meta: meta)
                .frame(width: 1200, height: 1600)
        case .original:
            EmptyView()
        }
    }
}

// MARK: - A · 极简相框

private struct MinimalFrameCard: View {
    let photo: UIImage?
    let meta: ShareCardMeta

    private let paper = Color(red: 244 / 255, green: 245 / 255, blue: 247 / 255)
    private let ink = Color(red: 13 / 255, green: 14 / 255, blue: 16 / 255)
    private let muted = Color(red: 106 / 255, green: 106 / 255, blue: 112 / 255)

    var body: some View {
        ZStack(alignment: .topLeading) {
            paper

            photoLayer
                .frame(width: 1116, height: 1488)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .offset(x: 42, y: 42)

            metaBlock
                .padding(.leading, 68)
                .padding(.trailing, 68)
                .padding(.bottom, 88)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }

    @ViewBuilder
    private var photoLayer: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: 1116, height: 1488)
                .clipped()
        } else {
            Color(white: 0.12)
        }
    }

    private var metaBlock: some View {
        let showLoc = meta.displaysLocation
        let showDate = meta.displaysDate
        let hasPrimary = showLoc || showDate

        return VStack(alignment: .leading, spacing: 0) {
            if showDate && showLoc {
                Text(meta.dateFull)
                    .font(.system(size: 34, weight: .regular))
                    .tracking(0.2)
                    .foregroundStyle(muted)
                    .padding(.bottom, 30)
            }

            HStack(alignment: .firstTextBaseline, spacing: 24) {
                if showLoc {
                    primaryLine(meta.location, size: 48)
                } else if showDate {
                    // 日期单独成行时退为灰字说明，品牌成为版面的锚点。
                    primaryLine(
                        meta.dateFull,
                        size: 44,
                        color: muted,
                        weight: .regular
                    )
                } else {
                    Spacer(minLength: 0)
                }

                if hasPrimary {
                    Spacer(minLength: 8)
                }

                Text(meta.signature)
                    .font(.system(size: 46, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(ink)
            }
        }
    }

    private func primaryLine(
        _ text: String,
        size: CGFloat,
        color: Color? = nil,
        weight: Font.Weight = .semibold
    ) -> some View {
        Text(text)
            .font(.system(size: size, weight: weight))
            .tracking(-0.5)
            .foregroundStyle(color ?? ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - B · 邮票票根

private struct TicketStubCard: View {
    let photo: UIImage?
    let meta: ShareCardMeta
    let palette: ShareCardTicketPalette

    private let ticketInk = Color(red: 22 / 255, green: 17 / 255, blue: 15 / 255)
    private let ticketW: CGFloat = 681
    private let ticketH: CGFloat = 1151
    private let seamY: CGFloat = 876

    var body: some View {
        ZStack {
            palette.mat

            ticketBody
                .frame(width: ticketW, height: ticketH)
        }
        .overlay(alignment: .bottomTrailing) {
            // 整张卡的右下角落款；站名回落成品牌时隐藏，避免同一张卡出现两次 Poca。
            if meta.displaysDate || meta.displaysLocation {
                Text(meta.signature)
                    .font(.custom("SnellRoundhand", size: 44))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.trailing, 68)
                    .padding(.bottom, 72)
            }
        }
    }

    private var ticketBody: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(Color.white)

            photoLayer
                .frame(width: 639, height: 826)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .offset(x: 21, y: 21)

            stubBand
                .frame(width: ticketW, height: ticketH - seamY)
                .offset(y: seamY)

            // 撕票虚线
            Path { path in
                path.move(to: CGPoint(x: 0, y: seamY))
                path.addLine(to: CGPoint(x: ticketW, y: seamY))
            }
            .stroke(
                Color.black.opacity(0.5),
                style: StrokeStyle(lineWidth: 2.5, dash: [7, 5])
            )

            // 打孔（叠 mat 色圆盖住票边）
            Circle()
                .fill(palette.mat)
                .frame(width: 40, height: 40)
                .position(x: 0, y: seamY)
            Circle()
                .fill(palette.mat)
                .frame(width: 40, height: 40)
                .position(x: ticketW, y: seamY)

            barcodePlate
                .frame(width: 107, height: 235)
                .offset(x: ticketW - 63 - 107, y: 898)
        }
        .frame(width: ticketW, height: ticketH)
        .clipShape(TicketStubMask(seamY: seamY, notchRadius: 20), style: FillStyle(eoFill: true))
    }

    @ViewBuilder
    private var photoLayer: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: 639, height: 826)
                .clipped()
        } else {
            Color(white: 0.9)
        }
    }

    private var stubBand: some View {
        // kicker + 站名作为一个组，在点线上方（或整条票根）垂直居中；
        // 组随行数自然上下移动，不会出现 kicker 留在顶部、站名单独下沉的断层。
        let showsColumns = meta.ticketShowsDateColumns
        // Barcode plate left edge = ticketW - 63 - 107; keep ~20pt air gap.
        let textMaxWidth: CGFloat = ticketW - 58 - (63 + 107 + 20)

        return ZStack(alignment: .topLeading) {
            palette.stub

            stationGroup
                .frame(
                    width: textMaxWidth,
                    height: showsColumns ? 182 : 275,
                    alignment: .leading
                )
                .padding(.leading, 58)

            if showsColumns {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 400, y: 0))
                }
                .stroke(
                    ticketInk.opacity(0.5),
                    style: StrokeStyle(lineWidth: 2, dash: [2, 4])
                )
                .frame(width: 400, height: 2)
                .padding(.leading, 58)
                .padding(.top, 182)

                HStack(alignment: .top, spacing: 66) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YEAR")
                            .font(.system(size: 16, weight: .medium))
                            .tracking(2.4)
                            .foregroundStyle(ticketInk.opacity(0.72))
                        Text(meta.dateYear)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(ticketInk)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DATE")
                            .font(.system(size: 16, weight: .medium))
                            .tracking(2.4)
                            .foregroundStyle(ticketInk.opacity(0.72))
                        Text(meta.dateMonthDay)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(ticketInk)
                    }
                }
                .padding(.leading, 58)
                .padding(.top, 206)
            }
        }
    }

    private var stationGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEXT STATION")
                .font(.system(size: 20, weight: .medium))
                .tracking(1.8)
                .foregroundStyle(ticketInk.opacity(0.72))

            Text(meta.ticketStationName)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(ticketInk)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private var barcodePlate: some View {
        // Prototype: .bc-rot = 235×107, origin top-left, translateX(107) rotate(90°).
        Color.white
            .overlay(alignment: .topLeading) {
                ShareCardBarcodeView(seed: meta.barcodeSeed)
                    .frame(width: 235, height: 107, alignment: .topLeading)
                    .rotationEffect(.degrees(90), anchor: .topLeading)
                    .offset(x: 107)
            }
            .frame(width: 107, height: 235)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct TicketStubMask: Shape {
    let seamY: CGFloat
    let notchRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 48)
        let left = CGRect(
            x: rect.minX - notchRadius,
            y: seamY - notchRadius,
            width: notchRadius * 2,
            height: notchRadius * 2
        )
        let right = CGRect(
            x: rect.maxX - notchRadius,
            y: seamY - notchRadius,
            width: notchRadius * 2,
            height: notchRadius * 2
        )
        path.addEllipse(in: left)
        path.addEllipse(in: right)
        return path
    }
}

private struct ShareCardBarcodeView: View {
    let seed: String

    /// Horizontal Code128 layout before 90° rotation into the 107×235 plate.
    /// Matches prototype `.bc-bars` / `.bc-num` absolute insets inside 235×107.
    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let image = Self.makeBarcode(seed: seed) {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 229, height: 62)
                } else {
                    barcodeFallback
                }
            }
            .padding(.leading, 3)
            .padding(.trailing, 3)
            .padding(.top, 7)

            Text(Self.displayDigits(from: seed))
                .font(.system(size: 15.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(white: 0.07))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 219, height: 31, alignment: .center)
                .padding(.leading, 8)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 7)
        }
        .frame(width: 235, height: 107)
    }

    private var barcodeFallback: some View {
        HStack(spacing: 2) {
            ForEach(0..<24, id: \.self) { i in
                Rectangle()
                    .fill(Color.black)
                    .frame(width: CGFloat((i % 5) + 1), height: 62)
                Spacer(minLength: 1)
            }
        }
        .frame(width: 229, height: 62)
    }

    private static func makeBarcode(seed: String) -> UIImage? {
        let data = Data(seed.utf8)
        guard let filter = CIFilter(name: "CICode128BarcodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(8.0, forKey: "inputQuietSpace")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// FNV-1a：导出物必须可复现，不能用进程级随机种子的 `Hasher`。
    private static func displayDigits(from seed: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        var digits = String(hash)
        while digits.count < 21 {
            hash = hash &* 0x0000_0100_0000_01b3
            digits += String(hash)
        }
        return String(digits.prefix(21))
    }
}

// MARK: - C · Colorwork

private struct ColorworkCard: View {
    let photo: UIImage?
    let meta: ShareCardMeta

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 16 / 255, green: 16 / 255, blue: 20 / 255)

            VStack(spacing: 0) {
                ZStack {
                    meta.blockColor
                    VStack(spacing: 0) {
                        Text(meta.colorworkTitle)
                            .font(.custom("AmericanTypewriter-CondensedBold", size: 56))
                            .tracking(2.4)
                            .textCase(.uppercase)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        if meta.displaysDate {
                            Text(meta.dateFull)
                                .font(.custom("AmericanTypewriter-Condensed", size: 32))
                                .foregroundStyle(.white)
                                .padding(.top, 20)
                                .multilineTextAlignment(.center)
                        }

                        if meta.displaysLocation {
                            Text(meta.location)
                                .font(.custom("AmericanTypewriter-Condensed", size: 28))
                                .foregroundStyle(.white.opacity(0.88))
                                .padding(.top, 8)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 48)
                }
                .frame(width: 1200, height: 800)

                Group {
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(white: 0.12)
                    }
                }
                .frame(width: 1200, height: 800)
                .clipped()
            }
        }
    }
}

/// 把设计坐标卡片缩进预览槽。
struct ShareCardPreviewScaled: View {
    let template: ShareCardTemplate
    let photo: UIImage?
    let meta: ShareCardMeta
    var palette: ShareCardTicketPalette = .default

    var body: some View {
        GeometryReader { geo in
            let size = template.designSize
            let scale = min(geo.size.width / size.width, geo.size.height / size.height)
            // Preview-only radius: clip the scaled frame so ImageRenderer export stays sharp full-bleed.
            ShareCardView(template: template, photo: photo, meta: meta, palette: palette)
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .frame(width: size.width * scale, height: size.height * scale)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
