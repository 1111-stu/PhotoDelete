//
//  HomeView.swift
//  Poca
//
//  Created by Poca Team on 11/7/25.
//

import Photos
import SwiftUI
import UIKit

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
    /// 大卡当前手动选中的照片；nil 时回落到最新一张。
    @State private var heroOverrideAssetID: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PocaScreenBackground()

                ScrollView {
                    homeContent()
                        .padding(
                            .horizontal,
                            PocaAdaptiveLayout.homeHorizontalPadding(
                                in: geometry.size,
                                horizontalSizeClass: horizontalSizeClass
                            )
                        )
                        .padding(
                            .top,
                            PocaAdaptiveLayout.homeTopPadding(
                                in: geometry.size,
                                horizontalSizeClass: horizontalSizeClass
                            )
                        )
                        .padding(.bottom, Theme.space24)
                        .frame(
                            maxWidth: PocaAdaptiveLayout.homeContentMaxWidth(
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
            (
                Text(AppConstants.appDisplayName)
                    .font(.system(size: 34, weight: .bold))
                // 串联 Text 时前导普通空格可能被折叠掉，用不换行空格保证留出一个空格。
                + Text(verbatim: "\u{00A0}!")
                    .font(.system(size: 34, weight: .bold))
                    .italic()
            )
            .foregroundColor(Theme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)

            trashBinEntryButton
        }
        .padding(.top, 10)
    }

    /// 右上角待删除入口：进入「垃圾桶」（TrashBinView）。
    /// 用归档图标表达「暂存待确认」；数量角标挂在按钮上（最多 99+）。
    private var trashBinEntryButton: some View {
        PocaCircleIconButton(
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

    /// 待删除角标：数量 > 0 时显示，最多 99+（统一角标组件）。
    @ViewBuilder
    private var pendingDeleteBadge: some View {
        if pendingDeleteCount > 0 {
            PocaCountBadge(count: pendingDeleteCount)
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
            heroOverview
            periodCardsSection
            specialCleanupSection
            // 工具（图片/视频压缩）暂不展示；`toolSection` 保留便于恢复。
        }
    }

    // MARK: - 权限授权区域
    private var authorizationSection: some View {
        PhotoAuthorizationCard(
            subtitle: String(format: L10n.string("Poca needs photo library access to organize your albums. %@"), AppConstants.privacyShortText),
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
                    description: Text(L10n.string("There are no photos in the current access scope. You can adjust Poca's photo access in System Settings."))
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

                    Text(L10n.string("There are no photos in the current access scope. You can adjust Poca's photo access in System Settings."))
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

    // MARK: - 首屏（照片墙 = 一张照片；随机整理 = 动作行）

    private var heroOverview: some View {
        VStack(spacing: 12) {
            photoWallHeroCard
            randomReviewActionRow
        }
    }

    /// 照片墙入口：整张卡就是一张真实照片，信息压在底部。
    /// 左下角信息区放「换一张」胶囊（占原日期位），主 CTA 独占右下，不再压照片。
    private var photoWallHeroCard: some View {
        let total = libraryStats.totalAssets
        let asset = heroPhotoAsset

        return ZStack(alignment: .bottom) {
            Button {
                // 先进待整理照片墙；墙上再选月/日起滑。
                router.push(SwipeViewDestination.pendingPhotoWall)
            } label: {
                HomeHeroPhoto(asset: asset, manager: dataManager.photoLibraryManager)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .overlay {
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.10), location: 0),
                                .init(color: .clear, location: 0.34),
                                .init(color: .black.opacity(0.55), location: 0.68),
                                .init(color: .black.opacity(0.93), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .allowsHitTesting(false)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: Theme.stroke)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.string("Photo Wall"))
            .accessibilityValue("\(PocaCountFormat.plain(total)) \(L10n.string("photos label"))")
            .accessibilityIdentifier("home-pending-review")

            heroInfoBar(total: total)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
        }
    }

    /// 大卡底部信息条：左列数量 + 换一张，右侧主 CTA。
    /// 数量与 CTA 只做视觉，点击穿透到整卡按钮；只有「换一张」是独立热区。
    private func heroInfoBar(total: Int) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(PocaCountFormat.plain(total))
                        .font(.system(size: 26, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.78)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.28), radius: 5, y: 1)
                        .lineLimit(1)

                    Text(L10n.string("photos label"))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.74))
                        .lineLimit(1)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                if dataManager.photoLibraryManager.allPhotos.count > 1 {
                    shuffleHeroPhotoChip
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 7) {
                Text(L10n.string("Start Review"))
                    .font(.system(size: 12, weight: .bold))

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(Theme.onAccent)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule(style: .continuous).fill(Theme.accent))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// 「换一张」胶囊：视觉 36pt，热区补到 44pt。
    private var shuffleHeroPhotoChip: some View {
        Button {
            shuffleHeroPhoto()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .bold))

                Text(L10n.string("Shuffle photo"))
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.14)))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: Theme.stroke)
            )
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("Shuffle photo"))
        .accessibilityIdentifier("home-hero-shuffle")
    }

    /// 随机整理入口：动作行，不是第四个浏览卡。
    private var randomReviewActionRow: some View {
        Button {
            router.push(SwipeViewDestination.random(.memories))
        } label: {
            HStack(spacing: 12) {
                Image("RandomPileIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("Random Review"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(1)

                    Text(randomReviewDetail)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.right")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(Theme.primaryText.opacity(0.9))
                    .frame(width: 44, height: 44)
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .frame(height: 70)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.homeActionSurface)

                    HomeActionSheen()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.homeActionStroke, lineWidth: Theme.stroke)
            )
            .shadow(color: Color.black.opacity(0.36), radius: 11, y: 6)
        }
        .buttonStyle(HomeRandomActionButtonStyle())
        .accessibilityLabel(L10n.string("Random Review"))
        .accessibilityValue(randomReviewDetail)
        .accessibilityIdentifier("home-random-review")
    }

    // MARK: - 按时间段开始（三张独立卡：主体进本期 / 右区选周期）

    private var periodCardsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            PocaSectionHeader(title: L10n.string("By time"))

            VStack(spacing: Theme.space3) {
                periodCard(
                    scope: .week,
                    title: L10n.string("This week"),
                    moreTitle: L10n.string("More"),
                    moreAccessibilityLabel: L10n.string("Choose date"),
                    illustrationName: "PeriodWeekIcon",
                    identifier: "home-period-week",
                    rollDelay: 0.22
                )
                periodCard(
                    scope: .month,
                    title: L10n.string("This Month"),
                    moreTitle: L10n.string("More"),
                    moreAccessibilityLabel: L10n.string("Choose month"),
                    illustrationName: "PeriodMonthIcon",
                    identifier: "home-period-month",
                    rollDelay: 0.30
                )
                periodCard(
                    scope: .year,
                    title: L10n.string("This year"),
                    moreTitle: L10n.string("More"),
                    moreAccessibilityLabel: L10n.string("Choose year"),
                    illustrationName: "PeriodYearIcon",
                    identifier: "home-period-year",
                    rollDelay: 0.38
                )
            }
        }
    }

    private func periodCard(
        scope: AdvancedTimeScope,
        title: String,
        moreTitle: String,
        moreAccessibilityLabel: String,
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
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)

                        Text(String(
                            format: L10n.string("%@ items · %@"),
                            PocaCountFormat.plain(summary.assetCount),
                            summary.formattedEstimatedSize
                        ))
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
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
            .accessibilityLabel(moreAccessibilityLabel)
            .accessibilityIdentifier("\(identifier)-more")
        }
        .photoDeleteCard(radius: Theme.radiusLg)
    }

    // MARK: - 专项清理（行式列表，值用中性灰）

    private var specialCleanupSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            PocaSectionHeader(
                title: L10n.string("Special cleanup"),
                trailing: String(format: L10n.string("About %@ to clear"), cleanupReclaimableSizeText)
            )

            VStack(spacing: 0) {
                PocaListRow(
                    iconImage: "CleanupScreenshotsIcon",
                    iconImageSize: 42,
                    titleFont: .system(size: 16, weight: .semibold),
                    title: L10n.string("Screenshots"),
                    value: specialCleanupSizeText(dataManager.specialCleanupSizeSummary.screenshotsMB),
                    accessibilityIdentifier: "home-cleanup-screenshots"
                ) {
                    router.push(SwipeViewDestination.assetBrowser(.screenshots))
                }
                insetHairline(inset: 16)
                PocaListRow(
                    iconImage: "CleanupSimilarIcon",
                    iconImageSize: 42,
                    titleFont: .system(size: 16, weight: .semibold),
                    title: L10n.string("Similar"),
                    value: cleanupQueue(for: .similarPhotos)?.formattedSpace,
                    accessibilityIdentifier: "home-cleanup-similar"
                ) {
                    router.push(SwipeViewDestination.cleanup(.similarPhotos))
                }
                insetHairline(inset: 16)
                PocaListRow(
                    iconImage: "CleanupVideoIcon",
                    iconImageSize: 38,
                    titleFont: .system(size: 16, weight: .semibold),
                    title: L10n.string("Videos & Screen Recordings"),
                    value: specialCleanupSizeText(dataManager.specialCleanupSizeSummary.videosMB),
                    accessibilityIdentifier: "home-cleanup-videos"
                ) {
                    router.push(SwipeViewDestination.assetBrowser(.videos))
                }
                insetHairline(inset: 16)
                PocaListRow(
                    iconImage: "CleanupLivePhotoIcon",
                    iconImageSize: 38,
                    titleFont: .system(size: 16, weight: .semibold),
                    title: L10n.string("Live Photos"),
                    value: specialCleanupSizeText(dataManager.specialCleanupSizeSummary.livePhotosMB),
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
            PocaSectionHeader(title: L10n.string("Tools"))

            VStack(spacing: 0) {
                if AppConstants.isImageCompressionVisible {
                    PocaListRow(
                        title: L10n.string("Image Compression"),
                        subtitle: L10n.string("Smaller, not deleted"),
                        value: countText(cleanupQueue(for: .imageCompression)?.assetCount),
                        accessibilityIdentifier: "home-tool-image-compression"
                    ) {
                        router.push(SwipeViewDestination.cleanup(.imageCompression))
                    }
                    insetHairline()
                }

                PocaListRow(
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

    private func specialCleanupSizeText(_ megabytes: Double) -> String? {
        guard megabytes > 0 else { return nil }
        return CleanupStatsFormatter.space(megabytes)
    }

    private var libraryStats: AdvancedLibraryStats {
        dataManager.makeSettingsStatsSummary()
    }

    /// 专项清理头部合计：相似可回收 + 视频/录屏 + 截图 + 实况。
    /// 录屏是视频子集，videosMB 已覆盖，不再单独相加。
    private var cleanupReclaimableSizeText: String {
        let similarMB = cleanupQueue(for: .similarPhotos)?.estimatedSpaceMB ?? 0
        let reclaimMB = similarMB + dataManager.specialCleanupSizeSummary.totalMB
        if reclaimMB <= 0 && dataManager.isLoadingAdvancedCleanupQueues {
            return L10n.string("Reading")
        }
        return CleanupStatsFormatter.space(reclaimMB)
    }

    private var randomReviewDetail: String {
        let count = PhotoRandomReviewBatchSize.normalized(randomReviewBatchSizeValue).rawValue
        return String(format: L10n.string("Up to %lld photos per round"), Int64(count))
    }

    /// 首页主卡默认取最新的一张照片：排除视频/录屏和截图。
    /// 用户点「换一张」后跟随手动选中的那张；照片被删则回落到最新。
    /// 月份跟随这张照片；数量仍是全库总数。
    private var heroPhotoAsset: PHAsset? {
        let manager = dataManager.photoLibraryManager
        let allPhotos = manager.allPhotos

        func isEligibleHeroAsset(_ asset: PHAsset) -> Bool {
            asset.mediaType == .image && !asset.isHidden && !manager.isScreenshot(asset)
        }

        if let heroOverrideAssetID,
           let overridden = allPhotos.first(where: {
               $0.localIdentifier == heroOverrideAssetID && isEligibleHeroAsset($0)
           }) {
            return overridden
        }

        return allPhotos.first(where: isEligibleHeroAsset)
    }

    /// 在候选池里随机换一张，排除当前这张；候选只剩一张时保持不动。
    private func shuffleHeroPhoto() {
        let manager = dataManager.photoLibraryManager
        let currentID = heroPhotoAsset?.localIdentifier
        let candidates = manager.allPhotos.filter {
            $0.mediaType == .image && !$0.isHidden && !manager.isScreenshot($0)
        }
        let pool = candidates.count > 1
            ? candidates.filter { $0.localIdentifier != currentID }
            : candidates

        guard let next = pool.randomElement() else { return }
        heroOverrideAssetID = next.localIdentifier
    }

    private func countText(_ count: Int?) -> String {
        guard let count else { return L10n.string("Reading") }
        return PocaCountFormat.plain(count)
    }

}

// MARK: - 首页组件（对齐 home-prototype.html）

/// 首页照片墙主卡：只加载一张照片，失败时退回石墨渐变。
private struct HomeHeroPhoto: View {
    let asset: PHAsset?
    let manager: PhotoLibraryManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?
    @State private var renderID = 0
    @State private var requestID: PHImageRequestID?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.elevatedSurface, Theme.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .id(renderID)
                    .transition(.opacity)
            } else if asset == nil {
                Image("PhotoWallIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140)
                    .opacity(0.92)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear(perform: load)
        .onDisappear(perform: cancel)
        .onChange(of: asset?.localIdentifier) { _, _ in load() }
    }

    private func load() {
        cancel()
        image = nil
        guard let asset else { return }

        let targetID = asset.localIdentifier
        requestID = manager.loadFastThumbnail(
            for: asset,
            size: CGSize(width: 1_200, height: 900)
        ) { loaded in
            // 换图较快时，丢掉已经过期的回包。
            guard let loaded, targetID == self.asset?.localIdentifier else { return }
            self.requestID = nil

            let apply = {
                self.image = loaded
                self.renderID += 1
            }
            if reduceMotion {
                apply()
            } else {
                withAnimation(.easeInOut(duration: 0.24), apply)
            }
        }
    }

    private func cancel() {
        manager.cancelImageRequest(requestID)
        requestID = nil
    }
}

/// 首页随机整理行的常驻扫光（产品指定，非按压触发）：
/// 7 秒一轮，前 3 秒扫过，其余留白，低透明度白光，避免持续闪烁。
private struct HomeActionSheen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Color.clear
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    GeometryReader { proxy in
                        let cycle: TimeInterval = 7
                        let sweepPortion: Double = 0.42
                        let normalized = context.date
                            .timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: cycle) / cycle
                        let progress = min(normalized / sweepPortion, 1)
                        let bandWidth = max(proxy.size.width * 0.62, 190)
                        let x = -bandWidth + (proxy.size.width + bandWidth * 2) * progress

                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.04), location: 0.22),
                                .init(color: .white.opacity(0.13), location: 0.50),
                                .init(color: .white.opacity(0.04), location: 0.78),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: bandWidth, height: proxy.size.height * 1.8)
                        .rotationEffect(.degrees(14))
                        .offset(x: x, y: -proxy.size.height * 0.4)
                        .blur(radius: 9)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 动作行按压反馈：只跟随按压状态，没有常驻动效。
private struct HomeRandomActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.04 : 0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

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
        Text(PocaCountFormat.plain(displayed))
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
