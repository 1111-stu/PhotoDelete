//
//  AlbumBrowserViews.swift
//  PhotoDelete
//

import SwiftUI
import Photos

enum AlbumDisplayStyle: String, CaseIterable, Identifiable {
    case compact
    case cover
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: return L10n.string("Compact")
        case .cover: return L10n.string("Covers")
        case .list: return L10n.string("List")
        }
    }

    var icon: String {
        switch self {
        case .compact: return "square.grid.2x2"
        case .cover: return "rectangle.portrait"
        case .list: return "list.bullet"
        }
    }
}

enum AlbumBrowserContentFilter: String, CaseIterable, Identifiable {
    case all
    case photos
    case videos
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.string("All")
        case .photos: return L10n.string("Photos")
        case .videos: return L10n.string("Videos")
        case .favorites: return L10n.string("Favorite")
        }
    }

    var icon: String {
        switch self {
        case .all: return "photo.on.rectangle"
        case .photos: return "photo"
        case .videos: return "video"
        case .favorites: return "heart"
        }
    }
}

enum AlbumBrowserGrouping: String, CaseIterable, Identifiable {
    case none
    case day
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return L10n.string("None")
        case .day: return L10n.string("By Day")
        case .month: return L10n.string("By Month")
        }
    }
}

enum AlbumBrowserDensity: String, CaseIterable, Identifiable {
    case relaxed
    case standard
    case compact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relaxed: return L10n.string("Relaxed")
        case .standard: return L10n.string("Standard")
        case .compact: return L10n.string("Compact")
        }
    }

    var columnCount: Int {
        switch self {
        case .relaxed: return 2
        case .standard: return 3
        case .compact: return 4
        }
    }
}

enum AlbumBrowserSort: String, CaseIterable, Identifiable {
    case newest
    case oldest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return L10n.string("Newest")
        case .oldest: return L10n.string("Oldest")
        }
    }

    var icon: String {
        switch self {
        case .newest: return "arrow.down"
        case .oldest: return "arrow.up"
        }
    }
}

struct AlbumBrowserSection: Identifiable {
    let id: String
    let title: String
    let assets: [PHAsset]
}

enum AlbumBrowserGroupingBuilder {
    static func sections(
        from assets: [PHAsset],
        grouping: AlbumBrowserGrouping,
        calendar: Calendar = .current
    ) -> [AlbumBrowserSection] {
        switch grouping {
        case .none:
            return [AlbumBrowserSection(id: "all", title: "", assets: assets)]
        case .day:
            return grouped(assets, calendar: calendar) { date in
                calendar.startOfDay(for: date)
            } title: { date in
                dayTitle(for: date, calendar: calendar)
            }
        case .month:
            return grouped(assets, calendar: calendar) { date in
                calendar.dateInterval(of: .month, for: date)?.start ?? date
            } title: { date in
                AppDateFormatter.string(from: date, template: "yMMMM")
            }
        }
    }

    static func dayTitle(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return L10n.string("Today")
        }
        if calendar.isDateInYesterday(date) {
            return L10n.string("Yesterday")
        }
        let day = AppDateFormatter.string(from: date, template: "MMMd")
        let weekday = AppDateFormatter.string(from: date, template: "EEE")
        return "\(day) · \(weekday)"
    }

    private static func grouped(
        _ assets: [PHAsset],
        calendar: Calendar,
        start: (Date) -> Date,
        title: (Date) -> String
    ) -> [AlbumBrowserSection] {
        var buckets: [Date: [PHAsset]] = [:]
        var undated: [PHAsset] = []
        for asset in assets {
            guard let creationDate = asset.creationDate else {
                undated.append(asset)
                continue
            }
            let key = start(creationDate)
            buckets[key, default: []].append(asset)
        }

        var sections = buckets.keys.sorted(by: >).map { date in
            AlbumBrowserSection(id: "\(date.timeIntervalSince1970)", title: title(date), assets: buckets[date] ?? [])
        }
        if !undated.isEmpty {
            sections.append(AlbumBrowserSection(id: "undated", title: "", assets: undated))
        }
        return sections
    }
}

