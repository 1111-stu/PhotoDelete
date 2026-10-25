//
//  HomeView.swift
//  PhotoDelete
//
//  Created by PhotoDelete Team on 11/7/25.
//

import SwiftUI

enum SwipeViewDestination: Hashable {
    case category(PhotoCategory)
    case assetBrowser(AssetCategoryID)
    case timeGroup(String)
    case album(AlbumInfo)
    case random(PhotoRandomReviewScope)
    case timeBrowser
    case locationBrowser
    case historicalToday
    case location(String)
    case period(AdvancedTimeScope, Date)
    /// 照片墙进月整理：`monthDate` 定月份；`startFromAssetID` 优先落到墙上那张封面，没有再按 `startFromDay`。
    case wallMonth(Date, startFromDay: Date?, startFromAssetID: String?)
    case pendingPhotoWall
    case cleanup(AdvancedCleanupKind)
    case trashBin

    static func == (lhs: SwipeViewDestination, rhs: SwipeViewDestination) -> Bool {
        switch (lhs, rhs) {
        case (.assetBrowser(let lhsCategory), .assetBrowser(let rhsCategory)):
            return lhsCategory == rhsCategory
        case (.category(let lhsCategory), .category(let rhsCategory)):
            return lhsCategory == rhsCategory
        case (.timeGroup(let lhsTimeGroup), .timeGroup(let rhsTimeGroup)):
            return lhsTimeGroup == rhsTimeGroup
        case (.album(let lhsAlbum), .album(let rhsAlbum)):
            return lhsAlbum.id == rhsAlbum.id
        case (.random(let lhsScope), .random(let rhsScope)):
            return lhsScope == rhsScope
        case (.timeBrowser, .timeBrowser):
            return true
        case (.locationBrowser, .locationBrowser):
            return true
        case (.historicalToday, .historicalToday):
            return true
        case (.location(let lhsGroupID), .location(let rhsGroupID)):
            return lhsGroupID == rhsGroupID
        case (.period(let lhsScope, let lhsDate), .period(let rhsScope, let rhsDate)):
            return lhsScope == rhsScope && lhsDate == rhsDate
        case (.wallMonth(let lhsMonth, let lhsStart, let lhsAsset), .wallMonth(let rhsMonth, let rhsStart, let rhsAsset)):
            return lhsMonth == rhsMonth && lhsStart == rhsStart && lhsAsset == rhsAsset
        case (.pendingPhotoWall, .pendingPhotoWall):
            return true
        case (.cleanup(let lhsKind), .cleanup(let rhsKind)):
            return lhsKind == rhsKind
        case (.trashBin, .trashBin):
            return true
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .assetBrowser(let category):
            hasher.combine("assetBrowser")
            hasher.combine(category)
        case .category(let category):
            hasher.combine("category")
            hasher.combine(category)
        case .timeGroup(let timeGroup):
            hasher.combine("timeGroup")
            hasher.combine(timeGroup)
        case .album(let album):
            hasher.combine("album")
            hasher.combine(album.id)
        case .random(let scope):
            hasher.combine("random")
            hasher.combine(scope)
        case .timeBrowser:
            hasher.combine("timeBrowser")
        case .locationBrowser:
            hasher.combine("locationBrowser")
        case .historicalToday:
            hasher.combine("historicalToday")
        case .location(let groupID):
            hasher.combine("location")
            hasher.combine(groupID)
        case .period(let scope, let date):
            hasher.combine("period")
            hasher.combine(scope)
            hasher.combine(date)
        case .wallMonth(let monthDate, let startFromDay, let startFromAssetID):
            hasher.combine("wallMonth")
            hasher.combine(monthDate)
            hasher.combine(startFromDay)
            hasher.combine(startFromAssetID)
        case .pendingPhotoWall:
            hasher.combine("pendingPhotoWall")
        case .cleanup(let kind):
            hasher.combine("cleanup")
            hasher.combine(kind)
        case .trashBin:
            hasher.combine("trashBin")
        }
    }
}

enum HomeLibraryContentState: Equatable {
    case needsAuthorization
    case preparing
    case available
    case empty

