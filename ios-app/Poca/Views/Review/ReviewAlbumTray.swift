//
//  ReviewAlbumTray.swift
//  Poca
//
//  Floating album tray for the review screen, replacing the old filing sheet.
//  Visual reference: designs/review-album-tray-prototype.html
//

import SwiftUI

// MARK: - Layout

enum ReviewAlbumTrayLayout {
    static let sideMargin: CGFloat = 16
    static let bottomMargin: CGFloat = 16
    static let maxWidth: CGFloat = 720

    static let topBandHeight: CGFloat = 28
    static let hintFontSize: CGFloat = 11
    static let hintLeading: CGFloat = 20
    static let hintTrailing: CGFloat = 64

    static let closeVisualSize: CGFloat = 24
    static let closeHitSize: CGFloat = 44
    static let closeSymbolSize: CGFloat = 10
    static let closeTrailingOffset: CGFloat = 2
    static let closeTopOffset: CGFloat = -22

    static let railHorizontalPadding: CGFloat = 18
    static let railTopPadding: CGFloat = 2
    static let railBottomPadding: CGFloat = 14
    static let railSpacing: CGFloat = 12
    static let edgeFadeLocation: CGFloat = 0.03

    static let cardWidth: CGFloat = 82
    static let folderSize: CGFloat = 82
    static let folderNameSpacing: CGFloat = 9
    static let nameFontSize: CGFloat = 12
    static let nameLineHeight: CGFloat = 15
    static let folderCornerRadius: CGFloat = 20
    static let pocketCornerRadius: CGFloat = 12
    static let photoCornerRadius: CGFloat = 6

    /// Intrinsic height of the horizontal rail. A horizontal ScrollView would
    /// otherwise expand to fill all proposed height and turn the tray into a sheet.
    static let railHeight: CGFloat =
        railTopPadding + folderSize + folderNameSpacing + nameLineHeight + railBottomPadding

    static let pressScale: CGFloat = 0.97

    static let presentationAnimation: Animation = .spring(response: 0.34, dampingFraction: 0.88)
    static let reduceMotionAnimation: Animation = .easeOut(duration: 0.16)

    /// Stable FNV-1a hash so an album keeps the same folder color across launches.
    /// Do not use Swift's randomized `hashValue` here.
    static func paletteIndex(for albumID: String) -> Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in albumID.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return Int(hash % UInt64(Theme.albumFolderPalettes.count))
    }

    static func palette(for albumID: String) -> Theme.AlbumFolderPalette {
        Theme.albumFolderPalettes[paletteIndex(for: albumID)]
    }
}

// MARK: - Tray

