//
//  MainTabView.swift
//  PhotoDelete
//
//  Created by PhotoDelete Team on 11/7/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct MainTabView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.photoDeleteTheme) private var theme
    @AppStorage(AppConstants.appAppearanceKey) private var appAppearanceValue = AppAppearance.system.rawValue
    @State private var selectedTab: PhotoDeleteMainTab = .organize
    
    var body: some View {
        tabRoot
        .onAppear {
            configureTabBarAppearance()
            DispatchQueue.main.async {
                configureTabBarAppearance()
            }
            dataManager.syncPhotoLibraryAuthorization()
            Task {
                await purchaseManager.activateStoreKit()
            }
            #if DEBUG
            UITestPhotoLibrarySeeder.seedIfRequested {
                dataManager.syncPhotoLibraryAuthorization(showPreparing: true)
                dataManager.refreshAlbumsFromLibrary(showLoading: false)
            }
            #endif
        }
        .onChange(of: appAppearanceValue) { _ in
            configureTabBarAppearance()
        }
        .onChange(of: theme) { _ in
            configureTabBarAppearance()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else {
                dataManager.cancelLocationTitleResolution()
                return
            }
            configureTabBarAppearance()
            dataManager.syncPhotoLibraryAuthorization()
            purchaseManager.refreshEntitlementsAfterForegroundActivationIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppConstants.openAlbumsTabNotificationName)) { _ in
            guard AppConstants.showsAlbumsTab else { return }
            selectedTab = .albums
        }
    }

    private var tabRoot: some View {
        TabView(selection: $selectedTab) {
            tabContent(for: .organize)
                .tint(theme.navigationTint)
                .tabItem {
                    Image(systemName: PhotoDeleteMainTab.organize.systemImage)
                    Text(PhotoDeleteMainTab.organize.title)
                }
                .tag(PhotoDeleteMainTab.organize)
            
            if AppConstants.showsAlbumsTab {
                tabContent(for: .albums)
                    .tint(theme.navigationTint)
                    .tabItem {
                        Image(systemName: PhotoDeleteMainTab.albums.systemImage)
                        Text(PhotoDeleteMainTab.albums.title)
                    }
                    .tag(PhotoDeleteMainTab.albums)
            }

            tabContent(for: .settings)
                .tint(theme.navigationTint)
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
                .environmentObject(purchaseManager)
        case .stats:
            StatsView()
                .environmentObject(dataManager)
        case .settings:
            SettingsView()
                .environmentObject(dataManager)
                .environmentObject(purchaseManager)
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
    static let selectedIcon = UIColor(red: 243.0 / 255.0, green: 177.0 / 255.0, blue: 76.0 / 255.0, alpha: 1)
    static let selectedLabel = UIColor(white: 1, alpha: 0.96)
    static let unselected = UIColor(red: 142.0 / 255.0, green: 144.0 / 255.0, blue: 152.0 / 255.0, alpha: 1)
    static let barBackground = UIColor(red: 23.0 / 255.0, green: 24.0 / 255.0, blue: 31.0 / 255.0, alpha: 1)
    static let selectionPlate = UIColor(red: 44.0 / 255.0, green: 46.0 / 255.0, blue: 54.0 / 255.0, alpha: 1)

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
            return "sparkles"
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
        .environmentObject(PurchaseManager())
}
