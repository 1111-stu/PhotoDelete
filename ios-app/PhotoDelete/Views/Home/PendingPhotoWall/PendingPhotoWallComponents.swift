//
//  PendingPhotoWallComponents.swift
//  PhotoDelete
//
//  待整理照片墙：顶栏、日历格、相纸板、空状态、年份液态玻璃下拉。
//

import Photos
import SwiftUI

// MARK: - Chrome

struct PendingPhotoWallYearMenu: View {
    let years: [PendingPhotoWallYearOption]
    let selectedYear: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(years) { option in
                Button {
                    onSelect(option.year)
                } label: {
                    HStack(spacing: 10) {
                        Text(yearLabel(for: option.year))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.primaryText)
                            .monospacedDigit()
                        Spacer(minLength: 8)
                        if option.year == selectedYear {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .modifier(PendingPhotoWallGlassPanelChrome(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.35), radius: 18, y: 10)
        .accessibilityLabel(L10n.string("Select year"))
    }

    private func yearLabel(for year: Int) -> String {
        AppDateFormatter.string(
            from: Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date(),
            template: "y"
        )
    }
}

/// 年份下拉面板：iOS 26+ 液态玻璃，老系统半透明深色面板。
private struct PendingPhotoWallGlassPanelChrome: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Theme.elevatedSurface.opacity(0.92))
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: Theme.stroke)
                        }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
        }
    }
}

// MARK: - Month section

struct PendingPhotoWallMonthSection<Content: View>: View {
    let title: String
    let remainingCount: Int
    let displayMode: PendingPhotoWallDisplayMode
    let onSelectMode: (PendingPhotoWallDisplayMode) -> Void
    let onOrganizeMonth: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Theme.primaryText)

                Spacer(minLength: 8)

                PendingPhotoWallModeSegment(mode: displayMode, onSelect: onSelectMode)

                Button(action: onOrganizeMonth) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.tertiaryText)
                        Text(PhotoDeleteCountFormat.plain(remainingCount))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.secondaryText)
                            .monospacedDigit()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.tertiaryText.opacity(0.7))
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    String(
                        format: L10n.string("Organize %@ · %@ photos"),
                        title,
                        PhotoDeleteCountFormat.plain(remainingCount)
                    )
                )
            }

            content()
        }
        .padding(.bottom, 18)
    }
}

struct PendingPhotoWallModeSegment: View {
    let mode: PendingPhotoWallDisplayMode
    let onSelect: (PendingPhotoWallDisplayMode) -> Void

    var body: some View {
        HStack(spacing: 2) {
            modeButton(.calendar, systemName: "calendar", label: L10n.string("Calendar"))
            modeButton(.polaroid, systemName: "rectangle.stack", label: L10n.string("Photo board"))
        }
        .padding(2)
        .background(Capsule(style: .continuous).fill(Theme.elevatedSurface))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.string("Display mode"))
    }

    private func modeButton(
        _ value: PendingPhotoWallDisplayMode,
        systemName: String,
        label: String
    ) -> some View {
        Button {
            onSelect(value)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(mode == value ? Theme.primaryText : Theme.tertiaryText)
                .frame(width: 30, height: 24)
                .background {
                    if mode == value {
                        Capsule(style: .continuous).fill(Color.white.opacity(0.12))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }
}

// MARK: - Calendar

struct PendingPhotoWallCalendarGrid: View {
    let month: PendingPhotoWallMonth
    let today: Date
    let photoLibraryManager: PhotoLibraryManager
    let onSelectDay: (PendingPhotoWallDayCell) -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 7),
                spacing: 0
            ) {
                // veryShortWeekdaySymbols：index 0 = 周日（与原型周日首列一致）。
                ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Theme.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 7),
                spacing: 10
            ) {
                ForEach(0..<leadingBlankCount, id: \.self) { _ in
                    PendingPhotoWallDayCellView(
                        kind: .blank(isToday: false),
                        photoLibraryManager: photoLibraryManager,
                        onTap: {}
                    )
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    let isToday = isToday(day: day)
                    if let cell = month.daysWithPhotos[day] {
                        PendingPhotoWallDayCellView(
                            kind: .photo(cell: cell, isToday: isToday, dayOfMonth: day),
                            photoLibraryManager: photoLibraryManager,
                            onTap: { onSelectDay(cell) }
                        )
                    } else {
                        PendingPhotoWallDayCellView(
                            kind: .blank(isToday: isToday),
                            photoLibraryManager: photoLibraryManager,
                            onTap: {}
                        )
                    }
                }
            }
        }
    }

    private var leadingBlankCount: Int {
        let weekday = calendar.component(.weekday, from: month.monthStart)
        return weekday - 1
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: month.monthStart)?.count ?? 30
    }

    private func isToday(day: Int) -> Bool {
        calendar.isDate(today, equalTo: month.monthStart, toGranularity: .month)
            && calendar.component(.day, from: today) == day
    }
}

enum PendingPhotoWallDayCellKind: Equatable {
    case blank(isToday: Bool)
    case photo(cell: PendingPhotoWallDayCell, isToday: Bool, dayOfMonth: Int)
}

