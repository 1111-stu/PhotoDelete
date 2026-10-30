//
//  MainTabView.swift
//  PhotoDelete
//
//  Created by PhotoDelete Team on 11/7/25.
//
//  方案 C：NavigationStack 包住 TabView。只有三个 Tab 根页看得到底栏；
//  任意 push 后整页盖住 TabView，子页 .toolbar 无法再把底栏翻出来。
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MainTabView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var router = MainTabRouter()
    @State private var selectedTab: PhotoDeleteMainTab = .organize

    /// 根页：整理/相册用自绘顶栏，隐藏系统导航栏；设置用 large title。
    /// push 后一律显示系统导航栏（返回）。
    private var showsSystemNavigationBar: Bool {
        !router.path.isEmpty || selectedTab == .settings
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            tabRoot
                .toolbar(showsSystemNavigationBar ? .automatic : .hidden, for: .navigationBar)
                .navigationDestination(for: SwipeViewDestination.self) { destination in
                    homeDestination(destination)
                }
                .navigationDestination(for: AlbumNavigationDestination.self) { destination in
                    albumDestination(destination)
                }
                .navigationDestination(for: MainTabSystemDestination.self) { destination in
                    systemDestination(destination)
                }
        }
        .environmentObject(router)
        .onAppear {
            configureTabBarAppearance()
            DispatchQueue.main.async {
                configureTabBarAppearance()
            }
            dataManager.syncPhotoLibraryAuthorization()
            #if DEBUG
            UITestPhotoLibrarySeeder.seedIfRequested {
                dataManager.syncPhotoLibraryAuthorization(showPreparing: true)
                dataManager.refreshAlbumsFromLibrary(showLoading: false)
            }
            #endif
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else {
                dataManager.cancelLocationTitleResolution()
                return
            }
            configureTabBarAppearance()
            dataManager.syncPhotoLibraryAuthorization()
            Task {
                await subscriptionManager.checkSubscriptionStatus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppConstants.openAlbumsTabNotificationName)) { _ in
            guard AppConstants.showsAlbumsTab else { return }
            router.popToRoot()
            selectedTab = .albums
        }
        .onChange(of: selectedTab) { _ in
            // 切 Tab 时清空 push 栈，避免跨 Tab 残留目的地。
            if !router.path.isEmpty {
                router.popToRoot()
            }
        }
    }

    private var tabRoot: some View {
        TabView(selection: $selectedTab) {
            tabContent(for: .organize)
                .tint(Theme.accent)
                .tabItem {
                    Image(systemName: PhotoDeleteMainTab.organize.systemImage)
                    Text(PhotoDeleteMainTab.organize.title)
                }
                .tag(PhotoDeleteMainTab.organize)

            if AppConstants.showsAlbumsTab {
                tabContent(for: .albums)
                    .tint(Theme.accent)
                    .tabItem {
                        Image(systemName: PhotoDeleteMainTab.albums.systemImage)
                        Text(PhotoDeleteMainTab.albums.title)
                    }
                    .tag(PhotoDeleteMainTab.albums)
            }

            tabContent(for: .settings)
                .tint(Theme.accent)
                .tabItem {
                    Image(systemName: PhotoDeleteMainTab.settings.systemImage)
                    Text(PhotoDeleteMainTab.settings.title)
                }
                .tag(PhotoDeleteMainTab.settings)
        }
        .tint(PhotoDeleteTabBarColors.selectedIconColor)
        .toolbarColorScheme(.dark, for: .tabBar)
    }

    @ViewBuilder
    private func tabContent(for tab: PhotoDeleteMainTab) -> some View {
        switch tab {
        case .organize:
            HomeView()
                .environmentObject(dataManager)
        case .albums:
            AlbumsView()
                .environmentObject(dataManager)
        case .advanced:
            AdvancedView()
                .environmentObject(dataManager)
        case .stats:
            StatsView()
                .environmentObject(dataManager)
        case .settings:
            SettingsView()
                .environmentObject(dataManager)
        }
    }

    @ViewBuilder
    private func homeDestination(_ destination: SwipeViewDestination) -> some View {
        switch destination {
        case .assetBrowser(let category):
            CleanupAssetBrowserView(category: category)
                .environmentObject(dataManager)
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
        case .wallMonth(let monthDate, let startFromDay, let startFromAssetID):
            SwipePhotoView(
                selectedCategory: nil,
                selectedTimeGroup: nil,
                selectedAlbumInfo: nil,
                selectedDate: monthDate,
                selectedAdvancedTimeScope: .month,
                reviewStartFromDay: startFromDay,
                reviewStartFromAssetID: startFromAssetID
            )
            .environmentObject(dataManager)
        case .pendingPhotoWall:
            PendingPhotoWallView()
                .environmentObject(dataManager)
        case .cleanup(let kind):
            AdvancedCleanupDestination(kind: kind)
                .environmentObject(dataManager)
        case .trashBin:
            TrashBinView()
                .environmentObject(dataManager)
        }
    }

    @ViewBuilder
    private func albumDestination(_ destination: AlbumNavigationDestination) -> some View {
        switch destination {
        case .swipeAlbum(let selectedSwipeAlbum):
            SwipePhotoView(selectedCategory: nil, selectedTimeGroup: nil, selectedAlbumInfo: selectedSwipeAlbum)
                .environmentObject(dataManager)
        case .browser(let album):
            AlbumPhotoBrowserView(album: album)
                .environmentObject(dataManager)
        }
    }

    @ViewBuilder
    private func systemDestination(_ destination: MainTabSystemDestination) -> some View {
        switch destination {
        case .paywall:
            PaywallView()
        case .explicitReview(let scopeID):
            if let payload = router.explicitReviewPayload, payload.scope.id == scopeID {
                SwipePhotoView(
                    selectedCategory: payload.category,
                    selectedTimeGroup: nil,
                    selectedAlbumInfo: payload.album,
                    explicitReviewScope: payload.scope
                )
                .environmentObject(dataManager)
            } else {
                EmptyView()
                    .onAppear { router.popToRoot() }
            }
        }
    }

    private func configureTabBarAppearance() {
        let customBackground = Self.customTabBarBackgroundAppearance()
        let tabBarProxy = UITabBar.appearance()
        if let customBackground {
            tabBarProxy.standardAppearance = customBackground
            tabBarProxy.scrollEdgeAppearance = customBackground
        }
        tabBarProxy.tintColor = PhotoDeleteTabBarColors.selectedIcon
        tabBarProxy.unselectedItemTintColor = PhotoDeleteTabBarColors.unselected

        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.rootViewController?.applyPhotoDeleteTabBarAppearance(customBackground)
            }
        }
    }

    /// Dark glass fill for system tab bars that still accept a custom background.
    /// iOS 26 keeps Liquid Glass, so this returns nil and only item colors are applied.
    private static func customTabBarBackgroundAppearance() -> UITabBarAppearance? {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 26 else {
            return nil
        }

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = PhotoDeleteTabBarColors.barBackground
        appearance.backgroundEffect = nil
        appearance.selectionIndicatorTintColor = PhotoDeleteTabBarColors.selectionPlate
        PhotoDeleteTabBarColors.apply(to: appearance)
        return appearance
    }
}

