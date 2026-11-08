//
//  PendingPhotoWallComponents.swift
//  Poca
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
        .modifier(PendingPhotoWallGlassPanelChrome(cornerRadius: Theme.radiusMd))
        .shadow(color: Theme.floatingShadow, radius: 18, y: 10)
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
    let photoCount: Int
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                PendingPhotoWallModeSegment(mode: displayMode, onSelect: onSelectMode)

                Spacer(minLength: 8)

                Button(action: onOrganizeMonth) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.tertiaryText)
                        Text(PocaCountFormat.plain(photoCount))
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
                        PocaCountFormat.plain(photoCount)
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

    @Namespace private var selectionNamespace

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
            guard value != mode else { return }
            HapticManager.impact(.light)
            onSelect(value)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(mode == value ? Theme.primaryText : Theme.tertiaryText)
                .frame(width: 30, height: 24)
                .background {
                    if mode == value {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .matchedGeometryEffect(id: "mode-selection", in: selectionNamespace)
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
    let thumbnails: PendingPhotoWallThumbnailPipeline
    let thumbnailTargetSize: CGSize
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
                        thumbnails: thumbnails,
                        thumbnailTargetSize: thumbnailTargetSize,
                        onTap: {}
                    )
                }

                ForEach(1...daysInMonth, id: \.self) { day in
                    let isToday = isToday(day: day)
                    if let cell = month.daysWithPhotos[day] {
                        PendingPhotoWallDayCellView(
                            kind: .photo(cell: cell, isToday: isToday, dayOfMonth: day),
                            thumbnails: thumbnails,
                            thumbnailTargetSize: thumbnailTargetSize,
                            onTap: { onSelectDay(cell) }
                        )
                    } else {
                        PendingPhotoWallDayCellView(
                            kind: .blank(isToday: isToday),
                            thumbnails: thumbnails,
                            thumbnailTargetSize: thumbnailTargetSize,
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
    let thumbnails: PendingPhotoWallThumbnailPipeline
    let thumbnailTargetSize: CGSize
    let onTap: () -> Void

    private let paper = Theme.boardPaperWarm

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
                    PocaCountFormat.plain(cell.photoCount)
                )
            )
        }
    }

    private func blankCard(isToday: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Theme.boardBlank)
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
                thumbnails: thumbnails,
                targetSize: thumbnailTargetSize,
                cornerRadius: Theme.radiusSm
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
    let thumbnails: PendingPhotoWallThumbnailPipeline
    let onSelectPhoto: (PendingPhotoWallDayCell, String?) -> Void

    /// 排布是纯计算，先摆出空白相纸定住板高；缩略图等这块板进视口再拉，避免切到相纸墙时整年一起解码。
    @State private var isActivated = false
    /// 相纸一次性错峰落位；之后滚动进出视口不再重播。
    @State private var hasSettled = false
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
        GeometryReader { proxy in
            let scale = proxy.size.width / PolaroidBoardLayout.boardWidth
            ZStack(alignment: .topLeading) {
                boardBackground

                ForEach(Array(board.items.enumerated()), id: \.element.id) { index, item in
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
                        .opacity(reduceMotion || hasSettled ? 1 : 0)
                        .scaleEffect(reduceMotion || hasSettled ? 1 : 0.94)
                        .offset(y: reduceMotion || hasSettled ? 0 : -8)
                        .position(
                            x: (item.x + item.width / 2) * scale,
                            y: (item.y + item.height / 2) * scale
                        )
                        .zIndex(item.zIndex + 1)
                        .animation(
                            reduceMotion
                                ? nil
                                : .spring(response: 0.46, dampingFraction: 0.82)
                                    .delay(Double(index) * 0.018),
                            value: hasSettled
                        )
                }
            }
        }
        .aspectRatio(PolaroidBoardLayout.boardWidth / max(board.height, 1), contentMode: .fit)
        .onAppear {
            isActivated = true
            if !reduceMotion {
                motion.retain()
            }
            settleIfNeeded()
        }
        .onDisappear {
            if !reduceMotion {
                motion.release()
            }
        }
    }

    /// 先让“未落位”的首帧上屏，再触发错峰弹簧；否则所有相纸会同一帧到位。
    private func settleIfNeeded() {
        guard !hasSettled else { return }
        guard !reduceMotion else {
            hasSettled = true
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            hasSettled = true
        }
    }

    private var boardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Theme.boardSurfaceTop,
                        Theme.boardSurfaceBottom
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: Theme.stroke)
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
                    thumbnails: thumbnails,
                    cornerRadius: 2,
                    quality: .sharp
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
                PocaCountFormat.plain(item.photoCount)
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