    static func resolve(
        hasPhotoLibraryAccess: Bool,
        isPreparingLibrary: Bool,
        isLoadingPhotoLibrary: Bool,
        hasLoadedPhotoLibrary: Bool,
        totalPhotosCount: Int
    ) -> HomeLibraryContentState {
        guard hasPhotoLibraryAccess else { return .needsAuthorization }

        // First-time / cold scan: keep Home in "processing" until the full library is ready.
        // Avoid flashing partial batch counts like the first 500 photos.
        let isColdScanInProgress = isLoadingPhotoLibrary && !hasLoadedPhotoLibrary
        if isColdScanInProgress || (isPreparingLibrary && !hasLoadedPhotoLibrary) {
            return .preparing
        }

        if totalPhotosCount > 0 { return .available }
        if isPreparingLibrary || isLoadingPhotoLibrary { return .available }
        if !hasLoadedPhotoLibrary { return .preparing }
        return .empty
    }
}

enum HomeCategoryCountDetailResolver {
    static func shouldShowLibraryLoading(
        category _: PhotoCategory,
        count: Int,
        isPreparingLibrary: Bool,
        isLoadingPhotoLibrary: Bool,
        hasLoadedPhotoLibrary: Bool = true
    ) -> Bool {
        // While the cold scan is still running, never show intermediate counts.
        if isLoadingPhotoLibrary && !hasLoadedPhotoLibrary {
            return true
        }

        if isPreparingLibrary && isLoadingPhotoLibrary {
            return true
        }

        return count == 0 && isLoadingPhotoLibrary
    }
}

