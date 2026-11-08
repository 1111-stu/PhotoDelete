//
//  SwipePhotoView.swift
//  Poca
//
//  Created by Poca Team on 11/7/25.
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    let explicitReviewScope: ExplicitAssetReviewScope?
    /// 照片墙点天进月：没有指定封面 ID 时，落到该日未整理照片（忽略本源进度恢复）。
    let reviewStartFromDay: Date?
    /// 照片墙 / 日历点到的那张封面；优先于 `reviewStartFromDay`。
    let reviewStartFromAssetID: String?

    @StateObject private var session = PhotoReviewSession()
    @State private var showingPendingDeletion = false
    @State private var showCompletionMessage = false
    @StateObject private var actions = PhotoReviewActions()
    @State private var randomReviewSeed = UUID().uuidString
    @AppStorage(AppConstants.randomReviewHideFiledPhotosKey) private var randomReviewHideFiledPhotos = true
    @AppStorage(AppConstants.randomReviewBatchSizeKey) private var randomReviewBatchSizeValue = PhotoRandomReviewBatchSize.defaultValue.rawValue
    @State private var feedbackToast: PocaToast?
    @State private var didInitializeSession = false
    @State private var preloadedAssets: [PHAsset] = []
    @State private var sessionProgressSaveWorkItem: DispatchWorkItem?
    @State private var manuallyStoppedVideoAssetID: String?
    @State private var manuallyStartedVideoAssetID: String?
    @State private var currentAlbumInfo: AlbumInfo?
    @State private var sessionVideoMuted = true
    @State private var showingPhotoDetails = false
    @State private var didApplySessionPlaybackPreference = false
    @State private var inlineVideoControlsRevealToken: UUID?
    @State private var sharePayload: PhotoSharePayload?
    @State private var sharePreparationTask: Task<Void, Never>?
    @State private var isPreparingShare = false
    @State private var showingShareCardSheet = false
    @State private var pendingSharePayload: PhotoSharePayload?
    @State private var showsAlbumTray = false
    @State private var albumTrayAsset: PHAsset?
    @State private var dayWallTarget: DayWallTarget?
    @State private var filingAlbumID: String?
    @State private var needsSourceRefreshAfterAlbumTray = false
    /// 相册导轨正在被拖动/惯性滚动：切换照片不加动画，预加载推迟到停手。
    @State private var isStripScrubbing = false

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
        selectedHistoricalToday: Bool = false,
        explicitReviewScope: ExplicitAssetReviewScope? = nil,
        reviewStartFromDay: Date? = nil,
        reviewStartFromAssetID: String? = nil
    ) {
        self.selectedCategory = selectedCategory
        self.selectedTimeGroup = selectedTimeGroup
        self.selectedAlbumInfo = selectedAlbumInfo ?? explicitReviewScope?.albumInfo
        self.selectedDate = selectedDate
        self.selectedAdvancedTimeScope = selectedAdvancedTimeScope
        self.selectedAdvancedCleanup = selectedAdvancedCleanup
        self.selectedLocationGroupID = selectedLocationGroupID
        self.randomReviewScope = randomReviewScope
        self.selectedHistoricalToday = selectedHistoricalToday
        self.explicitReviewScope = explicitReviewScope
        self.reviewStartFromDay = reviewStartFromDay
        self.reviewStartFromAssetID = reviewStartFromAssetID
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
            randomReviewScope: randomReviewScope, selectedHistoricalToday: selectedHistoricalToday,
            explicitReviewScope: explicitReviewScope
        )
    }

    private var filteredRealPhotos: [PHAsset] {
        let photos = source.photos(
            dataManager: dataManager, activeAlbumInfo: activeAlbumInfo,
            randomSeed: randomReviewSeed, hideFiled: randomReviewHideFiledPhotos,
            batchSizeValue: randomReviewBatchSizeValue, sortOrderValue: reviewSortOrderValue
        )
        guard showsOnlyPendingPhotos else { return photos }
        return photos.filter { dataManager.disposition(for: $0) == .pending }
    }

    /// 整理队列只收「待整理」；相册浏览、收藏分类、显式 includeAll 范围保持原来源。
    /// 相册页的「整理」入口按待整理收，旧相册照片才能继续被清理。
    private var showsOnlyPendingPhotos: Bool {
        if randomReviewScope != nil { return false }
        if let explicitReviewScope {
            return explicitReviewScope.reviewedPolicy == .skipPreviouslyReviewed
        }
        return selectedCategory != .favorites
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
        guard canInlinePlayVideo(asset) else { return false }
        if manuallyStoppedVideoAssetID == asset.localIdentifier {
            return false
        }
        if manuallyStartedVideoAssetID == asset.localIdentifier {
            return true
        }
        return reviewVideoAutoPlay
    }

    /// 视频是否具备内联播放条件（与「自动播放」偏好无关）。
    private func canInlinePlayVideo(_ asset: PHAsset) -> Bool {
        asset.mediaType == .video &&
            !isAssetQueuedForDelete(asset) &&
            !isAssetQueuedForFavorite(asset) &&
            !isAssetBeingFiledToAlbum(asset) &&
            !isAssetFiledToAlbum(asset)
    }

    /// 关闭自动播放时，点卡片手动起播；再点一次用于唤出进度条。
    private func startInlineVideoPlayback(for asset: PHAsset) {
        guard canInlinePlayVideo(asset) else { return }
        manuallyStoppedVideoAssetID = nil
        manuallyStartedVideoAssetID = asset.localIdentifier
        HapticManager.impact(.light)
    }

    private var canPerformPhotoAction: Bool {
        canPerformPhotoAction(.keep)
    }

    private func canPerformPhotoAction(_ action: SwipeGestureAction) -> Bool {
        currentRealPhoto != nil &&
            !showCompletionMessage &&
            !showsAlbumTray &&
            !isCurrentPhotoBeingFiled &&
            actions.canStartAction(action)
    }

    /// 托盘打开时，写入目标固定为打开那一刻的照片，避免后台刷新把写入目标换掉。
    private var isAlbumTrayFiling: Bool {
        guard let asset = albumTrayAsset else { return false }
        return isAssetBeingFiledToAlbum(asset)
    }

    private var pendingDeleteCount: Int { dataManager.deleteCandidates.count }
    private var pendingFavoriteCount: Int { dataManager.favoriteCandidates.count }

    var body: some View {
        ZStack {
            Theme.reviewCanvas
                .ignoresSafeArea()

            GeometryReader { geometry in
                let usesSidebar = PocaAdaptiveLayout.prefersReviewSidebar(
                    in: geometry.size,
                    horizontalSizeClass: horizontalSizeClass
                )
                let sidebarWidth = PocaAdaptiveLayout.reviewSidebarWidth(totalWidth: geometry.size.width)
                let primaryWidth = geometry.size.width - sidebarWidth

                ZStack(alignment: .bottom) {
                    if usesSidebar {
                        HStack(spacing: 0) {
                            VStack(spacing: 0) {
                                navigationHeader
                                photoArea
                            }
                            .frame(width: primaryWidth)

                            landscapeSidebar
                                .frame(width: sidebarWidth, height: geometry.size.height)
                        }
                        .accessibilityHidden(showsAlbumTray)
                    } else {
                        VStack(spacing: 0) {
                            navigationHeader
                            photoArea
                            bottomControls
                        }
                        .accessibilityHidden(showsAlbumTray)
                    }

                    if showsAlbumTray {
                        Theme.trayScrim
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture { closeAlbumTray() }
                            .accessibilityHidden(true)
                            .transition(.opacity)

                        ReviewAlbumTray(
                            albums: dataManager.getUserAlbumsSortedByCustomOrder(),
                            isLoading: dataManager.isLoadingAlbums,
                            isFiling: isAlbumTrayFiling,
                            filingAlbumID: filingAlbumID,
                            onSelect: fileCurrentTrayPhoto(to:),
                            onClose: closeAlbumTray
                        )
                        .frame(
                            maxWidth: ReviewAlbumTrayLayout.maxWidth,
                            alignment: .leading
                        )
                        .padding(.leading, ReviewAlbumTrayLayout.sideMargin)
                        .padding(
                            .trailing,
                            usesSidebar
                                ? sidebarWidth + ReviewAlbumTrayLayout.sideMargin
                                : ReviewAlbumTrayLayout.sideMargin
                        )
                        .padding(.bottom, ReviewAlbumTrayLayout.bottomMargin)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity)
                        )
                    }

                    // 统一 Toast：始终固定在页头，托盘打开时也不下移。
                    if let feedbackToast {
                        PocaToastView(toast: feedbackToast) {
                            handleUndoAction()
                        }
                        .frame(maxWidth: 420)
                        .padding(.horizontal, Theme.space5)
                        .padding(.trailing, usesSidebar ? sidebarWidth : 0)
                        .allowsHitTesting(feedbackToast.showsUndo)
                        .padding(.top, Theme.space16)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .top
                        )
                        .transition(PocaToastTiming.transition(reduceMotion: reduceMotion, edge: .top))
                    }
                }
            }

            if showCompletionMessage {
                completionOverlay
            }
        }
        .photoDeleteToastAutoDismiss($feedbackToast)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingPhotoDetails) {
            if let asset = currentRealPhoto {
                PhotoDetailSheet(asset: asset, dataManager: dataManager)
            }
        }
        .sheet(isPresented: $showingShareCardSheet, onDismiss: presentPendingSharePayloadIfNeeded) {
            if let asset = currentRealPhoto {
                ShareCardPreviewSheet(
                    asset: asset,
                    dataManager: dataManager,
                    onSharePayload: { payload in
                        pendingSharePayload = payload
                    }
                )
            }
        }
        .sheet(item: $sharePayload, onDismiss: cleanupSharePayload) { payload in
            SystemShareSheet(activityItems: [payload.fileURL])
        }
        .fullScreenCover(isPresented: $showingPendingDeletion) {
            NavigationStack {
                PendingDeletionView()
                    .environmentObject(dataManager)
            }
        }
        .fullScreenCover(item: $dayWallTarget, onDismiss: handleDayWallDismiss) { target in
            DayPhotoWallView(day: target.day, sourceAssetID: target.sourceAssetID)
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
        .onChange(of: isAlbumTrayFiling) { _, isFiling in
            if !isFiling { filingAlbumID = nil }
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
        .onChange(of: dataManager.assetLibraryRevision) { _ in
            guard explicitReviewScope != nil else { return }
            refreshSessionForSourceChangeIfNeeded(force: true)
        }
        .onChange(of: dataManager.photoLibraryManager.favorites.count) { _ in
            guard selectedCategory == .favorites || activeAlbumInfo?.type == .favorites else { return }
            refreshSessionForSourceChangeIfNeeded(force: true)
        }
        .onChange(of: dataManager.deleteCandidates.map(\.localIdentifier)) { _ in
            reconcileSessionReviewedStateWithTrash()
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
            if explicitReviewScope != nil {
                refreshSessionForSourceChangeIfNeeded(force: true)
            }
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
        .onChange(of: isStripScrubbing) { isScrubbing in
            // 拖动中每跨一格都会切照片，预加载推迟到停手后补一次。
            if !isScrubbing {
                preloadUpcomingImages(from: session.currentIndex)
            }
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
            title: navigationHeaderTitle,
            deleteCount: pendingDeleteCount, canDelete: true,
            onBack: handleBackAction, onDelete: { showingPendingDeletion = true }
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
                            subtitle: L10n.string("Allow photo library access to start organizing photos"),
                            onRequestAccess: { dataManager.requestPhotoLibraryAccess() }
                        )
                        .padding(.horizontal, Theme.space5)
                    }
                } else if let realPhoto = currentRealPhoto {
                    ZStack {
                        cardPhotoArea(asset: realPhoto, in: geometry.size)
                    }
                    .scaleEffect(showsAlbumTray && !reduceMotion ? 0.97 : 1)
                    .animation(.easeOut(duration: 0.22), value: showsAlbumTray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if shouldShowInitialPreparingState {
                    centeredPhotoAreaPlaceholder(in: geometry, bottomReserve: placeholderBottomReserve) {
                        PhotoSelectionLoadingCard(
                            title: L10n.string("Reading Photos"),
                            message: L10n.string("When reading finishes, this cleanup will start automatically."),
                            progress: activeLibraryLoadingProgress
                        )
                        .padding(.horizontal, Theme.space5)
                    }
                } else if shouldShowBackgroundLoadingState {
                    centeredPhotoAreaPlaceholder(in: geometry, bottomReserve: placeholderBottomReserve) {
                        PhotoSelectionLoadingCard(
                            title: L10n.string("Reading Current Album"),
                            message: L10n.string("Large libraries can take a few seconds. Cleanup starts automatically when ready."),
                            progress: activeLibraryLoadingProgress
                        )
                        .padding(.horizontal, Theme.space5)
                    }
                } else {
                    centeredPhotoAreaPlaceholder(in: geometry, bottomReserve: placeholderBottomReserve) {
                        // 没有更多照片
                        VStack(spacing: 20) {
                            if totalPhotosCount == 0 {
                                // 没有照片的情况
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 60, weight: .medium))
                                    .foregroundColor(Theme.accent)

                                Text(emptyPhotoTitle)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(Theme.primaryText)

                                Text(emptyPhotoMessage)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(Theme.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, Theme.space5)

                                Button(action: { dismiss() }) {
                                    Text(L10n.string("Back to Home"))
                                        .frame(maxWidth: 180)
                                }
                                .photoDeleteSecondaryButton()
                            } else {
                                // 整理完成的情况
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60, weight: .medium))
                                    .foregroundColor(Theme.positive)

                                Text(L10n.string("Cleanup Complete!"))
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(Theme.primaryText)

                                Text(L10n.string("You have finished all photos"))
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(Theme.secondaryText)

                                Button(action: { dismiss() }) {
                                    Text(L10n.string("Back to Home"))
                                        .frame(maxWidth: 180)
                                }
                                .photoDeleteSecondaryButton()
                            }
                        }
                        .padding(24)
                        .photoDeleteCard()
                        .padding(.horizontal, Theme.space5)
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
        // 卡片 + 元数据小字作为一个整体居中：小字始终贴在卡片下方，而不是钉在区域底部。
        return VStack(spacing: 6) {
            ReviewPhotoPager(
                pages: horizontalPageEntries(),
                currentID: asset.localIdentifier,
                cardSize: cardSize,
                pageStride: containerSize.width,
                canDelete: canPerformPhotoAction(.delete),
                isVideoPlaying: shouldPlayVideo(for: asset),
                isEnabled: !showsAlbumTray,
                onBrowse: { step in
                    guard let index = horizontalNeighborIndex(step: step) else { return }
                    session.currentIndex = index
                    preloadUpcomingImages(from: index)
                    persistSessionProgressIfPossible()
                },
                onBrowsePastEnd: presentRoundSummary,
                onDelete: handleDeleteAction,
                onFile: openAlbumTray
            ) { photo, isCurrent in
                reviewPhotoCard(asset: photo, cardSize: cardSize, isCurrent: isCurrent)
            }
            .frame(height: cardSize.height)
            .zIndex(1)

            ReviewPhotoDetailLine(asset: asset)
                .id(asset.localIdentifier)
                .zIndex(0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .photoDeleteSimultaneousTapGesture(enabled: isCurrent && (isInlineVideoPlaying || canInlinePlayVideo(asset))) {
                if isInlineVideoPlaying {
                    revealInlineVideoPlaybackControls()
                } else {
                    startInlineVideoPlayback(for: asset)
                }
            }
            .accessibilityAction(named: Text(L10n.string("Mark to delete"))) {
                handleDeleteAction()

            }
            .accessibilityAction(named: Text(L10n.string("Add to Album"))) {
                openAlbumTray()
            }
            .accessibilityAction(named: Text(isCurrentPhotoFavorited ? L10n.string("Unfavorite") : L10n.string("Add to favorites"))) {
                handleFavoriteAction()

            }
            .accessibilityAction(named: Text(L10n.string("Next Photo"))) {
                browseToNextPhoto(reviewing: asset)
            }
            .accessibilityAction(named: Text(L10n.string("Previous"))) {
                browseToPreviousPhoto(reviewing: asset)
            }
            .modifier(
                DayWallAccessibilityAction(
                    isEnabled: AppConstants.dayWallEnabled && asset.creationDate != nil,
                    action: openDayWallIfPossible
                )
            )
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
            isAssetQueuedForDelete(session.photos[index])
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
        manuallyStartedVideoAssetID = nil
        if let asset, asset.mediaType == .video {
            manuallyStoppedVideoAssetID = asset.localIdentifier
        }
    }

    private var completionOverlay: some View {
        ReviewCompletionOverlay(
            sessionDeleteCount: actions.deleteActionCount,
            sessionFavoriteCount: actions.favoriteActionCount,
            collectionBinCount: pendingDeleteCount,
            onDismiss: {
                withAnimation(.easeOut(duration: 0.18)) {
                    showCompletionMessage = false
                }
            },
            onFinish: {
                showCompletionMessage = false
                dismiss()
            }
        )
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
        .disabled(showsAlbumTray)
        // 不垫底色遮罩：下滑的卡片直接滑到玻璃条后面，由玻璃虚化（去掉"切割感"）。
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
                    title: L10n.string("Undo"),
                    color: Theme.secondaryText
                ) {
                    handleUndoAction()

                }

                if AppConstants.dayWallEnabled {
                    SidebarActionButton(
                        icon: "calendar.day.timeline.left",
                        title: L10n.string("Photos from this day"),
                        color: Theme.accent
                    ) {
                        openDayWallIfPossible()
                    }
                    .disabled(currentRealPhoto?.creationDate == nil)
                    .opacity(currentRealPhoto?.creationDate == nil ? 0.35 : 1)
                }

                SidebarActionButton(
                    icon: isCurrentPhotoFavorited ? "heart.slash" : "heart",
                    title: isCurrentPhotoFavorited ? L10n.string("Unfavorite") : L10n.string("Favorite"),
                    color: Theme.iconTint(for: "favorite")
                ) {
                    handleFavoriteAction()

                }

                SidebarActionButton(
                    icon: isPreparingShare ? "hourglass" : "square.and.arrow.up",
                    title: isPreparingShare ? L10n.string("Preparing") : L10n.string("Share"),
                    color: Theme.accent
                ) {
                    handleShareAction()

                }

                SidebarActionButton(
                    icon: "trash",
                    title: L10n.string("Mark to delete"),
                    color: Theme.destructive
                ) {
                    handleDeleteAction()

                }

                SidebarActionButton(
                    icon: "checkmark",
                    title: L10n.string("Finish Organizing"),
                    color: Theme.positive
                ) {
                    presentRoundSummary()
                }
            }
            .disabled(!canPerformPhotoAction)
            .opacity(canPerformPhotoAction ? 1 : 0.45)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(Theme.reviewCanvas)
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
            isPreparingShare: isPreparingShare,
            showsDayWallButton: AppConstants.dayWallEnabled,
            canOpenDayWall: currentRealPhoto?.creationDate != nil,
            onShowDetails: { showingPhotoDetails = true },
            onUndo: handleUndoAction, onFavorite: handleFavoriteAction,
            onShare: handleShareAction, onFinish: handleFinishAction,
            onShowDayWall: openDayWallIfPossible
        )
    }

    private var showsAlbumPhotoStrip: Bool {
        selectedAlbumInfo != nil && randomReviewScope == nil && !session.photos.isEmpty
    }

    private var albumPhotoStrip: some View {
        // 导轨只列还留在本轮里的照片；已加入待删除的项不会再出现在选择列表里
        // （当前项例外，见 AlbumReviewStripPolicy）。下标要映射回 session，
        // 否则过滤后点缩略图会跳到错的照片。
        let sessionIndices = AlbumReviewStripPolicy.visibleSessionIndices(
            count: session.photos.count,
            currentIndex: session.currentIndex,
            isQueuedForDelete: { isAssetQueuedForDelete(session.photos[$0]) }
        )
        let stripPhotos = sessionIndices.map { session.photos[$0] }
        let currentStripIndex = sessionIndices.firstIndex(of: session.currentIndex) ?? 0
        return ReviewPhotoStrip(
            photos: stripPhotos,
            currentIndex: currentStripIndex,
            photoLibraryManager: dataManager.photoLibraryManager,
            isScrubbing: $isStripScrubbing,
            onSelect: { stripIndex in
                guard sessionIndices.indices.contains(stripIndex) else { return }
                selectAlbumStripPhoto(at: sessionIndices[stripIndex])
            }
        )
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
            return randomReviewHideFiledPhotos ? L10n.string("No unfiled photos found") : L10n.string("No photos to clean up here yet")
        }
        return L10n.string("No photos to clean up here yet")
    }

    private var emptyPhotoMessage: String {
        if isRandomMemoriesMode {
            return randomReviewHideFiledPhotos
                ? L10n.string("Filed photos are hidden. You can show them again in review settings.")
                : L10n.string("If photo access is limited, allow more photos in System Settings.")
        }
        return L10n.string("Go back and choose another category, or add more photos in Photos and come back later.")
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
        // 数字一律无千分位
        "\(PocaCountFormat.plain(currentProgress)) / \(PocaCountFormat.plain(totalPhotosCount))"
    }

    private var headerProgressSubtitle: String {
        String(
            format: L10n.string("%lld left this round"),
            Int64(max(totalPhotosCount - currentProgress, 0))
        )
    }

    private func formattedCount(_ count: Int) -> String {
        Self.countFormatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private func loadAlbumShortcutsIfNeeded() {
        guard !isAlbumMode else { return }
        dataManager.loadAlbumsIfNeeded()
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
                showFeedback(L10n.string("This album no longer exists. The list has been updated."), icon: "arrow.clockwise", style: .warning)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            }
            return false
        }

        let previousAlbumInfo = activeAlbumInfo
        currentAlbumInfo = latestAlbumInfo

        if showsAlbumTray {
            needsSourceRefreshAfterAlbumTray = true
            return true
        }

        guard didInitializeSession,
              previousAlbumInfo?.id == latestAlbumInfo.id,
              previousAlbumInfo?.title != latestAlbumInfo.title ||
              previousAlbumInfo?.photosCount != latestAlbumInfo.photosCount ||
              previousAlbumInfo?.thumbnailAsset?.localIdentifier != latestAlbumInfo.thumbnailAsset?.localIdentifier else {
            return true
        }

        if explicitReviewScope != nil {
            refreshSessionForSourceChangeIfNeeded(force: true)
        } else {
            refreshSessionPhotos(dataManager.getPhotosForAlbum(latestAlbumInfo))
        }
        return true
    }

    private func initializeSessionIfNeeded() {
        guard !didInitializeSession else { return }

        let photos = filteredRealPhotos
        if PhotoReviewSessionInitializationPolicy.shouldWaitForSource(
            isRandomReview: randomReviewScope != nil,
            hasPhotos: !photos.isEmpty,
            isWaitingForSourceData: isWaitingForSourceData,
            requiresCompleteSource: explicitReviewScope == nil && selectedCategory == .all,
            isSourceComplete: dataManager.photoLibraryManager.hasLoadedPhotoLibrary
        ) {
            return
        }

        refreshSessionPhotos(photos)
        didInitializeSession = true
    }

    private var isWaitingForSourceData: Bool {
        guard explicitReviewScope == nil else { return false }
        return PhotoReviewSourceReadiness.isWaiting(
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
        if showsAlbumTray {
            needsSourceRefreshAfterAlbumTray = true
            return
        }
        guard didInitializeSession else {
            if refreshSelectedAlbumState() {
                initializeSessionIfNeeded()
            }
            return
        }

        let photos: [PHAsset]
        if let explicitReviewScope {
            // Once an ID disappears, it cannot rejoin this temporary session.
            photos = explicitReviewScope.orderedElements(
                from: filteredRealPhotos,
                retainingAssetIDs: Set(session.assetIdentifiers),
                identifier: \.localIdentifier
            )
        } else {
            photos = filteredRealPhotos
        }
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
            persistedReviewedIDs: dataManager.completedAssetIDsForReview,
            // 收藏本身就是完成信号；收藏分类要能继续浏览收藏照片做清理，不能按“已完成”跳过。
            usesPersistedReviewedState: explicitReviewScope?.usesPersistedReviewedState(hasAlbumContext: isAlbumMode)
                ?? (!isAlbumMode && !isRandomMemoriesMode && selectedCategory != .favorites),
            preservesSessionReviewedState: didInitializeSession,
            savedAssetIdentifier: (reviewStartFromDay == nil && reviewStartFromAssetID == nil)
                ? restoredSessionProgressAssetID
                : nil,
            prefersFirstUnreviewedBeforeSavedProgress: shouldPrioritizeNewPhotosBeforeSavedProgress,
            startFromDay: didInitializeSession ? nil : reviewStartFromDay,
            startFromAssetID: didInitializeSession ? nil : reviewStartFromAssetID,
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
        // 两侧留出页面边距；翻页步长仍是整页宽，卡片之间因此有可见间隔。
        let availableWidth = max(containerSize.width - Theme.space5 * 2, 180)
        let availableHeight = max(containerSize.height - 132, 220)
        let maxSize = PocaAdaptiveLayout.reviewPhotoCardMaxSize(
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
        if asset.mediaType == .video {
            prepareOriginalShare(for: asset)
        } else {
            showingShareCardSheet = true
        }
    }

    private func prepareOriginalShare(for asset: PHAsset) {
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
                        L10n.string("Operation failed. Try again later."),
                        icon: "exclamationmark.triangle",
                        style: .warning
                    )
                }
            }
        }
    }

    private func presentPendingSharePayloadIfNeeded() {
        guard let pendingSharePayload else { return }
        sharePayload = pendingSharePayload
        self.pendingSharePayload = nil
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
            sessionVideoMuted ? L10n.string("Muted") : L10n.string("Sound On"),
            icon: sessionVideoMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            style: .neutral,
            duration: 1.1
        )
    }

    private func browseToPreviousPhoto(reviewing asset: PHAsset) {
        guard let index = horizontalNeighborIndex(step: -1) else {
            showFeedback(L10n.string("This is the first photo"), icon: "chevron.left", style: .neutral, duration: 1.2)
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
            presentRoundSummary()
            persistSessionProgressIfPossible()
            return
        }
        stopInlineVideoPlayback()
        setCurrentPhotoIndex(index)
        preloadUpcomingImages(from: index)
        persistSessionProgressIfPossible()
    }

    private func setCurrentPhotoIndex(_ index: Int, animated: Bool = true) {
        guard isValidPhotoIndex(index), index != session.currentIndex else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                session.currentIndex = index
            }
        } else {
            // 导轨拖动中即时切换：0.18s 动画会让快速 scrub 发粘。
            session.currentIndex = index
        }
    }

    private func moveToNextPhoto() {
        guard !session.photos.isEmpty else { return }

        stopInlineVideoPlayback()
        // 所有来源都跳过垃圾桶里的照片：待确认不在待整理的浏览队列里。
        let queuedIdentifiers = Set(dataManager.deleteCandidates.map(\.localIdentifier))
        let isExcluded: (Int) -> Bool = { index in
            guard session.assetIdentifiers.indices.contains(index) else { return false }
            return queuedIdentifiers.contains(session.assetIdentifiers[index])
        }
        if let newIndex = session.nextUnreviewedIndex(after: session.currentIndex, isExcluded: isExcluded) {
            while newIndex >= session.photos.count,
                  session.expand(for: session.photos.count, force: true) { }

            guard newIndex < session.photos.count else {
                presentRoundSummary()
                return
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                session.currentIndex = newIndex
            }
            preloadUpcomingImages(from: newIndex)
        } else {
            presentRoundSummary()
        }
    }

    private func moveToPreviousPhoto() {
        guard session.currentIndex > 0 else { return }
        session.currentIndex -= 1
    }

    // MARK: - 回到那天

    private func openDayWallIfPossible() {
        guard AppConstants.dayWallEnabled,
              !showsAlbumTray,
              !showCompletionMessage,
              !isCurrentPhotoBeingFiled,
              let asset = currentRealPhoto,
              let day = asset.creationDate else { return }

        stopInlineVideoPlayback(rememberManualStopFor: asset)
        HapticManager.impact(.light)
        dayWallTarget = DayWallTarget(day: day, sourceAssetID: asset.localIdentifier)
    }

    private func handleDayWallDismiss() {
        // 当前这张如果被点进垃圾桶，回来时落到下一张未处理的照片（任何来源都跳过垃圾桶里的）。
        guard let current = currentRealPhoto, isAssetQueuedForDelete(current) else { return }

        let start = session.currentIndex + 1
        let nextIndex = session.photos.indices.first {
            $0 >= start && !isAssetQueuedForDelete(session.photos[$0])
        } ?? session.photos.indices.first {
            !isAssetQueuedForDelete(session.photos[$0])
        }

        guard let nextIndex else {
            presentRoundSummary()
            return
        }

        setCurrentPhotoIndex(nextIndex, animated: false)
        preloadUpcomingImages(from: nextIndex)
        persistSessionProgressIfPossible()
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

    private var restoredSessionProgressAssetID: String? {
        guard source.persistsProgress else { return nil }
        return PhotoReviewProgressStore.load(scopeID: sessionProgressScopeID)
    }

    private var shouldPrioritizeNewPhotosBeforeSavedProgress: Bool {
        explicitReviewScope == nil &&
            (selectedCategory == .all || selectedCategory == .unclassified) && randomReviewScope == nil
    }

    private func scheduleSessionProgressSave() {
        guard source.persistsProgress else { return }
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
        guard source.persistsProgress,
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

    /// 从垃圾桶移出的照片回到本轮：撤掉仅因暂存产生的会话已处理标记。
    private func reconcileSessionReviewedStateWithTrash() {
        let stagedIDs = Set(dataManager.deleteCandidates.map(\.localIdentifier))
        let completedIDs = dataManager.reviewedAssetIDs
        let restoredIDs = session.reviewedIDs.filter { identifier in
            !stagedIDs.contains(identifier)
                && !completedIDs.contains(identifier)
                && !actions.albumFilingAssetIDs.contains(identifier)
                && !actions.recentlyFiledAlbumAssetIDs.contains(identifier)
        }
        guard !restoredIDs.isEmpty else { return }
        session.reviewedIDs.subtract(restoredIDs)
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
        presentRoundSummary()
    }

    /// 本轮结算（完成钮 / 末张越界滑 / 队列到头）。不提交删除。
    private func presentRoundSummary() {
        guard !showCompletionMessage else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            showCompletionMessage = true
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
        case let .feedback(message, icon, style, showsUndo):
            let toastStyle: PocaToastStyle
            switch style {
            case .neutral: toastStyle = .neutral
            case .positive: toastStyle = .positive
            case .destructive: toastStyle = .destructive
            case .favorite: toastStyle = .favorite
            case .warning: toastStyle = .warning
            }
            showFeedback(message, icon: icon, style: toastStyle, showsUndo: showsUndo)
        case let .restorePosition(asset, preferredIndex, refreshSource):
            if showsAlbumTray {
                needsSourceRefreshAfterAlbumTray = needsSourceRefreshAfterAlbumTray || refreshSource
                return
            }
            if refreshSource { refreshSessionForSourceChangeIfNeeded(force: true) }
            restorePhotoPosition(asset, preferredIndex: preferredIndex)
        case let .albumSuccess(title):
            showAlbumFilingSuccessToast(albumTitle: title)
        case .albumFilingSelectionChange:
            // 托盘是一击即写入，没有多选状态需要回滚。
            break
        case let .haptic(haptic):
            switch haptic {
            case .light: HapticManager.impact(.light)
            case .medium: HapticManager.impact(.medium)
            case .success: HapticManager.notify(.success)
            case .error: HapticManager.notify(.error)
            }
        }
    }

    private func openAlbumTray() {
        guard let asset = currentRealPhoto, !showCompletionMessage, !showsAlbumTray else { return }
        if asset.mediaType == .video {
            stopInlineVideoPlayback(rememberManualStopFor: asset)
        }
        albumTrayAsset = asset
        filingAlbumID = nil
        needsSourceRefreshAfterAlbumTray = false
        dataManager.loadAlbumsIfNeeded()
        withAnimation(
            reduceMotion
                ? ReviewAlbumTrayLayout.reduceMotionAnimation
                : ReviewAlbumTrayLayout.presentationAnimation
        ) {
            showsAlbumTray = true
        }
    }

    private func closeAlbumTray() {
        guard showsAlbumTray else { return }
        withAnimation(
            reduceMotion
                ? ReviewAlbumTrayLayout.reduceMotionAnimation
                : ReviewAlbumTrayLayout.presentationAnimation
        ) {
            showsAlbumTray = false
        }
        albumTrayAsset = nil
        filingAlbumID = nil
        if needsSourceRefreshAfterAlbumTray {
            needsSourceRefreshAfterAlbumTray = false
            refreshSessionForSourceChangeIfNeeded(force: true)
        }
    }

    private func fileCurrentTrayPhoto(to album: AlbumInfo) {
        guard showsAlbumTray,
              let asset = albumTrayAsset,
              !isAlbumTrayFiling else { return }

        if actions.fileToAlbum(asset, albumInfo: album, dataManager: dataManager, session: session) {
            filingAlbumID = album.id
        }
        // 刻意不调用 moveToNextPhoto()：托盘保持打开，当前照片不前进。
    }

    private func selectAlbumStripPhoto(at index: Int) {
        guard session.photos.indices.contains(index), index != session.currentIndex else { return }
        stopInlineVideoPlayback()
        // 只有相邻一张才走滑动动画；远处跳转会整组换页，加动画反而会浮出错的过渡。
        let isNeighborStep = abs(index - session.currentIndex) == 1
        setCurrentPhotoIndex(index, animated: !isStripScrubbing && isNeighborStep)
        // 拖动中每跨一格都会走到这里：预加载留到停手后统一补（见 isStripScrubbing 的 onChange）。
        if !isStripScrubbing {
            preloadUpcomingImages(from: index)
        }
    }

    private func handleBackAction() {
        dismiss()
    }

    private func showAlbumFilingSuccessToast(albumTitle: String) {
        showFeedback(
            String(format: L10n.string("Added to %@"), albumTitle),
            icon: "checkmark.circle.fill",
            style: .positive,
            showsUndo: true
        )
    }

    private func showFeedback(
        _ message: String,
        icon: String,
        style: PocaToastStyle,
        showsUndo: Bool = false,
        duration: TimeInterval? = nil
    ) {
        let toast = PocaToast(
            message: message,
            icon: icon,
            style: style,
            showsUndo: showsUndo,
            duration: duration
        )
        withAnimation(reduceMotion ? PocaToastTiming.reducedEnter : PocaToastTiming.enter) {
            feedbackToast = toast
        }
    }

}

private struct DayWallTarget: Identifiable {
    let id = UUID()
    let day: Date
    let sourceAssetID: String
}

/// 日期墙入口在相册模式下不存在，VoiceOver 的自定义动作也要跟着只在随机整理里出现。
private struct DayWallAccessibilityAction: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.accessibilityAction(
                named: Text(L10n.string("Photos from this day")),
                action
            )
        } else {
            content
        }
    }
}

#Preview {
    SwipePhotoView(selectedCategory: PhotoCategory.all, selectedTimeGroup: nil, selectedAlbumInfo: nil)
        .environmentObject(DataManager())
}
