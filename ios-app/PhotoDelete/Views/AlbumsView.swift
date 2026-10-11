//
//  AlbumsView.swift
//  PhotoDelete
//
//  Created by PhotoDelete Team on 11/7/25.
//

import Combine
import SwiftUI
import Photos
#if canImport(UIKit)
import UIKit
#endif

/// Lightweight, equatable row model so List rows only rebuild when display data changes.
private struct AlbumListRowModel: Identifiable, Equatable {
    let id: String
    let title: String
    let photosCount: Int
    let type: AlbumType
    let thumbnailAssetID: String?
    let canEdit: Bool

    static func == (lhs: AlbumListRowModel, rhs: AlbumListRowModel) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.photosCount == rhs.photosCount
            && lhs.type == rhs.type
            && lhs.thumbnailAssetID == rhs.thumbnailAssetID
            && lhs.canEdit == rhs.canEdit
    }
}

struct AlbumsView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var activeSheet: AlbumSheet?
    @AppStorage(AppConstants.albumDisplayStyleKey) private var albumDisplayStyleValue = AlbumDisplayStyle.cover.rawValue
    @State private var showsDisplayStyle = false
    @State private var albumToast: PhotoDeleteToast?
    @State private var displayedRows: [AlbumListRowModel] = []
    @State private var albumsByID: [String: AlbumInfo] = [:]
    @State private var displayedAlbumCount = 0

    // MARK: - 长按拖拽排序
    @State private var reorder = AlbumReorderSession()
    /// 按下瞬间的槽位（内容坐标系，已排除被拿起的那一格），换位判定以这份快照为准，
    /// 避免让位动画把实时 frame 喂回判定里造成抖动。
    @State private var reorderSlots: [String: CGRect] = [:]
    @State private var reorderSlotOrder: [String] = []
    @State private var itemFrames: [String: CGRect] = [:]
    @State private var dragStartFrame: CGRect = .zero
    @State private var dragGrabPoint: CGPoint?
    @State private var dragTranslation: CGSize = .zero
    @State private var lastViewportPoint: CGPoint?
    @State private var contentScrollOffset: CGFloat = 0
    @State private var viewportSize: CGSize = .zero
    @State private var actionMenu: AlbumActionMenuTarget?
    @State private var menuSize: CGSize = .zero
    @State private var suppressItemTapUntil = Date.distantPast
    @State private var lastAutoScrollAt = Date.distantPast
    /// Debug: last scroll offset we printed (avoid PreferenceKey spam).
    @State private var lastLoggedScrollOffset: CGFloat = .nan

    private static let contentSpace = "albums-content"
    private static let viewportSpace = "albums-viewport"
    /// 长按确认时长；与 UI 测试里的 hold 时长对齐。
    private static let reorderLongPressDuration: Double = 0.45
    /// 长按允许的抖动；超过则视为滚动/滑动，整段排序手势失败，把 pan 还给 ScrollView。
    private static let reorderLongPressSlop: CGFloat = 14
    /// 超过该位移才从「抬起 + 菜单」进入真正换位。
    private static let reorderDragThreshold: CGFloat = 6

    var body: some View {
        NavigationStack(path: $navigationPath) {
            rootContent
                .frame(maxWidth: PhotoDeleteAdaptiveLayout.listContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
                .background {
                    PhotoDeleteScreenBackground()
                }
                .overlay {
                    if let albumToast {
                        albumToastView(albumToast)
                    }
                }
                .navigationDestination(for: AlbumNavigationDestination.self) { destination in
                    switch destination {
                    case .swipeAlbum(let selectedSwipeAlbum):
                        SwipePhotoView(selectedCategory: nil, selectedTimeGroup: nil, selectedAlbumInfo: selectedSwipeAlbum)
                            .environmentObject(dataManager)
                    case .browser(let album):
                        AlbumPhotoBrowserView(album: album)
                            .environmentObject(dataManager)
                    }
                }
        }
        .sheet(isPresented: $showsDisplayStyle) {
            AlbumDisplayStyleSheet(style: displayStyleBinding)
        }
        .fullScreenCover(item: $activeSheet) { sheet in
            Group {
                switch sheet {
                case .create:
                    CreateAlbumView()
                case .edit(let album):
                    EditAlbumView(album: album)
                }
            }
            .environmentObject(dataManager)
            .presentationBackground(.clear)
        }
        .onChange(of: searchText) { _ in
            rebuildDisplayedRows()
        }
        .onChange(of: albumDisplayStyleValue) { _ in
            endReorderIfNeeded()
        }
        .onChange(of: reorder.isDragging) { isDragging in
            AlbumScrollDebug.log(
                "scrollDisabled(isDragging)=\(isDragging) \(reorderDebugSnapshot())"
            )
        }
        .onChange(of: actionMenu?.id) { menuID in
            AlbumScrollDebug.log(
                "actionMenu=\(menuID ?? "nil") hitTestWhenIdle=\(menuID != nil) \(reorderDebugSnapshot())"
            )
        }
        .onDisappear {
            AlbumScrollDebug.log("onDisappear → cancelReorder")
            cancelReorder()
        }
        .onReceive(dataManager.$userAlbums) { _ in
            rebuildDisplayedRows()
        }
        .onAppear {
            dataManager.loadAlbumsIfNeeded()
            rebuildDisplayedRows()
        }
    }

    private var rootContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            albumsTitleBar

            if !dataManager.photoLibraryManager.hasPhotoLibraryAccess {
                authorizationSection
            } else {
                albumBrowser
            }
        }
    }

    /// 相册页顶栏（对齐 style.md §4.5：左侧大标题 34/700 + 右上圆钮）。
    /// 排序不再有编辑模式：长按即可拖动，右上只保留显示方式入口。
    private var albumsTitleBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(L10n.string("Albums"))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(PhotoDeleteStyle.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if dataManager.photoLibraryManager.hasPhotoLibraryAccess {
                displayStyleEntryButton
            }
        }
        .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    /// 右上角显示方式入口：iOS 26+ 用液态玻璃，老系统回落实心圆钮。
    @ViewBuilder
    private var displayStyleEntryButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                showsDisplayStyle = true
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .foregroundStyle(PhotoDeleteStyle.primaryText)
            .accessibilityLabel(L10n.string("Display"))
            .accessibilityIdentifier("album-display-style")
        } else {
            Button {
                showsDisplayStyle = true
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                    .frame(width: 44, height: 44)
                    .background(PhotoDeleteStyle.elevatedSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("Display"))
            .accessibilityIdentifier("album-display-style")
        }
    }

    private var displayStyle: AlbumDisplayStyle {
        AlbumDisplayStyle(rawValue: albumDisplayStyleValue) ?? .cover
    }

    private var displayStyleBinding: Binding<AlbumDisplayStyle> {
        Binding(
            get: { displayStyle },
            set: { albumDisplayStyleValue = $0.rawValue }
        )
    }

    /// 搜索框 + 新建相册：新建入口贴着搜索栏右侧，同高 44。
    private var albumSearchRow: some View {
        HStack(spacing: 10) {
            albumSearchField

            Button(action: createAlbum) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PhotoDeleteStyle.primaryText)
                    .frame(width: 44, height: 44)
                    .background(PhotoDeleteStyle.elevatedSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("Create Album"))
        }
    }

    private var albumSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PhotoDeleteStyle.secondaryText)
            TextField(L10n.string("Search albums"), text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(PhotoDeleteStyle.elevatedSurface, in: RoundedRectangle(cornerRadius: PhotoDeleteStyle.Metrics.compactRadius, style: .continuous))
    }

    private func createAlbum() {
        HapticManager.impact(.light)
        activeSheet = .create
    }

    // MARK: - 权限授权区域
    private var authorizationSection: some View {
        VStack {
            Spacer()
            PhotoAuthorizationCard(
                subtitle: L10n.string("OnePhoto needs photo library access to manage albums. \(AppConstants.privacyShortText)"),
                onRequestAccess: { dataManager.requestPhotoLibraryAccess() }
            )
            .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
            Spacer()
        }
    }

    // MARK: - 相册列表（三种布局共用一个滚动容器）
    private var albumBrowser: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    scrollOffsetReader

                    Text(albumHeaderSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(PhotoDeleteStyle.secondaryText)

                    albumSearchRow

                    if isLoadingAlbums {
                        loadingRow
                    } else if displayedRows.isEmpty {
                        emptyRow
                    } else {
                        albumItems(proxy: proxy)
                    }
                }
                .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                .padding(.top, 4)
                .padding(.bottom, PhotoDeleteStyle.Metrics.bottomChromeSpacing)
                .coordinateSpace(name: Self.contentSpace)
                .overlay(alignment: .topLeading) {
                    reorderOverlays
                }
            }
            .coordinateSpace(name: Self.viewportSpace)
            // A long-press menu is not a reorder yet. Keep the scroll view live
            // until the drag has actually crossed the movement threshold.
            .scrollDisabled(reorder.isDragging)
            .scrollDismissesKeyboard(.immediately)
            .background(viewportSizeReader)
            .refreshable {
                dataManager.loadAlbums(showLoading: false)
            }
            .onAppear {
                AlbumScrollDebug.log(
                    "albumBrowser appear scrollDisabled=\(reorder.isDragging) rows=\(displayedRows.count) \(reorderDebugSnapshot())"
                )
            }
            .onPreferenceChange(AlbumItemFramesKey.self) { frames in
                itemFrames = frames
            }
            .onPreferenceChange(AlbumsScrollOffsetKey.self) { contentMinY in
                // contentMinY 是内容顶部在视口里的位置：向下滚动时为负，取反才是滚动距离。
                let nextOffset = -contentMinY
                let previous = contentScrollOffset
                contentScrollOffset = nextOffset
                logScrollOffsetIfNeeded(previous: previous, next: nextOffset, contentMinY: contentMinY)
                // 自动滚动会改变手指下方的内容，落点要跟着重算。
                if reorder.isDragging, let viewportPoint = lastViewportPoint {
                    updateReorder(viewportPoint: viewportPoint, proxy: proxy)
                }
            }
        }
    }

    private func reorderDebugSnapshot() -> String {
        "phase=\(reorder.phase) item=\(reorder.itemID ?? "nil") menu=\(actionMenu?.id ?? "nil") offset=\(Int(contentScrollOffset)) viewport=\(Int(viewportSize.width))x\(Int(viewportSize.height))"
    }

    private func logScrollOffsetIfNeeded(previous: CGFloat, next: CGFloat, contentMinY: CGFloat) {
        let delta = abs(next - (lastLoggedScrollOffset.isNaN ? next : lastLoggedScrollOffset))
        // PreferenceKey 很吵：位移 < 2pt 或与上次相同则跳过。
        guard delta >= 2 || lastLoggedScrollOffset.isNaN else { return }
        lastLoggedScrollOffset = next
        AlbumScrollDebug.log(
            "scrollOffset \(Int(previous))→\(Int(next)) (minY=\(Int(contentMinY))) delta=\(Int(next - previous)) \(reorderDebugSnapshot())"
        )
    }

    private var albumColumnCount: Int {
        switch displayStyle {
        case .compact:
            return horizontalSizeClass == .regular ? 5 : 3
        case .cover:
            return horizontalSizeClass == .regular ? 4 : 2
        case .list:
            return 1
        }
    }

    @ViewBuilder
    private func albumItems(proxy: ScrollViewProxy) -> some View {
        let rows = Array(displayedRows.enumerated())
        if displayStyle == .list {
            LazyVStack(spacing: PhotoDeleteStyle.albumListCardSpacing) {
                ForEach(rows, id: \.element.id) { index, row in
                    albumItem(row, index: index, proxy: proxy)
                        .id(row.id)
                }
            }
        } else {
            LazyVGrid(columns: gridColumns, spacing: 18) {
                ForEach(rows, id: \.element.id) { index, row in
                    albumItem(row, index: index, proxy: proxy)
                        .id(row.id)
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: albumColumnCount)
    }

    private func albumItem(_ row: AlbumListRowModel, index: Int, proxy: ScrollViewProxy) -> some View {
        let isLifted = reorder.itemID == row.id
        let isPlaceholder = isLifted && reorder.isDragging
        // No `Button`: its gesture wins over `.gesture(UIGestureRecognizerRepresentable)`
        // and long-press never fires (logs showed itemTap only, never UIKit18 began).
        return albumItemContent(row, isPlaceholder: isPlaceholder)
            // Hide the armed card without changing its slot geometry.
            .opacity(isLifted && !isPlaceholder ? 0 : 1)
            .background(itemFrameReader(row.id))
            .contentShape(Rectangle())
            .onTapGesture {
                AlbumScrollDebug.log("itemTap id=\(row.id) \(reorderDebugSnapshot())")
                openAlbum(id: row.id)
            }
            .gesture(albumReorderGesture(row: row, index: index, proxy: proxy))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("album-item-\(row.id)")
            .accessibilityLabel("\(row.title), \(L10n.photoCount(row.photosCount))")
            .accessibilityHint(L10n.string("Tap to organize this album"))
            .accessibilityValue(positionText(for: index))
            .accessibilityAction(named: Text(L10n.string("Move up"))) {
                moveAlbum(id: row.id, by: -1)
            }
            .accessibilityAction(named: Text(L10n.string("Move down"))) {
                moveAlbum(id: row.id, by: 1)
            }
    }

    private func albumReorderGesture(
        row: AlbumListRowModel,
        index: Int,
        proxy: ScrollViewProxy
    ) -> AlbumReorderLongPressGesture {
        AlbumReorderLongPressGesture(
            minimumPressDuration: Self.reorderLongPressDuration,
            allowableMovement: Self.reorderLongPressSlop,
            isEnabled: searchText.isEmpty,
            viewportSpaceName: Self.viewportSpace,
            contentSpaceName: Self.contentSpace,
            onBegan: { viewport, content in
                handleItemReorderBegan(
                    row: row,
                    index: index,
                    viewportPoint: viewport,
                    contentPoint: content,
                    proxy: proxy
                )
            },
            onChanged: { viewport, content in
                handleItemReorderChanged(
                    rowID: row.id,
                    viewportPoint: viewport,
                    contentPoint: content,
                    proxy: proxy
                )
            },
            onEnded: { viewport, content in
                handleItemReorderEnded(
                    rowID: row.id,
                    viewportPoint: viewport,
                    contentPoint: content,
                    proxy: proxy
                )
            },
            onCancelled: {
                AlbumScrollDebug.log("item gesture cancelled row=\(row.id) \(reorderDebugSnapshot())")
                if reorder.itemID == row.id { cancelReorder() }
            }
        )
    }

    @ViewBuilder
    private func albumItemContent(_ row: AlbumListRowModel, isPlaceholder: Bool) -> some View {
        if displayStyle == .list {
            AlbumListCard(
                id: row.id,
                title: row.title,
                photosCount: row.photosCount,
                type: row.type,
                thumbnailAssetID: row.thumbnailAssetID,
                photoLibraryManager: dataManager.photoLibraryManager,
                isDropSlot: isPlaceholder
            )
        } else {
            AlbumCoverTile(
                title: row.title,
                photosCount: row.photosCount,
                thumbnailAssetID: row.thumbnailAssetID,
                photoLibraryManager: dataManager.photoLibraryManager,
                isCompact: displayStyle == .compact,
                isDropSlot: isPlaceholder
            )
        }
    }

    /// 读屏时的位置播报（「第 3 个，共 9 个」）。
    private func positionText(for index: Int) -> String {
        L10n.string("\(index + 1) of \(displayedRows.count)")
    }

    private var loadingRow: some View {
        let progress = activeAlbumLoadingProgress

        return VStack(spacing: 14) {
            VStack(spacing: 8) {
                ProgressView(value: max(progress, 0.03))
                    .progressViewStyle(LinearProgressViewStyle(tint: PhotoDeleteStyle.accent))
                    .frame(maxWidth: 220)
                    .clipShape(Capsule(style: .continuous))

                Text(progress > 0.01 ? L10n.percent(Int(progress * 100)) : L10n.string("Preparing"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.tertiaryText)
            }

            VStack(spacing: 5) {
                Text(albumLoadingTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)

                Text(albumLoadingMessage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PhotoDeleteStyle.Metrics.contentBottomPadding)
    }

    private var emptyRow: some View {
        Group {
            if #available(iOS 17.0, *) {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: searchText.isEmpty ? "photo.stack" : "magnifyingglass",
                    description: Text(emptyMessage)
                )
                .foregroundStyle(PhotoDeleteStyle.secondaryText)
            } else {
                VStack(spacing: 18) {
                    Image(systemName: searchText.isEmpty ? "photo.stack" : "magnifyingglass")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)

                    VStack(spacing: 6) {
                        Text(emptyTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(PhotoDeleteStyle.primaryText)

                        Text(emptyMessage)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(PhotoDeleteStyle.secondaryText)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 58)
    }

    private var emptyTitle: String {
        searchText.isEmpty ? L10n.string("No Albums Yet") : L10n.string("No Albums Found")
    }

    private var emptyMessage: String {
        searchText.isEmpty ? L10n.string("Tap the plus button in the top right to create a new album.") : L10n.string("Try another keyword.")
    }

    private var albumHeaderSubtitle: String {
        if isLoadingPhotoLibraryForAlbums {
            return L10n.string("Initializing Photo Library")
        }
        if dataManager.isLoadingAlbums && displayedAlbumCount == 0 {
            return L10n.string("Updating Album List")
        }
        return L10n.string("\(displayedAlbumCount) albums")
    }

    // MARK: - 计算属性
    private var isLoadingAlbums: Bool {
        displayedRows.isEmpty &&
            (dataManager.isLoadingAlbums || isLoadingPhotoLibraryForAlbums) &&
            searchText.isEmpty
    }

    private var isLoadingPhotoLibraryForAlbums: Bool {
        dataManager.photoLibraryManager.isLoading &&
            !dataManager.photoLibraryManager.hasLoadedPhotoLibrary
    }

    private var activeAlbumLoadingProgress: Double {
        let progress = isLoadingPhotoLibraryForAlbums
            ? dataManager.photoLibraryManager.loadingProgress
            : dataManager.albumLoadingProgress
        return min(max(progress, 0), 1)
    }

    private var albumLoadingTitle: String {
        isLoadingPhotoLibraryForAlbums ? L10n.string("Initializing Photo Library") : L10n.string("Updating Album List")
    }

    private var albumLoadingMessage: String {
        isLoadingPhotoLibraryForAlbums
            ? L10n.string("Reading album counts and covers. Your albums will appear when ready.")
            : L10n.string("Counting albums and loading covers.")
    }

    // MARK: - 长按拖拽排序
    //
    // 手势契约（iOS 18 `UIGestureRecognizerRepresentable`）：
    // 1. idle 滚动：长按未识别前 ScrollView pan 正常；位移 > slop → 长按失败
    // 2. 长按成功：`.began` → arm（浮起 + 菜单）
    // 3. 继续拖动：同一识别器 `.changed` → 超过阈值后 beginDragging
    // 4. 原地松手：finish 但不提交顺序，菜单保留可点
    // 5. 系统取消：`.cancelled` / `.failed` → cancelReorder

    /// 内容坐标系里的拖动点：视口坐标 + 当前滚动偏移（自动滚动回调等兜底路径）。
    private func contentPoint(for viewportPoint: CGPoint) -> CGPoint {
        CGPoint(x: viewportPoint.x, y: viewportPoint.y + contentScrollOffset)
    }

    private func handleItemReorderBegan(
        row: AlbumListRowModel,
        index: Int,
        viewportPoint: CGPoint,
        contentPoint: CGPoint,
        proxy: ScrollViewProxy
    ) {
        AlbumScrollDebug.log(
            "item began row=\(row.id) index=\(index) \(reorderDebugSnapshot())"
        )
        armReorder(row: row, index: index)
        guard reorder.isActive else { return }
        updateReorder(
            viewportPoint: viewportPoint,
            contentPoint: contentPoint,
            startContentPoint: contentPoint,
            proxy: proxy
        )
    }

    private func handleItemReorderChanged(
        rowID: String,
        viewportPoint: CGPoint,
        contentPoint: CGPoint,
        proxy: ScrollViewProxy
    ) {
        guard reorder.itemID == rowID else { return }
        updateReorder(
            viewportPoint: viewportPoint,
            contentPoint: contentPoint,
            proxy: proxy
        )
    }

    private func handleItemReorderEnded(
        rowID: String,
        viewportPoint: CGPoint,
        contentPoint: CGPoint,
        proxy: ScrollViewProxy
    ) {
        guard reorder.itemID == rowID else { return }
        updateReorder(
            viewportPoint: viewportPoint,
            contentPoint: contentPoint,
            proxy: proxy
        )
        finishReorder()
    }

    /// 长按抬起：记下按下瞬间的槽位快照，卡片离手但还没有换位。
    private func armReorder(row: AlbumListRowModel, index: Int) {
        guard !reorder.isActive else { return }
        guard searchText.isEmpty else {
            AlbumScrollDebug.log("arm blocked: search active row=\(row.id)")
            showAlbumToast(
                L10n.string("Clear search before reordering"),
                icon: "magnifyingglass",
                style: .warning
            )
            return
        }
        guard let frame = itemFrames[row.id] else {
            AlbumScrollDebug.log("arm blocked: missing frame row=\(row.id)")
            return
        }

        reorderSlots = itemFrames.filter { $0.key != row.id }
        reorderSlotOrder = displayedRows.map(\.id).filter { $0 != row.id }
        dragStartFrame = frame
        dragGrabPoint = nil
        dragTranslation = .zero
        lastViewportPoint = nil
        suppressItemTapUntil = Date().addingTimeInterval(0.6)
        reorder.arm(itemID: row.id, index: index)
        // 长按确认后立即展示操作菜单；继续移动时会在进入拖动状态时收起。
        actionMenu = AlbumActionMenuTarget(id: row.id)
        AlbumScrollDebug.log(
            "arm row=\(row.id) index=\(index) frame=\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height)) \(reorderDebugSnapshot())"
        )
        HapticManager.impact(.medium)
    }

    private func updateReorder(
        viewportPoint: CGPoint,
        contentPoint resolvedContentPoint: CGPoint? = nil,
        startContentPoint: CGPoint? = nil,
        proxy: ScrollViewProxy
    ) {
        guard reorder.isActive else { return }
        lastViewportPoint = viewportPoint

        // 抓起的位置：保住抓取偏移，卡片不会在抬起的瞬间跳一下。
        let point = resolvedContentPoint ?? contentPoint(for: viewportPoint)
        if dragGrabPoint == nil {
            dragGrabPoint = startContentPoint ?? point
        }
        let grabPoint = dragGrabPoint ?? point
        dragTranslation = CGSize(
            width: point.x - grabPoint.x,
            height: point.y - grabPoint.y
        )

        if !reorder.isDragging,
           hypot(dragTranslation.width, dragTranslation.height) > Self.reorderDragThreshold {
            // 菜单只服务于长按停留状态，手指一旦开始移动就让出视觉空间给排序。
            actionMenu = nil
            reorder.beginDragging()
            AlbumScrollDebug.log(
                "beginDragging t=(\(Int(dragTranslation.width)),\(Int(dragTranslation.height))) \(reorderDebugSnapshot())"
            )
        }
        guard reorder.isDragging else { return }

        applyInsertion(for: point)
        autoScrollIfNeeded(viewportPoint: viewportPoint, proxy: proxy)
    }

    /// 让位：越过其他格子中心时重排数组，其余卡片 0.22s 平移让开。
    private func applyInsertion(for point: CGPoint) {
        let frames = reorderSlotOrder.compactMap { reorderSlots[$0] }
        let target = AlbumReorderGeometry.insertionIndex(for: point, itemFrames: frames)
        guard reorder.updateInsertIndex(target) else { return }
        guard let id = reorder.itemID,
              let from = displayedRows.firstIndex(where: { $0.id == id }) else { return }

        withAnimation(.easeOut(duration: 0.22)) {
            displayedRows = AlbumReorderGeometry.moving(displayedRows, from: from, to: target)
        }
        HapticManager.impact(.light)
    }

    private func finishReorder() {
        guard reorder.isActive else { return }
        let wasDragging = reorder.isDragging
        let hasMove = reorder.hasPendingMove
        AlbumScrollDebug.log(
            "finish wasDragging=\(wasDragging) hasMove=\(hasMove) \(reorderDebugSnapshot())"
        )

        reorder.reset()
        reorderSlots = [:]
        reorderSlotOrder = []
        dragGrabPoint = nil
        dragTranslation = .zero
        lastViewportPoint = nil
        suppressItemTapUntil = Date().addingTimeInterval(0.4)

        if wasDragging {
            guard hasMove else {
                AlbumScrollDebug.log("finish: drag without move, keep order")
                return
            }
            dataManager.saveCustomAlbumOrder(displayedRows.map(\.id))
            HapticManager.impact(.light)
            showAlbumToast(L10n.string("Album order saved"), icon: "checkmark", style: .positive)
        } else {
            // 原地松手保留长按时已展示的菜单，并允许点击菜单操作。
            suppressItemTapUntil = Date().addingTimeInterval(1.2)
            AlbumScrollDebug.log("finish: keep action menu \(actionMenu?.id ?? "nil")")
        }
    }

    private func endReorderIfNeeded() {
        if reorder.isActive {
            finishReorder()
        }
        actionMenu = nil
    }

    private func cancelReorder() {
        AlbumScrollDebug.log("cancelReorder \(reorderDebugSnapshot())")
        reorder.reset()
        reorderSlots = [:]
        reorderSlotOrder = []
        dragGrabPoint = nil
        dragTranslation = .zero
        lastViewportPoint = nil
        actionMenu = nil
        rebuildDisplayedRows()
    }

    /// 拖到滚动区上下边缘时自动滚动（滚动本身会改内容，落点由偏移变化的回调重算）。
    private func autoScrollIfNeeded(viewportPoint: CGPoint, proxy: ScrollViewProxy) {
        guard viewportSize.height > 0 else { return }
        let band: CGFloat = 70
        let targetIndex: Int
        if viewportPoint.y < band {
            targetIndex = max(reorder.insertIndex - 1, 0)
        } else if viewportPoint.y > viewportSize.height - band {
            targetIndex = min(reorder.insertIndex + 1, displayedRows.count - 1)
        } else {
            return
        }
        guard displayedRows.indices.contains(targetIndex) else { return }

        let now = Date()
        guard now.timeIntervalSince(lastAutoScrollAt) > 0.28 else { return }
        lastAutoScrollAt = now

        let id = displayedRows[targetIndex].id
        withAnimation(.easeOut(duration: 0.22)) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    /// 无障碍路径：没有长按拖动的用户，用「上移 / 下移」动作改顺序。
    private func moveAlbum(id: String, by offset: Int) {
        guard let from = displayedRows.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard displayedRows.indices.contains(to) else { return }

        withAnimation(.easeOut(duration: 0.22)) {
            displayedRows.swapAt(from, to)
        }
        dataManager.saveCustomAlbumOrder(displayedRows.map(\.id))
        HapticManager.impact(.light)
    }

    // MARK: 排序相关的浮层与测量

    private func itemFrameReader(_ id: String) -> some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: AlbumItemFramesKey.self,
                value: [id: geometry.frame(in: .named(Self.contentSpace))]
            )
        }
    }

    private var scrollOffsetReader: some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: AlbumsScrollOffsetKey.self,
                value: geometry.frame(in: .named(Self.viewportSpace)).minY
            )
        }
        .frame(height: 0)
    }

    private var viewportSizeReader: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear { viewportSize = geometry.size }
                .onChange(of: geometry.size) { newValue in
                    viewportSize = newValue
                }
        }
    }

    private var reorderOverlays: some View {
        // The full-size menu dismissal layer must not recenter the card.
        ZStack(alignment: .topLeading) {
            if let actionMenu {
                actionMenuOverlay(actionMenu)
            }
            if let id = reorder.itemID,
               let row = displayedRows.first(where: { $0.id == id }) {
                floatingCard(row)
            }
        }
    }

    /// 浮起的卡片：跟手移动、带阴影，形状与原来那一格一致。
    private func floatingCard(_ row: AlbumListRowModel) -> some View {
        let lift: CGFloat = displayStyle == .list ? 1.035 : 1.06
        return albumItemContent(row, isPlaceholder: false)
            .frame(
                width: dragStartFrame.width,
                height: dragStartFrame.height,
                alignment: .topLeading
            )
            .scaleEffect(lift)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            .offset(
                x: dragStartFrame.minX + dragTranslation.width,
                y: dragStartFrame.minY + dragTranslation.height
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .zIndex(30)
    }

    private func actionMenuOverlay(_ target: AlbumActionMenuTarget) -> some View {
        let anchor = itemFrames[target.id] ?? .zero
        let menuWidth = max(menuSize.width, 208)
        let x = min(
            max(anchor.minX, 16),
            max(16, viewportSize.width - menuWidth - 16)
        )
        let visibleTop = contentScrollOffset + 12
        let visibleBottom = contentScrollOffset + viewportSize.height - 12
        var y = anchor.maxY + 8
        if y + menuSize.height > visibleBottom {
            y = anchor.minY - menuSize.height - 8
        }
        y = max(visibleTop, min(y, max(visibleTop, visibleBottom - menuSize.height)))

        return ZStack(alignment: .topLeading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    AlbumScrollDebug.log("menuDismissTap \(reorderDebugSnapshot())")
                    actionMenu = nil
                }

            AlbumActionMenu(
                canOrganize: albumPhotosCount(target.id) > 0,
                canEdit: displayedRows.first(where: { $0.id == target.id })?.canEdit == true,
                onOrganize: {
                    let id = target.id
                    actionMenu = nil
                    openAlbumSwipe(id: id)
                },
                onEdit: {
                    let id = target.id
                    actionMenu = nil
                    editAlbum(id: id)
                },
                onDelete: {
                    let id = target.id
                    actionMenu = nil
                    deleteAlbum(id: id)
                }
            )
            .frame(width: menuWidth)
            .accessibilityIdentifier("album-action-menu")
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { menuSize = geometry.size }
                        .onChange(of: geometry.size) { newValue in
                            menuSize = newValue
                        }
                }
            )
            .offset(x: x, y: y)
        }
        .zIndex(20)
        // 长按确认后菜单需要可见，但不能在同一根手指仍按住时拦截拖动手势。
        .allowsHitTesting(!reorder.isActive)
    }

    private func albumPhotosCount(_ id: String) -> Int {
        displayedRows.first(where: { $0.id == id })?.photosCount ?? 0
    }

    // MARK: - 方法
    private func rebuildDisplayedRows() {
        // 拖动期间冻结列表：图库刷新或 DataManager 发布会打断手势与落点。
        guard !reorder.isActive else { return }

        let sourceAlbums = dataManager.getUserAlbums()
        displayedAlbumCount = sourceAlbums.count

        let sorted = DataManager.albumsSortedByCustomOrder(
            sourceAlbums,
            customOrder: dataManager.customAlbumOrderForDisplay
        )
        let filtered: [AlbumInfo]
        if searchText.isEmpty {
            filtered = sorted
        } else {
            filtered = sorted.filter { $0.title.localizedStandardContains(searchText) }
        }

        var nextAlbumsByID: [String: AlbumInfo] = [:]
        nextAlbumsByID.reserveCapacity(filtered.count)

        let rows: [AlbumListRowModel] = filtered.map { album in
            nextAlbumsByID[album.id] = album
            let canEdit: Bool = {
                guard let collection = album.assetCollection,
                      collection.assetCollectionType == .album else {
                    return false
                }
                // Defer expensive canPerform checks: album type is enough for swipe affordance;
                // Photos will refuse the write if unsupported.
                return true
            }()

            return AlbumListRowModel(
                id: album.id,
                title: album.title,
                photosCount: album.photosCount,
                type: album.type,
                thumbnailAssetID: album.thumbnailAsset?.localIdentifier,
                canEdit: canEdit && album.type == .userCreated
            )
        }

        // Avoid redundant state writes that force List to re-diff every unrelated DataManager publish.
        if rows != displayedRows {
            displayedRows = rows
        }
        albumsByID = nextAlbumsByID
    }

    private func openAlbum(id: String) {
        guard !reorder.isActive, actionMenu == nil else { return }
        guard Date() >= suppressItemTapUntil else { return }
        guard let albumInfo = albumsByID[id] ?? dataManager.userAlbums.first(where: { $0.id == id }) else {
            HapticManager.impact(.light)
            showAlbumToast(L10n.string("This album no longer exists. The list has been updated."), icon: "arrow.clockwise", style: .warning)
            rebuildDisplayedRows()
            return
        }

        guard let currentAlbumInfo = dataManager.currentUserAlbumInfo(for: albumInfo) else {
            HapticManager.impact(.light)
            showAlbumToast(L10n.string("This album no longer exists. The list has been updated."), icon: "arrow.clockwise", style: .warning)
            rebuildDisplayedRows()
            return
        }

        HapticManager.impact(.light)
        navigationPath.append(AlbumNavigationDestination.browser(currentAlbumInfo))
    }

    private func openAlbumSwipe(id: String) {
        guard let albumInfo = albumsByID[id] ?? dataManager.userAlbums.first(where: { $0.id == id }),
              let currentAlbumInfo = dataManager.currentUserAlbumInfo(for: albumInfo),
              currentAlbumInfo.photosCount > 0 else {
            HapticManager.impact(.light)
            showAlbumToast(L10n.string("This album has no photos yet"), icon: "photo", style: .warning)
            return
        }

        HapticManager.impact(.light)
        navigationPath.append(AlbumNavigationDestination.swipeAlbum(currentAlbumInfo))
    }

    private func editAlbum(id: String) {
        guard let albumInfo = albumsByID[id] ?? dataManager.userAlbums.first(where: { $0.id == id }),
              let currentAlbumInfo = dataManager.currentUserAlbumInfo(for: albumInfo),
              let album = currentAlbumInfo.assetCollection else {
            HapticManager.impact(.light)
            showAlbumToast(L10n.string("This album no longer exists. The list has been updated."), icon: "arrow.clockwise", style: .warning)
            rebuildDisplayedRows()
            return
        }

        activeSheet = .edit(album)
    }

    private func deleteAlbum(id: String) {
        guard let albumInfo = albumsByID[id] ?? dataManager.userAlbums.first(where: { $0.id == id }),
              let currentAlbumInfo = dataManager.currentUserAlbumInfo(for: albumInfo),
              let album = currentAlbumInfo.assetCollection else {
            HapticManager.impact(.light)
            showAlbumToast(L10n.string("This album no longer exists. The list has been updated."), icon: "arrow.clockwise", style: .warning)
            rebuildDisplayedRows()
            return
        }

        dataManager.deleteUserAlbum(album) { success in
            if success {
                HapticManager.notify(.success)
                self.showAlbumToast(L10n.string("Album deleted"), icon: "trash", style: .positive)
            } else {
                HapticManager.notify(.error)
                self.showAlbumToast(L10n.string("Album list updated. Try again."), icon: "arrow.clockwise", style: .warning)
            }
            self.rebuildDisplayedRows()
        }
    }

    private func showAlbumToast(_ message: String, icon: String, style: PhotoDeleteToastStyle) {
        let toast = PhotoDeleteToast(message: message, icon: icon, style: style)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            albumToast = toast
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            guard albumToast?.id == toast.id else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                albumToast = nil
            }
        }
    }

    private func albumToastView(_ toast: PhotoDeleteToast) -> some View {
        VStack {
            Spacer()
            PhotoDeleteToastView(toast: toast)
                .padding(.bottom, 96)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .allowsHitTesting(false)
    }
}