struct HomeView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject private var router: MainTabRouter
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppConstants.randomReviewBatchSizeKey) private var randomReviewBatchSizeValue = PhotoRandomReviewBatchSize.defaultValue.rawValue
    @State private var showingRecentOrganized = false
    @State private var periodPickerScope: AdvancedTimeScope?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PhotoDeleteScreenBackground()

                ScrollView {
                    homeContent()
                        .padding(
                            .horizontal,
                            PhotoDeleteAdaptiveLayout.homeHorizontalPadding(
                                in: geometry.size,
                                horizontalSizeClass: horizontalSizeClass
                            )
                        )
                        .padding(
                            .top,
                            PhotoDeleteAdaptiveLayout.homeTopPadding(
                                in: geometry.size,
                                horizontalSizeClass: horizontalSizeClass
                            )
                        )
                        .padding(.bottom, Theme.space24)
                        .frame(
                            maxWidth: PhotoDeleteAdaptiveLayout.homeContentMaxWidth(
                                in: geometry.size,
                                horizontalSizeClass: horizontalSizeClass
                            )
                        )
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            dataManager.loadAlbumsIfNeeded()
            refreshHomeLibrarySummaries()
        }
        .onChange(of: dataManager.photoLibraryManager.hasLoadedPhotoLibrary) { loaded in
            guard loaded else { return }
            refreshHomeLibrarySummaries()
        }
        .onChange(of: dataManager.cleanupStatsRevision) { _ in
            refreshHomeLibrarySummaries()
        }
        .sheet(isPresented: $showingRecentOrganized) {
            RecentOrganizedPhotosView(dataManager: dataManager)
        }
        .sheet(item: $periodPickerScope) { scope in
            PeriodPickerSheet(dataManager: dataManager, scope: scope) { selectedScope, intervalStart in
                periodPickerScope = nil
                router.push(SwipeViewDestination.period(selectedScope, intervalStart))
            }
        }
    }

    @ViewBuilder
    private func homeContent() -> some View {
        if libraryContentState != .needsAuthorization {
            VStack(spacing: Theme.space6) {
                homeTitleBar
                libraryDashboard
            }
        } else {
            VStack(spacing: Theme.space6) {
                homeTitleBar
                authorizationSection
            }
        }
    }

    /// 首页大标题（对齐原型：34/700）+ 右上角待删除入口。
    private var homeTitleBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(L10n.string("Organize"))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(Theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            trashBinEntryButton
        }
        .padding(.top, 10)
    }

    /// 右上角待删除入口：进入「垃圾桶」（TrashBinView）。
    /// 用归档图标表达「暂存待确认」；数量角标挂在按钮上（最多 99+）。
    private var trashBinEntryButton: some View {
        PhotoDeleteCircleIconButton(
            systemName: "archivebox",
            accessibilityLabel: trashBinAccessibilityLabel,
            accessibilityIdentifier: "home-trash-bin"
        ) {
            router.push(SwipeViewDestination.trashBin)
        } badge: {
            pendingDeleteBadge
        }
    }

    private var pendingDeleteCount: Int {
        dataManager.deleteCandidates.count
    }

    private var trashBinAccessibilityLabel: String {
        pendingDeleteCount > 0
            ? L10n.string("Trash, \(pendingDeleteCount) photos pending deletion")
            : L10n.string("Trash")
    }

    /// 待删除角标：数量 > 0 时显示，最多 99+（对齐原型 tbadge：红底白字 + 背景色描边环）。
    @ViewBuilder
    private var pendingDeleteBadge: some View {
        let count = pendingDeleteCount
        if count > 0 {
            Text(count > 99 ? "99+" : PhotoDeleteCountFormat.plain(count))
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .frame(minWidth: 20, minHeight: 20)
                .background(
                    Capsule(style: .continuous)
                        .fill(Theme.destructive)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Theme.backgroundTop, lineWidth: 2.5)
                )
                .offset(x: 3, y: -3)
                .accessibilityHidden(true)
        }
    }

    private var isLibraryPreparing: Bool {
        libraryContentState == .preparing
    }

    private var libraryContentState: HomeLibraryContentState {
        HomeLibraryContentState.resolve(
            hasPhotoLibraryAccess: dataManager.photoLibraryManager.hasPhotoLibraryAccess,
            isPreparingLibrary: dataManager.isPreparingLibrary,
            isLoadingPhotoLibrary: dataManager.photoLibraryManager.isLoading,
            hasLoadedPhotoLibrary: dataManager.photoLibraryManager.hasLoadedPhotoLibrary,
            totalPhotosCount: dataManager.photoLibraryManager.displayTotalPhotosCount
        )
    }

    @ViewBuilder
    private var libraryDashboard: some View {
        switch libraryContentState {
        case .preparing:
            libraryScanningSection
        case .empty:
            emptyLibrarySection
        case .available:
            availableLibraryDashboard
        case .needsAuthorization:
            EmptyView()
        }
    }

    private var availableLibraryDashboard: some View {
        VStack(spacing: 22) {
            duoRow
            periodCardsSection
            specialCleanupSection
            // 工具（图片/视频压缩）暂不展示；`toolSection` 保留便于恢复。
        }
    }

    // MARK: - 权限授权区域
    private var authorizationSection: some View {
        PhotoAuthorizationCard(
            subtitle: String(format: L10n.string("OnePhoto needs photo library access to organize your albums. %@"), AppConstants.privacyShortText),
            onRequestAccess: { dataManager.requestPhotoLibraryAccess() }
        )
    }

    // MARK: - 照片库扫描区域
    private var libraryScanningSection: some View {
        VStack(spacing: 18) {
            ScanningSwipeGlyph()

            VStack(spacing: 8) {
                Text(L10n.string("Reading Photos"))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.primaryText)

                if dataManager.photoLibraryManager.loadingProgress > 0.01 {
                    Text(L10n.percent(Int(dataManager.photoLibraryManager.loadingProgress * 100)))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                }

                Text(L10n.string("Categories and counts will appear automatically when ready. Everything stays on this device."))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if dataManager.photoLibraryManager.loadingProgress > 0.01 {
                ProgressView(value: dataManager.photoLibraryManager.loadingProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: Theme.accent))
                    .frame(maxWidth: .infinity)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
            }
        }
            .padding(Theme.space6)
        .photoDeleteCard()
    }

    // MARK: - 空照片库区域
    private var emptyLibrarySection: some View {
        VStack(spacing: 16) {
            if #available(iOS 17.0, *) {
                ContentUnavailableView(
                    L10n.string("No Photos to Organize"),
                    systemImage: "photo.on.rectangle.angled",
                    description: Text(L10n.string("There are no photos in the current access scope. You can adjust OnePhoto's photo access in System Settings."))
                )
                .foregroundStyle(Theme.secondaryText)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundColor(Theme.secondaryText)

                    Text(L10n.string("No Photos to Organize"))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Theme.primaryText)

                    Text(L10n.string("There are no photos in the current access scope. You can adjust OnePhoto's photo access in System Settings."))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }

            Button {
                dataManager.managePhotoLibraryAccessSettings()
            } label: {
                Label(L10n.string("Manage Photo Access"), systemImage: dataManager.photoLibraryManager.hasLimitedPhotoLibraryAccess ? "photo.badge.plus" : "gearshape")
            }
            .photoDeleteSecondaryButton()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .photoDeleteCard()
    }

    // MARK: - 首屏双卡（珊瑚=待整理 / 琥珀=随机整理，对齐原型）

    private var duoRow: some View {
        HStack(spacing: 12) {
            pendingReviewCard
            randomReviewFanCard
        }
        .frame(height: 158)
    }

    private var pendingReviewCard: some View {
        let stats = libraryStats
        let total = stats.totalAssets
        let reviewed = min(stats.reviewedAssets, total)
        let pending = max(total - reviewed, 0)
        let progress = total > 0 ? Double(reviewed) / Double(total) : 0
        
        return Button {
            // 先进待整理照片墙；卡上数字仍是全库待整理，墙上再选月/日起滑。
            router.push(SwipeViewDestination.pendingPhotoWall)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.string("To review"))
                    .font(.system(size: 16.5, weight: .bold))

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    RollingNumberText(target: pending)
                        .font(.system(size: 31, weight: .bold))
                    Text(L10n.string("photos"))
                        .font(.system(size: 14, weight: .semibold))
                        .opacity(0.72)
                }
                .padding(.top, 10)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("Est. reclaimable"))
                        .font(.system(size: 11, weight: .regular))
                        .opacity(0.72)
                    Text(librarySizeText)
                        .font(.system(size: 18, weight: .bold))
                }

                CoralProgressBar(progress: progress, ink: Theme.coralInk)
                    .padding(.top, 10)
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))
            .foregroundColor(Theme.coralInk)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.coralGradientTop, Theme.coralGradientBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("home-pending-review")
    }

    private var randomReviewFanCard: some View {
        Button {
            router.push(SwipeViewDestination.random(.memories))
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.string("Random Review"))
                    .font(.system(size: 16.5, weight: .bold))
                Text(randomReviewDetail)
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.72)
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
            .foregroundColor(Theme.amberInk)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.amberGradientTop, Theme.amberGradientBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(alignment: .bottom) {
                RandomFanDecoration()
                    .offset(y: -52)
                    .accessibilityHidden(true)
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(L10n.string("Random Review"))
        .accessibilityIdentifier("home-random-review")
    }

    // 旧首屏三卡（库概览 / 随机整理 / 往年今日）已由上方 duoRow 双卡替代。

    // MARK: - 按时间段开始（三张独立卡：主体进本期 / 右区选周期）

    private var periodCardsSection: some View {
        VStack(alignment: .leading, spacing: Theme.space3) {
            periodCard(
                scope: .week,
                title: L10n.string("This week"),
                moreTitle: L10n.string("Choose date"),
                illustrationName: "PeriodWeekIcon",
                identifier: "home-period-week",
                rollDelay: 0.22
            )
            periodCard(
                scope: .month,
                title: L10n.string("This Month"),
                moreTitle: L10n.string("Choose month"),
                illustrationName: "PeriodMonthIcon",
                identifier: "home-period-month",
                rollDelay: 0.30
            )
            periodCard(
                scope: .year,
                title: L10n.string("This year"),
                moreTitle: L10n.string("Choose year"),
                illustrationName: "PeriodYearIcon",
                identifier: "home-period-year",
                rollDelay: 0.38
            )
        }
    }

    private func periodCard(
        scope: AdvancedTimeScope,
        title: String,
        moreTitle: String,
        illustrationName: String,
        identifier: String,
        rollDelay: Double
    ) -> some View {
        let summary = currentPeriodSummary(for: scope)

        return HStack(spacing: 0) {
            // 主体：直接进入本期整理，不再先弹周期列表。
            Button {
                router.push(SwipeViewDestination.period(scope, summary.intervalStart))
            } label: {
                HStack(spacing: 12) {
                    PeriodCardIllustration(name: illustrationName)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16.5, weight: .bold))
                            .foregroundColor(Theme.primaryText)

                        Text(String(
                            format: L10n.string("%@ items · %@"),
                            PhotoDeleteCountFormat.plain(summary.assetCount),
                            summary.formattedEstimatedSize
                        ))
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 1) {
                        RollingNumberText(target: summary.remainingCount, delay: rollDelay)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Theme.primaryText)

                        Text(L10n.string("To review"))
                            .font(.system(size: 10.5, weight: .regular))
                            .foregroundColor(Theme.tertiaryText)
                    }
                }
                .padding(.horizontal, Theme.space3)
                .padding(.vertical, Theme.space3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)

            // 右区：独立热区，只负责切换同粒度周期。
            Button {
                periodPickerScope = scope
            } label: {
                HStack(spacing: 4) {
                    Text(moreTitle)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.tertiaryText)
                }
                .padding(.horizontal, Theme.space3)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("\(identifier)-more")
        }
        .photoDeleteCard(radius: Theme.radiusLg)
    }

    // MARK: - 专项清理（行式列表，值用中性灰）

    private var specialCleanupSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            PhotoDeleteSectionHeader(
                title: L10n.string("Special cleanup"),
                trailing: String(format: L10n.string("About %@ to clear"), cleanupReclaimableSizeText)
            )

            VStack(spacing: 0) {
                PhotoDeleteListRow(
                    iconImage: "CleanupStackedPhotosIcon",
                    iconImageSize: 40,
                    title: L10n.string("Screenshots"),
                    accessibilityIdentifier: "home-cleanup-screenshots"
                ) {
                    router.push(SwipeViewDestination.assetBrowser(.screenshots))
                }
                insetHairline(inset: 16)
                PhotoDeleteListRow(
                    iconImage: "CleanupSimilarIcon",
                    iconImageSize: 42,
                    title: L10n.string("Similar"),
                    value: cleanupQueue(for: .similarPhotos)?.formattedSpace,
                    accessibilityIdentifier: "home-cleanup-similar"
                ) {
                    router.push(SwipeViewDestination.cleanup(.similarPhotos))
                }
                insetHairline(inset: 16)
                PhotoDeleteListRow(
                    iconImage: "CleanupVideoIcon",
                    iconImageSize: 33,
                    title: L10n.string("Videos & Screen Recordings"),
                    value: videosAndScreenRecordingsQueueValue,
                    accessibilityIdentifier: "home-cleanup-videos"
                ) {
                    router.push(SwipeViewDestination.assetBrowser(.videos))
                }
                insetHairline(inset: 16)
                PhotoDeleteListRow(
                    iconImage: "CleanupLivePhotoIcon",
                    iconImageSize: 33,
                    title: L10n.string("Live Photos"),
                    accessibilityIdentifier: "home-cleanup-live-photos"
                ) {
                    router.push(SwipeViewDestination.assetBrowser(.livePhotos))
                }
            }
            .photoDeleteCard(radius: Theme.radiusLg)
        }
    }

    private func insetHairline(inset: CGFloat = 18) -> some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
            .padding(.horizontal, inset)
    }

    private var toolSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            PhotoDeleteSectionHeader(title: L10n.string("Tools"))

            VStack(spacing: 0) {
                if AppConstants.isImageCompressionVisible {
                    PhotoDeleteListRow(
                        title: L10n.string("Image Compression"),
                        subtitle: L10n.string("Smaller, not deleted"),
                        value: countText(cleanupQueue(for: .imageCompression)?.assetCount),
                        accessibilityIdentifier: "home-tool-image-compression"
                    ) {
                        router.push(SwipeViewDestination.cleanup(.imageCompression))
                    }
                    insetHairline()
                }

                PhotoDeleteListRow(
                    title: L10n.string("Video Compression"),
                    subtitle: L10n.string("Smaller, not deleted"),
                    value: countText(cleanupQueue(for: .videoCompression)?.assetCount),
                    accessibilityIdentifier: "home-tool-video-compression"
                ) {
                    router.push(SwipeViewDestination.cleanup(.videoCompression))
                }
            }
            .photoDeleteCard(radius: Theme.radiusLg)
        }
    }

    private func refreshHomeLibrarySummaries() {
        guard dataManager.photoLibraryManager.hasPhotoLibraryAccess else { return }
        guard dataManager.photoLibraryManager.hasLoadedPhotoLibrary else { return }
        dataManager.refreshPhotoPeriodSummaries(for: [.week, .month, .year])
        dataManager.refreshAdvancedCleanupQueues()
    }

    private func currentPeriodSummary(for scope: AdvancedTimeScope) -> PhotoPeriodSummary {
        TimePeriodBrowser.currentSummary(for: scope, in: dataManager.periodSummariesByScope[scope] ?? [])
    }

    private func cleanupQueue(for kind: AdvancedCleanupKind) -> AdvancedCleanupQueue? {
        dataManager.advancedCleanupQueues.first { $0.kind == kind }
    }

    /// 录屏是视频的子集：两个队列取较大值，避免重复计数；录像大小未读到时用录屏估算兜底。
    private var videosAndScreenRecordingsQueueValue: String? {
        let videosMB = cleanupQueue(for: .videos)?.estimatedSpaceMB ?? 0
        let recordingsMB = cleanupQueue(for: .screenRecordings)?.estimatedSpaceMB ?? 0
        let totalMB = max(videosMB, recordingsMB)
        guard totalMB > 0 else { return nil }
        return CleanupStatsFormatter.space(totalMB)
    }

    private var libraryStats: AdvancedLibraryStats {
        dataManager.makeSettingsStatsSummary()
    }

    private var librarySizeText: String {
        let summaries = dataManager.periodSummariesByScope[.year] ?? []
        let totalMB = summaries.reduce(0) { $0 + $1.estimatedSizeMB }
        if totalMB <= 0 && (dataManager.isLoadingPeriodSummaries || !dataManager.photoLibraryManager.hasLoadedPhotoLibrary) {
            return L10n.string("Reading")
        }
        return CleanupStatsFormatter.space(totalMB)
    }

    /// 专项清理头部合计（相似 + 视频与录屏；录屏是视频子集，取两者较大值避免重复计数）。
    private var cleanupReclaimableSizeText: String {
        let similarMB = cleanupQueue(for: .similarPhotos)?.estimatedSpaceMB ?? 0
        let videosMB = cleanupQueue(for: .videos)?.estimatedSpaceMB ?? 0
        let recordingsMB = cleanupQueue(for: .screenRecordings)?.estimatedSpaceMB ?? 0
        let reclaimMB = similarMB + max(videosMB, recordingsMB)
        if reclaimMB <= 0 && dataManager.isLoadingAdvancedCleanupQueues {
            return L10n.string("Reading")
        }
        return CleanupStatsFormatter.space(reclaimMB)
    }

    private var randomReviewDetail: String {
        let count = PhotoRandomReviewBatchSize.normalized(randomReviewBatchSizeValue).rawValue
        return String(format: L10n.string("Up to %@"), PhotoDeleteCountFormat.plain(count))
    }

    private func countText(_ count: Int?) -> String {
        guard let count else { return L10n.string("Reading") }
        return PhotoDeleteCountFormat.plain(count)
    }

}