struct PendingPhotoWallDayCellView: View {
    let kind: PendingPhotoWallDayCellKind
    let photoLibraryManager: PhotoLibraryManager
    let onTap: () -> Void

    private let paper = Color(red: 242 / 255, green: 237 / 255, blue: 228 / 255)

    var body: some View {
        switch kind {
        case .blank(let isToday):
            blankCard(isToday: isToday)
        case .photo(let cell, let isToday, let dayOfMonth):
            Button(action: onTap) {
                photoCard(cell: cell, isToday: isToday, dayOfMonth: dayOfMonth)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                String(
                    format: L10n.string("Organize from %@ · %@ photos"),
                    AppDateFormatter.string(from: cell.date, template: "MMMd"),
                    PhotoDeleteCountFormat.plain(cell.remainingCount)
                )
            )
        }
    }

    private func blankCard(isToday: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(red: 0.071, green: 0.071, blue: 0.086))
            .aspectRatio(100 / 118, contentMode: .fit)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.36), lineWidth: 1.5)
                }
            }
            .accessibilityHidden(true)
    }

    private func photoCard(cell: PendingPhotoWallDayCell, isToday: Bool, dayOfMonth: Int) -> some View {
        let tilt = Double((dayOfMonth % 5) - 2) * 0.6
        return ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(paper)
                .shadow(color: Color.black.opacity(0.35), radius: 1.5, y: 1)

            PendingPhotoWallThumbnail(
                assetID: cell.coverAssetID,
                photoLibraryManager: photoLibraryManager,
                cornerRadius: 8
            )
            .padding(2)
        }
        .aspectRatio(100 / 118, contentMode: .fit)
        .rotationEffect(.degrees(tilt))
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.36), lineWidth: 1.5)
            }
        }
    }
}

// MARK: - Polaroid board

struct PendingPhotoWallPolaroidBoard: View {
    let month: PendingPhotoWallMonth
    let photoLibraryManager: PhotoLibraryManager
    let onSelectPhoto: (PendingPhotoWallDayCell, String?) -> Void

    /// 排布是纯计算，先摆出空白相纸定住板高；缩略图等这块板进视口再拉，避免切到相纸墙时整年一起解码。
    @State private var isActivated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var motion = PolaroidBoardMotion.shared

    private var board: PolaroidBoard {
        PolaroidBoardLayout.layout(
            year: month.year,
            month: month.month,
            days: Array(month.daysWithPhotos.values)
        )
    }

    var body: some View {
        let board = board
        VStack(spacing: 9) {
            GeometryReader { proxy in
                let scale = proxy.size.width / PolaroidBoardLayout.boardWidth
                ZStack(alignment: .topLeading) {
                    boardBackground

                    ForEach(board.items) { item in
                        polaroid(item, scale: scale)
                            .frame(width: item.width * scale, height: item.height * scale)
                            .overlay(alignment: .top) {
                                if let clip = item.clip {
                                    PendingPhotoWallBoardClip(colorIndex: clip.colorIndex)
                                        .frame(
                                            width: PolaroidBoardLayout.clipWidth * scale,
                                            height: PolaroidBoardLayout.clipHeight * scale
                                        )
                                        .rotationEffect(.degrees(Double(clip.rotationDegrees)))
                                        .offset(
                                            x: clip.offsetX * scale,
                                            y: -PolaroidBoardLayout.clipRise * scale
                                        )
                                        .allowsHitTesting(false)
                                }
                            }
                            .offset(
                                x: reduceMotion ? 0 : motion.swingX(hang: item.hang) * scale,
                                y: reduceMotion ? 0 : motion.swingY(hang: item.hang) * scale
                            )
                            .rotationEffect(
                                .degrees(
                                    Double(item.rotationDegrees)
                                        + (reduceMotion ? 0 : Double(motion.swingRotation(hang: item.hang)))
                                )
                            )
                            .position(
                                x: (item.x + item.width / 2) * scale,
                                y: (item.y + item.height / 2) * scale
                            )
                            .zIndex(item.zIndex + 1)
                    }
                }
            }
            .aspectRatio(PolaroidBoardLayout.boardWidth / max(board.height, 1), contentMode: .fit)
            .onAppear {
                isActivated = true
                if !reduceMotion {
                    motion.retain()
                }
            }
            .onDisappear {
                if !reduceMotion {
                    motion.release()
                }
            }

            Text(
                String(
                    format: L10n.string("Showing %lld of %lld photos"),
                    Int64(board.items.count),
                    Int64(month.remainingCount)
                )
            )
            .font(.system(size: 11.5))
            .foregroundColor(Theme.secondaryText)
            .monospacedDigit()
            .frame(maxWidth: .infinity)
        }
    }

