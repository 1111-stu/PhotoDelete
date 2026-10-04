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
    @Environment(\.colorScheme) private var colorScheme
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
                            .padding(.bottom, 112)
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
            .navigationTitle(L10n.string("整理"))
            .navigationBarTitleDisplayMode(.large)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        navigationPath.append(SwipeViewDestination.stats)
                    } label: {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .accessibilityLabel(L10n.string("统计"))
                    .accessibilityIdentifier("home-stats-entry")
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
                introSection(isCompact: isLandscape)
                libraryDashboard
            }
        } else {
            VStack(spacing: PhotoDeleteStyle.sectionSpacing) {
                introSection(isCompact: false)
                authorizationSection
            }
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
                        cornerRadius: 8
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
                        cornerRadius: 8
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
            spotlightRow
            periodSection
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
        .padding(24)
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

    private var spotlightRow: some View {
        HStack(alignment: .top, spacing: 10) {
            libraryOverviewCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 10) {
                randomReviewCard
                historicalTodayCard
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 196)
    }

    private var libraryOverviewCard: some View {
        Button {
            navigationPath.append(SwipeViewDestination.stats)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.string("照片库概览"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.tertiaryText)
                }

                Text(librarySizeText)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(libraryCountLine)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("累计清理"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(PhotoDeleteStyle.tertiaryText)
                    Text(cleanedSizeText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.primaryText)
                        .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .photoDeleteCard(radius: 22)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("home-library-overview")
    }

    private var randomReviewCard: some View {
        Button {
            navigationPath.append(SwipeViewDestination.random(.memories))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string("随机整理"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(randomReviewDetail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.82))
                Spacer(minLength: 0)
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.76, green: 0.34, blue: 0.24))
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(L10n.string("随机整理"))
        .accessibilityIdentifier("home-random-review")
    }

    private var historicalTodayCard: some View {
        Button {
            navigationPath.append(SwipeViewDestination.historicalToday)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("往年今日"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(historicalCardTitle)
                    Text(historicalTodayDetail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(historicalCardTitle.opacity(0.72))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "calendar")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(historicalCardTitle.opacity(0.85))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(historicalCardFill)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(L10n.string("往年今日"))
        .accessibilityIdentifier("home-historical-today")
    }

    private var periodSection: some View {
        VStack(spacing: 10) {
            periodCard(scope: .week, title: L10n.string("本周新增"), icon: "calendar", identifier: "home-period-week")
            periodCard(scope: .month, title: L10n.string("本月新增"), icon: "calendar", identifier: "home-period-month")
            periodCard(scope: .year, title: L10n.string("本年新增"), icon: "calendar", identifier: "home-period-year")
        }
    }

    private func periodCard(
        scope: AdvancedTimeScope,
        title: String,
        icon: String,
        identifier: String
    ) -> some View {
        let summary = currentPeriodSummary(for: scope)
        let countText = summary.assetCount.formatted(.number.grouping(.automatic))
        let pendingText = summary.remainingCount.formatted(.number.grouping(.automatic))

        return Button {
            navigationPath.append(SwipeViewDestination.period(scope, summary.intervalStart))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.96, green: 0.78, blue: 0.35))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(String(format: L10n.string("共 %@ 项 · %@"), countText, summary.formattedEstimatedSize))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(pendingText)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text(L10n.string("待整理"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.62))
                }

                HStack(spacing: 2) {
                    Text(L10n.string("更多"))
                        .font(.system(size: 13, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.78))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(periodCardFill)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private var specialCleanupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.string("专项清理"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                Spacer(minLength: 8)
                Text(String(format: L10n.string("预计可清理 %@"), reclaimableSizeText))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)

            HStack(spacing: 0) {
                specialCleanupTile(
                    title: L10n.string("相似与重复"),
                    icon: "rectangle.on.rectangle",
                    identifier: "home-cleanup-similar"
                ) {
                    navigationPath.append(SwipeViewDestination.cleanup(.similarPhotos))
                }
                specialCleanupDivider
                specialCleanupTile(
                    title: L10n.string("视频"),
                    icon: "video",
                    identifier: "home-cleanup-videos"
                ) {
                    navigationPath.append(SwipeViewDestination.category(.videos))
                }
                specialCleanupDivider
                specialCleanupTile(
                    title: L10n.string("截图"),
                    icon: "iphone",
                    identifier: "home-cleanup-screenshots"
                ) {
                    navigationPath.append(SwipeViewDestination.category(.screenshots))
                }
                specialCleanupDivider
                specialCleanupTile(
                    title: L10n.string("大文件"),
                    icon: "internaldrive",
                    identifier: "home-cleanup-large-files"
                ) {
                    navigationPath.append(SwipeViewDestination.cleanup(.largeFiles))
                }
            }
            .padding(.vertical, 8)
            .photoDeleteCard(radius: 22)
        }
    }

    private var specialCleanupDivider: some View {
        Rectangle()
            .fill(PhotoDeleteStyle.hairline)
            .frame(width: 1, height: 52)
    }

    private func specialCleanupTile(
        title: String,
        icon: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                    .frame(height: 28)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    private var toolSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("工具"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.primaryText)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                if AppConstants.isImageCompressionVisible {
                    toolRow(
                        title: L10n.string("图片压缩"),
                        count: cleanupQueue(for: .imageCompression)?.assetCount,
                        identifier: "home-tool-image-compression"
                    ) {
                        navigationPath.append(SwipeViewDestination.cleanup(.imageCompression))
                    }
                    Divider()
                        .background(PhotoDeleteStyle.hairline)
                        .padding(.leading, 16)
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.primaryText)
                    Text(L10n.string("变小，不删除"))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                }

                Spacer(minLength: 8)

                Text(countText(count))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.tertiaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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

    private var libraryCountLine: String {
        let total = libraryStats.totalAssets
        let reviewed = min(libraryStats.reviewedAssets, total)
        let ratio = total > 0 ? Double(reviewed) / Double(total) * 100 : 0
        let percent = ratio < 10
            ? "\(ratio.formatted(.number.precision(.fractionLength(1))))%"
            : "\(Int(ratio.rounded()))%"
        let countText = total.formatted(.number.grouping(.automatic))
        return String(format: L10n.string("共 %@ 项 · 已整理 %@"), countText, percent)
    }

    private var cleanedSizeText: String {
        libraryStats.formattedSpaceSaved
    }

    private var randomReviewDetail: String {
        let count = PhotoRandomReviewBatchSize.normalized(randomReviewBatchSizeValue).rawValue
        return String(format: L10n.string("最多 %@ 项"), count.formatted(.number.grouping(.automatic)))
    }

    private var historicalTodayDetail: String {
        let count = dataManager.historicalTodayPhotoCount
        if count > 0 {
            return L10n.shortPhotoCount(count)
        }
        return L10n.string("点按查看")
    }

    private var reclaimableSizeText: String {
        let reclaimMB = [AdvancedCleanupKind.similarPhotos, .largeFiles].reduce(0.0) { total, kind in
            total + (cleanupQueue(for: kind)?.estimatedSpaceMB ?? 0)
        }
        if reclaimMB <= 0 && dataManager.isLoadingAdvancedCleanupQueues {
            return L10n.string("读取中")
        }
        return CleanupStatsFormatter.space(reclaimMB)
    }

    private func countText(_ count: Int?) -> String {
        guard let count else { return L10n.string("读取中") }
        return count.formatted(.number.grouping(.automatic))
    }

    private var periodCardFill: Color {
        colorScheme == .dark
            ? Color(white: 0.16)
            : Color(red: 0.12, green: 0.13, blue: 0.12)
    }

    private var historicalCardFill: Color {
        colorScheme == .dark
            ? Color(red: 0.42, green: 0.34, blue: 0.24)
            : Color(red: 0.93, green: 0.86, blue: 0.72)
    }

    private var historicalCardTitle: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : Color(red: 0.28, green: 0.2, blue: 0.12)
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