// MARK: - 首页组件（对齐 home-prototype.html）

/// 周期卡插画：用户提供的 3D 小图标，切图去底后使用。
private struct PeriodCardIllustration: View {
    let name: String

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: 56, height: 56)
            .shadow(color: Color.black.opacity(0.22), radius: 3, y: 2)
            .accessibilityHidden(true)
    }
}

/// 数字滚动：从 0 以 easeOut 滚到目标值（一律无千分位），支持错峰 delay。
private struct RollingNumberText: View {
    let target: Int
    var delay: Double = 0
    var duration: Double = 0.9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed = 0
    @State private var hasRun = false

    var body: some View {
        Text(PhotoDeleteCountFormat.plain(displayed))
            .monospacedDigit()
            .onAppear(perform: startCounting)
    }

    private func startCounting() {
        guard !hasRun else {
            displayed = target
            return
        }
        hasRun = true

        guard !reduceMotion else {
            displayed = target
            return
        }

        displayed = 0
        Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            let start = Date()
            while !Task.isCancelled {
                let progress = min(max(Date().timeIntervalSince(start) / duration, 0), 1)
                let eased = 1 - pow(1 - progress, 3)
                displayed = Int((Double(target) * eased).rounded())
                if progress >= 1 { break }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }
}

/// 珊瑚卡进度条：7pt 胶囊，深棕填充 + 18% 深棕轨道，出现时生长到目标进度。
private struct CoralProgressBar: View {
    let progress: Double
    let ink: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(ink.opacity(0.18))
                Capsule(style: .continuous)
                    .fill(ink)
                    .frame(width: geometry.size.width * (shown ? min(max(progress, 0), 1) : 0))
            }
        }
        .frame(height: 7)
        .onAppear {
            guard !reduceMotion else {
                shown = true
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                withAnimation(.easeOut(duration: 0.95)) {
                    shown = true
                }
            }
        }
    }
}