enum AlbumNavigationDestination: Hashable {
    case swipeAlbum(AlbumInfo)
    case browser(AlbumInfo)

    static func == (lhs: AlbumNavigationDestination, rhs: AlbumNavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.swipeAlbum(let lhsAlbum), .swipeAlbum(let rhsAlbum)):
            return lhsAlbum.id == rhsAlbum.id
        case (.browser(let lhsAlbum), .browser(let rhsAlbum)):
            return lhsAlbum.id == rhsAlbum.id
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .swipeAlbum(let album):
            hasher.combine("swipeAlbum")
            hasher.combine(album.id)
        case .browser(let album):
            hasher.combine("browser")
            hasher.combine(album.id)
        }
    }
}

private enum AlbumSheet: Identifiable {
    case create
    case edit(PHAssetCollection)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .edit(let album):
            return "edit-\(album.localIdentifier)"
        }
    }
}

/// 长按确认时打开的菜单目标（位置取自按下的那一格）。
private struct AlbumActionMenuTarget: Identifiable, Equatable {
    let id: String
}

/// 每格在内容坐标系里的 frame，供落点判定、浮起卡起点与菜单锚点使用。
private struct AlbumItemFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// 滚动偏移：手指在视口坐标里，落点判定在内容坐标里，两者靠这个值换算。
private struct AlbumsScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private final class ThumbnailRequestBox: @unchecked Sendable {
    var id: PHImageRequestID?
}