struct ReviewAlbumTray: View {
    let albums: [AlbumInfo]
    let isLoading: Bool
    let isFiling: Bool
    let filingAlbumID: String?
    let onSelect: (AlbumInfo) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(trayBackground)
        .shadow(color: Theme.floatingShadow, radius: 12, y: 6)
        .overlay(alignment: .topTrailing) { closeButton }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review-album-tray")
    }

    private var header: some View {
        ZStack(alignment: .leading) {
            if !albums.isEmpty {
                Text(L10n.string("Tap an album to add"))
                    .font(.system(size: ReviewAlbumTrayLayout.hintFontSize, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.leading, ReviewAlbumTrayLayout.hintLeading)
                    .padding(.trailing, ReviewAlbumTrayLayout.hintTrailing)
                    .accessibilityIdentifier("review-album-tray-hint")
            }
        }
        .frame(height: ReviewAlbumTrayLayout.topBandHeight)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            loadingState
        } else if albums.isEmpty {
            emptyState
        } else {
            albumRail
        }
    }

    private var albumRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: ReviewAlbumTrayLayout.railSpacing) {
                ForEach(Array(albums.enumerated()), id: \.element.id) { item in
                    let index: Int = item.offset
                    let album: AlbumInfo = item.element
                    let isThisAlbumFiling = isFiling && filingAlbumID == album.id
                    ReviewAlbumFolderCard(
                        album: album,
                        palette: ReviewAlbumTrayLayout.palette(for: album.id),
                        index: index,
                        isFiling: isThisAlbumFiling,
                        isDisabled: isFiling,
                        onSelect: { onSelect(album) }
                    )
                }
            }
            .padding(.horizontal, ReviewAlbumTrayLayout.railHorizontalPadding)
            .padding(.top, ReviewAlbumTrayLayout.railTopPadding)
            .padding(.bottom, ReviewAlbumTrayLayout.railBottomPadding)
        }
        .frame(height: ReviewAlbumTrayLayout.railHeight)
        .mask(edgeFadeMask)
    }

    private var edgeFadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: ReviewAlbumTrayLayout.edgeFadeLocation),
                .init(color: .black, location: 1 - ReviewAlbumTrayLayout.edgeFadeLocation),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var loadingState: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            ProgressView()
                .tint(Theme.accent)
            Spacer(minLength: 0)
        }
        .frame(height: ReviewAlbumTrayLayout.railHeight)
        .accessibilityIdentifier("review-album-tray-loading")
    }

    private var emptyState: some View {
        VStack(spacing: Theme.space2) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
            Text(L10n.string("No Albums Yet"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: ReviewAlbumTrayLayout.railHeight)
        .accessibilityIdentifier("review-album-tray-empty")
    }

    private var trayBackground: some View {
        RoundedRectangle(cornerRadius: Theme.radiusXl, style: .continuous)
            .fill(Theme.surface.opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusXl, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: Theme.stroke)
            }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: ReviewAlbumTrayLayout.closeSymbolSize, weight: .bold))
                .foregroundStyle(Theme.secondaryText)
                .frame(
                    width: ReviewAlbumTrayLayout.closeVisualSize,
                    height: ReviewAlbumTrayLayout.closeVisualSize
                )
                .background {
                    Circle()
                        .fill(Theme.elevatedSurface.opacity(0.95))
                        .overlay {
                            Circle()
                                .stroke(Theme.hairline, lineWidth: Theme.stroke)
                        }
                }
                .frame(
                    width: ReviewAlbumTrayLayout.closeHitSize,
                    height: ReviewAlbumTrayLayout.closeHitSize
                )
                .contentShape(Circle())
                .shadow(color: Theme.floatingShadow, radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.string("Close")))
        .accessibilityIdentifier("review-album-tray-close")
        .offset(
            x: ReviewAlbumTrayLayout.closeTrailingOffset,
            y: ReviewAlbumTrayLayout.closeTopOffset
        )
    }
}

// MARK: - Folder card

struct ReviewAlbumFolderCard: View {
    let album: AlbumInfo
    let palette: Theme.AlbumFolderPalette
    let index: Int
    let isFiling: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: ReviewAlbumTrayLayout.folderNameSpacing) {
                AlbumFolderIllustration(album: album, palette: palette)
                    .frame(
                        width: ReviewAlbumTrayLayout.folderSize,
                        height: ReviewAlbumTrayLayout.folderSize
                    )

                Text(album.title)
                    .font(.system(size: ReviewAlbumTrayLayout.nameFontSize, weight: .semibold))
                    .foregroundStyle(Theme.primaryText.opacity(0.84))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: ReviewAlbumTrayLayout.cardWidth)
            }
            .frame(width: ReviewAlbumTrayLayout.cardWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(ReviewAlbumFolderButtonStyle(isFiling: isFiling))
        .disabled(isDisabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: L10n.string("Add to %@"), album.title)))
        .accessibilityValue(Text(L10n.photoCount(album.photosCount)))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("review-album-tray-album-\(index)")
    }
}

// MARK: - Folder illustration

struct AlbumFolderIllustration: View {
    let album: AlbumInfo
    let palette: Theme.AlbumFolderPalette

    private static let coolPaperLight = Color(red: 0.918, green: 0.945, blue: 0.965)
    private static let coolPaperDark = Color(red: 0.796, green: 0.847, blue: 0.894)
    private static let creamPaperLight = Color(red: 0.988, green: 0.969, blue: 0.925)
    private static let creamPaperDark = Color(red: 0.882, green: 0.843, blue: 0.773)
    private static let peachPaperLight = Color(red: 0.973, green: 0.910, blue: 0.855)
    private static let peachPaperDark = Color(red: 0.882, green: 0.776, blue: 0.694)

