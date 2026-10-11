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
                .padding(.trailing, 62)
                .padding(.bottom, 72)
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

    @ViewBuilder
    private var metaBlock: some View {
        let showLoc = meta.displaysLocation
        let showDate = meta.displaysDate

        VStack(alignment: .leading, spacing: 0) {
            if showDate && showLoc {
                Text(meta.dateFull)
                    .font(.system(size: 42, weight: .regular))
                    .foregroundStyle(muted)
                    .padding(.bottom, 52)
            }

            HStack(alignment: .firstTextBaseline, spacing: 24) {
                if showLoc {
                    Text(meta.location)
                        .font(.system(size: 68, weight: .semibold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 8)
                    Text(meta.signature)
                        .font(.system(size: 37, weight: .semibold))
                        .foregroundStyle(ink)
                } else if showDate {
                    Text(meta.dateFull)
                        .font(.system(size: 68, weight: .semibold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 8)
                    Text(meta.signature)
                        .font(.system(size: 37, weight: .semibold))
                        .foregroundStyle(ink)
                } else {
                    Spacer(minLength: 0)
                    Text(meta.signature)
                        .font(.system(size: 37, weight: .semibold))
                        .foregroundStyle(ink)
                }
            }
        }
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
        let centerName = !meta.ticketShowsDateColumns
        return ZStack(alignment: .topLeading) {
            palette.stub

            VStack(alignment: .leading, spacing: 0) {
                Text("NEXT STATION")
                    .font(.system(size: 21, weight: .medium))
                    .tracking(1.7)
                    .foregroundStyle(ticketInk)
                    .padding(.top, centerName ? 100 : 30)
                    .padding(.leading, 59)

                Text(meta.ticketStationName)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(ticketInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 10)
                    .padding(.leading, 57)
                    .padding(.trailing, 130)

                if meta.ticketShowsDateColumns {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 400, y: 0))
                    }
                    .stroke(
                        ticketInk.opacity(0.5),
                        style: StrokeStyle(lineWidth: 2, dash: [2, 4])
                    )
                    .frame(width: 400, height: 2)
                    .padding(.top, 28)
                    .padding(.leading, 59)

                    HStack(alignment: .top, spacing: 66) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("YEAR")
                                .font(.system(size: 18, weight: .medium))
                                .tracking(2.2)
                                .foregroundStyle(ticketInk)
                            Text(meta.dateYear)
                                .font(.system(size: 29, weight: .bold))
                                .foregroundStyle(ticketInk)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DATE")
                                .font(.system(size: 18, weight: .medium))
                                .tracking(2.2)
                                .foregroundStyle(ticketInk)
                            Text(meta.dateMonthDay)
                                .font(.system(size: 29, weight: .bold))
                                .foregroundStyle(ticketInk)
                        }
                    }
                    .padding(.top, 18)
                    .padding(.leading, 59)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: centerName ? .center : .topLeading)
        }
    }

    private var barcodePlate: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white)
            ShareCardBarcodeView(seed: meta.barcodeSeed)
                .frame(width: 235, height: 107)
                .rotationEffect(.degrees(90))
        }
        .clipped()
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

    var body: some View {
        VStack(spacing: 4) {
            if let image = Self.makeBarcode(seed: seed) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(height: 62)
                    .padding(.horizontal, 3)
            } else {
                barcodeFallback
            }
            Text(Self.displayDigits(from: seed))
                .font(.system(size: 15.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(white: 0.07))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 8)
        }
        .padding(.vertical, 7)
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
        .padding(.horizontal, 3)
        .frame(height: 62)
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

    private static func displayDigits(from seed: String) -> String {
        var hasher = Hasher()
        hasher.combine(seed)
        let hash = abs(hasher.finalize())
        var digits = String(hash)
        while digits.count < 21 {
            var step = Hasher()
            step.combine(seed)
            step.combine(digits.count)
            digits += String(abs(step.finalize()))
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
                            .font(.custom("AmericanTypewriter-CondensedBold", size: 48))
                            .tracking(2.4)
                            .textCase(.uppercase)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        if meta.displaysDate {
                            Text(meta.dateFull)
                                .font(.custom("AmericanTypewriter-Condensed", size: 28))
                                .foregroundStyle(.white)
                                .padding(.top, 17)
                                .multilineTextAlignment(.center)
                        }

                        if meta.displaysLocation {
                            Text(meta.location)
                                .font(.custom("AmericanTypewriter-Condensed", size: 25))
                                .foregroundStyle(.white.opacity(0.88))
                                .padding(.top, 7)
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
            ShareCardView(template: template, photo: photo, meta: meta, palette: palette)
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .frame(width: size.width * scale, height: size.height * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
