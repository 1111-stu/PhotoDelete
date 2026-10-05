//
//  SwipePhotoView.swift
//  PhotoDelete
//
//  Created by PhotoDelete Team on 11/7/25.
//

import SwiftUI
import Photos
#if canImport(UIKit)
import UIKit
#endif

struct SwipePhotoView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppConstants.reviewVideoAutoPlayKey) private var reviewVideoAutoPlay = true
    @AppStorage(AppConstants.reviewLivePhotoAutoPlayKey) private var reviewLivePhotoAutoPlay = false
    @AppStorage(AppConstants.reviewVideoMutedKey) private var defaultReviewVideoMuted = true
    @AppStorage(AppConstants.reviewSortOrderKey) private var reviewSortOrderValue = PhotoReviewSortOrder.newestFirst.rawValue

    let selectedCategory: PhotoCategory?
    let selectedTimeGroup: String?
    let selectedAlbumInfo: AlbumInfo?
    let selectedDate: Date?
    let selectedAdvancedTimeScope: AdvancedTimeScope?
    let selectedAdvancedCleanup: AdvancedCleanupKind?
    let selectedLocationGroupID: String?
    let randomReviewScope: PhotoRandomReviewScope?
    let selectedHistoricalToday: Bool

    @StateObject private var session = PhotoReviewSession()
    @State private var showBatchConfirm = false
    @State private var showCompletionMessage = false
    @StateObject private var actions = PhotoReviewActions()
    @State private var randomReviewSeed = UUID().uuidString
    @AppStorage(AppConstants.randomReviewHideFiledPhotosKey) private var randomReviewHideFiledPhotos = true
    @AppStorage(AppConstants.randomReviewBatchSizeKey) private var randomReviewBatchSizeValue = PhotoRandomReviewBatchSize.defaultValue.rawValue
    @State private var shouldDismissAfterBatch = false
    @State private var didCompleteBatch = false
    @State private var feedbackToast: PhotoDeleteToast?
    @State private var didInitializeSession = false
    @State private var preloadedAssets: [PHAsset] = []
    @State private var sessionProgressSaveWorkItem: DispatchWorkItem?
    @State private var manuallyStoppedVideoAssetID: String?
    @State private var currentAlbumInfo: AlbumInfo?
    @State private var sessionVideoMuted = true
    @State private var didApplySessionPlaybackPreference = false
    @State private var inlineVideoControlsRevealToken: UUID?
    @State private var sharePayload: PhotoSharePayload?
    @State private var sharePreparationTask: Task<Void, Never>?
    @State private var isPreparingShare = false
    @State private var showsAlbumFilingSheet = false
    @State private var albumFilingSheetSelection: Set<String> = []
    @State private var albumFilingSheetAsset: PHAsset?
    @State private var pendingAlbumSuccessToastTitle: String?

    private static let countFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    init(
        selectedCategory: PhotoCategory?,
        selectedTimeGroup: String?,
        selectedAlbumInfo: AlbumInfo?,
        selectedDate: Date? = nil,
        selectedAdvancedTimeScope: AdvancedTimeScope? = nil,
        selectedAdvancedCleanup: AdvancedCleanupKind? = nil,
        selectedLocationGroupID: String? = nil,
        randomReviewScope: PhotoRandomReviewScope? = nil,
        selectedHistoricalToday: Bool = false
    ) {
        self.selectedCategory = selectedCategory
        self.selectedTimeGroup = selectedTimeGroup
        self.selectedAlbumInfo = selectedAlbumInfo
        self.selectedDate = selectedDate
        self.selectedAdvancedTimeScope = selectedAdvancedTimeScope
        self.selectedAdvancedCleanup = selectedAdvancedCleanup
        self.selectedLocationGroupID = selectedLocationGroupID
        self.randomReviewScope = randomReviewScope
        self.selectedHistoricalToday = selectedHistoricalToday
    }

    private var currentRealPhoto: PHAsset? {
        guard !session.photos.isEmpty, session.currentIndex >= 0, session.currentIndex < session.photos.count else {
            return nil
        }
        return session.photos[session.currentIndex]
    }

    private var source: PhotoReviewSource {
        PhotoReviewSource(
            selectedCategory: selectedCategory, selectedTimeGroup: selectedTimeGroup,
            selectedAlbumInfo: selectedAlbumInfo, selectedDate: selectedDate,
            selectedAdvancedTimeScope: selectedAdvancedTimeScope,
            selectedAdvancedCleanup: selectedAdvancedCleanup,
            selectedLocationGroupID: selectedLocationGroupID,
            randomReviewScope: randomReviewScope, selectedHistoricalToday: selectedHistoricalToday
        )
    }

    private var filteredRealPhotos: [PHAsset] {
        source.photos(
            dataManager: dataManager, activeAlbumInfo: activeAlbumInfo,
            randomSeed: randomReviewSeed, hideFiled: randomReviewHideFiledPhotos,
            batchSizeValue: randomReviewBatchSizeValue, sortOrderValue: reviewSortOrderValue
        )
    }

    private var usesChronologicalReviewOrder: Bool { source.usesChronologicalOrder }

    private var totalPhotosCount: Int {
        return session.allPhotos.isEmpty ? session.photos.count : session.allPhotos.count
    }

    private var currentProgress: Int {
        return min(session.currentIndex + 1, totalPhotosCount)
    }

    private var organizedProgress: Int {
        guard totalPhotosCount > 0 else { return 0 }
        return min(session.reviewedIDs.count, totalPhotosCount)
    }

    private var remainingPhotosCount: Int {
        max(totalPhotosCount - organizedProgress, 0)
    }

    private var progressFraction: Double {
        guard totalPhotosCount > 0 else { return 0 }
        return Double(organizedProgress) / Double(totalPhotosCount)
    }

    private var isAlbumMode: Bool {
        return selectedAlbumInfo != nil
    }

    private var isRandomMemoriesMode: Bool {
        randomReviewScope == .memories
    }

    private var shouldPageSessionPhotos: Bool {
        selectedAdvancedCleanup == nil
    }

    private var activeAlbumInfo: AlbumInfo? {
        currentAlbumInfo ?? selectedAlbumInfo
    }

    private var isCurrentPhotoFavorited: Bool {
        guard let asset = currentRealPhoto else { return false }
        return effectiveFavoriteStatus(for: asset)
    }

    private var isCurrentPhotoBeingFiled: Bool {
        guard let asset = currentRealPhoto else { return false }
        return isAssetBeingFiledToAlbum(asset)
    }

    private var reviewVideoMuted: Bool {
        didApplySessionPlaybackPreference ? sessionVideoMuted : defaultReviewVideoMuted
    }

    private var shouldShowSessionMuteButton: Bool {
        guard let asset = currentRealPhoto else { return false }
        return asset.mediaType == .video || dataManager.photoLibraryManager.isLivePhoto(asset)
    }

    private func shouldPlayVideo(for asset: PHAsset) -> Bool {
        guard asset.mediaType == .video else { return false }
        if manuallyStoppedVideoAssetID == asset.localIdentifier {
            return false
        }
        return reviewVideoAutoPlay &&
            !isAssetQueuedForDelete(asset) &&
            !isAssetQueuedForFavorite(asset) &&
            !isAssetBeingFiledToAlbum(asset) &&
            !isAssetFiledToAlbum(asset)
    }

    private var canPerformPhotoAction: Bool {
        canPerformPhotoAction(.keep)
    }

    private func canPerformPhotoAction(_ action: SwipeGestureAction) -> Bool {
        currentRealPhoto != nil &&
            !showCompletionMessage &&
            !isCurrentPhotoBeingFiled &&
            actions.canStartAction(action)
    }

    private var pendingDeleteCount: Int { dataManager.deleteCandidates.count }
    private var pendingFavoriteCount: Int { dataManager.favoriteCandidates.count }

    var body: some View {
        ZStack {
            PhotoDeleteStyle.reviewCanvas
                .ignoresSafeArea()

            GeometryReader { geometry in
                let usesSidebar = PhotoDeleteAdaptiveLayout.prefersReviewSidebar(
                    in: geometry.size,
                    horizontalSizeClass: horizontalSizeClass
                )
                let sidebarWidth = PhotoDeleteAdaptiveLayout.reviewSidebarWidth(totalWidth: geometry.size.width)
                let primaryWidth = geometry.size.width - sidebarWidth

                ZStack(alignment: .bottom) {
                    if usesSidebar {
                        HStack(spacing: 0) {
                            VStack(spacing: 0) {
                                navigationHeader
                                photoArea
                                    .overlay(alignment: .top) {
                                        if let feedbackToast {
                                            PhotoDeleteToastView(toast: feedbackToast) {
                                                handleUndoAction()

                                            }
                                            .frame(maxWidth: 420)
                                            .padding(.horizontal, 24)
                                            .padding(.top, 16)
                                            .allowsHitTesting(feedbackToast.showsUndo)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                        }
                                    }
                            }
                            .frame(width: primaryWidth)

                            landscapeSidebar
                                .frame(width: sidebarWidth, height: geometry.size.height)
                        }
                    } else {
                        VStack(spacing: 0) {
                            navigationHeader
                            photoArea
                            bottomControls
                        }
                    }

                    if !usesSidebar, let feedbackToast {
                        PhotoDeleteToastView(toast: feedbackToast) {
                            handleUndoAction()

                        }
                        .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                        .allowsHitTesting(feedbackToast.showsUndo)
                        .padding(.top, 88)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .top
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showsAlbumFilingSheet, onDismiss: {
            if let title = pendingAlbumSuccessToastTitle {
                showAlbumFilingSuccessToast(albumTitle: title)
            }
            albumFilingSheetSelection.removeAll()
            albumFilingSheetAsset = nil
            pendingAlbumSuccessToastTitle = nil
        }) {
            ReviewAlbumFilingSheet(
                albums: dataManager.getUserAlbumsSortedByCustomOrder(),
                shortcutAlbums: albumShortcutAlbums,
                selectedAlbumIDs: albumFilingSheetSelection,
                onFile: fileCurrentPhotoFromSheet(_:),
                onContinue: finishAlbumFilingSheet
            )
            .environmentObject(dataManager)
        }
        .sheet(item: $sharePayload, onDismiss: cleanupSharePayload) { payload in
            SystemShareSheet(activityItems: [payload.fileURL])
        }
        .fullScreenCover(isPresented: $showBatchConfirm, onDismiss: {
            let shouldCloseReview = shouldDismissAfterBatch && didCompleteBatch
            shouldDismissAfterBatch = false
            didCompleteBatch = false
            if shouldCloseReview {
                dismiss()
            } else {
                refreshSessionForSourceChangeIfNeeded(force: true)
            }
        }) {
            BatchConfirmView(albumInfo: activeAlbumInfo) { _ in
                didCompleteBatch = true
            }
                .environmentObject(dataManager)
        }
        .onDisappear {
            stopInlineVideoPlayback()
            sharePreparationTask?.cancel()
            sharePreparationTask = nil
            isPreparingShare = false
            flushSessionProgressSave()
            dataManager.flushReviewPersistence()
            dataManager.photoLibraryManager.stopCachingImages(
                preloadedAssets,
                size: swipeImageTargetSize
            )
            dataManager.photoLibraryManager.cancelSwipePreviewPreloads()
            preloadedAssets.removeAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            // 处理内存警告
            dataManager.photoLibraryManager.handleMemoryWarning()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            flushSessionProgressSave()
            dataManager.flushReviewPersistence()
        }
        .onAppear {
            applySessionPlaybackPreferenceIfNeeded()
            dataManager.commitLegacyFavoriteCandidatesIfNeeded()
            loadAlbumShortcutsIfNeeded()
            if selectedLocationGroupID != nil {
                dataManager.loadLocationGroups()
            }
            if refreshSelectedAlbumState() {
                initializeSessionIfNeeded()
            }
        }
        .onChange(of: albumStateRefreshToken) { _ in
            refreshSelectedAlbumState()
        }
        .onChange(of: dataManager.photoLibraryManager.isLoading) { _ in
            initializeSessionIfNeeded()
        }
        .onChange(of: dataManager.isPreparingLibrary) { _ in
            initializeSessionIfNeeded()
        }
        .onChange(of: dataManager.photoLibraryManager.allPhotos.count) { _ in
            refreshSessionForSourceChangeIfNeeded()
        }
        .onChange(of: dataManager.photoLibraryManager.favorites.count) { _ in
            guard selectedCategory == .favorites || activeAlbumInfo?.type == .favorites else { return }
            refreshSessionForSourceChangeIfNeeded(force: true)
        }
        .onChange(of: dataManager.hasLoadedAlbumMembership) { _ in
            initializeSessionIfNeeded()
        }
        .onChange(of: randomReviewHideFiledPhotos) { _ in
            guard randomReviewScope != nil else { return }
            randomReviewSeed = UUID().uuidString
            refreshSessionForSourceChangeIfNeeded(force: true)
        }
        .onChange(of: randomReviewBatchSizeValue) { _ in
            guard randomReviewScope != nil else { return }
            randomReviewSeed = UUID().uuidString
            refreshSessionForSourceChangeIfNeeded(force: true)
        }
        .onChange(of: reviewSortOrderValue) { _ in
            guard usesChronologicalReviewOrder else { return }
            refreshSessionForSourceChangeIfNeeded(force: true)
        }
        .onChange(of: unclassifiedSourceRefreshToken) { _ in
            guard selectedCategory == .unclassified else { return }
            refreshSessionForSourceChangeIfNeeded(force: true)
        }
        .onChange(of: dataManager.photoLibraryManager.hasPhotoLibraryAccess) { hasAccess in
            guard hasAccess else { return }
            loadAlbumShortcutsIfNeeded()
        }
        .onChange(of: dataManager.advancedCleanupQueuesRevision) { _ in
            guard selectedAdvancedCleanup != nil else { return }
            refreshSessionForSourceChangeIfNeeded(force: true)
        }
        .onChange(of: dataManager.locationGroupsRevision) { _ in
            guard selectedLocationGroupID != nil else { return }
            refreshSessionForSourceChangeIfNeeded(force: true)
        }
        .onChange(of: session.currentIndex) { _ in
            manuallyStoppedVideoAssetID = nil
            session.expand(for: session.currentIndex)
            scheduleSessionProgressSave()
        }
        .onReceive(actions.events, perform: handleActionEvent)
        .onChange(of: defaultReviewVideoMuted) { muted in
            sessionVideoMuted = muted
            didApplySessionPlaybackPreference = true
        }
    }

    // MARK: - 导航栏
    private var navigationHeader: some View {
        ReviewNavigationHeader(
            title: navigationHeaderTitle, subtitle: headerProgressSubtitle,
            deleteCount: pendingDeleteCount, canDelete: canPerformPhotoAction,
            onBack: handleBackAction, onDelete: handleDeleteAction
        )
    }

    // MARK: - 照片区域
    private var photoArea: some View {
        GeometryReader { geometry in
            let placeholderBottomReserve: CGFloat = geometry.size.width > geometry.size.height ? 0 : 88

            Group {
                if !dataManager.photoLibraryManager.hasPhotoLibraryAccess {
                    centeredPhotoAreaPlaceholder(in: geometry, bottomReserve: placeholderBottomReserve) {
                        PhotoAuthorizationCard(
                            subtitle: L10n.string("请允许访问您的照片库来开始整理照片"),
                            onRequestAccess: { dataManager.requestPhotoLibraryAccess() }
                        )
                        .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    }
                } else if let realPhoto = currentRealPhoto {
                    ZStack {
                        cardPhotoArea(asset: realPhoto, in: geometry.size)

                        if showCompletionMessage {
                            completionOverlay
                        }

                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if shouldShowInitialPreparingState {
                    centeredPhotoAreaPlaceholder(in: geometry, bottomReserve: placeholderBottomReserve) {
                        PhotoSelectionLoadingCard(
                            title: L10n.string("正在读取照片"),
                            message: L10n.string("读取完成后会直接进入当前整理。"),
                            progress: activeLibraryLoadingProgress
                        )
                        .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    }
                } else if shouldShowBackgroundLoadingState {
                    centeredPhotoAreaPlaceholder(in: geometry, bottomReserve: placeholderBottomReserve) {
                        PhotoSelectionLoadingCard(
                            title: L10n.string("正在读取当前相册"),
                            message: L10n.string("照片很多时可能需要几秒，完成后会自动开始。"),
                            progress: activeLibraryLoadingProgress
                        )
                        .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    }
                } else {
                    centeredPhotoAreaPlaceholder(in: geometry, bottomReserve: placeholderBottomReserve) {
                        // 没有更多照片
                        VStack(spacing: 20) {
                            if totalPhotosCount == 0 {
                                // 没有照片的情况
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 60, weight: .medium))
                                    .foregroundColor(PhotoDeleteStyle.accent)

                                Text(emptyPhotoTitle)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(PhotoDeleteStyle.primaryText)

                                Text(emptyPhotoMessage)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)

                                Button(action: { dismiss() }) {
                                    Text(L10n.string("返回主页"))
                                        .frame(maxWidth: 180)
                                }
                                .photoDeleteSecondaryButton()
                            } else {
                                // 整理完成的情况
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60, weight: .medium))
                                    .foregroundColor(PhotoDeleteStyle.positive)

                                Text(L10n.string("整理完成！"))
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(PhotoDeleteStyle.primaryText)

                                Text(L10n.string("您已经整理完所有照片"))
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(PhotoDeleteStyle.secondaryText)

                                Button(action: { dismiss() }) {
                                    Text(L10n.string("返回主页"))
                                        .frame(maxWidth: 180)
                                }
                                .photoDeleteSecondaryButton()
                            }
                        }
                        .padding(24)
                        .photoDeleteCard()
                        .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func centeredPhotoAreaPlaceholder<Content: View>(
        in geometry: GeometryProxy,
        bottomReserve: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let resolvedBottomReserve = min(bottomReserve, geometry.size.height * 0.2)

        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(0, geometry.size.height - resolvedBottomReserve), alignment: .center)
        .padding(.bottom, resolvedBottomReserve)
    }

    private func cardPhotoArea(asset: PHAsset, in containerSize: CGSize) -> some View {
        let cardSize = photoCardSize(in: containerSize)
        return ReviewPhotoPager(
            pages: horizontalPageEntries(),
            currentID: asset.localIdentifier,
            cardSize: cardSize,
            pageStride: containerSize.width,
            canDelete: canPerformPhotoAction(.delete),
            isVideoPlaying: shouldPlayVideo(for: asset),
            onBrowse: { step in
                guard let index = horizontalNeighborIndex(step: step) else { return }
                session.currentIndex = index
                preloadUpcomingImages(from: index)
                persistSessionProgressIfPossible()
            },
            onDelete: handleDeleteAction,
            onFile: openAlbumFilingSheet
        ) { photo, isCurrent in
            reviewPhotoCard(asset: photo, cardSize: cardSize, isCurrent: isCurrent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 8) {
            ReviewPhotoDetailLine(asset: asset).id(asset.localIdentifier)
        }
    }

    private func reviewPhotoCard(asset: PHAsset, cardSize: CGSize, isCurrent: Bool) -> some View {
        let isInlineVideoPlaying = isCurrent && shouldPlayVideo(for: asset)

        return ZStack {
            RealPhotoCard(
                asset: asset,
                photoLibraryManager: dataManager.photoLibraryManager,
                isInDeleteCandidates: isAssetQueuedForDelete(asset),
                isBeingFiledToAlbum: isAssetBeingFiledToAlbum(asset),
                isFiledToAlbum: isAssetFiledToAlbum(asset),
                isVideoPlaying: isInlineVideoPlaying,
                allowsLivePhotoPlayback: reviewLivePhotoAutoPlay,
                videoMuted: reviewVideoMuted,
                memoryCaption: memoryCaption(for: asset),
                metadataSummary: metadataSummary(for: asset),
                albumTitles: dataManager.albumTitles(for: asset),
                displaySize: cardSize,
                targetSize: imageTargetSize(for: cardSize),
                playbackControlsRevealToken: inlineVideoControlsRevealToken,
                onStopVideoPlayback: {
                    stopInlineVideoPlayback(rememberManualStopFor: asset)
                }
            )
            .overlay(alignment: isInlineVideoPlaying ? .topTrailing : .bottomTrailing) {
                if isCurrent {
                HStack(spacing: 8) {
                    if shouldShowSessionMuteButton {
                        SessionMuteToggleButton(isMuted: reviewVideoMuted, action: toggleSessionVideoMuted)
                    }
                }
                .padding(12)
                .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .photoDeleteSimultaneousTapGesture(enabled: isCurrent && isInlineVideoPlaying) {
                revealInlineVideoPlaybackControls()
            }
            .accessibilityAction(named: Text(L10n.string("加入待删除"))) {
                handleDeleteAction()

            }
            .accessibilityAction(named: Text(L10n.string("加入相册"))) {
                openAlbumFilingSheet()
            }
            .accessibilityAction(named: Text(isCurrentPhotoFavorited ? L10n.string("取消收藏") : L10n.string("加入收藏"))) {
                handleFavoriteAction()

            }
            .accessibilityAction(named: Text(L10n.string("下一张"))) {
                browseToNextPhoto(reviewing: asset)
            }
            .accessibilityAction(named: Text(L10n.string("上一张"))) {
                browseToPreviousPhoto(reviewing: asset)
            }
            .allowsHitTesting(isCurrent)
        }
    }

    private func horizontalPageEntries() -> [ReviewHorizontalPage] {
        var pages: [ReviewHorizontalPage] = []
        if let index = horizontalNeighborIndex(step: -1) {
            pages.append(ReviewHorizontalPage(offset: -1, asset: session.photos[index]))
        }
        if let asset = currentRealPhoto {
            pages.append(ReviewHorizontalPage(offset: 0, asset: asset))
        }
        if let index = horizontalNeighborIndex(step: 1) {
            pages.append(ReviewHorizontalPage(offset: 1, asset: session.photos[index]))
        }
        return pages
    }

    private func horizontalNeighborIndex(step: Int) -> Int? {
        let isExcluded: (Int) -> Bool = { index in
            randomReviewScope != nil && isAssetQueuedForDelete(session.photos[index])
        }
        if step < 0 {
            return PhotoRandomReviewNavigationPolicy.previousIndex(
                currentIndex: session.currentIndex, count: session.photos.count, isExcluded: isExcluded
            )
        }
        return PhotoRandomReviewNavigationPolicy.nextIndex(
            currentIndex: session.currentIndex, count: session.photos.count, isExcluded: isExcluded
        )
    }

    private func memoryCaption(for asset: PHAsset) -> PhotoMemoryCaption {
        PhotoMemoryCaption(
            title: PhotoMemoryCaptionFormatter.relativeTitle(for: asset.creationDate),
            subtitle: PhotoMemoryCaptionFormatter.dateSubtitle(for: asset.creationDate)
        )
    }

    private func metadataSummary(for asset: PHAsset) -> PhotoAssetMetadataSummary {
        PhotoAssetMetadataSummary(
            captureDateText: PhotoAssetMetadataFormatter.shortCaptureDate(for: asset.creationDate),
            locationText: dataManager.locationDisplayTextIfAvailable(for: asset)
        )
    }

    private func revealInlineVideoPlaybackControls() {
        inlineVideoControlsRevealToken = UUID()
    }

    private func stopInlineVideoPlayback(rememberManualStopFor asset: PHAsset? = nil) {
        if let asset, asset.mediaType == .video {
            manuallyStoppedVideoAssetID = asset.localIdentifier
        }
    }

    private var completionOverlay: some View {
        ReviewCompletionOverlay(
            title: completionTitle, subtitle: completionSubtitle,
            hasUnreviewedPhotos: hasUnreviewedPhotos,
            primaryActionTitle: completionPrimaryActionTitle,
            showsSessionStats: randomReviewScope != nil,
            deleteCount: actions.deleteActionCount,
            favoriteCount: actions.favoriteActionCount,
            onContinue: {
                continueToNextUnreviewedPhoto()
                showCompletionMessage = false
            },
            onFinish: handleFinishAction
        )
    }

    private var completionTitle: String {
        hasUnreviewedPhotos ? L10n.string("已浏览到最后一张") : L10n.string("整理完成！")
    }

    private var completionSubtitle: String {
        if hasUnreviewedPhotos {
            return String(
                format: L10n.string("剩余 %lld 张 · 共 %lld 张"),
                Int64(remainingPhotosCount),
                Int64(totalPhotosCount)
            )
        }

        if randomReviewScope == nil {
            return L10n.string("您已经浏览完所有照片")
        }

        return String(
            format: L10n.string("已整理 %lld/%lld 张，确认后再统一删除。"),
            Int64(organizedProgress),
            Int64(totalPhotosCount)
        )
    }

    private var completionPrimaryActionTitle: String {
        if pendingDeleteCount > 0 || !dataManager.deleteCandidates.isEmpty {
            return L10n.string("确认删除")
        }
        if pendingFavoriteCount > 0 || !dataManager.favoriteCandidates.isEmpty {
            return L10n.string("确认收藏")
        }
        return L10n.string("完成整理")
    }

    // MARK: - 底部控制区域
    private var bottomControls: some View {
        VStack(spacing: 10) {
            if showsAlbumPhotoStrip {
                albumPhotoStrip
            }
            actionToolbar
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(PhotoDeleteStyle.reviewCanvas)
    }

    private var landscapeSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            sessionSummaryPanel
            if showsAlbumPhotoStrip {
                albumPhotoStrip
            }

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                SidebarActionButton(
                    icon: "arrow.uturn.backward",
                    title: L10n.string("撤销"),
                    color: PhotoDeleteStyle.secondaryText
                ) {
                    handleUndoAction()

                }

                SidebarActionButton(
                    icon: isCurrentPhotoFavorited ? "heart.slash" : "heart",
                    title: isCurrentPhotoFavorited ? L10n.string("取消收藏") : L10n.string("收藏"),
                    color: PhotoDeleteStyle.iconTint(for: "favorite")
                ) {
                    handleFavoriteAction()

                }

                SidebarActionButton(
                    icon: isPreparingShare ? "hourglass" : "square.and.arrow.up",
                    title: isPreparingShare ? L10n.string("准备中") : L10n.string("分享"),
                    color: PhotoDeleteStyle.accent
                ) {
                    handleShareAction()

                }

                SidebarActionButton(
                    icon: "trash",
                    title: L10n.string("加入待删除"),
                    color: PhotoDeleteStyle.destructive
                ) {
                    handleDeleteAction()

                }

                SidebarActionButton(
                    icon: "checkmark",
                    title: L10n.string("完成整理"),
                    color: PhotoDeleteStyle.positive
                ) {
                    handleFinishAction()

                }
            }
            .disabled(!canPerformPhotoAction)
            .opacity(canPerformPhotoAction ? 1 : 0.45)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(PhotoDeleteStyle.reviewCanvas)
    }

    private var sessionSummaryPanel: some View {
        ReviewSessionSummaryPanel(
            title: source.title(dataManager: dataManager, activeAlbumInfo: activeAlbumInfo), subtitle: progressSubtitle,
            showsProgress: totalPhotosCount > 0, progress: progressFraction,
            deleteCount: pendingDeleteCount, favoriteCount: pendingFavoriteCount
        )
    }

    private var actionToolbar: some View {
        ReviewActionToolbar(
            isFavorite: isCurrentPhotoFavorited,
            canPerformAction: canPerformPhotoAction,
            isPreparingShare: isPreparingShare, deleteCount: pendingDeleteCount,
            onUndo: handleUndoAction, onFavorite: handleFavoriteAction,
            onShare: handleShareAction, onFinish: handleFinishAction
        )
    }

    private var showsAlbumPhotoStrip: Bool {
        selectedAlbumInfo != nil && randomReviewScope == nil && !session.photos.isEmpty
    }

    private var albumPhotoStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(session.photos.enumerated()), id: \.element.localIdentifier) { index, asset in
                        Button {
                            selectAlbumStripPhoto(at: index)
                        } label: {
                            AlbumAssetThumbnail(
                                assetID: asset.localIdentifier,
                                photoLibraryManager: dataManager.photoLibraryManager,
                                cornerRadius: PhotoDeleteStyle.Metrics.thumbnailRadius
                            )
                            .frame(width: 64, height: 64)
                            .overlay {
                                RoundedRectangle(cornerRadius: PhotoDeleteStyle.Metrics.thumbnailRadius, style: .continuous)
                                    .stroke(
                                        index == session.currentIndex ? PhotoDeleteStyle.accent : Color.clear,
                                        lineWidth: 2
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .id(asset.localIdentifier)
                    }
                }
                .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
            }
            .frame(height: 72)
            .onChange(of: session.currentIndex) { index in
                guard session.photos.indices.contains(index) else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(session.photos[index].localIdentifier, anchor: .center)
                }
            }
        }
    }

    // MARK: - 手势处理
    private var shouldShowInitialPreparingState: Bool {
        !didInitializeSession &&
            session.photos.isEmpty &&
            dataManager.isPreparingLibrary
    }

    private var shouldShowBackgroundLoadingState: Bool {
        !didInitializeSession &&
            session.photos.isEmpty &&
            !dataManager.isPreparingLibrary &&
            (
                dataManager.photoLibraryManager.isLoading &&
                    (!dataManager.photoLibraryManager.hasLoadedPhotoLibrary || randomReviewScope != nil) ||
                    isWaitingForAlbumMembershipSource
            )
    }

    private var emptyPhotoTitle: String {
        if isRandomMemoriesMode {
            return randomReviewHideFiledPhotos ? L10n.string("没有未归类的照片") : L10n.string("这里还没有可整理的照片")
        }
        return L10n.string("这里还没有可整理的照片")
    }

    private var emptyPhotoMessage: String {
        if isRandomMemoriesMode {
            return randomReviewHideFiledPhotos
                ? L10n.string("已归类照片当前被隐藏，可在整理设置中重新显示。")
                : L10n.string("若照片权限为部分访问，请在系统设置中允许更多照片。")
        }
        return L10n.string("您可以返回选择其他分类，或稍后在系统照片中添加更多照片后再回来。")
    }

    private var activeLibraryLoadingProgress: Double {
        if isWaitingForAlbumMembershipSource {
            guard dataManager.isLoadingAlbums else { return 0 }
            return min(max(dataManager.albumLoadingProgress, 0), 1)
        }
        return min(max(dataManager.photoLibraryManager.loadingProgress, 0), 1)
    }

    private var isWaitingForAlbumMembershipSource: Bool {
        (selectedCategory == .unclassified || (randomReviewScope != nil && randomReviewHideFiledPhotos)) &&
            dataManager.photoLibraryManager.hasPhotoLibraryAccess &&
            !dataManager.hasLoadedAlbumMembership
    }

    private var progressSubtitle: String {
        headerProgressSubtitle
    }

    private var navigationHeaderTitle: String {
        "\(formattedCount(currentProgress)) / \(formattedCount(totalPhotosCount))"
    }

    private var headerProgressSubtitle: String {
        String(
            format: L10n.string("本轮待整理 %lld 张"),
            Int64(max(totalPhotosCount - currentProgress, 0))
        )
    }

    private func formattedCount(_ count: Int) -> String {
        Self.countFormatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private var albumShortcutAlbums: [AlbumInfo] {
        AlbumShortcutEligibility.filteredAlbums(dataManager.getUserAlbumsSortedByCustomOrder())
    }

    private func loadAlbumShortcutsIfNeeded() {
        guard !isAlbumMode else { return }
        dataManager.loadAlbumsIfNeeded()
    }

    private var hasUnreviewedPhotos: Bool {
        remainingPhotosCount > 0
    }

    private var albumStateRefreshToken: [String] {
        guard isAlbumMode else { return [] }
        return dataManager.userAlbums.map { album in
            "\(album.id)|\(album.title)|\(album.photosCount)|\(album.thumbnailAsset?.localIdentifier ?? "")"
        }
    }

    @discardableResult
    private func refreshSelectedAlbumState(showMissingToast: Bool = true) -> Bool {
        guard let selectedAlbumInfo else { return true }

        guard let latestAlbumInfo = dataManager.currentUserAlbumInfo(for: selectedAlbumInfo) else {
            currentAlbumInfo = nil
            if showMissingToast {
                showFeedback(L10n.string("这个相册已不存在，列表已更新"), icon: "arrow.clockwise", style: .warning)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            }
            return false
        }

        let previousAlbumInfo = activeAlbumInfo
        currentAlbumInfo = latestAlbumInfo

        guard didInitializeSession,
              previousAlbumInfo?.id == latestAlbumInfo.id,
              previousAlbumInfo?.title != latestAlbumInfo.title ||
              previousAlbumInfo?.photosCount != latestAlbumInfo.photosCount ||
              previousAlbumInfo?.thumbnailAsset?.localIdentifier != latestAlbumInfo.thumbnailAsset?.localIdentifier else {
            return true
        }

        refreshSessionPhotos(dataManager.getPhotosForAlbum(latestAlbumInfo))
        return true
    }

    private func initializeSessionIfNeeded() {
        guard !didInitializeSession else { return }

        let photos = filteredRealPhotos
        if PhotoReviewSessionInitializationPolicy.shouldWaitForSource(
            isRandomReview: randomReviewScope != nil,
            hasPhotos: !photos.isEmpty,
            isWaitingForSourceData: isWaitingForSourceData,
            requiresCompleteSource: selectedCategory == .all,
            isSourceComplete: dataManager.photoLibraryManager.hasLoadedPhotoLibrary
        ) {
            return
        }

        refreshSessionPhotos(photos)
        didInitializeSession = true
    }

    private var isWaitingForSourceData: Bool {
        PhotoReviewSourceReadiness.isWaiting(
            selectedCategory: selectedCategory,
            selectedLocationGroupID: selectedLocationGroupID,
            hasLoadedAllCategoryPhotos: dataManager.photoLibraryManager.hasLoadedPhotoLibrary,
            isPhotoLibraryLoading: dataManager.photoLibraryManager.isLoading,
            isPreparingLibrary: dataManager.isPreparingLibrary,
            isRestoringLibrarySnapshot: dataManager.isRestoringLibrarySnapshot,
            isLoadingLocationGroups: dataManager.isLoadingLocationGroups,
            isResolvingLocationTitles: dataManager.isResolvingLocationTitles,
            isLoadingAdvancedCleanupQueues: dataManager.isLoadingAdvancedCleanupQueues,
            hasLoadedAlbumMembership: dataManager.hasLoadedAlbumMembership,
            isLoadingAlbums: dataManager.isLoadingAlbums
        ) || isWaitingForAlbumMembershipSource
    }

    private var unclassifiedSourceRefreshToken: String {
        guard selectedCategory == .unclassified else { return "" }
        return [
            dataManager.hasLoadedAlbumMembership ? "1" : "0",
            String(dataManager.albumMemberAssetIDs.count),
            String(dataManager.unclassifiedPhotosCount)
        ].joined(separator: "|")
    }

    private func refreshSessionForSourceChangeIfNeeded(force: Bool = false) {
        guard didInitializeSession else {
            if refreshSelectedAlbumState() {
                initializeSessionIfNeeded()
            }
            return
        }

        let photos = filteredRealPhotos
        if photos.isEmpty, isWaitingForSourceData, !session.allPhotos.isEmpty {
            return
        }

        let nextIDs = photos.map(\.localIdentifier)
        guard force || session.assetIdentifiers != nextIDs || (session.allPhotos.isEmpty && !photos.isEmpty) else {
            return
        }

        if session.allPhotos.isEmpty, !photos.isEmpty {
            didInitializeSession = false
            refreshSessionPhotos(photos)
            didInitializeSession = true
            return
        }

        let currentID = currentRealPhoto?.localIdentifier
        refreshSessionPhotos(photos)
        if let currentID,
           let updatedIndex = session.photos.firstIndex(where: { $0.localIdentifier == currentID }) {
            session.currentIndex = updatedIndex
        }
    }

    private func refreshSessionPhotos(_ photos: [PHAsset]? = nil) {
        showCompletionMessage = session.refresh(
            photos: photos ?? filteredRealPhotos,
            persistedReviewedIDs: dataManager.reviewedAssetIDs,
            usesPersistedReviewedState: !isAlbumMode && !isRandomMemoriesMode,
            preservesSessionReviewedState: didInitializeSession,
            savedAssetIdentifier: restoredSessionProgressAssetID,
            prefersFirstUnreviewedBeforeSavedProgress: shouldPrioritizeNewPhotosBeforeSavedProgress,
            paginates: shouldPageSessionPhotos
        )
        preloadUpcomingImages(from: session.currentIndex)
        persistSessionProgressIfPossible()
    }

    private func preloadUpcomingImages(from index: Int) {
        guard index < session.photos.count else { return }

        let upcomingPhotos = Array(session.photos.dropFirst(index).prefix(6))
        let currentIDs = preloadedAssets.map(\.localIdentifier)
        let nextIDs = upcomingPhotos.map(\.localIdentifier)
        guard currentIDs != nextIDs else { return }

        dataManager.photoLibraryManager.stopCachingImages(
            preloadedAssets,
            size: swipeImageTargetSize
        )
        dataManager.photoLibraryManager.preloadImagesForAssets(
            upcomingPhotos,
            size: swipeImageTargetSize,
            maxCount: 6
        )
        dataManager.photoLibraryManager.preloadSwipePreviewsForAssets(
            Array(upcomingPhotos.dropFirst()),
            size: swipeImageTargetSize,
            maxCount: 3
        )
        preloadedAssets = upcomingPhotos
    }

    private var swipeImageTargetSize: CGSize {
        let scale = displayScale
        return CGSize(width: 380 * scale, height: 520 * scale)
    }

    private func photoCardSize(in containerSize: CGSize) -> CGSize {
        let availableWidth = max(containerSize.width, 180)
        let availableHeight = max(containerSize.height - 132, 220)
        let maxSize = PhotoDeleteAdaptiveLayout.reviewPhotoCardMaxSize(
            in: containerSize,
            horizontalSizeClass: horizontalSizeClass
        )
        let width = availableWidth
        let height = min(availableHeight, maxSize.height)
        return CGSize(width: width, height: height)
    }

    private func imageTargetSize(for displaySize: CGSize) -> CGSize {
        let scale = displayScale
        return CGSize(width: displaySize.width * scale, height: displaySize.height * scale)
    }

    private func handleShareAction() {
        guard !isPreparingShare, let asset = currentRealPhoto else { return }

        HapticManager.impact(.light)
        isPreparingShare = true
        sharePreparationTask?.cancel()
        sharePreparationTask = Task {
            do {
                let payload = try await dataManager.photoLibraryManager.prepareSharePayload(for: asset)
                guard !Task.isCancelled else {
                    payload.cleanup()
                    return
                }
                await MainActor.run {
                    sharePayload = payload
                    isPreparingShare = false
                    sharePreparationTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    isPreparingShare = false
                    sharePreparationTask = nil
                }
            } catch {
                await MainActor.run {
                    isPreparingShare = false
                    sharePreparationTask = nil
                    showFeedback(
                        L10n.string("操作失败，请稍后重试。"),
                        icon: "exclamationmark.triangle",
                        style: .warning
                    )
                }
            }
        }
    }

    private func cleanupSharePayload() {
        sharePayload?.cleanup()
        sharePayload = nil
    }

    private func applySessionPlaybackPreferenceIfNeeded() {
        guard !didApplySessionPlaybackPreference else { return }
        sessionVideoMuted = defaultReviewVideoMuted
        didApplySessionPlaybackPreference = true
    }

    private func toggleSessionVideoMuted() {
        sessionVideoMuted.toggle()
        didApplySessionPlaybackPreference = true
        HapticManager.impact(.light)
        showFeedback(
            sessionVideoMuted ? L10n.string("已静音") : L10n.string("已打开声音"),
            icon: sessionVideoMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            style: .neutral,
            duration: 1.1
        )
    }

    private func browseToPreviousPhoto(reviewing asset: PHAsset) {
        guard let index = horizontalNeighborIndex(step: -1) else {
            showFeedback(L10n.string("已经是第一张"), icon: "chevron.left", style: .neutral, duration: 1.2)
            return
        }
        stopInlineVideoPlayback()
        setCurrentPhotoIndex(index)
        preloadUpcomingImages(from: index)
        persistSessionProgressIfPossible()
    }

    private func browseToNextPhoto(reviewing asset: PHAsset) {
        while horizontalNeighborIndex(step: 1) == nil,
              session.expand(for: session.photos.count, force: true) { }
        guard let index = horizontalNeighborIndex(step: 1) else {
            if randomReviewScope != nil {
                showFeedback(L10n.string("已浏览到最后一张"), icon: "checkmark", style: .positive, duration: 1.5)
            } else {
                showCompletionMessage = true
            }
            persistSessionProgressIfPossible()
            return
        }
        stopInlineVideoPlayback()
        setCurrentPhotoIndex(index)
        preloadUpcomingImages(from: index)
        persistSessionProgressIfPossible()
    }

    private func setCurrentPhotoIndex(_ index: Int) {
        guard isValidPhotoIndex(index), index != session.currentIndex else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            session.currentIndex = index
        }
    }

    private func moveToNextPhoto() {
        guard !session.photos.isEmpty else { return }

        stopInlineVideoPlayback()
        if let newIndex = session.nextUnreviewedIndex(after: session.currentIndex) {
            while newIndex >= session.photos.count,
                  session.expand(for: session.photos.count, force: true) { }

            guard newIndex < session.photos.count else {
                showCompletionMessage = true
                return
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                session.currentIndex = newIndex
            }
            preloadUpcomingImages(from: newIndex)
        } else {
            showCompletionMessage = true
        }
    }

    private func moveToPreviousPhoto() {
        guard session.currentIndex > 0 else { return }
        session.currentIndex -= 1
    }

    private func restorePhotoPosition(_ asset: PHAsset, preferredIndex: Int) {
        if isValidPhotoIndex(preferredIndex),
           session.photos[preferredIndex].localIdentifier == asset.localIdentifier {
            session.currentIndex = preferredIndex
        } else if let index = session.photos.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
            session.currentIndex = index
        } else {
            moveToPreviousPhoto()
        }
        showCompletionMessage = false
        preloadUpcomingImages(from: session.currentIndex)
    }

    private func continueToNextUnreviewedPhoto() {
        var nextIndex = firstLocallyUnreviewedPhotoIndex(startingAt: 0)
        while nextIndex == nil,
              session.expand(for: session.photos.count, force: true) {
            nextIndex = firstLocallyUnreviewedPhotoIndex(startingAt: 0)
        }

        guard let nextIndex else {
            return
        }
        session.currentIndex = nextIndex
        preloadUpcomingImages(from: nextIndex)
    }

    private func firstLocallyUnreviewedPhotoIndex(startingAt startIndex: Int) -> Int? {
        session.firstUnreviewedIndex(startingAt: startIndex)
    }

    private var restoredSessionProgressAssetID: String? {
        guard randomReviewScope == nil else { return nil }
        return PhotoReviewProgressStore.load(scopeID: sessionProgressScopeID)
    }

    private var shouldPrioritizeNewPhotosBeforeSavedProgress: Bool {
        (selectedCategory == .all || selectedCategory == .unclassified) && randomReviewScope == nil
    }

    private func scheduleSessionProgressSave() {
        sessionProgressSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            persistSessionProgressIfPossible()
            sessionProgressSaveWorkItem = nil
        }
        sessionProgressSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65, execute: workItem)
    }

    private func flushSessionProgressSave() {
        sessionProgressSaveWorkItem?.cancel()
        sessionProgressSaveWorkItem = nil
        persistSessionProgressIfPossible()
    }

    private func persistSessionProgressIfPossible() {
        guard randomReviewScope == nil,
              didInitializeSession,
              let asset = currentRealPhoto else { return }
        PhotoReviewProgressStore.save(
            assetIdentifier: asset.localIdentifier,
            scopeID: sessionProgressScopeID
        )
    }

    private var sessionProgressScopeID: String { source.progressScopeID }

    private func isValidPhotoIndex(_ index: Int) -> Bool {
        return index >= 0 && index < session.photos.count
    }

    private func isAssetQueuedForDelete(_ asset: PHAsset) -> Bool {
        actions.isAssetQueuedForDelete(asset, dataManager: dataManager)
    }

    private func isAssetQueuedForFavorite(_ asset: PHAsset) -> Bool {
        actions.isAssetQueuedForFavorite(asset, dataManager: dataManager)
    }

    private func isAssetBeingFiledToAlbum(_ asset: PHAsset) -> Bool {
        actions.isAssetBeingFiled(asset)
    }

    private func isAssetFiledToAlbum(_ asset: PHAsset) -> Bool {
        actions.isAssetRecentlyFiled(asset)
    }

    private func handleFavoriteAction() {
        guard canPerformPhotoAction(.favorite), let asset = currentRealPhoto else { return }
        actions.toggleFavoriteStatus(asset, dataManager: dataManager, session: session)
    }

    private func handleDeleteAction() {
        guard canPerformPhotoAction, let asset = currentRealPhoto else { return }
        if isAssetQueuedForDelete(asset) {
            actions.cancelDelete(asset, at: session.currentIndex, dataManager: dataManager, session: session)
            return
        }

        if actions.markDelete(asset, dataManager: dataManager, session: session) {
            moveToNextPhoto()
        }
    }

    private func handleFinishAction() {
        if hasPendingOperations {
            showCompletionMessage = false
            presentBatchConfirmation(dismissAfter: true)
        } else {
            dismiss()
        }
    }

    private func handleUndoAction() {
        actions.undo(
            dataManager: dataManager, session: session,
            refreshesAfterFavoriteUndo: selectedCategory == .favorites || activeAlbumInfo?.type == .favorites,
            refreshesAfterAlbumRemoval: selectedCategory == .unclassified || (randomReviewScope != nil && randomReviewHideFiledPhotos)
        )
    }

    private func effectiveFavoriteStatus(for asset: PHAsset) -> Bool {
        actions.effectiveFavoriteStatus(for: asset, dataManager: dataManager)
    }

    private func handleActionEvent(_ event: PhotoReviewActionEvent) {
        switch event {
        case let .feedback(message, icon, style, showsUndo, duration):
            let toastStyle: PhotoDeleteToastStyle
            switch style {
            case .neutral: toastStyle = .neutral
            case .positive: toastStyle = .positive
            case .destructive: toastStyle = .destructive
            case .favorite: toastStyle = .favorite
            case .warning: toastStyle = .warning
            }
            showFeedback(message, icon: icon, style: toastStyle, showsUndo: showsUndo, duration: duration)
        case let .restorePosition(asset, preferredIndex, refreshSource):
            if refreshSource { refreshSessionForSourceChangeIfNeeded(force: true) }
            restorePhotoPosition(asset, preferredIndex: preferredIndex)
        case let .albumSuccess(title):
            if showsAlbumFilingSheet {
                pendingAlbumSuccessToastTitle = title
            } else {
                showAlbumFilingSuccessToast(albumTitle: title)
            }
        case let .haptic(haptic):
            switch haptic {
            case .light: HapticManager.impact(.light)
            case .medium: HapticManager.impact(.medium)
            case .success: HapticManager.notify(.success)
            case .error: HapticManager.notify(.error)
            }
        }
    }

    private func openAlbumFilingSheet() {
        guard let asset = currentRealPhoto, !showCompletionMessage else { return }
        albumFilingSheetAsset = asset
        albumFilingSheetSelection.removeAll()
        dataManager.loadAlbumsIfNeeded()
        showsAlbumFilingSheet = true
    }

    private func fileCurrentPhotoFromSheet(_ albumInfo: AlbumInfo) {
        guard !albumFilingSheetSelection.contains(albumInfo.id),
              let asset = albumFilingSheetAsset else { return }
        guard actions.fileToAlbum(asset, albumInfo: albumInfo, dataManager: dataManager, session: session) else { return }
        albumFilingSheetSelection.insert(albumInfo.id)
    }

    private func finishAlbumFilingSheet() {
        let shouldAdvance = !albumFilingSheetSelection.isEmpty &&
            currentRealPhoto?.localIdentifier == albumFilingSheetAsset?.localIdentifier
        showsAlbumFilingSheet = false
        guard shouldAdvance else { return }
        moveToNextPhoto()
    }

    private func selectAlbumStripPhoto(at index: Int) {
        guard session.photos.indices.contains(index), index != session.currentIndex else { return }
        stopInlineVideoPlayback()
        setCurrentPhotoIndex(index)
        preloadUpcomingImages(from: index)
    }

    private func presentBatchConfirmation(dismissAfter: Bool) {
        shouldDismissAfterBatch = dismissAfter
        showBatchConfirm = true
    }

    private func handleBackAction() {
        // 如果有待处理的删除操作，显示确认对话框
        if hasPendingOperations {
            presentBatchConfirmation(dismissAfter: true)
        } else {
            dismiss()
        }
    }

    private var hasPendingOperations: Bool {
        pendingDeleteCount > 0 || pendingFavoriteCount > 0
    }

    private func showAlbumFilingSuccessToast(albumTitle: String) {
        showFeedback(
            String(format: L10n.string("已归类到 %@"), albumTitle),
            icon: "checkmark.circle.fill",
            style: .positive,
            duration: 1.6
        )
    }

    private func showFeedback(
        _ message: String,
        icon: String,
        style: PhotoDeleteToastStyle,
        showsUndo: Bool = false,
        duration: TimeInterval = 3.0
    ) {
        let toast = PhotoDeleteToast(message: message, icon: icon, style: style, showsUndo: showsUndo)
        withAnimation(.easeOut(duration: 0.18)) {
            feedbackToast = toast
        }

        let visibleDuration = showsUndo ? max(duration, 4.5) : duration
        DispatchQueue.main.asyncAfter(deadline: .now() + visibleDuration) {
            guard feedbackToast?.id == toast.id else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                feedbackToast = nil
            }
        }
    }

}

#Preview {
    SwipePhotoView(selectedCategory: PhotoCategory.all, selectedTimeGroup: nil, selectedAlbumInfo: nil)
        .environmentObject(DataManager())
}
