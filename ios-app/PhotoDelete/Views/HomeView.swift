//
//  HomeView.swift
//  PhotoDelete
//
//  Created by PhotoDelete Team on 11/7/25.
//

import SwiftUI

enum SwipeViewDestination: Hashable {
    case category(PhotoCategory)
    case timeGroup(String)
    case album(AlbumInfo)
    case random(PhotoRandomReviewScope)
    case timeBrowser
    case locationBrowser
    case historicalToday
    case location(String)
    case period(AdvancedTimeScope, Date)
    case stats
    case cleanup(AdvancedCleanupKind)

    static func == (lhs: SwipeViewDestination, rhs: SwipeViewDestination) -> Bool {
        switch (lhs, rhs) {
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
        case (.stats, .stats):
            return true
        case (.cleanup(let lhsKind), .cleanup(let rhsKind)):
            return lhsKind == rhsKind
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
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
        case .stats:
            hasher.combine("stats")
        case .cleanup(let kind):
            hasher.combine("cleanup")
            hasher.combine(kind)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppConstants.hasSeenIntroKey) private var hasSeenPhotoDeleteIntro = false
    @AppStorage(AppConstants.randomReviewBatchSizeKey) private var randomReviewBatchSizeValue = PhotoRandomReviewBatchSize.defaultValue.rawValue
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { geometry in
                let usesExpandedLayout = PhotoDeleteAdaptiveLayout.prefersExpandedContent(
                    in: geometry.size,
                    horizontalSizeClass: horizontalSizeClass
                )

                ZStack {
                    PhotoDeleteScreenBackground()

                    ScrollView {
                        homeContent(isLandscape: usesExpandedLayout)
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
                            .padding(.bottom, PhotoDeleteStyle.Metrics.bottomChromeSpacing)
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
            .navigationDestination(for: SwipeViewDestination.self) { destination in
                switch destination {
                case .category(let category):
                    SwipePhotoView(selectedCategory: category, selectedTimeGroup: nil, selectedAlbumInfo: nil)
                        .environmentObject(dataManager)
                case .timeGroup(let timeGroup):
                    SwipePhotoView(selectedCategory: nil, selectedTimeGroup: timeGroup, selectedAlbumInfo: nil)
                        .environmentObject(dataManager)
                case .album(let albumInfo):
                    SwipePhotoView(selectedCategory: nil, selectedTimeGroup: nil, selectedAlbumInfo: albumInfo)
                        .environmentObject(dataManager)
                case .random(let scope):
                    SwipePhotoView(
                        selectedCategory: nil,
                        selectedTimeGroup: nil,
                        selectedAlbumInfo: nil,
                        randomReviewScope: scope
                    )
                    .environmentObject(dataManager)
                case .timeBrowser:
                    TimeOrganizeView()
                        .environmentObject(dataManager)
                case .locationBrowser:
                    LocationOrganizeView()
                        .environmentObject(dataManager)
                case .historicalToday:
                    SwipePhotoView(
                        selectedCategory: nil,
                        selectedTimeGroup: nil,
                        selectedAlbumInfo: nil,
                        selectedHistoricalToday: true
                    )
                    .environmentObject(dataManager)
                case .location(let groupID):
                    SwipePhotoView(
                        selectedCategory: nil,
                        selectedTimeGroup: nil,
                        selectedAlbumInfo: nil,
                        selectedLocationGroupID: groupID
                    )
                    .environmentObject(dataManager)
                case .period(let scope, let intervalStart):
                    SwipePhotoView(
                        selectedCategory: nil,
                        selectedTimeGroup: nil,
                        selectedAlbumInfo: nil,
                        selectedDate: intervalStart,
                        selectedAdvancedTimeScope: scope
                    )
                    .environmentObject(dataManager)
                case .stats:
                    StatsView()
                        .environmentObject(dataManager)
                case .cleanup(let kind):
                    AdvancedCleanupDestination(kind: kind)
                        .environmentObject(dataManager)
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
    }

    @ViewBuilder
    private func homeContent(isLandscape: Bool) -> some View {
        if libraryContentState != .needsAuthorization {
            VStack(spacing: PhotoDeleteStyle.sectionSpacing) {
                homeTitleBar
                introSection(isCompact: isLandscape)
                libraryDashboard
            }
        } else {
            VStack(spacing: PhotoDeleteStyle.sectionSpacing) {
                homeTitleBar
                introSection(isCompact: false)
                authorizationSection
            }
        }
    }

    /// 首页大标题（对齐原型：34/700）+ 右上角删除入口占位。
    private var homeTitleBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(L10n.string("整理"))
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(PhotoDeleteStyle.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            trashPlaceholderButton
        }
        .padding(.top, 10)
    }

    /// 右上角删除按钮占位：iOS 26+ 用液态玻璃，老系统回落实心圆钮。
    /// 入口细节（回收站 / 最近删除）待定，点击暂不动作。
    @ViewBuilder
    private var trashPlaceholderButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                // 入口细节待定
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .foregroundStyle(PhotoDeleteStyle.primaryText)
            .accessibilityLabel(L10n.string("删除"))
            .accessibilityIdentifier("home-trash-placeholder")
        } else {
            Button {
                // 入口细节待定
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                    .frame(width: 44, height: 44)
                    .background(PhotoDeleteStyle.elevatedSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("删除"))
            .accessibilityIdentifier("home-trash-placeholder")
        }
    }

    @ViewBuilder
    private func introSection(isCompact: Bool) -> some View {
        if !hasSeenPhotoDeleteIntro {
            VStack(alignment: .leading, spacing: isCompact ? 12 : 14) {
                HStack(alignment: .top, spacing: 12) {
                    PhotoDeleteIconTile(
                        icon: "hand.draw",
                        size: 28,
                        cornerRadius: PhotoDeleteStyle.Metrics.compactRadius
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("快速上手"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(PhotoDeleteStyle.primaryText)

                        Text(L10n.string("默认左滑删除、右滑保留、上滑收藏；想换手势，可以在整理页底部打开设置。"))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(PhotoDeleteStyle.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    PhotoDeleteIconTile(
                        icon: "lock.shield",
                        tint: PhotoDeleteStyle.positive,
                        size: 28,
                        cornerRadius: PhotoDeleteStyle.Metrics.compactRadius
                    )

                    Text(L10n.string("隐私优先：\(AppConstants.privacyShortText)"))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hasSeenPhotoDeleteIntro = true
                    }
                } label: {
                    Text(L10n.string("知道了"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .photoDeleteMinimumTapTarget()
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                        .fill(PhotoDeleteStyle.elevatedSurface)
                )
            }
            .padding(isCompact ? 16 : 18)
            .photoDeleteCard()
            .transition(.opacity.combined(with: .move(edge: .top)))
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
            periodBandSection
            specialCleanupSection
            toolSection
        }
    }

    // MARK: - 权限授权区域
    private var authorizationSection: some View {
        PhotoAuthorizationCard(
            subtitle: String(format: L10n.string("删图需要照片库权限来整理相册。%@"), AppConstants.privacyShortText),
            onRequestAccess: { dataManager.requestPhotoLibraryAccess() }
        )
    }

    // MARK: - 照片库扫描区域
    private var libraryScanningSection: some View {
        VStack(spacing: 18) {
            ScanningSwipeGlyph()

            VStack(spacing: 8) {
                Text(L10n.string("正在读取照片"))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)

                if dataManager.photoLibraryManager.loadingProgress > 0.01 {
                    Text(L10n.percent(Int(dataManager.photoLibraryManager.loadingProgress * 100)))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                }

                Text(L10n.string("准备完成后会自动显示分类和数量。整理过程只在本机完成。"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if dataManager.photoLibraryManager.loadingProgress > 0.01 {
                ProgressView(value: dataManager.photoLibraryManager.loadingProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: PhotoDeleteStyle.accent))
                    .frame(maxWidth: .infinity)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: PhotoDeleteStyle.accent))
            }
        }
            .padding(PhotoDeleteStyle.Metrics.contentBottomPadding)
        .photoDeleteCard()
    }

    // MARK: - 空照片库区域
    private var emptyLibrarySection: some View {
        VStack(spacing: 16) {
            if #available(iOS 17.0, *) {
                ContentUnavailableView(
                    L10n.string("没有可整理的照片"),
                    systemImage: "photo.on.rectangle.angled",
                    description: Text(L10n.string("当前授权范围内没有照片。您可以在系统设置里调整删图的照片访问范围。"))
                )
                .foregroundStyle(PhotoDeleteStyle.secondaryText)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 52, weight: .medium))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)

                    Text(L10n.string("没有可整理的照片"))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.primaryText)

                    Text(L10n.string("当前授权范围内没有照片。您可以在系统设置里调整删图的照片访问范围。"))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }

            Button {
                dataManager.managePhotoLibraryAccessSettings()
            } label: {
                Label(L10n.string("管理照片访问范围"), systemImage: dataManager.photoLibraryManager.hasLimitedPhotoLibraryAccess ? "photo.badge.plus" : "gearshape")
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
        let theme = PhotoDeleteTheme.current

        return Button {
            let yearSummary = currentPeriodSummary(for: .year)
            navigationPath.append(SwipeViewDestination.period(.year, yearSummary.intervalStart))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.string("待整理"))
                    .font(.system(size: 16.5, weight: .bold))

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    RollingNumberText(target: pending)
                        .font(.system(size: 31, weight: .bold))
                    Text(L10n.string("张"))
                        .font(.system(size: 14, weight: .semibold))
                        .opacity(0.72)
                }
                .padding(.top, 10)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("预计可释放"))
                        .font(.system(size: 11, weight: .regular))
                        .opacity(0.72)
                    Text(librarySizeText)
                        .font(.system(size: 18, weight: .bold))
                }

                CoralProgressBar(progress: progress, ink: theme.coralInk)
                    .padding(.top, 10)
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 16))
            .foregroundColor(theme.coralInk)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.coralGradientTop, theme.coralGradientBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("home-pending-review")
    }

    private var randomReviewFanCard: some View {
        let theme = PhotoDeleteTheme.current

        return Button {
            navigationPath.append(SwipeViewDestination.random(.memories))
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.string("随机整理"))
                    .font(.system(size: 16.5, weight: .bold))
                Text(randomReviewDetail)
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.72)
                Spacer(minLength: 0)
            }
            .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
            .foregroundColor(theme.amberInk)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.amberGradientTop, theme.amberGradientBottom],
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
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(L10n.string("随机整理"))
        .accessibilityIdentifier("home-random-review")
    }

    // 旧首屏三卡（库概览 / 随机整理 / 往年今日）已由上方 duoRow 双卡替代；
    // 统计页入口迁移到设置页（「使用统计」）。

    // MARK: - 按时间段开始（三段 band，对齐原型）

    private var periodBandSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            PhotoDeleteSectionHeader(title: L10n.string("按时间段开始"))

            HStack(spacing: 0) {
                periodBandSegment(
                    scope: .week,
                    title: L10n.string("本周"),
                    identifier: "home-period-week",
                    rollDelay: 0.22
                )
                bandDivider
                periodBandSegment(
                    scope: .month,
                    title: L10n.string("本月"),
                    identifier: "home-period-month",
                    rollDelay: 0.30
                )
                bandDivider
                periodBandSegment(
                    scope: .year,
                    title: L10n.string("本年"),
                    identifier: "home-period-year",
                    rollDelay: 0.38
                )
            }
            .photoDeleteCard(radius: 22)
        }
    }

    private var bandDivider: some View {
        Rectangle()
            .fill(PhotoDeleteStyle.hairline)
            .frame(width: 1)
            .padding(.vertical, 13)
    }

    private func periodBandSegment(
        scope: AdvancedTimeScope,
        title: String,
        identifier: String,
        rollDelay: Double
    ) -> some View {
        let summary = currentPeriodSummary(for: scope)

        return Button {
            navigationPath.append(SwipeViewDestination.period(scope, summary.intervalStart))
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    Text(title)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(PhotoDeleteStyle.secondaryText)

                RollingNumberText(target: summary.remainingCount, delay: rollDelay)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)

                Text(String(format: L10n.string("可释放 %@"), summary.formattedEstimatedSize))
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - 专项清理（行式列表，值用中性灰）

    private var specialCleanupSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            PhotoDeleteSectionHeader(
                title: L10n.string("专项清理"),
                trailing: String(format: L10n.string("预计可清理 %@"), cleanupReclaimableSizeText)
            )

            VStack(spacing: 0) {
                cleanupRow(
                    icon: "rectangle.on.rectangle",
                    title: L10n.string("相似与重复"),
                    value: cleanupQueue(for: .similarPhotos)?.formattedSpace,
                    identifier: "home-cleanup-similar"
                ) {
                    navigationPath.append(SwipeViewDestination.cleanup(.similarPhotos))
                }
                insetHairline
                cleanupRow(
                    icon: "video",
                    title: L10n.string("视频"),
                    value: cleanupQueue(for: .videos)?.formattedSpace,
                    identifier: "home-cleanup-videos"
                ) {
                    navigationPath.append(SwipeViewDestination.category(.videos))
                }
                insetHairline
                cleanupRow(
                    icon: "iphone",
                    title: L10n.string("截图"),
                    value: nil,
                    identifier: "home-cleanup-screenshots"
                ) {
                    navigationPath.append(SwipeViewDestination.category(.screenshots))
                }
                insetHairline
                cleanupRow(
                    icon: "internaldrive",
                    title: L10n.string("大文件"),
                    value: cleanupQueue(for: .largeFiles)?.formattedSpace,
                    identifier: "home-cleanup-large-files"
                ) {
                    navigationPath.append(SwipeViewDestination.cleanup(.largeFiles))
                }
            }
            .photoDeleteCard(radius: 22)
        }
    }

    private var insetHairline: some View {
        Rectangle()
            .fill(PhotoDeleteStyle.hairline)
            .frame(height: 1)
            .padding(.horizontal, 18)
    }

    private func cleanupRow(
        icon: String,
        title: String,
        value: String?,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(
                        Color.white.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)

                Spacer(minLength: 8)

                if let value {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.tertiaryText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private var toolSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            PhotoDeleteSectionHeader(title: L10n.string("工具"))

            VStack(spacing: 0) {
                if AppConstants.isImageCompressionVisible {
                    toolRow(
                        title: L10n.string("图片压缩"),
                        count: cleanupQueue(for: .imageCompression)?.assetCount,
                        identifier: "home-tool-image-compression"
                    ) {
                        navigationPath.append(SwipeViewDestination.cleanup(.imageCompression))
                    }
                    insetHairline
                }

                toolRow(
                    title: L10n.string("视频压缩"),
                    count: cleanupQueue(for: .videoCompression)?.assetCount,
                    identifier: "home-tool-video-compression"
                ) {
                    navigationPath.append(SwipeViewDestination.cleanup(.videoCompression))
                }
            }
            .photoDeleteCard(radius: 22)
        }
    }

    private func toolRow(
        title: String,
        count: Int?,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.primaryText)
                    Text(L10n.string("变小，不删除"))
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                }

                Spacer(minLength: 8)

                Text(countText(count))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.tertiaryText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func refreshHomeLibrarySummaries() {
        guard dataManager.photoLibraryManager.hasPhotoLibraryAccess else { return }
        guard dataManager.photoLibraryManager.hasLoadedPhotoLibrary else { return }
        dataManager.refreshPhotoPeriodSummaries(for: [.week, .month, .year])
        dataManager.refreshAdvancedCleanupQueues()
    }

    private func currentPeriodSummary(for scope: AdvancedTimeScope) -> PhotoPeriodSummary {
        let now = Date()
        let summaries = dataManager.periodSummariesByScope[scope] ?? []
        if let current = summaries.first(where: { now >= $0.intervalStart && now < $0.intervalEnd }) {
            return current
        }
        return .empty(scope: scope, containing: now)
    }

    private func cleanupQueue(for kind: AdvancedCleanupKind) -> AdvancedCleanupQueue? {
        dataManager.advancedCleanupQueues.first { $0.kind == kind }
    }

    private var libraryStats: AdvancedLibraryStats {
        dataManager.makeSettingsStatsSummary()
    }

    private var librarySizeText: String {
        let summaries = dataManager.periodSummariesByScope[.year] ?? []
        let totalMB = summaries.reduce(0) { $0 + $1.estimatedSizeMB }
        if totalMB <= 0 && (dataManager.isLoadingPeriodSummaries || !dataManager.photoLibraryManager.hasLoadedPhotoLibrary) {
            return L10n.string("读取中")
        }
        return CleanupStatsFormatter.space(totalMB)
    }

    /// 专项清理头部合计（相似 + 视频 + 大文件；视频/截图的估算数据待补齐，当前可能显示 0）。
    private var cleanupReclaimableSizeText: String {
        let kinds: [AdvancedCleanupKind] = [.similarPhotos, .videos, .largeFiles]
        let reclaimMB = kinds.reduce(0.0) { total, kind in
            total + (cleanupQueue(for: kind)?.estimatedSpaceMB ?? 0)
        }
        if reclaimMB <= 0 && dataManager.isLoadingAdvancedCleanupQueues {
            return L10n.string("读取中")
        }
        return CleanupStatsFormatter.space(reclaimMB)
    }

    private var randomReviewDetail: String {
        let count = PhotoRandomReviewBatchSize.normalized(randomReviewBatchSizeValue).rawValue
        return String(format: L10n.string("最多 %@ 项"), PhotoDeleteCountFormat.plain(count))
    }

    private func countText(_ count: Int?) -> String {
        guard let count else { return L10n.string("读取中") }
        return PhotoDeleteCountFormat.plain(count)
    }

}

// MARK: - 首页组件（对齐 home-prototype.html）

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

/// 扇形牌的三张静态渐变占位（对应原型里的森林 / 城市 / 落日三张照片卡）。
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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PhotoDeleteStyle.elevatedSurface)
                .frame(width: 132, height: 92)
                .rotationEffect(.degrees(animate ? 5 : 1))
                .offset(x: animate ? 20 : 14, y: -3)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                .foregroundColor(PhotoDeleteStyle.accent)
                .offset(x: -70, y: 4)

            Image(systemName: "trash")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.destructive)
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
}