/// 日历格统一的缩略图目标尺寸：只由视口宽度决定，预取和单格请求共用同一份缓存。
enum PendingPhotoWallThumbnailMetrics {
    private static let columnCount: CGFloat = 7
    private static let columnSpacing: CGFloat = 9
    private static let horizontalPadding: CGFloat = 16
    private static let cardAspectRatio: CGFloat = 100.0 / 118.0

    static func calendarTargetSize(for containerWidth: CGFloat) -> CGSize {
        let contentWidth = max(containerWidth - horizontalPadding * 2, 1)
        let cellWidth = (contentWidth - columnSpacing * (columnCount - 1)) / columnCount
        let cellHeight = cellWidth / cardAspectRatio
        let side = max(cellWidth, cellHeight) * UIScreen.main.scale
        let pixels = max(side.rounded(.up), 1)
        return CGSize(width: pixels, height: pixels)
    }
}

struct PendingPhotoWallThumbnail: View {
    let assetID: String?
    let thumbnails: PendingPhotoWallThumbnailPipeline
    /// 日历格传入统一像素尺寸；相纸板按自身宽度计算。
    var targetSize: CGSize? = nil
    var cornerRadius: CGFloat = 8
    var quality: PendingPhotoWallThumbnailQuality = .fast

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?
    @State private var loadGeneration = 0

    var body: some View {
        GeometryReader { proxy in
            let targetSize = resolvedTargetSize(for: proxy.size)
            ZStack {
                Theme.boardThumbnailPlaceholder

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(quality == .sharp ? .high : .medium)
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .transition(.opacity)
                } else {
                    placeholder
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .task(id: taskID(targetSize: targetSize)) {
                await load(targetSize: targetSize)
            }
        }
        .onDisappear { cancel() }
    }

    /// 静态占位。墙面保持静止，不为每格挂常驻 shimmer 动画。
    private var placeholder: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.02),
                Color.black.opacity(0.08),
                Color.black.opacity(0.02)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func taskID(targetSize: CGSize) -> String {
        "\(assetID ?? "")-\(quality.cacheToken)-\(Int(targetSize.width))x\(Int(targetSize.height))"
    }

    private func resolvedTargetSize(for size: CGSize) -> CGSize {
        if let targetSize, targetSize.width > 1, targetSize.height > 1 {
            return targetSize
        }
        let side = max(max(size.width, size.height) * UIScreen.main.scale, 1)
        return CGSize(width: side.rounded(.up), height: side.rounded(.up))
    }

    @MainActor
    private func load(targetSize: CGSize) async {
        cancel()
        guard let assetID, targetSize.width > 1, targetSize.height > 1 else {
            image = nil
            return
        }
        if let cached = thumbnails.cachedImage(
            for: assetID,
            targetSize: targetSize,
            quality: quality
        ) {
            image = cached
            return
        }
        // 快速滚动时一闪而过的格子不必发请求；停留超过一帧再加载。
        try? await Task.sleep(for: .milliseconds(80))
        guard !Task.isCancelled else { return }

        loadGeneration += 1
        let generation = loadGeneration
        requestID = thumbnails.load(
            assetID: assetID,
            targetSize: targetSize,
            quality: quality
        ) { loaded in
            guard generation == loadGeneration, let loaded else { return }
            // 缓存命中直接显示；只有真正解码出来的图淡入，避免入场时所有格子同一帧硬切。
            if reduceMotion {
                image = loaded
                return
            }
            withAnimation(.easeOut(duration: 0.16)) {
                image = loaded
            }
        }
    }

    private func cancel() {
        thumbnails.cancel(requestID)
        requestID = nil
    }
}

// MARK: - Empty

struct PendingPhotoWallEmptyState: View {
    let onViewHistory: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .frame(width: 84, height: 84)
                Image(systemName: "photo")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Theme.tertiaryText)
            }
            .padding(.bottom, 22)

            Text(L10n.string("No photos yet"))
                .font(.system(size: 21, weight: .bold))
                .foregroundColor(Theme.primaryText)
                .padding(.bottom, 10)

            Text(L10n.string("Your photo library is empty."))
                .font(.system(size: 13))
                .foregroundColor(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

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
        .padding(.horizontal, 24)
        .padding(.top, 100)
        .frame(maxWidth: .infinity)
    }
}