// MARK: - 相册信息行
struct AlbumProgressSnapshot: Equatable {
    let totalCount: Int
    let reviewedCount: Int

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return min(Double(reviewedCount) / Double(totalCount), 1)
    }

    var displayText: String? {
        guard totalCount > 0 else { return nil }
        return L10n.percent(Int((progress * 100).rounded()))
    }

    var tint: Color {
        if progress >= 1 {
            return PhotoDeleteStyle.positive
        }
        if progress > 0 {
            return PhotoDeleteStyle.accent
        }
        return PhotoDeleteStyle.tertiaryText
    }
}

struct AlbumInfoRow: View, Equatable {
    let id: String
    let title: String
    let photosCount: Int
    let type: AlbumType
    let thumbnailAssetID: String?
    let photoLibraryManager: PhotoLibraryManager
    var progress: AlbumProgressSnapshot? = nil
    var showsChevron = true

    @State private var thumbnailImage: UIImage?
    @State private var requestID: PHImageRequestID?
    @State private var loadedThumbnailAssetID: String?

    private static let thumbnailPointSize: CGFloat = 36

    static func == (lhs: AlbumInfoRow, rhs: AlbumInfoRow) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.photosCount == rhs.photosCount
            && lhs.type == rhs.type
            && lhs.thumbnailAssetID == rhs.thumbnailAssetID
            && lhs.progress == rhs.progress
            && lhs.showsChevron == rhs.showsChevron
    }

    var body: some View {
        rowContent
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("\(title), \(L10n.photoCount(photosCount))")
            .task(id: thumbnailAssetID) {
                await loadAlbumThumbnail()
            }
    }

    private var rowContent: some View {
        HStack(spacing: 9) {
            albumThumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                    .lineLimit(1)

                Text(L10n.photoCount(photosCount))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
            }

            Spacer(minLength: 8)

            if let progressText {
                Text(progressText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(progress?.tint ?? PhotoDeleteStyle.tertiaryText)
                    .monospacedDigit()
                    .accessibilityLabel(L10n.string("Photo data preparation progress"))
                    .accessibilityValue(progressText)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(PhotoDeleteStyle.tertiaryText)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
    }

    @ViewBuilder
    private var albumThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(PhotoDeleteStyle.elevatedSurface)
                .frame(width: Self.thumbnailPointSize, height: Self.thumbnailPointSize)

            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.low)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Self.thumbnailPointSize, height: Self.thumbnailPointSize)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .transaction { $0.animation = nil }
            } else {
                Image(systemName: type.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(albumIconTint)
            }
        }
        .frame(width: Self.thumbnailPointSize, height: Self.thumbnailPointSize)
    }

    @MainActor
    private func loadAlbumThumbnail() async {
        guard let thumbnailAssetID else {
            thumbnailImage = nil
            loadedThumbnailAssetID = nil
            return
        }

        if loadedThumbnailAssetID == thumbnailAssetID, thumbnailImage != nil {
            return
        }

        cancelThumbnailRequest()

        let scale = UIScreen.main.scale
        let pixel = Self.thumbnailPointSize * scale
        let targetSize = CGSize(width: pixel, height: pixel)

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [thumbnailAssetID], options: nil)
        guard let asset = assets.firstObject else {
            thumbnailImage = nil
            loadedThumbnailAssetID = nil
            return
        }

        let requestBox = ThumbnailRequestBox()
        let manager = photoLibraryManager
        let image: UIImage? = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                var hasResumed = false
                let resumeOnce: (UIImage?) -> Void = { image in
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: image)
                }

                let id = manager.loadAlbumListThumbnail(for: asset, size: targetSize) { image in
                    resumeOnce(image)
                }
                requestBox.id = id
                requestID = id
            }
        } onCancel: {
            if let id = requestBox.id {
                manager.cancelImageRequest(id)
            }
        }

        guard !Task.isCancelled else { return }
        if let image {
            thumbnailImage = image
            loadedThumbnailAssetID = thumbnailAssetID
        }
        requestID = nil
    }

    private func cancelThumbnailRequest() {
        if let requestID {
            photoLibraryManager.cancelImageRequest(requestID)
        }
        requestID = nil
    }

    private var albumIconTint: Color {
        switch type {
        case .favorites:
            return PhotoDeleteStyle.iconTint(for: "favorite")
        case .videos:
            return PhotoDeleteStyle.iconTint(for: "video")
        case .livePhotos:
            return PhotoDeleteStyle.iconTint(for: "livephoto")
        default:
            return PhotoDeleteStyle.accent
        }
    }

    private var progressText: String? {
        progress?.displayText
    }
}

