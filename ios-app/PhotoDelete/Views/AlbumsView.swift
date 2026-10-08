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
    @AppStorage(AppConstants.hasDismissedAlbumSwipeHintKey) private var hasDismissedAlbumSwipeHint = false
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var activeSheet: AlbumSheet?
    @AppStorage(AppConstants.albumDisplayStyleKey) private var albumDisplayStyleValue = AlbumDisplayStyle.cover.rawValue
    @State private var showsDisplayStyle = false
    @State private var editMode: EditMode = .inactive
    @State private var albumToast: PhotoDeleteToast?
    @State private var displayedRows: [AlbumListRowModel] = []
    @State private var albumsByID: [String: AlbumInfo] = [:]
    @State private var displayedAlbumCount = 0

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
                        AlbumPhotoBrowserView(album: album) {
                            navigationPath.append(AlbumNavigationDestination.swipeAlbum(album))
                        }
                        .environmentObject(dataManager)
                    }
                }
        }
        .sheet(isPresented: $showsDisplayStyle) {
            AlbumDisplayStyleSheet(
                style: displayStyleBinding,
                onReorder: beginReorderingFromDisplaySheet
            )
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .create:
                CreateAlbumView()
                    .environmentObject(dataManager)
            case .edit(let album):
                EditAlbumView(album: album)
                    .environmentObject(dataManager)
            }
        }
        .onChange(of: searchText) { _ in
            rebuildDisplayedRows()
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
                albumsList
            }
        }
    }

    /// 相册页顶栏（对齐 style.md §4.5：左侧大标题 34/700 + 右上圆钮）。
    private var albumsTitleBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(L10n.string("Albums"))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(PhotoDeleteStyle.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if editMode == .active {
                Button(L10n.string("Done"), action: toggleReordering)
                    .font(.body.weight(.semibold))
                    .foregroundColor(PhotoDeleteStyle.accent)
            } else if dataManager.photoLibraryManager.hasPhotoLibraryAccess {
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

    // MARK: - 相册列表
    @ViewBuilder
    private var albumsList: some View {
        if editMode == .active || displayStyle == .list {
            albumRowsList
        } else {
            albumCoverBrowser
        }
    }

    private var albumCoverBrowser: some View {
        let columnCount = displayStyle == .compact
            ? (horizontalSizeClass == .regular ? 5 : 3)
            : (horizontalSizeClass == .regular ? 4 : 2)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: columnCount)

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(albumHeaderSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(PhotoDeleteStyle.secondaryText)

                albumSearchRow

                if isLoadingAlbums {
                    loadingRow
                } else if displayedRows.isEmpty {
                    emptyRow
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(displayedRows) { row in
                            albumCoverButton(row)
                        }
                    }
                }
            }
            .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
            .padding(.top, 4)
            .padding(.bottom, PhotoDeleteStyle.Metrics.bottomChromeSpacing)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable {
            dataManager.loadAlbums(showLoading: false)
        }
    }

    private func albumCoverButton(_ row: AlbumListRowModel) -> some View {
        Button {
            openAlbum(id: row.id)
        } label: {
            AlbumCoverTile(
                title: row.title,
                photosCount: row.photosCount,
                thumbnailAssetID: row.thumbnailAssetID,
                photoLibraryManager: dataManager.photoLibraryManager,
                isCompact: displayStyle == .compact
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if row.photosCount > 0 {
                Button {
                    openAlbumSwipe(id: row.id)
                } label: {
                    Label(L10n.string("Organize"), systemImage: "hand.draw")
                }
            }
            if row.canEdit {
                Button {
                    editAlbum(id: row.id)
                } label: {
                    Label(L10n.string("Edit"), systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleteAlbum(id: row.id)
                } label: {
                    Label(L10n.string("Delete"), systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var albumRowsList: some View {
        List {
            if isLoadingAlbums {
                Section {
                    loadingRow
                } header: {
                    albumCountHeader
                }
            } else if displayedRows.isEmpty {
                Section {
                    emptyRow
                } header: {
                    albumCountHeader
                }
            } else {
                // Keep count in the section header (not its own Section) so insetGrouped
                // does not leave a large empty gap under "N 个相册".
                Section {
                    albumSearchRow
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if shouldShowAlbumSwipeHint {
                        AlbumSwipeHintRow {
                            hasDismissedAlbumSwipeHint = true
                        }
                    }

                    if editMode == .active {
                        ForEach(displayedRows) { row in
                            albumRow(row)
                        }
                        .onMove(perform: moveUserAlbums)
                    } else {
                        // Avoid always-on reorder handlers while scrolling.
                        ForEach(displayedRows) { row in
                            albumRow(row)
                        }
                    }
                } header: {
                    albumCountHeader
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
        .scrollDismissesKeyboard(.immediately)
        .refreshable {
            dataManager.loadAlbums(showLoading: false)
        }
    }

    private var albumCountHeader: some View {
        Text(albumHeaderSubtitle)
            .font(.subheadline)
            .foregroundStyle(PhotoDeleteStyle.secondaryText)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textCase(nil)
            .padding(.bottom, 2)
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
        .listRowInsets(EdgeInsets(top: 0, leading: PhotoDeleteStyle.screenHorizontalPadding, bottom: 0, trailing: PhotoDeleteStyle.screenHorizontalPadding))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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
        .listRowInsets(EdgeInsets(top: 0, leading: PhotoDeleteStyle.screenHorizontalPadding, bottom: 0, trailing: PhotoDeleteStyle.screenHorizontalPadding))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var emptyTitle: String {
        searchText.isEmpty ? L10n.string("No Albums Yet") : L10n.string("No Albums Found")
    }

    private var emptyMessage: String {
        searchText.isEmpty ? L10n.string("Tap the plus button in the top right to create a new album.") : L10n.string("Try another keyword.")
    }

    private func albumRow(_ row: AlbumListRowModel) -> some View {
        Button {
            openAlbum(id: row.id)
        } label: {
            AlbumInfoRow(
                id: row.id,
                title: row.title,
                photosCount: row.photosCount,
                type: row.type,
                thumbnailAssetID: row.thumbnailAssetID,
                photoLibraryManager: dataManager.photoLibraryManager,
                showsChevron: editMode != .active
            )
            .equatable()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(L10n.string("Tap to organize this album"))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if row.canEdit {
                Button(role: .destructive) {
                    deleteAlbum(id: row.id)
                } label: {
                    Label(L10n.string("Delete"), systemImage: "trash")
                }
                .tint(PhotoDeleteStyle.destructive)

                Button {
                    editAlbum(id: row.id)
                } label: {
                    Label(L10n.string("Edit"), systemImage: "pencil")
                }
                .tint(PhotoDeleteStyle.accent)
            }
        }
        .listRowBackground(PhotoDeleteStyle.surface)
        .listRowSeparatorTint(PhotoDeleteStyle.hairline)
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

    private var shouldShowAlbumSwipeHint: Bool {
        !hasDismissedAlbumSwipeHint &&
            searchText.isEmpty &&
            editMode != .active
    }

    // MARK: - 方法
    private func rebuildDisplayedRows() {
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

    private func beginReorderingFromDisplaySheet() {
        showsDisplayStyle = false
        albumDisplayStyleValue = AlbumDisplayStyle.list.rawValue
        guard editMode != .active else { return }
        toggleReordering()
    }

    private func toggleReordering() {
        if editMode != .active && !searchText.isEmpty {
            showAlbumToast(L10n.string("Clear search before reordering"), icon: "magnifyingglass", style: .warning)
            return
        }

        HapticManager.impact(.light)
        withAnimation(.easeInOut(duration: 0.18)) {
            editMode = editMode == .active ? .inactive : .active
        }
    }

    private func moveUserAlbums(from source: IndexSet, to destination: Int) {
        guard searchText.isEmpty else {
            showAlbumToast(L10n.string("Clear search before reordering"), icon: "magnifyingglass", style: .warning)
            return
        }

        var rows = displayedRows
        rows.move(fromOffsets: source, toOffset: destination)
        displayedRows = rows
        dataManager.saveCustomAlbumOrder(rows.map(\.id))
        HapticManager.impact(.light)
    }

    private func openAlbum(id: String) {
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

private struct AlbumSwipeHintRow: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.draw")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.string("Use Sort in the top right to reorder"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(L10n.string("Swipe left on an album to edit or delete it"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Text(L10n.string("Got it"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.accent)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowBackground(PhotoDeleteStyle.surface)
        .listRowSeparator(.hidden)
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

// MARK: - 创建相册视图
struct CreateAlbumView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var albumName = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PhotoDeleteScreenBackground()

                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Image(systemName: "plus.rectangle.on.folder")
                            .font(.system(size: 60, weight: .medium))
                            .foregroundColor(PhotoDeleteStyle.accent)

                        Text(L10n.string("Create New Album"))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(PhotoDeleteStyle.primaryText)
                    }

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("Album Name"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(PhotoDeleteStyle.primaryText)

                            TextField(L10n.string("Enter album name"), text: $albumName)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(PhotoDeleteStyle.primaryText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                                        .fill(PhotoDeleteStyle.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                                .stroke(PhotoDeleteStyle.hairline, lineWidth: PhotoDeleteStyle.Metrics.cardStrokeWidth)
                                        )
                                )
                        }

                        Text(L10n.string("Use a simple album name, like \"Travel\" or \"Family\"."))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(PhotoDeleteStyle.secondaryText)
                            .multilineTextAlignment(.leading)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PhotoDeleteStyle.warning)
                    }

                    VStack(spacing: 12) {
                        Button(action: createAlbum) {
                            HStack(spacing: 8) {
                                if isCreating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: PhotoDeleteStyle.primaryButtonText))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .semibold))
                                }

                                Text(isCreating ? L10n.string("Creating...") : L10n.string("Create Album"))
                            }
                        }
                        .photoDeletePrimaryButton()
                        .disabled(albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)

                        Button(action: { dismiss() }) {
                            Text(L10n.string("Cancel"))
                        }
                        .photoDeleteSecondaryButton()
                    }

                    Spacer()
                }
                .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                .padding(.top, 40)
                .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(L10n.string("Create Album"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Cancel")) {
                        dismiss()
                    }
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                }
            }
        }
    }

    private func createAlbum() {
        let trimmedName = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isCreating = true
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

// MARK: - 编辑相册视图
struct EditAlbumView: View {
    let album: PHAssetCollection
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var newName: String
    @State private var isUpdating = false
    @State private var errorMessage: String?

    init(album: PHAssetCollection) {
        self.album = album
        self._newName = State(initialValue: album.localizedTitle ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PhotoDeleteScreenBackground()

                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 60, weight: .medium))
                            .foregroundColor(PhotoDeleteStyle.accent)

                        Text(L10n.string("Edit Album"))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(PhotoDeleteStyle.primaryText)
                    }

                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.string("Album Name"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(PhotoDeleteStyle.primaryText)

                            TextField(L10n.string("Enter album name"), text: $newName)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(PhotoDeleteStyle.primaryText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                                        .fill(PhotoDeleteStyle.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                                                .stroke(PhotoDeleteStyle.hairline, lineWidth: 1)
                                        )
                                )
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(PhotoDeleteStyle.warning)
                    }

                    VStack(spacing: 12) {
                        Button(action: updateAlbum) {
                            HStack(spacing: 8) {
                                if isUpdating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: PhotoDeleteStyle.primaryButtonText))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                }

                                Text(isUpdating ? L10n.string("Updating...") : L10n.string("Save Changes"))
                            }
                        }
                        .photoDeletePrimaryButton()
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isUpdating)

                        Button(action: { dismiss() }) {
                            Text(L10n.string("Cancel"))
                        }
                        .photoDeleteSecondaryButton()
                    }

                    Spacer()
                }
                .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                .padding(.top, 40)
                .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(L10n.string("Edit Album"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Cancel")) {
                        dismiss()
                    }
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                }
            }
        }
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