/// 扇形牌的三张静态渐变占位（森林 / 城市冷蓝 / 落日）。
/// 故意保留的装饰例外色，勿统一进 Theme。
private enum HomeFanArt {
    static let gradients: [LinearGradient] = [
        LinearGradient(
            colors: [
                Color(red: 0.70, green: 0.79, blue: 0.72),
                Color(red: 0.37, green: 0.55, blue: 0.45),
                Color(red: 0.17, green: 0.32, blue: 0.26)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        LinearGradient(
            colors: [
                Color(red: 0.11, green: 0.17, blue: 0.33),
                Color(red: 0.14, green: 0.22, blue: 0.43),
                Color(red: 0.16, green: 0.24, blue: 0.44)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.75, blue: 0.54),
                Color(red: 0.96, green: 0.52, blue: 0.44),
                Color(red: 0.29, green: 0.25, blue: 0.47)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    ]
}

/// 扇形牌轮（纯装饰）：进场时把牌一张张摊开，之后静止。几何与原型一致（R=104、±24°）。
private struct RandomFanDecoration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dealt = false

    private static let radius: CGFloat = 104
    private static let spread: CGFloat = 24

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                fanCard(index: index)
            }
        }
        .frame(width: 0, height: 0)
        .onAppear {
            if reduceMotion {
                dealt = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    dealt = true
                }
            }
        }
    }

    private func fanCard(index: Int) -> some View {
        let i = CGFloat(index)
        let restAngle = (i - 1) * Self.spread
        let radians = restAngle * .pi / 180
        let restX = Self.radius * sin(radians)
        let restY = Self.radius * (1 - cos(radians))

        // 9pt：46×62 微缩媒体牌 chrome，低于 radiusSm 以保持扇形比例
        return RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(HomeFanArt.gradients[index % HomeFanArt.gradients.count])
            .frame(width: 46, height: 62)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.62), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
            .rotationEffect(.degrees(dealt ? restAngle : 0))
            .offset(x: dealt ? restX : 0, y: dealt ? restY : 0)
            .scaleEffect(dealt ? 1 : 0.82)
            .opacity(dealt ? 1 : (index == 0 ? 1 : 0))
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.62).delay(Double(index) * 0.09),
                value: dealt
            )
    }
}

// MARK: - 扫描态组件
struct ScanningSwipeGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(Theme.elevatedSurface)
                .frame(width: 132, height: 92)
                .rotationEffect(.degrees(animate ? 5 : 1))
                .offset(x: animate ? 20 : 14, y: -3)

            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .frame(width: 132, height: 92)
                .overlay(
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.black.opacity(0.16))
                            .frame(width: 58, height: 8)

                        Spacer()

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.black.opacity(0.12))
                            .frame(width: 82, height: 10)
                    }
                    .padding(16)
                )
                .rotationEffect(.degrees(animate ? -5 : -1))
                .offset(x: animate ? -18 : -8)

            Image(systemName: "arrow.left")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Theme.accent)
                .offset(x: -70, y: 4)

            Image(systemName: "trash")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.destructive)
                .offset(x: 76, y: 28)
        }
        .frame(height: 108)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else {
                animate = true
                return
            }
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(DataManager())
        .environmentObject(MainTabRouter())
}
