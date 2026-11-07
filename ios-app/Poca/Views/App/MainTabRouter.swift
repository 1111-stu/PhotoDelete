//
//  MainTabRouter.swift
//  Poca
//
//  方案 C：根 NavigationStack 盖住 TabView。path 非空时底栏不在可见层。
//

import Foundation
import SwiftUI

enum MainTabSystemDestination: Hashable {
    case paywall
    case explicitReview(UUID)
}

@MainActor
final class MainTabRouter: ObservableObject {
    @Published var path = NavigationPath()

    /// 二次 push（清理/相册浏览器 → 整理）的大包 payload，不进 Hashable path。
    private(set) var explicitReviewPayload: ExplicitReviewPayload?

    struct ExplicitReviewPayload {
        let scope: ExplicitAssetReviewScope
        let category: PhotoCategory?
        let album: AlbumInfo?
    }

    func push(_ destination: SwipeViewDestination) {
        path.append(destination)
    }

    func push(_ destination: AlbumNavigationDestination) {
        path.append(destination)
    }

    func pushPaywall() {
        path.append(MainTabSystemDestination.paywall)
    }

    func pushExplicitReview(
        scope: ExplicitAssetReviewScope,
        category: PhotoCategory? = nil,
        album: AlbumInfo? = nil
    ) {
        explicitReviewPayload = ExplicitReviewPayload(scope: scope, category: category, album: album)
        path.append(MainTabSystemDestination.explicitReview(scope.id))
    }

    func popToRoot() {
        path = NavigationPath()
        explicitReviewPayload = nil
    }
}