    var body: some View {
        ZStack(alignment: .topLeading) {
            AlbumFolderBackShape()
                .fill(
                    LinearGradient(
                        colors: [palette.dark, palette.light],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            photo(
                width: 58, height: 28, x: 12, y: 18, rotation: -1,
                light: Self.coolPaperLight, dark: Self.coolPaperDark, strokeOpacity: 0.30
            )
            photo(
                width: 50, height: 26, x: 17, y: 22, rotation: 1,
                light: Self.creamPaperLight, dark: Self.creamPaperDark, strokeOpacity: 0.36
            )
            photo(
                width: 42, height: 24, x: 22, y: 26, rotation: -0.5,
                light: Self.peachPaperLight, dark: Self.peachPaperDark, strokeOpacity: 0.42
            )

            RoundedRectangle(
                cornerRadius: ReviewAlbumTrayLayout.pocketCornerRadius,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [palette.light, palette.dark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                LinearGradient(
                    colors: [Color.white.opacity(0.38), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: ReviewAlbumTrayLayout.pocketCornerRadius,
                        style: .continuous
                    )
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                countLabel
                    .padding(.leading, 8)
                    .padding(.bottom, 6)
            }
            .frame(width: 76, height: 44)
            .offset(x: 3, y: 35)
        }
        .frame(width: ReviewAlbumTrayLayout.folderSize, height: ReviewAlbumTrayLayout.folderSize)
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.28), radius: 6, y: 5)
    }

    private var countLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 11, weight: .semibold))
            Text(PocaCountFormat.plain(album.photosCount))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(palette.ink.opacity(0.86))
    }

    private func photo(
        width: CGFloat,
        height: CGFloat,
        x: CGFloat,
        y: CGFloat,
        rotation: Double,
        light: Color,
        dark: Color,
        strokeOpacity: Double
    ) -> some View {
        RoundedRectangle(
            cornerRadius: ReviewAlbumTrayLayout.photoCornerRadius,
            style: .continuous
        )
        .fill(
            LinearGradient(colors: [light, dark], startPoint: .top, endPoint: .bottom)
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: ReviewAlbumTrayLayout.photoCornerRadius,
                style: .continuous
            )
            .stroke(Color.white.opacity(strokeOpacity), lineWidth: 0.8)
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(rotation))
        .offset(x: x, y: y)
    }
}

/// Folder back panel with the rounded top-leading tab, matching the HTML prototype.
struct AlbumFolderBackShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 82
        let sy = rect.height / 82
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }

        var path = Path()
        path.move(to: p(8, 17))
        path.addCurve(to: p(18, 6), control1: p(8, 10), control2: p(11, 6))
        path.addLine(to: p(35, 6))
        path.addCurve(to: p(44, 11), control1: p(39, 6), control2: p(42, 8))
        path.addLine(to: p(48, 18))
        path.addLine(to: p(72, 18))
        path.addCurve(to: p(80, 26), control1: p(77, 18), control2: p(80, 21))
        path.addLine(to: p(80, 72))
        path.addCurve(to: p(72, 80), control1: p(80, 77), control2: p(77, 80))
        path.addLine(to: p(10, 80))
        path.addCurve(to: p(2, 72), control1: p(5, 80), control2: p(2, 77))
        path.addLine(to: p(2, 26))
        path.addCurve(to: p(8, 17), control1: p(2, 21), control2: p(5, 17))
        path.closeSubpath()
        return path
    }
}

// MARK: - Press feedback

struct ReviewAlbumFolderButtonStyle: ButtonStyle {
    let isFiling: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                configuration.isPressed && !isFiling
                    ? ReviewAlbumTrayLayout.pressScale
                    : 1
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview("Album tray") {
    ZStack(alignment: .bottom) {
        Theme.reviewCanvas.ignoresSafeArea()
        ReviewAlbumTray(
            albums: [
                AlbumInfo(id: "flow", title: "Flow", assetCollection: nil, type: .userCreated, photosCount: 128, thumbnailAsset: nil),
                AlbumInfo(id: "xhs", title: "小红书", assetCollection: nil, type: .userCreated, photosCount: 64, thumbnailAsset: nil),
                AlbumInfo(id: "wechat", title: "微信", assetCollection: nil, type: .userCreated, photosCount: 320, thumbnailAsset: nil),
                AlbumInfo(id: "travel", title: "旅行", assetCollection: nil, type: .userCreated, photosCount: 210, thumbnailAsset: nil)
            ],
            isLoading: false,
            isFiling: false,
            filingAlbumID: nil,
            onSelect: { _ in },
            onClose: {}
        )
        .padding(.horizontal, ReviewAlbumTrayLayout.sideMargin)
        .padding(.bottom, ReviewAlbumTrayLayout.bottomMargin)
    }
}