// MARK: - 相册名称弹窗（创建 / 编辑共用）

/// 居中对话框：遮罩 + 圆角卡 + 单字段输入。创建与编辑共用壳子，避免整页表单。
private struct AlbumNameDialog: View {
    let title: String
    let iconSystemName: String
    let placeholder: String
    let primaryTitle: String
    let busyTitle: String
    @Binding var albumName: String
    let isBusy: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onPrimary: () -> Void

    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        albumName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedName.isEmpty && !isBusy
    }

    var body: some View {
        ZStack {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.black.opacity(0.42)
            }
            .ignoresSafeArea()
            .onTapGesture {
                guard !isBusy else { return }
                onCancel()
            }

            VStack {
                Spacer(minLength: 24)

                dialogCard
                    .padding(.horizontal, 28)
                    .frame(maxWidth: 360)

                Spacer(minLength: 24)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                isNameFocused = true
            }
        }
    }

    private var dialogCard: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .topTrailing) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PhotoDeleteStyle.primaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 36)

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PhotoDeleteStyle.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(PhotoDeleteStyle.elevatedSurface))
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityLabel(Text(L10n.string("Cancel")))
            }

            Image(systemName: iconSystemName)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(PhotoDeleteStyle.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("Album Name"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PhotoDeleteStyle.primaryText)

                TextField(placeholder, text: $albumName)
                    .font(.body)
                    .foregroundStyle(PhotoDeleteStyle.primaryText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        guard canSubmit else { return }
                        onPrimary()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                            .fill(PhotoDeleteStyle.elevatedSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                                    .stroke(PhotoDeleteStyle.hairline, lineWidth: PhotoDeleteStyle.Metrics.cardStrokeWidth)
                            )
                    )
                    .disabled(isBusy)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(PhotoDeleteStyle.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text(L10n.string("Cancel"))
                }
                .photoDeleteSecondaryButton()
                .disabled(isBusy)
                .frame(maxWidth: .infinity)

                Button(action: onPrimary) {
                    HStack(spacing: 8) {
                        if isBusy {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: PhotoDeleteStyle.primaryButtonText))
                                .scaleEffect(0.85)
                        }

                        Text(isBusy ? busyTitle : primaryTitle)
                    }
                }
                .photoDeletePrimaryButton()
                .disabled(!canSubmit)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .background(
            RoundedRectangle(cornerRadius: PhotoDeleteStyle.cardRadius, style: .continuous)
                .fill(PhotoDeleteStyle.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: PhotoDeleteStyle.cardRadius, style: .continuous)
                        .stroke(PhotoDeleteStyle.hairline, lineWidth: PhotoDeleteStyle.Metrics.cardStrokeWidth)
                )
                .shadow(color: PhotoDeleteStyle.floatingShadow.opacity(0.35), radius: 24, y: 12)
        )
    }
}