    private var boardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.110, green: 0.110, blue: 0.133),
                        Color(red: 0.071, green: 0.071, blue: 0.086)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.48), radius: 14, y: 10)
    }

    private func polaroid(_ item: PolaroidBoardItem, scale: CGFloat) -> some View {
        Button {
            if let cell = month.daysWithPhotos[item.dayOfMonth] {
                onSelectPhoto(cell, item.coverAssetID)
            }
        } label: {
            VStack(spacing: 0) {
                PendingPhotoWallThumbnail(
                    assetID: isActivated ? item.coverAssetID : nil,
                    photoLibraryManager: photoLibraryManager,
                    cornerRadius: 2
                )
                .aspectRatio(item.photoAspectRatio, contentMode: .fit)
                .padding(.horizontal, PolaroidBoardLayout.frameSide * scale)
                .padding(.top, PolaroidBoardLayout.frameTop * scale)
                Spacer(minLength: 0)
            }
            .padding(.bottom, PolaroidBoardLayout.frameBottom * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                // 贴边一层让压边处有清楚的分界，环境一层把相纸托离板面。
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(Theme.boardPaper)
                    .shadow(color: Color.black.opacity(0.42), radius: 1.2 * scale, y: 0.8 * scale)
                    .shadow(color: Color.black.opacity(0.38), radius: 6 * scale, y: 4 * scale)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(
                format: L10n.string("Organize from day %lld · %@ photos"),
                Int64(item.dayOfMonth),
                PhotoDeleteCountFormat.plain(item.remainingCount)
            )
        )
    }
}

/// 正面看的小木夹：上下两片夹口 + 弹簧缝 + 顶部受光。
private struct PendingPhotoWallBoardClip: View {
    let colorIndex: Int

    var body: some View {
        let palette = Theme.boardClipPalette
        let shape = RoundedRectangle(cornerRadius: 1.4, style: .continuous)
        shape
            .fill(palette[colorIndex % palette.count])
            .overlay {
                LinearGradient(
                    colors: [Color.white.opacity(0.42), Color.white.opacity(0)],
                    startPoint: .top,
                    endPoint: .center
                )
                .clipShape(shape)
            }
            .overlay {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(Color.black.opacity(0.24))
                        .frame(height: max(proxy.size.height * 0.05, 0.6))
                        .offset(y: proxy.size.height * 0.42)
                }
            }
            .shadow(color: Color.black.opacity(0.4), radius: 0.8, y: 0.8)
    }
}

// MARK: - Thumbnail

struct PendingPhotoWallThumbnail: View {
    let assetID: String?
    let photoLibraryManager: PhotoLibraryManager
    var cornerRadius: CGFloat = 8

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?
    @State private var loadGeneration = 0
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.886, green: 0.859, blue: 0.812)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    shimmer
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .task(id: "\(assetID ?? "")-\(Int(proxy.size.width.rounded()))") {
                load(side: max(proxy.size.width, proxy.size.height))
            }
        }
        .onDisappear { cancel() }
    }

    private var shimmer: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.02),
                Color.black.opacity(0.08),
                Color.black.opacity(0.02)
            ],
            startPoint: UnitPoint(x: shimmerPhase, y: 0.5),
            endPoint: UnitPoint(x: shimmerPhase + 0.45, y: 0.5)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.7).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.3
            }
        }
    }

    @MainActor
    private func load(side: CGFloat) {
        cancel()
        guard let assetID, side > 1 else {
            image = nil
            return
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = assets.firstObject else {
            image = nil
            return
        }
        loadGeneration += 1
        let generation = loadGeneration
        let scale = UIScreen.main.scale
        let pixels = side * scale
        let target = CGSize(width: pixels, height: pixels)
        requestID = photoLibraryManager.loadAlbumCoverThumbnail(for: asset, size: target) { loaded in
            guard generation == loadGeneration else { return }
            if let loaded {
                withAnimation(.easeOut(duration: 0.28)) {
                    image = loaded
                }
            }
        }
    }

    private func cancel() {
        if let requestID {
            photoLibraryManager.cancelImageRequest(requestID)
        }
        requestID = nil
    }
}

// MARK: - Empty

struct PendingPhotoWallEmptyState: View {
    let isWholeLibrary: Bool
    let onViewHistory: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .frame(width: 84, height: 84)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.positive)
            }
            .padding(.bottom, 22)

            Text(isWholeLibrary ? L10n.string("All caught up") : L10n.string("This year is done"))
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(Theme.primaryText)
                .padding(.bottom, 10)

            Text(
                isWholeLibrary
                    ? L10n.string("Every photo has been reviewed.")
                    : L10n.string("Pick another year, or keep going elsewhere.")
            )
            .font(.system(size: 13))
            .foregroundColor(Theme.secondaryText)
            .multilineTextAlignment(.center)
            .lineSpacing(4)

            if isWholeLibrary {
                Button(action: onViewHistory) {
                    HStack(spacing: 8) {
                        Text(L10n.string("View review history"))
                            .font(.system(size: 13.5, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.tertiaryText)
                    }
                    .foregroundColor(Theme.primaryText)
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .background(Capsule(style: .continuous).fill(Theme.elevatedSurface))
                }
                .buttonStyle(.plain)
                .padding(.top, 24)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 100)
        .frame(maxWidth: .infinity)
    }
}