private enum PhotoDeleteTabBarColors {
    static let selectedIcon = Theme.uiAccent
    static let selectedLabel = UIColor(Theme.primaryText)
    static let unselected = Theme.uiSecondaryText
    static let barBackground = UIColor(Theme.reviewCanvas)
    static let selectionPlate = UIColor(Theme.elevatedSurface)

    static var selectedIconColor: Color { Color(uiColor: selectedIcon) }

    static func apply(to appearance: UITabBarAppearance) {
        apply(to: appearance.stackedLayoutAppearance)
        apply(to: appearance.inlineLayoutAppearance)
        apply(to: appearance.compactInlineLayoutAppearance)
    }

    static func apply(to item: UITabBarItemAppearance) {
        item.normal.iconColor = unselected
        item.normal.titleTextAttributes = [.foregroundColor: unselected]
        item.selected.iconColor = selectedIcon
        item.selected.titleTextAttributes = [.foregroundColor: selectedLabel]
    }
}

private extension UIViewController {
    func applyPhotoDeleteTabBarAppearance(_ customBackground: UITabBarAppearance?) {
        if let tabBar = (self as? UITabBarController)?.tabBar {
            if let customBackground {
                tabBar.standardAppearance = customBackground
                tabBar.scrollEdgeAppearance = customBackground
            } else {
                let standardAppearance = tabBar.standardAppearance
                PhotoDeleteTabBarColors.apply(to: standardAppearance)
                tabBar.standardAppearance = standardAppearance
                if let scrollEdgeAppearance = tabBar.scrollEdgeAppearance {
                    PhotoDeleteTabBarColors.apply(to: scrollEdgeAppearance)
                    tabBar.scrollEdgeAppearance = scrollEdgeAppearance
                }
            }
            tabBar.tintColor = PhotoDeleteTabBarColors.selectedIcon
            tabBar.unselectedItemTintColor = PhotoDeleteTabBarColors.unselected
        }

        children.forEach { $0.applyPhotoDeleteTabBarAppearance(customBackground) }
        presentedViewController?.applyPhotoDeleteTabBarAppearance(customBackground)
    }
}

private enum PhotoDeleteMainTab: CaseIterable, Identifiable, Hashable {
    case organize
    case albums
    case advanced
    case stats
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .organize:
            return L10n.string("Organize")
        case .albums:
            return L10n.string("Albums")
        case .advanced:
            return L10n.string("Advanced")
        case .stats:
            return L10n.string("Stats")
        case .settings:
            return L10n.string("Settings")
        }
    }

    var systemImage: String {
        switch self {
        case .organize:
            return "checkmark.rectangle.stack"
        case .albums:
            return "photo.on.rectangle"
        case .advanced:
            return "chart.bar.xaxis"
        case .stats:
            return "chart.bar.doc.horizontal"
        case .settings:
            return "gearshape"
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(DataManager())
}