// MARK: - 创建相册
struct CreateAlbumView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var albumName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        AlbumNameDialog(
            title: L10n.string("Create New Album"),
            iconSystemName: "plus.rectangle.on.folder",
            placeholder: L10n.string("Enter album name"),
            primaryTitle: L10n.string("Create Album"),
            busyTitle: L10n.string("Creating..."),
            albumName: $albumName,
            isBusy: isCreating,
            errorMessage: errorMessage,
            onCancel: { dismiss() },
            onPrimary: createAlbum
        )
    }

    private func createAlbum() {
        let trimmedName = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isCreating = true
        errorMessage = nil
        dataManager.createUserAlbum(named: trimmedName) { success in
            self.isCreating = false
            if success {
                self.dismiss()
            } else {
                self.errorMessage = L10n.string("Could not create the album. Try again.")
            }
        }
    }
}

// MARK: - 编辑相册
struct EditAlbumView: View {
    let album: PHAssetCollection
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @State private var newName: String
    @State private var isUpdating = false
    @State private var errorMessage: String?

    init(album: PHAssetCollection) {
        self.album = album
        self._newName = State(initialValue: album.localizedTitle ?? "")
    }

    var body: some View {
        AlbumNameDialog(
            title: L10n.string("Edit Album"),
            iconSystemName: "pencil.circle",
            placeholder: L10n.string("Enter album name"),
            primaryTitle: L10n.string("Save Changes"),
            busyTitle: L10n.string("Updating..."),
            albumName: $newName,
            isBusy: isUpdating,
            errorMessage: errorMessage,
            onCancel: { dismiss() },
            onPrimary: updateAlbum
        )
    }

    private func updateAlbum() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, album.assetCollectionType == .album else { return }
        guard dataManager.currentUserAlbumInfo(for: album) != nil else {
            errorMessage = L10n.string("This album no longer exists. The list has been updated.")
            dismissAfterShowingMissingAlbumMessage()
            return
        }

        isUpdating = true
        errorMessage = nil
        dataManager.renameUserAlbum(album, title: trimmedName) { success in
            self.isUpdating = false
            if success {
                self.dismiss()
            } else if self.dataManager.currentUserAlbumInfo(for: album) == nil {
                self.errorMessage = L10n.string("This album no longer exists. The list has been updated.")
                self.dismissAfterShowingMissingAlbumMessage()
            } else {
                self.errorMessage = L10n.string("Could not update the album. Try again.")
            }
        }
    }

    private func dismissAfterShowingMissingAlbumMessage() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }
}

#Preview {
    AlbumsView()
        .environmentObject(DataManager())
}