struct AlbumDisplayStyleSheet: View {
    @Binding var style: AlbumDisplayStyle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 10) {
                        ForEach(AlbumDisplayStyle.allCases) { item in
                            styleCard(item)
                        }
                    }
                }
                .padding(20)
            }
            .background(PhotoDeleteScreenBackground())
            .navigationTitle(L10n.string("Display"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel(L10n.string("Close"))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func styleCard(_ item: AlbumDisplayStyle) -> some View {
        let isSelected = style == item
        return Button {
            style = item
        } label: {
            VStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.title3.weight(.semibold))
                Text(item.title)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 84)
            .foregroundStyle(isSelected ? PhotoDeleteStyle.accent : PhotoDeleteStyle.primaryText)
            .background(
            RoundedRectangle(cornerRadius: PhotoDeleteStyle.Metrics.compactRadius, style: .continuous)
                    .fill(isSelected ? PhotoDeleteStyle.accent.opacity(0.16) : PhotoDeleteStyle.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 拖拽排序的「站位」：被拿起的那一格留在原位的空槽。
/// 尺寸与圆角跟随布局，画法与网格、列表一致（视觉基准见 designs/albums-reorder-prototype.html）。
struct AlbumDropSlot: View {
    var cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(PhotoDeleteStyle.dropSlotFill)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        PhotoDeleteStyle.dropSlotStroke,
                        style: StrokeStyle(
                            lineWidth: PhotoDeleteStyle.dropSlotLineWidth,
                            dash: PhotoDeleteStyle.dropSlotDash
                        )
                    )
            }
            .accessibilityHidden(true)
    }
}

/// 列表布局的每个相册：一张独立卡片（不再是「分组卡 + 分隔线」），
/// 拖拽时整张托出，空位是同样形状的卡槽。
struct AlbumListCard: View {
    let id: String
    let title: String
    let photosCount: Int
    let type: AlbumType
    let thumbnailAssetID: String?
    let photoLibraryManager: PhotoLibraryManager
    var isDropSlot = false

    var body: some View {
        Group {
            if isDropSlot {
                AlbumDropSlot(cornerRadius: PhotoDeleteStyle.albumListCardRadius)
                    .frame(maxWidth: .infinity, minHeight: PhotoDeleteStyle.albumListCardMinHeight)
            } else {
                AlbumInfoRow(
                    id: id,
                    title: title,
                    photosCount: photosCount,
                    type: type,
                    thumbnailAssetID: thumbnailAssetID,
                    photoLibraryManager: photoLibraryManager,
                    showsChevron: true
                )
                .equatable()
                .padding(.horizontal, 14)
                .frame(
                    maxWidth: .infinity,
                    minHeight: PhotoDeleteStyle.albumListCardMinHeight,
                    alignment: .leading
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: PhotoDeleteStyle.albumListCardRadius, style: .continuous)
                .fill(isDropSlot ? Color.clear : PhotoDeleteStyle.surface)
        )
        .contentShape(RoundedRectangle(cornerRadius: PhotoDeleteStyle.albumListCardRadius, style: .continuous))
    }
}

/// 相册长按菜单：整理 / 编辑 / 删除，最后一行小字说明拖动排序。
/// 用自绘浮层而不是系统 contextMenu —— 系统菜单只放得下可点条目，
/// 放不下这行说明，而它就是排序能力的唯一入口提示（见 docs/albums-reorder-research.md）。
struct AlbumActionMenu: View {
    let canOrganize: Bool
    let canEdit: Bool
    let onOrganize: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if canOrganize {
                row(L10n.string("Organize"), systemImage: "hand.draw", action: onOrganize)
            }
            if canEdit {
                row(L10n.string("Edit"), systemImage: "pencil", action: onEdit)
                row(L10n.string("Delete"), systemImage: "trash", isDestructive: true, action: onDelete)
            }

            Rectangle()
                .fill(PhotoDeleteStyle.hairline)
                .frame(height: 1)
                .padding(.top, 4)

            Text(L10n.string("Hold and drag to reorder"))
                .font(.system(size: 11.5))
                .foregroundStyle(PhotoDeleteStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.top, 9)
                .padding(.bottom, 5)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PhotoDeleteStyle.elevatedSurface)
        )
        .shadow(color: .black.opacity(0.45), radius: 22, x: 0, y: 12)
    }

    private func row(
        _ title: String,
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16))
                .foregroundStyle(isDestructive ? PhotoDeleteStyle.destructive : PhotoDeleteStyle.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct AlbumCoverTile: View {
    let title: String
    let photosCount: Int
    let thumbnailAssetID: String?
    let photoLibraryManager: PhotoLibraryManager
    let isCompact: Bool
    /// 拖拽排序时，被拿起的那一格渲染成空位（标题保留占位但不显示）。
    var isDropSlot = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                if isDropSlot {
                    AlbumDropSlot(cornerRadius: isCompact ? 14 : 18)
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    AlbumAssetThumbnail(
                        assetID: thumbnailAssetID,
                        photoLibraryManager: photoLibraryManager,
                        cornerRadius: isCompact ? 14 : 18,
                        emptyIcon: "photo.on.rectangle.angled"
                    )
                    .aspectRatio(1, contentMode: .fit)

                    Text(photosCount.formatted(.number.grouping(.automatic)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.55), in: Capsule(style: .continuous))
                        .padding(8)
                }
            }

            Text(title)
                .font(isCompact ? .caption.weight(.medium) : .subheadline.weight(.medium))
                .foregroundStyle(PhotoDeleteStyle.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .opacity(isDropSlot ? 0 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(L10n.photoCount(photosCount))")
        .accessibilityAddTraits(.isButton)
    }
}

struct AlbumAssetThumbnail: View {
    let assetID: String?
    let photoLibraryManager: PhotoLibraryManager
    var cornerRadius: CGFloat = 12
    var emptyIcon: String = "photo"

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?
    @State private var loadGeneration = 0

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    ZStack {
                        PhotoDeleteStyle.elevatedSurface

                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        } else {
                            Image(systemName: emptyIcon)
                                .font(.title2.weight(.medium))
                                .foregroundStyle(PhotoDeleteStyle.secondaryText)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .task(id: "\(assetID ?? "")-\(Int(proxy.size.width.rounded()))") {
                        load(side: proxy.size.width)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onDisappear {
            cancel()
        }
    }

    @MainActor
    private func load(side: CGFloat) {
        cancel()
        guard let assetID, side > 1 else {
            if assetID == nil {
                image = nil
            }
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
        let manager = photoLibraryManager
        requestID = manager.loadAlbumCoverThumbnail(for: asset, size: target) { loaded in
            guard generation == loadGeneration else { return }
            if let loaded {
                image = loaded
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

struct AlbumPhotoBrowserView: View {
    @EnvironmentObject private var dataManager: DataManager
    let album: AlbumInfo
    /// 右上角「整理」：从相册整本开始（保留相册进度语义）。
    let onOrganize: () -> Void

    @State private var assets: [PHAsset] = []
    @State private var isLoading = true
    @State private var showsFilters = false
    @State private var contentFilter: AlbumBrowserContentFilter = .all
    @State private var grouping: AlbumBrowserGrouping = .day
    @State private var density: AlbumBrowserDensity = .standard
    @State private var sort: AlbumBrowserSort = .newest
    /// 点缩略图：按当前筛选/排序，从该图起进入临时整理队列。
    @State private var reviewScope: ExplicitAssetReviewScope?
    @State private var showsReview = false

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else if visibleAssets.isEmpty {
                Text(L10n.string("This album has no photos yet"))
                    .font(.body)
                    .foregroundStyle(PhotoDeleteStyle.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            if !section.title.isEmpty {
                                HStack {
                                    Text(section.title)
                                        .font(.headline)
                                        .foregroundStyle(PhotoDeleteStyle.primaryText)
                                    Spacer()
                                    Text(L10n.photoCount(section.assets.count))
                                        .font(.subheadline)
                                        .foregroundStyle(PhotoDeleteStyle.secondaryText)
                                }
                            }

                            LazyVGrid(columns: gridColumns, spacing: 6) {
                                ForEach(section.assets, id: \.localIdentifier) { asset in
                                    Button {
                                        startOrganize(from: asset)
                                    } label: {
                                        AlbumAssetThumbnail(
                                            assetID: asset.localIdentifier,
                                            photoLibraryManager: dataManager.photoLibraryManager,
                                            cornerRadius: 10
                                        )
                                        .aspectRatio(1, contentMode: .fit)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(L10n.photoCount(1))
                                    .accessibilityHint(Text(L10n.string("Organize")))
                                    .accessibilityIdentifier("album-browser-asset-\(asset.localIdentifier)")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(PhotoDeleteScreenBackground())
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: onOrganize) {
                        Text(L10n.string("Organize"))
                    }
                    .disabled(album.photosCount == 0)
                    .accessibilityIdentifier("album-start-review")

                    Button {
                        showsFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .accessibilityLabel(L10n.string("Filter and sort"))
                }
            }
        }
        .sheet(isPresented: $showsFilters) {
            AlbumBrowserFilterSheet(
                assets: assets,
                contentFilter: $contentFilter,
                grouping: $grouping,
                density: $density,
                sort: $sort
            )
        }
        .navigationDestination(isPresented: $showsReview) {
            if let reviewScope {
                SwipePhotoView(
                    selectedCategory: nil,
                    selectedTimeGroup: nil,
                    selectedAlbumInfo: album,
                    explicitReviewScope: reviewScope
                )
                .environmentObject(dataManager)
            }
        }
        .task {
            await loadAssets()
        }
    }

    /// 从当前可见列表里点中的那张起，按现有顺序往后进入整理。
    private func startOrganize(from asset: PHAsset) {
        let ordered = visibleAssets
        guard let index = ordered.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) else {
            return
        }

        let ids = ordered[index...].map(\.localIdentifier)
        guard !ids.isEmpty else { return }

        HapticManager.impact(.light)
        reviewScope = ExplicitAssetReviewScope(orderedAssetIDs: ids, albumInfo: album)
        showsReview = true
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: density.columnCount)
    }

    private var visibleAssets: [PHAsset] {
        let filtered: [PHAsset]
        switch contentFilter {
        case .all:
            filtered = assets
        case .photos:
            filtered = assets.filter { $0.mediaType == .image }
        case .videos:
            filtered = assets.filter { $0.mediaType == .video }
        case .favorites:
            filtered = assets.filter(\.isFavorite)
        }

        return filtered.sorted { lhs, rhs in
            let left = lhs.creationDate ?? .distantPast
            let right = rhs.creationDate ?? .distantPast
            return sort == .newest ? left > right : left < right
        }
    }

    private var sections: [AlbumBrowserSection] {
        let built = AlbumBrowserGroupingBuilder.sections(from: visibleAssets, grouping: grouping)
        guard sort == .oldest, grouping != .none else { return built }
        return built.reversed()
    }

    private func loadAssets() async {
        let album = album
        let manager = dataManager
        let loaded = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: manager.getPhotosForAlbum(album))
            }
        }
        assets = loaded
        isLoading = false
    }
}

struct AlbumBrowserFilterSheet: View {
    let assets: [PHAsset]
    @Binding var contentFilter: AlbumBrowserContentFilter
    @Binding var grouping: AlbumBrowserGrouping
    @Binding var density: AlbumBrowserDensity
    @Binding var sort: AlbumBrowserSort
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if isDefault {
                        Text(L10n.string("Showing the default view"))
                            .font(.footnote)
                            .foregroundStyle(PhotoDeleteStyle.secondaryText)
                    }

                    filterSection(title: L10n.string("Content")) {
                        ForEach(AlbumBrowserContentFilter.allCases) { item in
                            countChip(
                                title: item.title,
                                icon: item.icon,
                                count: count(for: item),
                                isSelected: contentFilter == item
                            ) {
                                contentFilter = item
                            }
                        }
                    }

                    optionSection(title: L10n.string("Group by time"), options: AlbumBrowserGrouping.allCases.map(\.title), selection: grouping.title) { title in
                        grouping = AlbumBrowserGrouping.allCases.first { $0.title == title } ?? .day
                    }

                    optionSection(title: L10n.string("Grid density"), options: AlbumBrowserDensity.allCases.map(\.title), selection: density.title) { title in
                        density = AlbumBrowserDensity.allCases.first { $0.title == title } ?? .standard
                    }

                    optionSection(title: L10n.string("Sort"), options: AlbumBrowserSort.allCases.map(\.title), selection: sort.title) { title in
                        sort = AlbumBrowserSort.allCases.first { $0.title == title } ?? .newest
                    }
                }
                .padding(20)
            }
            .background(PhotoDeleteScreenBackground())
            .navigationTitle(L10n.string("Filter and sort"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("Reset")) {
                        contentFilter = .all
                        grouping = .day
                        density = .standard
                        sort = .newest
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isDefault: Bool {
        contentFilter == .all && grouping == .day && density == .standard && sort == .newest
    }

    private func count(for filter: AlbumBrowserContentFilter) -> Int {
        switch filter {
        case .all:
            return assets.count
        case .photos:
            return assets.filter { $0.mediaType == .image }.count
        case .videos:
            return assets.filter { $0.mediaType == .video }.count
        case .favorites:
            return assets.filter(\.isFavorite).count
        }
    }

    private func filterSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PhotoDeleteStyle.secondaryText)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                content()
            }
        }
    }

    private func countChip(title: String, icon: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(count.formatted(.number.grouping(.automatic)))
                    .font(.caption2)
                    .foregroundStyle(PhotoDeleteStyle.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 78)
            .foregroundStyle(isSelected ? PhotoDeleteStyle.accent : PhotoDeleteStyle.primaryText)
            .background(
                RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                    .fill(PhotoDeleteStyle.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? PhotoDeleteStyle.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func optionSection(title: String, options: [String], selection: String, onSelect: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PhotoDeleteStyle.secondaryText)
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = option == selection
                    Button {
                        onSelect(option)
                    } label: {
                        Text(option)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 40)
                            .foregroundStyle(isSelected ? PhotoDeleteStyle.primaryText : PhotoDeleteStyle.secondaryText)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? PhotoDeleteStyle.elevatedSurface : PhotoDeleteStyle.surface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
