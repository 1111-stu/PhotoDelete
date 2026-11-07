//
//  AdvancedView.swift
//  PhotoDelete
//
//  Created by PhotoDelete Team on 6/11/26.
//

import SwiftUI
import Photos
import Combine
import StoreKit
import UIKit

struct AdvancedView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(AppConstants.appLanguageKey) private var appLanguageValue = AppLanguage.system.rawValue
    @State private var selectedScope: AdvancedTimeScope = .month
    @State private var selectedPeriodDate = Date()
    @State private var dashboardSnapshot = AdvancedLibrarySnapshot.demo(referenceDate: Date())
    @State private var activePeriodRoute: AdvancedPeriodRoute?
    @State private var advancedRefreshWorkItem: DispatchWorkItem?
    @State private var lastDashboardRefreshKey: AdvancedDashboardRefreshKey?
    @State private var showingSupporterBenefits = false
    @State private var showingPaywall = false
    @State private var visibleAdvancedPeriodLimit = 5

    private var isLocked: Bool {
        AppConstants.advancedPaywallEnabled && !subscriptionManager.isPro
    }

    private var isAwaitingPhotoLibraryAccess: Bool {
        !isLocked && !dataManager.photoLibraryManager.hasPhotoLibraryAccess
    }

    var body: some View {
        let _ = appLanguageValue

        NavigationStack {
            advancedRootContent
                .navigationTitle(L10n.string("Advanced"))
                .navigationBarTitleDisplayMode(.large)
                .photoDeleteMainTabBarVisible()
                .navigationDestination(isPresented: isShowingActivePeriodRoute) {
                    if let activePeriodRoute {
                        AdvancedPeriodSwipeDestination(
                            scope: activePeriodRoute.scope,
                            intervalStart: activePeriodRoute.intervalStart
                        )
                        .environmentObject(dataManager)
                        .photoDeleteHidesMainTabBar()
                    }
                }
                .navigationDestination(isPresented: $showingPaywall) {
                    PaywallView()
                        .photoDeleteHidesMainTabBar()
                }
        }
        .onChange(of: selectedScope) { _ in
            selectedPeriodDate = Date()
            visibleAdvancedPeriodLimit = 5
            refreshAdvancedDashboard(resetSelectedPeriod: false, force: true)
        }
        .onChange(of: subscriptionManager.currentSubscriptionType) { _ in
            refreshAdvancedDashboard(resetSelectedPeriod: true, force: true)
        }
        .onChange(of: dataManager.cleanupStatsRevision) { _ in
            scheduleAdvancedDashboardRefresh()
        }
        .onChange(of: dataManager.advancedCleanupQueuesRevision) { _ in
            scheduleAdvancedDashboardRefresh()
        }
        .onReceive(dataManager.photoLibraryManager.$isLoading) { isLoading in
            if !isLoading {
                scheduleAdvancedDashboardRefresh()
            }
        }
        .onReceive(dataManager.photoLibraryManager.$allPhotos) { _ in
            guard !isPreparingRealAdvancedData else { return }
            scheduleAdvancedDashboardRefresh()
        }
        .task {
            dataManager.syncPhotoLibraryAuthorization()
            refreshAdvancedDashboard(resetSelectedPeriod: true)
        }
    }

    private var advancedRootContent: some View {
        ZStack {
            PhotoDeleteScreenBackground()

            ScrollView {
                let snapshot = dashboardSnapshot
                let periodSummaries = visiblePeriodSummaries

                VStack(spacing: 16) {
                    if isAwaitingPhotoLibraryAccess {
                        PhotoAuthorizationCard(
                            subtitle: L10n.string("Advanced features need the local photo library to build real monthly progress and cleanup queues."),
                            onRequestAccess: { dataManager.requestPhotoLibraryAccess() }
                        )
                    } else if shouldShowAdvancedPreparingCard {
                        AdvancedLibraryPreparingCard(progress: advancedLoadingProgress)
                    } else {
                        cleanupEntrySection(
                            queues: snapshot.cleanupQueues,
                            isLocked: isLocked
                        )
                        .redacted(reason: shouldRedactAdvancedContent ? .placeholder : [])
                        .allowsHitTesting(!shouldRedactAdvancedContent)

                        advancedPeriodListSection(
                            summaries: periodSummaries,
                            isLocked: isLocked
                        )
                        .redacted(reason: shouldRedactAdvancedContent ? .placeholder : [])
                        .allowsHitTesting(!shouldRedactAdvancedContent)
                    }

                    Spacer()
                        .frame(height: isLocked ? 24 : 96)
                }
                .padding(.horizontal, Theme.space5)
                .padding(.top, Theme.space2)
                .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isLocked {
                AdvancedPaywallBar(
                    yearlyPriceText: subscriptionManager.yearlyProduct?.displayPrice,
                    isLoading: subscriptionManager.isLoading,
                    errorMessage: subscriptionManager.errorMessage,
                    onViewPlans: openLockedAdvancedFeature,
                    onRestore: restorePurchases,
                    onShowBenefits: { showingSupporterBenefits = true }
                )
            }
        }
        .sheet(isPresented: $showingSupporterBenefits) {
            SupporterBenefitsSheet()
        }
    }

    private var visiblePeriodSummaries: [PhotoPeriodSummary] {
        if isLocked {
            return demoPeriodSummaries(for: selectedScope).filter { $0.assetCount > 0 }
        }

        if let summaries = dataManager.periodSummariesByScope[selectedScope] {
            return summaries.filter { $0.assetCount > 0 }
        }
        return []
    }

    private var displayedAdvancedPeriodSummaries: [PhotoPeriodSummary] {
        Array(visiblePeriodSummaries.prefix(visibleAdvancedPeriodLimit))
    }

    private var isPreparingRealAdvancedData: Bool {
        !isLocked &&
            dataManager.photoLibraryManager.hasPhotoLibraryAccess &&
            (
                dataManager.isPreparingLibrary ||
                dataManager.isRestoringLibrarySnapshot ||
                dataManager.photoLibraryManager.isLoading ||
                !dataManager.photoLibraryManager.hasLoadedPhotoLibrary
            )
    }

    private var shouldShowAdvancedPreparingCard: Bool {
        isPreparingRealAdvancedData &&
            !dataManager.photoLibraryManager.hasCachedPhotoLibrarySnapshot
    }

    private var shouldRedactAdvancedContent: Bool {
        !isLocked &&
            dataManager.photoLibraryManager.hasPhotoLibraryAccess &&
            !dataManager.photoLibraryManager.hasLoadedPhotoLibrary &&
            dataManager.photoLibraryManager.hasCachedPhotoLibrarySnapshot
    }

    private var shouldDeferAdvancedDashboardRefresh: Bool {
        !isLocked &&
            dataManager.photoLibraryManager.hasPhotoLibraryAccess &&
            !dataManager.photoLibraryManager.hasLoadedPhotoLibrary
    }

    private var advancedLoadingProgress: Double {
        let progress = dataManager.photoLibraryManager.loadingProgress
        guard progress > 0 else { return 0.04 }
        return min(max(progress, 0.04), 1)
    }

    private var dashboardRefreshKey: AdvancedDashboardRefreshKey {
        AdvancedDashboardRefreshKey(
            isLocked: isLocked,
            hasPhotoLibraryAccess: dataManager.photoLibraryManager.hasPhotoLibraryAccess,
            isPreparingRealAdvancedData: isPreparingRealAdvancedData,
            allPhotoCount: dataManager.photoLibraryManager.allPhotos.count,
            screenshotCount: dataManager.photoLibraryManager.screenshots.count,
            videoCount: dataManager.photoLibraryManager.videos.count,
            reviewedCount: dataManager.reviewedAssetIDs.count,
            deleteCandidateCount: dataManager.deleteCandidates.count,
            favoriteCandidateCount: dataManager.favoriteCandidates.count,
            cleanupStatsRevision: dataManager.cleanupStatsRevision,
            advancedCleanupQueuesRevision: dataManager.advancedCleanupQueuesRevision
        )
    }

    private var isShowingActivePeriodRoute: Binding<Bool> {
        Binding(
            get: { activePeriodRoute != nil },
            set: { isPresented in
                if !isPresented {
                    activePeriodRoute = nil
                }
            }
        )
    }

    private func advancedPeriodListSection(
        summaries: [PhotoPeriodSummary],
        isLocked: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.string("Organize by Time"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.primaryText)

                    Text(L10n.string("Continue by day, week, month, or year."))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                }

                Spacer()
            }

            AdvancedTimeScopePicker(selectedScope: $selectedScope)

            if summaries.isEmpty {
                if !isLocked && dataManager.isLoadingPeriodSummaries {
                    AdvancedEmptyState(
                        icon: "clock",
                        title: L10n.string("Organizing timeline"),
                        subtitle: L10n.string("Dates, months, and years appear after loading.")
                    )
                } else {
                    AdvancedEmptyState(
                        icon: "calendar",
                        title: L10n.string("No photos to organize by time yet"),
                        subtitle: L10n.string("No photos with capture dates are available in the current access range.")
                    )
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(displayedAdvancedPeriodSummaries.enumerated()), id: \.element.id) { index, summary in
                        Button {
                            openAdvancedPeriod(summary, isLocked: isLocked)
                        } label: {
                            AdvancedTimePeriodRow(summary: summary, isLocked: isLocked)
                        }
                        .buttonStyle(.plain)

                        if index != displayedAdvancedPeriodSummaries.count - 1 {
                            Divider()
                                .background(Theme.hairline)
                                .padding(.leading, 62)
                        }
                    }
                }
                .photoDeleteCard()

                if summaries.count > displayedAdvancedPeriodSummaries.count {
                    Button(action: showMoreAdvancedPeriods) {
                        Text(L10n.string("Show More"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .photoDeleteMinimumTapTarget()
                }
            }
        }
    }

    private func periodProgressSection(
        summaries: [PhotoPeriodSummary],
        selectedPeriod: PhotoPeriodSummary,
        isLocked: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.string("Time Progress"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.primaryText)

                Spacer()

                if isLocked {
                    Text(L10n.string("Demo"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.tertiaryText)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(summaries.prefix(18)) { summary in
                        Button {
                            selectedPeriodDate = summary.intervalStart
                            activePeriodRoute = AdvancedPeriodRoute(
                                scope: summary.scope,
                                intervalStart: summary.intervalStart
                            )
                        } label: {
                            AdvancedPeriodChip(
                                summary: summary,
                                isSelected: summary.id == selectedPeriod.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func cleanupEntrySection(
        queues: [AdvancedCleanupQueue],
        isLocked: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.string("Focused Cleanup"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.primaryText)

                Text(L10n.string("Handle similar photos, large files, image compression, and video compression in one place."))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
            }

            if dataManager.imageCompressionJob.isCompressing {
                AdvancedVideoCompressionProgressCard(
                    processedCount: dataManager.imageCompressionJob.processedCount,
                    totalCount: dataManager.imageCompressionJob.totalCount,
                    currentProgress: dataManager.imageCompressionJob.currentProgress,
                    message: dataManager.imageCompressionJob.message
                )
            }

            if dataManager.videoCompressionJob.isCompressing {
                AdvancedVideoCompressionProgressCard(
                    processedCount: dataManager.videoCompressionJob.processedCount,
                    totalCount: dataManager.videoCompressionJob.totalCount,
                    currentProgress: dataManager.videoCompressionJob.currentProgress,
                    message: dataManager.videoCompressionJob.message
                )
            }

            let visibleQueues = queues.filter { AdvancedCleanupKind.visibleCases.contains($0.kind) }

            if visibleQueues.isEmpty && dataManager.isLoadingAdvancedCleanupQueues {
                AdvancedEmptyState(
                    icon: "sparkles",
                    title: L10n.string("Preparing cleanup options"),
                    subtitle: L10n.string("Photos and videos you can review will appear shortly.")
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleQueues.enumerated()), id: \.element.id) { index, queue in
                        if isLocked {
                            Button(action: openLockedAdvancedFeature) {
                                AdvancedCleanupEntryRow(queue: queue, isLocked: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                cleanupDestination(for: queue.kind)
                                    .photoDeleteHidesMainTabBar()
                            } label: {
                                AdvancedCleanupEntryRow(queue: queue, isLocked: false)
                            }
                            .buttonStyle(.plain)
                        }

                        if index != visibleQueues.count - 1 {
                            Divider()
                                .background(Theme.hairline)
                                .padding(.leading, 62)
                        }
                    }
                }
                .photoDeleteCard()
            }
        }
    }

    @ViewBuilder
    private func cleanupDestination(for kind: AdvancedCleanupKind) -> some View {
        switch kind {
        case .similarPhotos:
            AdvancedSimilarPhotoGroupsView()
                .environmentObject(dataManager)
        case .imageCompression:
            if AppConstants.isImageCompressionVisible {
                AdvancedImageCompressionView()
                    .environmentObject(dataManager)
            } else {
                EmptyView()
            }
        case .videoCompression:
            AdvancedVideoCompressionView()
                .environmentObject(dataManager)
        case .largeFiles, .videos:
            AdvancedAssetListView(mode: .cleanup(kind))
                .environmentObject(dataManager)
        case .screenRecordings:
            CleanupAssetBrowserView(category: .screenRecordings)
                .environmentObject(dataManager)
        }
    }

    private func selectedPeriodSummary(in summaries: [PhotoPeriodSummary]) -> PhotoPeriodSummary {
        let selectedInterval = Calendar.current.dateInterval(for: selectedScope, containing: selectedPeriodDate)
        if let selected = summaries.first(where: { Calendar.current.isDate($0.intervalStart, inSameDayAs: selectedInterval.start) || $0.intervalStart == selectedInterval.start }) {
            return selected
        }

        if let containing = summaries.first(where: { selectedPeriodDate >= $0.intervalStart && selectedPeriodDate < $0.intervalEnd }) {
            return containing
        }

        return PhotoPeriodSummary.empty(scope: selectedScope, containing: selectedPeriodDate)
    }

    private func demoPeriodSummaries(for scope: AdvancedTimeScope) -> [PhotoPeriodSummary] {
        let calendar = Calendar.current
        let currentInterval = calendar.dateInterval(for: scope, containing: Date.now)
        let count = demoPeriodCount(for: scope)
        var summaries: [PhotoPeriodSummary] = []
        summaries.reserveCapacity(count)

        for index in 0..<count {
            guard let start = calendar.date(
                byAdding: scope.calendarComponent,
                value: -index,
                to: currentInterval.start
            ) else { continue }

            let interval = calendar.dateInterval(for: scope, containing: start)
            let base = max(1, count - index)
            let assetCount = demoAssetCount(for: scope, base: base)
            let reviewedCount = demoReviewedCount(assetCount: assetCount, index: index)

            summaries.append(
                PhotoPeriodSummary(
                    scope: scope,
                    intervalStart: interval.start,
                    intervalEnd: interval.end,
                    assetCount: assetCount,
                    screenshotCount: max(assetCount / 5, 0),
                    videoCount: max(assetCount / 16, 0),
                    reviewedCount: reviewedCount,
                    estimatedSizeMB: demoEstimatedSizeMB(for: scope, assetCount: assetCount)
                )
            )
        }

        return summaries
    }

    private func demoPeriodCount(for scope: AdvancedTimeScope) -> Int {
        switch scope {
        case .day:
            return 14
        case .week:
            return 12
        case .month:
            return 18
        case .year:
            return 5
        }
    }

    private func demoAssetCount(for scope: AdvancedTimeScope, base: Int) -> Int {
        switch scope {
        case .day:
            return 18 + base * 3
        case .week:
            return 72 + base * 9
        case .month:
            return 320 + base * 42
        case .year:
            return 1_800 + base * 220
        }
    }

    private func demoReviewedCount(assetCount: Int, index: Int) -> Int {
        let progress = min(0.82, 0.28 + Double(index % 6) * 0.1)
        return Int(Double(assetCount) * progress)
    }

    private func demoEstimatedSizeMB(for scope: AdvancedTimeScope, assetCount: Int) -> Double {
        let averageAssetSizeMB: Double
        switch scope {
        case .day, .week, .month:
            averageAssetSizeMB = 3.1
        case .year:
            averageAssetSizeMB = 3.8
        }
        return Double(assetCount) * averageAssetSizeMB
    }

    private func moveSelectedPeriod(by offset: Int) {
        guard let next = Calendar.current.date(
            byAdding: selectedScope.calendarComponent,
            value: offset,
            to: selectedPeriodDate
        ) else { return }

        guard offset < 0 || canAdvance(to: next) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            selectedPeriodDate = next
        }
        HapticManager.impact(.light)
    }

    private func canAdvance(from summary: PhotoPeriodSummary) -> Bool {
        guard let next = Calendar.current.date(
            byAdding: selectedScope.calendarComponent,
            value: 1,
            to: summary.intervalStart
        ) else { return false }
        return canAdvance(to: next)
    }

    private func canAdvance(to date: Date) -> Bool {
        let nextStart = Calendar.current.dateInterval(for: selectedScope, containing: date).start
        let currentStart = Calendar.current.dateInterval(for: selectedScope, containing: Date()).start
        return nextStart <= currentStart
    }

    private func openAdvancedPeriod(_ summary: PhotoPeriodSummary, isLocked: Bool) {
        guard !isLocked else {
            openLockedAdvancedFeature()
            return
        }

        selectedPeriodDate = summary.intervalStart
        activePeriodRoute = AdvancedPeriodRoute(
            scope: summary.scope,
            intervalStart: summary.intervalStart
        )
    }

    private func openLockedAdvancedFeature() {
        showingPaywall = true
    }

    private func restorePurchases() {
        Task { await subscriptionManager.restorePurchases() }
    }

    private func scheduleAdvancedDashboardRefresh() {
        advancedRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            refreshAdvancedDashboard(resetSelectedPeriod: false)
        }
        advancedRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func refreshAdvancedDashboard(resetSelectedPeriod: Bool, force: Bool = false) {
        if resetSelectedPeriod {
            selectedPeriodDate = Date()
        }

        guard !shouldDeferAdvancedDashboardRefresh else { return }
        let refreshKey = dashboardRefreshKey
        guard force || refreshKey != lastDashboardRefreshKey else { return }
        lastDashboardRefreshKey = refreshKey

        if isLocked || !dataManager.photoLibraryManager.hasPhotoLibraryAccess {
            dashboardSnapshot = AdvancedLibrarySnapshot.demo(referenceDate: Date())
            return
        }

        dashboardSnapshot = AdvancedLibrarySnapshot(
            stats: dataManager.makeSettingsStatsSummary(),
            daySummaries: [],
            monthSummaries: [],
            cleanupQueues: dataManager.advancedCleanupQueues
        )
        dataManager.refreshAdvancedCleanupQueues()
        dataManager.refreshPhotoPeriodSummaries(for: [selectedScope])
    }

    private func showMoreAdvancedPeriods() {
        withAnimation(.easeInOut(duration: 0.18)) {
            visibleAdvancedPeriodLimit = VisibleListPagination.advancedLimit(
                totalCount: visiblePeriodSummaries.count,
                currentLimit: visibleAdvancedPeriodLimit,
                step: 20
            )
        }
    }
}

private struct AdvancedDashboardRefreshKey: Equatable {
    let isLocked: Bool
    let hasPhotoLibraryAccess: Bool
    let isPreparingRealAdvancedData: Bool
    let allPhotoCount: Int
    let screenshotCount: Int
    let videoCount: Int
    let reviewedCount: Int
    let deleteCandidateCount: Int
    let favoriteCandidateCount: Int
    let cleanupStatsRevision: UUID
    let advancedCleanupQueuesRevision: UUID
}

private struct AdvancedPeriodRoute: Identifiable, Hashable {
    let scope: AdvancedTimeScope
    let intervalStart: Date

    var id: String {
        PhotoPeriodSummary.empty(scope: scope, containing: intervalStart).id
    }
}

private struct AdvancedPeriodSwipeDestination: View {
    let scope: AdvancedTimeScope
    let intervalStart: Date

    var body: some View {
        SwipePhotoView(
            selectedCategory: nil,
            selectedTimeGroup: nil,
            selectedAlbumInfo: nil,
            selectedDate: intervalStart,
            selectedAdvancedTimeScope: scope
        )
    }
}

private struct AdvancedTimeScopePicker: View {
    @Binding var selectedScope: AdvancedTimeScope

    var body: some View {
        Picker(L10n.string("Time Range"), selection: $selectedScope) {
            ForEach(AdvancedTimeScope.allCases) { scope in
                Text(scope.title)
                    .tag(scope)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct AdvancedPeriodNavigator: View {
    let summary: PhotoPeriodSummary
    let canGoForward: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PhotoDeleteCircleIconButton(
                systemName: "chevron.left",
                accessibilityLabel: L10n.string("Previous Period"),
                action: onPrevious
            )

            VStack(spacing: 3) {
                Text(AdvancedPeriodFormatter.title(for: summary))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(AdvancedPeriodFormatter.subtitle(for: summary))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)

            PhotoDeleteCircleIconButton(
                systemName: "chevron.right",
                accessibilityLabel: L10n.string("Next Period"),
                action: onNext
            )
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1 : 0.42)
        }
        .padding(12)
        .photoDeleteCard()
    }
}

private struct AdvancedPeriodProgressCard: View {
    let summary: PhotoPeriodSummary
    let isDemo: Bool

    var body: some View {
        HStack(spacing: 16) {
            AdvancedProgressRing(progress: summary.progress, size: 78, lineWidth: 8) {
                Text("\(Int(summary.progress * 100))%")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(String(format: L10n.string("%@ cleanup progress"), AdvancedPeriodFormatter.compactTitle(for: summary)))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Theme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        if isDemo {
                            AdvancedDemoTag()
                        }
                    }

                    Text(String(
                        format: L10n.string("%lld/%lld items organized"),
                        Int64(summary.reviewedCount),
                        Int64(summary.assetCount)
                    ))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                HStack(spacing: 6) {
                    AdvancedMiniMetric(title: L10n.string("Photos"), value: "\(summary.assetCount)")
                    AdvancedMiniMetric(title: L10n.string("Videos"), value: "\(summary.videoCount)")
                    AdvancedMiniMetric(title: L10n.string("Screenshots"), value: "\(summary.screenshotCount)")
                }
            }
        }
        .padding(16)
        .photoDeleteCard()
    }
}

private struct AdvancedMiniMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.tertiaryText)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .fill(Theme.elevatedSurface)
        )
    }
}

private struct AdvancedPeriodChip: View {
    let summary: PhotoPeriodSummary
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                AdvancedProgressRing(progress: summary.progress, size: 34, lineWidth: 4) {
                    EmptyView()
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(AdvancedPeriodFormatter.chipTitle(for: summary))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(1)

                    Text(String(
                        format: L10n.string("%lld items · %lld%%"),
                        Int64(summary.assetCount),
                        Int64(summary.progress * 100)
                    ))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 94, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.16) : Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                        .stroke(isSelected ? Theme.accent.opacity(0.65) : Theme.hairline, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(Text(isSelected ? L10n.string("Selected") : L10n.string("Not Set")))
    }
}

private struct AdvancedCleanupEntryRow: View {
    let queue: AdvancedCleanupQueue
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            PhotoDeleteIconTile(
                icon: queue.kind.icon,
                tint: queue.kind.tint,
                size: 38,
                cornerRadius: Theme.radiusSm
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(queue.kind.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.primaryText)

                Text(detailText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer()

            Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.tertiaryText)
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    private var detailText: String {
        String(format: L10n.string("%lld items"), Int64(queue.assetCount))
    }
}

private struct AdvancedTimePeriodRow: View {
    let summary: PhotoPeriodSummary
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            AdvancedPeriodProgressBadge(progress: summary.progress)

            VStack(alignment: .leading, spacing: 4) {
                Text(AdvancedPeriodFormatter.title(for: summary))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(detailText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            Image(systemName: isLocked ? "lock.fill" : "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.tertiaryText)
        }
        .padding(14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var detailText: String {
        String(
            format: L10n.string("%lld remaining"),
            Int64(summary.remainingCount)
        )
    }
}

private struct AdvancedPeriodProgressBadge: View {
    let progress: Double

    var body: some View {
        AdvancedProgressRing(progress: progress, size: 48, lineWidth: 5) {
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityHidden(true)
    }
}

/// 进阶页锁定态底栏。只负责把用户带到唯一的购买入口（PaywallView），
/// 不在底栏里复刻一套套餐选择——购买路径只留一处，避免两套价格逻辑。
private struct AdvancedPaywallBar: View {
    let yearlyPriceText: String?
    let isLoading: Bool
    let errorMessage: String?
    let onViewPlans: () -> Void
    let onRestore: () -> Void
    let onShowBenefits: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Capsule(style: .continuous)
                .fill(Theme.hairline)
                .frame(width: 38, height: 4)
                .padding(.bottom, 4)

            VStack(spacing: 5) {
                HStack(spacing: 7) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(L10n.string("Unlock All Advanced Features"))
                        .font(.system(size: 20, weight: .semibold))
                }
                .foregroundColor(Theme.primaryText)

                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button(action: onViewPlans) {
                Text(L10n.string("View Plans"))
                    .frame(maxWidth: .infinity)
            }
            .photoDeletePrimaryButton()
            .accessibilityIdentifier("advanced-view-plans-button")

            Button(action: onRestore) {
                Text(L10n.string("Restore Purchase"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                            .fill(Theme.elevatedSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                                    .stroke(Theme.hairline, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .accessibilityLabel(L10n.string("Restore Purchase"))

            Text(L10n.string("Subscriptions renew automatically unless canceled in Apple ID settings. Lifetime Pro is a one-time purchase. Basic cleanup remains free."))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            SupporterLegalLinksRow()

            Button(action: onShowBenefits) {
                Text(L10n.string("Feature differences"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.secondaryText)
                    .underline()
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.warning)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Theme.space5)
        .padding(.top, 16)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                .fill(Theme.background.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var subtitle: String {
        guard let yearlyPriceText else {
            return L10n.string("Quarterly or annual subscription, or a one-time Lifetime purchase.")
        }

        return String(
            format: L10n.string("From %@/year, or a one-time Lifetime purchase."),
            yearlyPriceText
        )
    }
}

private struct AdvancedLibraryPreparingCard: View {
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 13) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.14))
                        .frame(width: 42, height: 42)

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                        .scaleEffect(0.82)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("Preparing Photo Data"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.primaryText)

                    Text(L10n.string("Reading local photos, screenshots, and videos. Available options will appear when ready."))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: Theme.accent))
                .accessibilityLabel(L10n.string("Photo data preparation progress"))
        }
        .padding(16)
        .photoDeleteCard()
    }
}

private struct AdvancedPeriodListView: View {
    @EnvironmentObject var dataManager: DataManager
    let summaries: [PhotoPeriodSummary]
    @State private var visibleLimit = 60

    private let limitStep = 60

    private var visibleSummaries: [PhotoPeriodSummary] {
        VisibleListPagination.visibleItems(summaries, limit: visibleLimit)
    }

    private var hasMore: Bool {
        VisibleListPagination.hasMore(totalCount: summaries.count, limit: visibleLimit)
    }

    var body: some View {
        ZStack {
            PhotoDeleteScreenBackground()

            ScrollView {
                LazyVStack(spacing: 16) {
                    VStack(spacing: 0) {
                        ForEach(Array(visibleSummaries.enumerated()), id: \.element.id) { index, summary in
                            NavigationLink {
                                AdvancedPeriodSwipeDestination(
                                    scope: summary.scope,
                                    intervalStart: summary.intervalStart
                                )
                                .environmentObject(dataManager)
                                .photoDeleteHidesMainTabBar()
                            } label: {
                                AdvancedPeriodListRow(summary: summary)
                            }
                            .buttonStyle(.plain)

                            if index != visibleSummaries.count - 1 {
                                Divider()
                                    .background(Theme.hairline)
                                    .padding(.leading, 70)
                            }
                        }
                    }
                    .photoDeleteCard()

                    if hasMore {
                        Button(action: showMore) {
                            Text(L10n.string("Show More"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .photoDeleteMinimumTapTarget()
                    }

                    Spacer()
                        .frame(height: 72)
                }
                .padding(Theme.space5)
            }
        }
        .advancedDetailNavigation(title: L10n.string("Time Progress"))
    }

    private func showMore() {
        withAnimation(.easeInOut(duration: 0.18)) {
            visibleLimit = VisibleListPagination.advancedLimit(
                totalCount: summaries.count,
                currentLimit: visibleLimit,
                step: limitStep
            )
        }
    }
}

private struct AdvancedPeriodListRow: View {
    let summary: PhotoPeriodSummary

    var body: some View {
        HStack(spacing: 13) {
            AdvancedProgressRing(progress: summary.progress, size: 40, lineWidth: 4) {
                EmptyView()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(AdvancedPeriodFormatter.title(for: summary))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.primaryText)

                Text(String(
                    format: L10n.string("%lld items · %lld%% organized"),
                    Int64(summary.assetCount),
                    Int64(summary.progress * 100)
                ))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.tertiaryText)
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

private struct AdvancedFilteredAssetSnapshot {
    let assets: [PHAsset]
    let visibleAssets: [PHAsset]
    let videoAssets: [PHAsset]
    let totalSizeMB: Double
    let loadedReliableSizeCount: Int
    let loadedReliableVideoSizeCount: Int
    let iCloudVideoCount: Int
    let hasMoreAssets: Bool

    var hasUnresolvedVideoSizes: Bool {
        !videoAssets.isEmpty && loadedReliableVideoSizeCount < videoAssets.count
    }
}

private struct AdvancedAssetListView: View {
    @EnvironmentObject var dataManager: DataManager
    let mode: AdvancedAssetListMode

    @State private var assets: [PHAsset] = []
    @State private var orderedAssets: [PHAsset] = []
    @State private var videoSizeEstimatesByAssetID: [String: VideoFileSizeEstimate] = [:]
    @State private var photoSizeEstimatesByAssetID: [String: AssetFileSizeEstimate] = [:]
    @State private var selectedAssetIDs: Set<String> = []
    @State private var selectedFilter: AdvancedCleanupFilter = .all
    @State private var showingICloudVideoInfo = false
    @State private var showBatchConfirm = false
    @State private var previewAsset: AdvancedPreviewAsset?
    @State private var sizeLoadingTask: Task<Void, Never>?
    @State private var visibleAssetLimit = 40
    @State private var isLoadingAssets = false
    @State private var isLoadingFileSizes = false
    @State private var assetLoadGeneration = 0
    @State private var sizeLoadGeneration = 0

    private let assetLimitStep = 40
    private let fileSizeUpdateBatchSize = 8

    private var selectedAssets: [PHAsset] {
        makeFilteredAssetSnapshot().assets.filter { selectedAssetIDs.contains($0.localIdentifier) }
    }

    private var prefersSizeFirstOrder: Bool {
        switch mode {
        case .cleanup(.largeFiles), .cleanup(.videos), .cleanup(.videoCompression), .cleanup(.screenRecordings):
            return true
        case .cleanup(.similarPhotos), .cleanup(.imageCompression):
            return false
        }
    }

    private var shouldLoadPhotoFileSizes: Bool {
        if case .cleanup(.largeFiles) = mode { return true }
        return false
    }

    private var fileSizeLoadTargets: [PHAsset] {
        makeFilteredAssetSnapshot().visibleAssets.filter { asset in
            asset.mediaType == .video || (shouldLoadPhotoFileSizes && asset.mediaType == .image)
        }
    }

    private func makeFilteredAssetSnapshot() -> AdvancedFilteredAssetSnapshot {
        let filteredAssets = filteredAssetCandidates()
        let visibleAssets = VisibleListPagination.visibleItems(filteredAssets, limit: visibleAssetLimit)
        let videoAssets = filteredAssets.filter { $0.mediaType == .video }
        let reliableSizes = filteredAssets.compactMap { asset -> Double? in
            if asset.mediaType == .video {
                return reliableVideoSizeMB(for: asset)
            }
            return reliablePhotoSizeMB(for: asset)
        }
        let totalSizeMB = reliableSizes.reduce(0, +)
        let loadedReliableVideoSizeCount = videoAssets.reduce(0) { partial, asset in
            reliableVideoSizeMB(for: asset) == nil ? partial : partial + 1
        }
        let iCloudVideoCount = videoAssets.reduce(0) { partial, asset in
            videoSizeEstimatesByAssetID[asset.localIdentifier]?.source == .iCloud ? partial + 1 : partial
        }

        return AdvancedFilteredAssetSnapshot(
            assets: filteredAssets,
            visibleAssets: visibleAssets,
            videoAssets: videoAssets,
            totalSizeMB: totalSizeMB,
            loadedReliableSizeCount: reliableSizes.count,
            loadedReliableVideoSizeCount: loadedReliableVideoSizeCount,
            iCloudVideoCount: iCloudVideoCount,
            hasMoreAssets: VisibleListPagination.hasMore(totalCount: filteredAssets.count, limit: visibleAssetLimit)
        )
    }

    private func filteredAssetCandidates() -> [PHAsset] {
        guard selectedFilter != .all else { return orderedAssets }
        return orderedAssets.filter { matches(asset: $0, filter: selectedFilter) }
    }

    var body: some View {
        let snapshot = makeFilteredAssetSnapshot()

        ZStack {
            PhotoDeleteScreenBackground()

            ScrollView {
                VStack(spacing: 14) {
                    if case .cleanup(let kind) = mode,
                       AdvancedCleanupFilter.options(for: kind).count > 1 {
                        AdvancedFilterPills(kind: kind, selection: $selectedFilter)
                    }

                    AdvancedAssetListSummaryCard(
                        title: summaryTitle(for: snapshot),
                        subtitle: summarySubtitle(for: snapshot),
                        buttonTitle: isAllFilteredSelected(in: snapshot) ? L10n.string("Cancel") : L10n.string("Select All"),
                        action: toggleBulkSelection
                    )

                    if !isLoadingAssets, !isLoadingFileSizes, snapshot.iCloudVideoCount > 0 {
                        AdvancedVideoCompressionICloudInfoCard(
                            count: snapshot.iCloudVideoCount,
                            subtitle: L10n.string("The original will download when previewing or processing."),
                            action: showICloudVideoInfo
                        )
                    }

                    if isLoadingAssets && assets.isEmpty {
                        AdvancedLoadingState(title: L10n.string("Preparing cleanup options"))
                    } else if assets.isEmpty {
                        AdvancedEmptyState(
                            icon: mode.icon,
                            title: L10n.string("Nothing to Organize"),
                            subtitle: L10n.string("No items currently match this cleanup entry.")
                        )
                    } else if snapshot.assets.isEmpty {
                        AdvancedEmptyState(
                            icon: mode.icon,
                            title: L10n.string("No Results for This Filter"),
                            subtitle: L10n.string("Switch to All, or check again later.")
                        )
                    } else {
                        LazyVStack(spacing: 9) {
                            ForEach(snapshot.visibleAssets, id: \.localIdentifier) { asset in
                                AdvancedAssetRow(
                                    asset: asset,
                                    photoLibraryManager: dataManager.photoLibraryManager,
                                    estimatedSizeMB: displaySizeMB(for: asset),
                                    sizeText: displaySizeText(for: asset),
                                    sizeSystemImage: sizeStatusSystemImage(for: asset),
                                    sizeTint: sizeStatusTint(for: asset),
                                    isSelected: selectedAssetIDs.contains(asset.localIdentifier),
                                    onToggleSelection: { toggleSelection(asset) },
                                    onPreview: { previewAsset = AdvancedPreviewAsset(asset: asset) }
                                )
                                .onAppear {
                                    showMoreAssetsIfNeeded(currentAsset: asset)
                                }
                            }
                        }

                        if snapshot.hasMoreAssets {
                            Text(L10n.string("Scroll down to load more"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }

                    Spacer()
                        .frame(height: 24)
                }
                .padding(Theme.space5)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !selectedAssetIDs.isEmpty {
                AdvancedSelectionActionBar(
                    count: selectedAssetIDs.count,
                    action: addSelectedAssetsToDeleteCandidates
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .advancedDetailNavigation(title: mode.title)
        .fullScreenCover(isPresented: $showBatchConfirm, onDismiss: {
            syncSelectionWithPendingDeleteCandidates()
            reloadAssets()
        }) {
            BatchConfirmView()
                .environmentObject(dataManager)
        }
        .sheet(item: $previewAsset) { item in
            AdvancedAssetPreviewView(
                asset: item.asset,
                photoLibraryManager: dataManager.photoLibraryManager,
                assets: item.assets,
                selectedAssetIDs: $selectedAssetIDs
            )
        }
        .alert(L10n.string("iCloud Videos"), isPresented: $showingICloudVideoInfo) {
            Button(L10n.string("Got it"), role: .cancel) {}
        } message: {
            Text(L10n.string("Videos with a cloud icon are currently stored in iCloud. The list will not automatically download large videos. The original will download when previewing or processing."))
        }
        .task(id: mode.id) {
            reloadAssets()
        }
        .onChange(of: selectedFilter) { _ in
            visibleAssetLimit = 40
            pruneSelectionToFilteredAssets()
            loadFileSizesForCurrentScope()
        }
        .onDisappear {
            sizeLoadingTask?.cancel()
        }
    }

    private func summaryTitle(for snapshot: AdvancedFilteredAssetSnapshot) -> String {
        switch mode {
        case .cleanup(.largeFiles):
            return String(format: L10n.string("%lld large files total"), Int64(snapshot.assets.count))
        case .cleanup(.imageCompression):
            return String(format: L10n.string("%lld compressible images"), Int64(snapshot.assets.count))
        case .cleanup(.videoCompression):
            return String(format: L10n.string("%lld videos ready to compress"), Int64(snapshot.assets.count))
        // 录屏是视频子集；该列表不承载录屏（录屏走 SwipePhotoView），此分支仅为穷尽性。
        case .cleanup(.videos), .cleanup(.screenRecordings):
            return String(format: L10n.string("%lld videos total"), Int64(snapshot.assets.count))
        case .cleanup(.similarPhotos):
            return String(format: L10n.string("%lld similar photos total"), Int64(snapshot.assets.count))
        }
    }

    private func summarySubtitle(for snapshot: AdvancedFilteredAssetSnapshot) -> String {
        switch mode {
        case .cleanup(.largeFiles):
            guard snapshot.loadedReliableSizeCount > 0 else {
                return L10n.string("Reading actual file sizes")
            }
            return String(
                format: L10n.string("%lld/%lld items read. Known size is about %@."),
                Int64(snapshot.loadedReliableSizeCount),
                Int64(snapshot.assets.count),
                CleanupStatsFormatter.fileSize(snapshot.totalSizeMB)
            )
        case .cleanup(.imageCompression):
            return L10n.string("Select images to compress. Actual file sizes appear when complete.")
        case .cleanup(.videoCompression):
            return L10n.string("Select videos to compress. Actual file sizes appear when complete.")
        case .cleanup(.videos), .cleanup(.screenRecordings):
            if snapshot.hasUnresolvedVideoSizes {
                return String(
                    format: L10n.string("%lld/%lld video sizes read. Known size is about %@."),
                    Int64(snapshot.loadedReliableVideoSizeCount),
                    Int64(snapshot.videoAssets.count),
                    CleanupStatsFormatter.fileSize(snapshot.totalSizeMB)
                )
            }
            return String(
                format: L10n.string("%lld/%lld video sizes read. Known size is about %@."),
                Int64(snapshot.loadedReliableVideoSizeCount),
                Int64(snapshot.videoAssets.count),
                CleanupStatsFormatter.fileSize(snapshot.totalSizeMB)
            )
        case .cleanup(.similarPhotos):
            return L10n.string("Review items before adding them to the delete queue.")
        }
    }

    private func reloadAssets() {
        assetLoadGeneration += 1
        let generation = assetLoadGeneration
        isLoadingAssets = true
        switch mode {
        case .cleanup(let kind):
            dataManager.loadPhotosForAdvancedCleanup(kind) { loadedAssets in
                guard generation == assetLoadGeneration else { return }
                applyLoadedAssets(loadedAssets)
            }
        }
    }

    private func applyLoadedAssets(_ loadedAssets: [PHAsset]) {
        assets = loadedAssets
        visibleAssetLimit = 40
        pruneVideoSizeEstimates(for: loadedAssets)
        prunePhotoSizeEstimates(for: loadedAssets)
        seedCachedVideoSizeEstimates(for: loadedAssets)
        refreshOrderedAssets()
        pruneSelectionToFilteredAssets()
        isLoadingAssets = false
        loadFileSizesForCurrentScope()
    }

    private func matches(asset: PHAsset, filter: AdvancedCleanupFilter) -> Bool {
        switch filter {
        case .all, .recommended, .burst:
            return true
        case .videos:
            return asset.mediaType == .video
        case .photos:
            return asset.mediaType == .image
        case .large:
            if asset.mediaType == .video {
                guard let estimate = videoSizeEstimatesByAssetID[asset.localIdentifier] else { return true }
                guard estimate.isReliable else { return true }
                return estimate.sizeMB >= 80
            }
            return (reliablePhotoSizeMB(for: asset) ?? dataManager.estimatedSizeMB(for: asset)) >= 18
        case .long:
            return asset.mediaType == .video && asset.duration >= 60
        case .month:
            guard let creationDate = asset.creationDate else { return false }
            return Calendar.current.isDate(creationDate, equalTo: Date(), toGranularity: .month)
        }
    }

    private func sizeForFiltering(_ asset: PHAsset) -> Double {
        if asset.mediaType == .video {
            return reliableVideoSizeMB(for: asset) ?? dataManager.estimatedSizeMB(for: asset)
        }
        return reliablePhotoSizeMB(for: asset) ?? dataManager.estimatedSizeMB(for: asset)
    }

    private func displaySizeMB(for asset: PHAsset) -> Double {
        if asset.mediaType == .video {
            return reliableVideoSizeMB(for: asset) ?? dataManager.estimatedSizeMB(for: asset)
        }
        return reliablePhotoSizeMB(for: asset) ?? dataManager.estimatedSizeMB(for: asset)
    }

    private func displaySizeText(for asset: PHAsset) -> String? {
        let estimate: AssetFileSizeEstimate?
        if asset.mediaType == .video {
            estimate = videoSizeEstimatesByAssetID[asset.localIdentifier]
        } else if shouldLoadPhotoFileSizes {
            estimate = photoSizeEstimatesByAssetID[asset.localIdentifier]
        } else {
            return nil
        }
        guard let estimate else {
            return L10n.string("Calculating")
        }
        switch estimate.source {
        case .assetResource:
            return CleanupStatsFormatter.fileSize(estimate.sizeMB)
        case .iCloud:
            return L10n.string("Needs download")
        case .unavailable:
            return L10n.string("Pending")
        }
    }

    private func sizeFirstOrder(_ lhs: PHAsset, _ rhs: PHAsset) -> Bool {
        let lhsRank = sizeSortRank(for: lhs)
        let rhsRank = sizeSortRank(for: rhs)

        if lhsRank.priority != rhsRank.priority {
            return lhsRank.priority < rhsRank.priority
        }

        if lhsRank.sizeMB != rhsRank.sizeMB {
            return lhsRank.sizeMB > rhsRank.sizeMB
        }

        let lhsDate = lhs.creationDate ?? .distantPast
        let rhsDate = rhs.creationDate ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }

        return lhs.localIdentifier < rhs.localIdentifier
    }

    private func sizeSortRank(for asset: PHAsset) -> (priority: Int, sizeMB: Double) {
        if asset.mediaType == .video {
            guard let estimate = videoSizeEstimatesByAssetID[asset.localIdentifier] else {
                return (priority: 1, sizeMB: dataManager.estimatedSizeMB(for: asset))
            }
            guard estimate.isReliable else {
                return (priority: 1, sizeMB: dataManager.estimatedSizeMB(for: asset))
            }
            return (priority: 0, sizeMB: estimate.sizeMB)
        }

        if let reliableSize = reliablePhotoSizeMB(for: asset) {
            return (priority: 0, sizeMB: reliableSize)
        }
        return (priority: 1, sizeMB: dataManager.estimatedSizeMB(for: asset))
    }

    private func sizeStatusSystemImage(for asset: PHAsset) -> String? {
        guard fileSizeEstimate(for: asset)?.source == .iCloud else {
            return nil
        }
        return "icloud.and.arrow.down"
    }

    private func sizeStatusTint(for asset: PHAsset) -> Color {
        guard fileSizeEstimate(for: asset)?.source == .iCloud else {
            return Theme.positive
        }
        return Theme.accent
    }

    private func reliableVideoSizeMB(for asset: PHAsset) -> Double? {
        guard let estimate = videoSizeEstimatesByAssetID[asset.localIdentifier],
              estimate.isReliable else {
            return nil
        }
        return estimate.sizeMB
    }

    private func reliablePhotoSizeMB(for asset: PHAsset) -> Double? {
        guard let estimate = photoSizeEstimatesByAssetID[asset.localIdentifier],
              estimate.isReliable else {
            return nil
        }
        return estimate.sizeMB
    }

    private func fileSizeEstimate(for asset: PHAsset) -> AssetFileSizeEstimate? {
        if asset.mediaType == .video {
            return videoSizeEstimatesByAssetID[asset.localIdentifier]
        }
        return photoSizeEstimatesByAssetID[asset.localIdentifier]
    }

    private func pruneVideoSizeEstimates(for loadedAssets: [PHAsset]) {
        let loadedIDs = Set(loadedAssets.map(\.localIdentifier))
        videoSizeEstimatesByAssetID = videoSizeEstimatesByAssetID.filter { loadedIDs.contains($0.key) }
    }

    private func prunePhotoSizeEstimates(for loadedAssets: [PHAsset]) {
        let loadedIDs = Set(loadedAssets.map(\.localIdentifier))
        photoSizeEstimatesByAssetID = photoSizeEstimatesByAssetID.filter { loadedIDs.contains($0.key) }
    }

    private func seedCachedVideoSizeEstimates(for loadedAssets: [PHAsset]) {
        for asset in loadedAssets where asset.mediaType == .video {
            guard let cached = dataManager.cachedVideoFileSizeEstimate(for: asset) else { continue }
            videoSizeEstimatesByAssetID[asset.localIdentifier] = cached
        }
    }

    private func applyVideoSizeEstimates(
        _ estimatesByAssetID: [String: VideoFileSizeEstimate],
        generation: Int
    ) {
        guard generation == sizeLoadGeneration, !estimatesByAssetID.isEmpty else { return }
        for (assetID, estimate) in estimatesByAssetID {
            dataManager.cacheVideoFileSizeEstimate(estimate, forAssetIdentifier: assetID)
            videoSizeEstimatesByAssetID[assetID] = estimate
        }
        refreshOrderedAssets()
    }

    private func applyPhotoSizeEstimates(
        _ estimatesByAssetID: [String: AssetFileSizeEstimate],
        generation: Int
    ) {
        guard generation == sizeLoadGeneration, !estimatesByAssetID.isEmpty else { return }
        for (assetID, estimate) in estimatesByAssetID {
            dataManager.cacheAssetFileSizeEstimate(
                estimate,
                forAssetIdentifier: assetID
            )
            photoSizeEstimatesByAssetID[assetID] = estimate
        }
        refreshOrderedAssets()
    }

    private func refreshOrderedAssets() {
        guard prefersSizeFirstOrder else {
            orderedAssets = assets
            return
        }
        orderedAssets = assets.sorted(by: sizeFirstOrder)
    }

    private func loadFileSizes(for loadedAssets: [PHAsset]) {
        sizeLoadingTask?.cancel()
        sizeLoadGeneration += 1
        let generation = sizeLoadGeneration
        let videos = loadedAssets.filter { $0.mediaType == .video }
        let photos = loadedAssets.filter { $0.mediaType == .image }
        guard !videos.isEmpty || !photos.isEmpty else {
            isLoadingFileSizes = false
            return
        }

        isLoadingFileSizes = true
        sizeLoadingTask = Task {
            var pendingVideoEstimates: [String: VideoFileSizeEstimate] = [:]
            for asset in videos {
                if Task.isCancelled { break }
                let alreadyLoaded = await MainActor.run {
                    guard generation == sizeLoadGeneration else { return true }
                    if let cached = dataManager.cachedVideoFileSizeEstimate(for: asset) {
                        videoSizeEstimatesByAssetID[asset.localIdentifier] = cached
                        return true
                    }
                    return videoSizeEstimatesByAssetID[asset.localIdentifier] != nil
                }
                if alreadyLoaded { continue }

                do {
                    let estimate = try await dataManager.photoLibraryManager.videoFileSizeEstimate(for: asset)
                    pendingVideoEstimates[asset.localIdentifier] = estimate
                    if pendingVideoEstimates.count >= fileSizeUpdateBatchSize {
                        let estimatesToApply = pendingVideoEstimates
                        pendingVideoEstimates.removeAll()
                        await MainActor.run {
                            applyVideoSizeEstimates(estimatesToApply, generation: generation)
                        }
                    }
                } catch {
                    continue
                }
            }
            if !pendingVideoEstimates.isEmpty {
                let estimatesToApply = pendingVideoEstimates
                await MainActor.run {
                    applyVideoSizeEstimates(estimatesToApply, generation: generation)
                }
            }

            var pendingPhotoEstimates: [String: AssetFileSizeEstimate] = [:]
            for asset in photos {
                if Task.isCancelled { break }
                let alreadyLoaded = await MainActor.run {
                    guard generation == sizeLoadGeneration else { return true }
                    return photoSizeEstimatesByAssetID[asset.localIdentifier] != nil
                }
                if alreadyLoaded { continue }

                do {
                    let estimate = try await dataManager.photoLibraryManager.photoFileSizeEstimate(for: asset)
                    pendingPhotoEstimates[asset.localIdentifier] = estimate
                    if pendingPhotoEstimates.count >= fileSizeUpdateBatchSize {
                        let estimatesToApply = pendingPhotoEstimates
                        pendingPhotoEstimates.removeAll()
                        await MainActor.run {
                            applyPhotoSizeEstimates(estimatesToApply, generation: generation)
                        }
                    }
                } catch {
                    continue
                }
            }
            if !pendingPhotoEstimates.isEmpty {
                let estimatesToApply = pendingPhotoEstimates
                await MainActor.run {
                    applyPhotoSizeEstimates(estimatesToApply, generation: generation)
                }
            }
            await MainActor.run {
                guard generation == sizeLoadGeneration else { return }
                isLoadingFileSizes = false
            }
        }
    }

    private func showMoreAssets() {
        let snapshot = makeFilteredAssetSnapshot()
        withAnimation(.easeInOut(duration: 0.18)) {
            visibleAssetLimit = VisibleListPagination.advancedLimit(
                totalCount: snapshot.assets.count,
                currentLimit: visibleAssetLimit,
                step: assetLimitStep
            )
        }
        loadFileSizesForCurrentScope()
    }

    private func showMoreAssetsIfNeeded(currentAsset asset: PHAsset) {
        let snapshot = makeFilteredAssetSnapshot()
        guard snapshot.hasMoreAssets,
              let index = snapshot.visibleAssets.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }),
              index >= max(snapshot.visibleAssets.count - 6, 0) else {
            return
        }
        showMoreAssets()
    }

    private func loadFileSizesForCurrentScope() {
        loadFileSizes(for: fileSizeLoadTargets)
    }

    private func toggleSelection(_ asset: PHAsset) {
        HapticManager.impact(.light)
        let id = asset.localIdentifier
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
        } else {
            selectedAssetIDs.insert(id)
        }
    }

    private func toggleBulkSelection() {
        HapticManager.impact(.light)
        let snapshot = makeFilteredAssetSnapshot()
        let visibleIDs = Set(snapshot.assets.map(\.localIdentifier))
        if isAllFilteredSelected(in: snapshot) {
            selectedAssetIDs.subtract(visibleIDs)
        } else {
            selectedAssetIDs.formUnion(visibleIDs)
        }
    }

    private func addSelectedAssetsToDeleteCandidates() {
        let assets = selectedAssets
        guard !assets.isEmpty else { return }
        dataManager.addToDeleteCandidates(assets)
        HapticManager.notify(.success)
        showBatchConfirm = true
    }

    private func syncSelectionWithPendingDeleteCandidates() {
        let pendingDeleteIDs = Set(dataManager.deleteCandidates.map(\.localIdentifier))
        selectedAssetIDs = selectedAssetIDs.filter { pendingDeleteIDs.contains($0) }
    }

    private func showICloudVideoInfo() {
        showingICloudVideoInfo = true
    }

    private func pruneSelectionToFilteredAssets() {
        let visibleIDs = Set(makeFilteredAssetSnapshot().assets.map(\.localIdentifier))
        selectedAssetIDs = selectedAssetIDs.filter { visibleIDs.contains($0) }
    }

    private func isAllFilteredSelected(in snapshot: AdvancedFilteredAssetSnapshot) -> Bool {
        !snapshot.assets.isEmpty &&
            snapshot.assets.allSatisfy { selectedAssetIDs.contains($0.localIdentifier) }
    }
}

private struct AdvancedSimilarGroupSnapshot {
    let groups: [AdvancedSimilarPhotoGroup]
    let visibleGroups: [AdvancedSimilarPhotoGroup]
    let suggestedDeleteCount: Int
    let hasMoreGroups: Bool
}

private struct AdvancedSimilarPhotoGroupsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var groups: [AdvancedSimilarPhotoGroup] = []
    @State private var isLoading = true
    @State private var loadGeneration = 0
    @State private var selectedAssetIDs: Set<String> = []
    @State private var filterQuery = SimilarPhotosFilterQuery.default
    @State private var showsFilters = false
    @State private var showBatchConfirm = false
    @State private var previewAsset: AdvancedPreviewAsset?
    @State private var visibleGroupLimit = 24

    private let groupLimitStep = 24

    private var selectedAssets: [PHAsset] {
        makeGroupSnapshot().groups.flatMap(\.assets).filter { selectedAssetIDs.contains($0.localIdentifier) }
    }

    private func makeGroupSnapshot() -> AdvancedSimilarGroupSnapshot {
        let filteredGroups = groups.filter { matches(group: $0, query: filterQuery) }
        return AdvancedSimilarGroupSnapshot(
            groups: filteredGroups,
            visibleGroups: VisibleListPagination.visibleItems(filteredGroups, limit: visibleGroupLimit),
            suggestedDeleteCount: filteredGroups.reduce(0) { $0 + $1.suggestedDeleteCount },
            hasMoreGroups: VisibleListPagination.hasMore(totalCount: filteredGroups.count, limit: visibleGroupLimit)
        )
    }

    var body: some View {
        ZStack {
            PhotoDeleteScreenBackground()

            ScrollView {
                VStack(spacing: 14) {
                    similarGroupsContent

                    Spacer()
                        .frame(height: 24)
                }
                .padding(24)
                .animation(.easeOut(duration: 0.22), value: isLoading)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !selectedAssetIDs.isEmpty {
                AdvancedSelectionActionBar(
                    count: selectedAssetIDs.count,
                    action: addSelectedAssetsToDeleteCandidates
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .advancedDetailNavigation(title: L10n.string("Similar Photos"))
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarTrailing) {
                    similarFilterButton
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    similarFilterButton
                }
            }
        }
        // 自定义 toolbar 后必须再 hide，否则盖过 destination / AdvancedCleanupDestination 的 hides。
        .photoDeleteHidesMainTabBar()
        .sheet(isPresented: $showsFilters) {
            SimilarPhotosFilterSheet(query: $filterQuery)
        }
        .fullScreenCover(isPresented: $showBatchConfirm, onDismiss: {
            syncSelectionWithPendingDeleteCandidates()
            Task { await reloadGroups() }
        }) {
            BatchConfirmView()
                .environmentObject(dataManager)
        }
        .sheet(item: $previewAsset) { item in
            AdvancedAssetPreviewView(
                asset: item.asset,
                photoLibraryManager: dataManager.photoLibraryManager,
                assets: item.assets,
                selectedAssetIDs: $selectedAssetIDs
            )
        }
        .task(id: filterQuery.match) {
            await reloadGroups()
        }
        .onChange(of: filterQuery.scope) { _ in
            visibleGroupLimit = groupLimitStep
            pruneSelectionToFilteredGroups()
        }
        .onChange(of: filterQuery.time) { _ in
            visibleGroupLimit = groupLimitStep
            pruneSelectionToFilteredGroups()
        }
    }

    private var similarFilterButton: some View {
        PhotoDeleteFilterToolbarButton(isActive: !filterQuery.isDefault) {
            showsFilters = true
        }
    }

    @ViewBuilder
    private var similarGroupsContent: some View {
        if isLoading {
            AdvancedSimilarGroupsLoadingSkeleton()
                .transition(.opacity)
        } else {
            similarGroupsLoadedContent(snapshot: makeGroupSnapshot())
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func similarGroupsLoadedContent(snapshot: AdvancedSimilarGroupSnapshot) -> some View {
        AdvancedAssetListSummaryCard(
            title: String(format: L10n.string("Found %lld similar groups"), Int64(snapshot.groups.count)),
            subtitle: String(
                format: L10n.string("Could reduce %lld photos. Confirming group by group is safer."),
                Int64(snapshot.suggestedDeleteCount)
            ),
            buttonTitle: selectedAssetIDs.isEmpty ? L10n.string("Select Suggested") : L10n.string("Cancel"),
            buttonStyle: selectedAssetIDs.isEmpty ? .accent : .quiet,
            action: toggleRecommendedSelection
        )

        if groups.isEmpty {
            AdvancedEmptyState(
                icon: AdvancedCleanupKind.similarPhotos.icon,
                title: L10n.string("No Similar Photos Found Yet"),
                subtitle: L10n.string("Photos taken close together are grouped so you can review each group.")
            )
        } else if snapshot.groups.isEmpty {
            AdvancedEmptyState(
                icon: AdvancedCleanupKind.similarPhotos.icon,
                title: L10n.string("No Results for This Filter"),
                subtitle: L10n.string("Try adjusting filters, or check again later.")
            )
        } else {
            LazyVStack(spacing: 10) {
                ForEach(snapshot.visibleGroups) { group in
                    AdvancedSimilarPhotoGroupCard(
                        group: group,
                        photoLibraryManager: dataManager.photoLibraryManager,
                        selectedAssetIDs: selectedAssetIDs,
                        onSelectRecommended: { selectRecommended(in: group) },
                        onToggleAsset: toggleSelection,
                        onPreview: { previewAsset = AdvancedPreviewAsset(asset: $0, assets: group.assets) }
                    )
                    .onAppear {
                        showMoreGroupsIfNeeded(currentGroup: group)
                    }
                }
            }

            if snapshot.hasMoreGroups {
                Text(L10n.string("Scroll down to load more"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
    }

    private func toggleRecommendedSelection() {
        HapticManager.impact(.light)
        if selectedAssetIDs.isEmpty {
            selectedAssetIDs = Set(makeGroupSnapshot().visibleGroups.flatMap { $0.assets.dropFirst().map(\.localIdentifier) })
        } else {
            selectedAssetIDs.removeAll()
        }
    }

    private func selectRecommended(in group: AdvancedSimilarPhotoGroup) {
        let updatedSelection = AdvancedSimilarPhotoRecommendedSelection.toggledSelection(
            current: selectedAssetIDs,
            groupAssetIDs: group.assets.map(\.localIdentifier)
        )
        guard updatedSelection != selectedAssetIDs else { return }
        HapticManager.impact(.light)
        selectedAssetIDs = updatedSelection
    }

    private func toggleSelection(_ asset: PHAsset) {
        HapticManager.impact(.light)
        let id = asset.localIdentifier
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
        } else {
            selectedAssetIDs.insert(id)
        }
    }

    private func addSelectedAssetsToDeleteCandidates() {
        let assets = selectedAssets
        guard !assets.isEmpty else { return }
        dataManager.addToDeleteCandidates(assets)
        HapticManager.notify(.success)
        showBatchConfirm = true
    }

    private func syncSelectionWithPendingDeleteCandidates() {
        let pendingDeleteIDs = Set(dataManager.deleteCandidates.map(\.localIdentifier))
        selectedAssetIDs = selectedAssetIDs.filter { pendingDeleteIDs.contains($0) }
    }

    private func reloadGroups() async {
        isLoading = true
        loadGeneration += 1
        let generation = loadGeneration
        let matchProfile = filterQuery.match.matchProfile
        let dataManager = self.dataManager
        let loadedGroups = await withCheckedContinuation { (continuation: CheckedContinuation<[AdvancedSimilarPhotoGroup], Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(
                    returning: dataManager.makeSimilarPhotoGroups(matchProfile: matchProfile)
                )
            }
        }
        guard generation == loadGeneration else { return }
        groups = loadedGroups
        isLoading = false
        visibleGroupLimit = groupLimitStep
        pruneSelectionToFilteredGroups()
    }

    private func showMoreGroups() {
        let snapshot = makeGroupSnapshot()
        withAnimation(.easeInOut(duration: 0.18)) {
            visibleGroupLimit = VisibleListPagination.advancedLimit(
                totalCount: snapshot.groups.count,
                currentLimit: visibleGroupLimit,
                step: groupLimitStep
            )
        }
    }

    private func showMoreGroupsIfNeeded(currentGroup group: AdvancedSimilarPhotoGroup) {
        let snapshot = makeGroupSnapshot()
        guard snapshot.hasMoreGroups,
              let index = snapshot.visibleGroups.firstIndex(where: { $0.id == group.id }),
              index >= max(snapshot.visibleGroups.count - 4, 0) else {
            return
        }
        showMoreGroups()
    }

    private func matches(group: AdvancedSimilarPhotoGroup, query: SimilarPhotosFilterQuery) -> Bool {
        if query.scope == .burst, !isLikelyBurst(group) {
            return false
        }

        guard let lookback = query.time.lookbackInterval else { return true }
        guard let newestDate = group.assets.compactMap(\.creationDate).max() else { return false }
        return newestDate >= Date().addingTimeInterval(-lookback)
    }

    private func isLikelyBurst(_ group: AdvancedSimilarPhotoGroup) -> Bool {
        guard group.assets.count >= 2 else { return false }
        let burstIDs = Set(group.assets.compactMap(\.burstIdentifier).filter { !$0.isEmpty })
        if burstIDs.count == 1, burstIDs.first != nil {
            return true
        }

        guard group.assets.count >= 3 else { return false }
        let dates = group.assets.compactMap(\.creationDate).sorted()
        guard let first = dates.first, let last = dates.last else { return false }
        return last.timeIntervalSince(first) <= 20
    }

    private func pruneSelectionToFilteredGroups() {
        let visibleIDs = Set(makeGroupSnapshot().groups.flatMap { $0.assets.map(\.localIdentifier) })
        selectedAssetIDs = selectedAssetIDs.filter { visibleIDs.contains($0) }
    }
}

enum AdvancedSimilarPhotoRecommendedSelection {
    static func toggledSelection(current selectedAssetIDs: Set<String>, groupAssetIDs: [String]) -> Set<String> {
        let recommendedAssetIDs = Set(groupAssetIDs.dropFirst())
        guard !recommendedAssetIDs.isEmpty else { return selectedAssetIDs }

        var updatedSelection = selectedAssetIDs
        if recommendedAssetIDs.isSubset(of: selectedAssetIDs) {
            updatedSelection.subtract(recommendedAssetIDs)
        } else {
            updatedSelection.formUnion(recommendedAssetIDs)
        }
        return updatedSelection
    }
}

private struct AdvancedSimilarPhotoGroupCard: View {
    let group: AdvancedSimilarPhotoGroup
    let photoLibraryManager: PhotoLibraryManager
    let selectedAssetIDs: Set<String>
    let onSelectRecommended: () -> Void
    let onToggleAsset: (PHAsset) -> Void
    let onPreview: (PHAsset) -> Void

    @State private var visibleAssetLimit = 24

    private let assetLimitStep = 24
    /// Slightly larger than the previous 66pt step so side-by-side comparison reads clearly without chrome.
    private static let thumbnailSize: CGFloat = 74

    private var visibleAssets: [PHAsset] {
        VisibleListPagination.visibleItems(group.assets, limit: visibleAssetLimit)
    }

    private var hasMoreAssets: Bool {
        VisibleListPagination.hasMore(totalCount: group.assets.count, limit: visibleAssetLimit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.primaryText)

                    Text(String(format: L10n.string("%lld similar candidates"), Int64(group.assets.count)))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                }

                Spacer(minLength: 8)

                AdvancedSimilarPhotoGroupActionButton(
                    title: L10n.string("Keep First"),
                    systemImage: "checkmark.circle",
                    action: onSelectRecommended
                )
                .accessibilityHint(Text(L10n.string("Select similar photos except the first one; tap again to clear the selection.")))
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(visibleAssets, id: \.localIdentifier) { asset in
                        AdvancedSelectableThumbnail(
                            asset: asset,
                            photoLibraryManager: photoLibraryManager,
                            size: Self.thumbnailSize,
                            isSelected: selectedAssetIDs.contains(asset.localIdentifier),
                            showsRecommendedBadge: asset.localIdentifier == group.assets.first?.localIdentifier,
                            onToggleSelection: { onToggleAsset(asset) },
                            onPreview: { onPreview(asset) }
                        )
                    }

                    if hasMoreAssets {
                        Button(action: showMoreAssets) {
                            Label(L10n.string("Show More"), systemImage: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.secondaryText)
                                .padding(.horizontal, 12)
                                .frame(height: Self.thumbnailSize)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                                        .fill(Theme.elevatedSurface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                                                .stroke(Theme.hairline, lineWidth: Theme.stroke)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .id(visibleAssetLimit)
                        .onAppear(perform: showMoreAssets)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(14)
        .photoDeleteCard()
    }

    private func showMoreAssets() {
        visibleAssetLimit = VisibleListPagination.advancedLimit(
            totalCount: group.assets.count,
            currentLimit: visibleAssetLimit,
            step: assetLimitStep
        )
    }
}

private struct AdvancedAssetListSummaryCard: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    var buttonStyle: AdvancedBulkSelectionButton.Style = .accent
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            AdvancedBulkSelectionButton(title: buttonTitle, style: buttonStyle, action: action)
        }
        .padding(14)
        .photoDeleteCard()
    }
}

/// Compact secondary control for similar-group chrome (not a primary CTA).
private struct AdvancedSimilarPhotoGroupActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    private static let height: CGFloat = 34

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 11)
                .frame(height: Self.height)
                .background(
                    Capsule(style: .continuous)
                        .fill(Theme.elevatedSurface)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Theme.hairline, lineWidth: Theme.stroke)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct AdvancedBulkSelectionButton: View {
    enum Style {
        case accent
        case quiet
    }

    let title: String
    var isDisabled = false
    var style: Style = .accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(style == .accent ? Theme.onAccent : Theme.secondaryText)
                .lineLimit(1)
                .padding(.horizontal, 15)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                        .fill(style == .accent ? Theme.accent : Theme.elevatedSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                                .stroke(style == .accent ? Color.clear : Theme.hairline, lineWidth: Theme.stroke)
                        )
                )
                .opacity(isDisabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private struct AdvancedAssetRow: View {
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager
    let estimatedSizeMB: Double
    var sizeText: String?
    var sizeSystemImage: String? = nil
    var sizeTint: Color = Theme.positive
    var statusText: String? = nil
    var statusSystemImage: String? = nil
    var statusTint: Color = Theme.secondaryText
    let isSelected: Bool
    let onToggleSelection: () -> Void
    let onPreview: () -> Void

    private var title: String {
        AdvancedAssetFormatter.title(for: asset, photoLibraryManager: photoLibraryManager)
    }

    private var metadata: String {
        AdvancedAssetFormatter.metadata(for: asset, photoLibraryManager: photoLibraryManager)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPreview) {
                AdvancedAssetThumbnail(
                    asset: asset,
                    photoLibraryManager: photoLibraryManager,
                    size: 62
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(asset.mediaType == .video ? L10n.string("Video Preview") : L10n.string("Photo Preview"))

            Button(action: onToggleSelection) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.primaryText)
                            .lineLimit(1)

                        if let statusText {
                            HStack(spacing: 6) {
                                AdvancedAssetStatusBadge(
                                    text: statusText,
                                    systemImage: statusSystemImage,
                                    tint: statusTint
                                )

                                Text(metadata)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(Theme.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                            }
                        } else {
                            Text(metadata)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Theme.secondaryText)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 8) {
                        AdvancedAssetSizeBadge(
                            text: sizeText ?? CleanupStatsFormatter.space(estimatedSizeMB),
                            systemImage: sizeSystemImage,
                            tint: sizeTint
                        )

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isSelected ? Theme.accent : Theme.tertiaryText)
                            .photoDeleteMinimumTapTarget()
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? L10n.string("Deselect") : L10n.string("Select"))
            .accessibilityValue(Text("\(isSelected ? L10n.string("Selected") : L10n.string("Not Set")), \(title), \(metadata)"))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .padding(10)
        .photoDeleteCard()
    }
}

private struct AdvancedAssetStatusBadge: View {
    let text: String
    let systemImage: String?
    let tint: Color

    var body: some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }
}

private struct AdvancedAssetSizeBadge: View {
    let text: String
    let systemImage: String?
    let tint: Color

    var body: some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
}

private struct AdvancedSelectableThumbnail: View {
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager
    var size: CGFloat = 74
    let isSelected: Bool
    let showsRecommendedBadge: Bool
    let onToggleSelection: () -> Void
    let onPreview: () -> Void

    private var previewAccessibilityLabel: String {
        if asset.mediaType == .video {
            return L10n.string("Video Preview")
        }
        if photoLibraryManager.isLivePhoto(asset) {
            return L10n.string("Live Photos")
        }
        return L10n.string("Photo Preview")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onPreview) {
                AdvancedAssetThumbnail(
                    asset: asset,
                    photoLibraryManager: photoLibraryManager,
                    size: size
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(previewAccessibilityLabel)

            AdvancedSelectableThumbnailSelectionButton(
                isSelected: isSelected,
                action: onToggleSelection
            )

            if showsRecommendedBadge {
                Text(L10n.string("Keep"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.58))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(5)
                    .accessibilityLabel(L10n.string("Keep"))
            }
        }
        .frame(width: size, height: size)
    }
}

private struct AdvancedSelectableThumbnailSelectionButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .frame(width: 44, height: 44)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: AdvancedSelectableThumbnailSelectionButtonStyle.iconSize, weight: .semibold))
                    .foregroundColor(
                        isSelected
                            ? Theme.accent.opacity(AdvancedSelectableThumbnailSelectionButtonStyle.selectedIconOpacity)
                            : Color.white.opacity(AdvancedSelectableThumbnailSelectionButtonStyle.unselectedIconOpacity)
                    )
                    .frame(
                        width: AdvancedSelectableThumbnailSelectionButtonStyle.visualSize,
                        height: AdvancedSelectableThumbnailSelectionButtonStyle.visualSize
                    )
                    .background(
                        Circle()
                            .fill(Theme.background.opacity(AdvancedSelectableThumbnailSelectionButtonStyle.backgroundOpacity(isSelected: isSelected)))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(AdvancedSelectableThumbnailSelectionButtonStyle.strokeOpacity(isSelected: isSelected)), lineWidth: 1)
                    )
                    .shadow(
                        color: .black.opacity(AdvancedSelectableThumbnailSelectionButtonStyle.shadowOpacity),
                        radius: AdvancedSelectableThumbnailSelectionButtonStyle.shadowRadius,
                        x: 0,
                        y: 1
                    )
                    .padding(4)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44, alignment: .topTrailing)
        .contentShape(Rectangle())
        .accessibilityLabel(isSelected ? L10n.string("Deselect") : L10n.string("Select"))
        .accessibilityValue(Text(isSelected ? L10n.string("Selected") : L10n.string("Not Set")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

enum AdvancedSelectableThumbnailSelectionButtonStyle {
    static let iconSize: CGFloat = 20
    static let visualSize: CGFloat = 28
    static let selectedIconOpacity = 0.78
    static let unselectedIconOpacity = 0.62
    static let selectedBackgroundOpacity = 0.48
    static let unselectedBackgroundOpacity = 0.24
    static let selectedStrokeOpacity = 0.16
    static let unselectedStrokeOpacity = 0.18
    static let shadowOpacity = 0.14
    static let shadowRadius: CGFloat = 3

    static func backgroundOpacity(isSelected: Bool) -> Double {
        isSelected ? selectedBackgroundOpacity : unselectedBackgroundOpacity
    }

    static func strokeOpacity(isSelected: Bool) -> Double {
        isSelected ? selectedStrokeOpacity : unselectedStrokeOpacity
    }
}

enum AdvancedLivePhotoPreviewPolicy {
    static let networkAccessAllowed = true
    static let deliveryMode: PHImageRequestOptionsDeliveryMode = .highQualityFormat

    static func shouldRequestLivePhoto(isLivePhoto: Bool, motionEnabled: Bool) -> Bool {
        isLivePhoto && motionEnabled
    }

    static func shouldDisplayLivePhoto(isDegraded: Bool) -> Bool {
        !isDegraded
    }

    /// TabView preloads adjacent pages; only the selected page should autoplay Live motion.
    static func shouldAutoPlay(isSelected: Bool, motionEnabled: Bool) -> Bool {
        isSelected && motionEnabled
    }

    /// When a preloaded page becomes selected, bump the playback trigger so autoplay can restart.
    static func shouldRestartPlaybackOnBecomingSelected(
        isSelected: Bool,
        motionEnabled: Bool
    ) -> Bool {
        isSelected && motionEnabled
    }

    static func badgeSystemImage(mediaType: PHAssetMediaType, isLivePhoto: Bool) -> String? {
        if mediaType == .video {
            return "play.fill"
        }
        return isLivePhoto ? "livephoto" : nil
    }
}

struct AdvancedAssetThumbnail: View {
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager
    let size: CGFloat

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?
    @State private var loadingAssetID: String?

    private var badgeSystemImage: String? {
        AdvancedLivePhotoPreviewPolicy.badgeSystemImage(
            mediaType: asset.mediaType,
            isLivePhoto: photoLibraryManager.isLivePhoto(asset)
        )
    }

    private var badgeAccessibilityLabel: String {
        asset.mediaType == .video ? L10n.string("Videos") : L10n.string("Live Photos")
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Theme.elevatedSurface)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Theme.secondaryText)
                        )
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))

            if let badgeSystemImage {
                Image(systemName: badgeSystemImage)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Theme.primaryText)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Theme.background.opacity(0.72)))
                    .padding(5)
                    .accessibilityLabel(badgeAccessibilityLabel)
            }
        }
        .frame(width: size, height: size)
        .onAppear(perform: loadImage)
        .onDisappear {
            photoLibraryManager.cancelImageRequest(requestID)
            requestID = nil
            loadingAssetID = nil
            image = nil
        }
    }

    private func loadImage() {
        photoLibraryManager.cancelImageRequest(requestID)
        let requestedID = asset.localIdentifier
        loadingAssetID = requestedID
        image = nil
        requestID = photoLibraryManager.loadFastThumbnail(
            for: asset,
            size: CGSize(width: size * 3, height: size * 3)
        ) { loadedImage in
            guard loadingAssetID == requestedID else { return }
            image = loadedImage
            requestID = nil
        }
    }
}

struct AdvancedAssetPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager
    let assets: [PHAsset]
    let selectedAssetIDs: Binding<Set<String>>?

    @State private var selectedAssetID: String

    init(
        asset: PHAsset,
        photoLibraryManager: PhotoLibraryManager,
        assets: [PHAsset] = [],
        selectedAssetIDs: Binding<Set<String>>? = nil
    ) {
        self.asset = asset
        self.photoLibraryManager = photoLibraryManager
        let uniqueAssets = Self.previewAssets(selectedAsset: asset, assets: assets)
        self.assets = uniqueAssets
        self.selectedAssetIDs = selectedAssetIDs
        _selectedAssetID = State(initialValue: asset.localIdentifier)
    }

    var body: some View {
        GeometryReader { geometry in
            let cardSize = previewCardSize(in: geometry.size)

            ZStack {
                PhotoDeleteScreenBackground()

                VStack(spacing: 0) {
                    previewHeader

                    VStack(spacing: 6) {
                        previewPager(cardSize: cardSize)
                        ReviewPhotoDetailLine(asset: selectedAsset)
                            .id(selectedAsset.localIdentifier)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    previewSelectionBar
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// 页头对齐整理页：左侧圆形关闭、标题居中、页码靠右。
    private var previewHeader: some View {
        ZStack {
            Text(navigationTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 88)

            HStack {
                // 轻量关闭：只留图标，不套圆形容器，避免压过标题和页码。
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.primaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("Close"))
                .accessibilityIdentifier("advanced-preview-close")

                Spacer(minLength: 0)

                Group {
                    if let previewPositionText {
                        Text(previewPositionText)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                            .monospacedDigit()
                            .accessibilityLabel(Text("\(L10n.string("Position")) \(previewPositionText)"))
                    } else {
                        Color.clear
                    }
                }
                .frame(minWidth: 28, minHeight: 44, alignment: .trailing)
            }
        }
        .padding(.horizontal, Theme.space5)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    /// 翻页时整张卡片（照片 + 承托面 + 描边）一起滑动，页与页之间露出背景间隔，
    /// 与整理页的卡片翻页一致；不做「卡片定住、照片在框内滑」。
    @ViewBuilder
    private func previewPager(cardSize: CGSize) -> some View {
        if assets.count > 1 {
            TabView(selection: $selectedAssetID) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    previewCardPage(asset: asset, size: cardSize)
                        .tag(asset.localIdentifier)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: cardSize.height)
        } else {
            previewCardPage(asset: selectedAsset, size: cardSize)
                .frame(height: cardSize.height)
        }
    }

    private func previewCardPage(asset: PHAsset, size: CGSize) -> some View {
        ZStack {
            ReviewPhotoSurfaceBackground(cornerRadius: Theme.radiusMd)

            AdvancedAssetPreviewPage(
                asset: asset,
                photoLibraryManager: photoLibraryManager,
                viewportSize: size,
                isSelected: selectedAssetID == asset.localIdentifier
            )
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Theme.reviewPhotoStroke,
                            Theme.reviewPhotoStrokeFade
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: Theme.stroke
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private var selectedAsset: PHAsset {
        assets.first { $0.localIdentifier == selectedAssetID } ?? asset
    }

    private var navigationTitle: String {
        if selectedAsset.mediaType == .video {
            return L10n.string("Video Preview")
        }
        if photoLibraryManager.isLivePhoto(selectedAsset) {
            return L10n.string("Live Photos")
        }
        return L10n.string("Photo Preview")
    }

    private var assetIdentifiers: [String] {
        assets.map(\.localIdentifier)
    }

    private var previewPositionText: String? {
        AdvancedPreviewPaging.positionText(
            selectedIdentifier: selectedAssetID,
            identifiers: assetIdentifiers
        )
    }

    private var isSelectedForDeletion: Bool {
        selectedAssetIDs?.wrappedValue.contains(selectedAssetID) ?? false
    }

    @ViewBuilder
    private var previewSelectionBar: some View {
        if selectedAssetIDs != nil {
            Button(action: toggleSelectedPreviewAsset) {
                Text(isSelectedForDeletion ? L10n.string("Marked to delete") : L10n.string("Mark to delete"))
            }
            .buttonStyle(AdvancedAssetPreviewSelectionButtonStyle(isSelected: isSelectedForDeletion))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(isSelectedForDeletion ? L10n.string("Marked to delete") : L10n.string("Mark to delete")))
            .accessibilityIdentifier("advanced-preview-delete-selection-toggle")
            .padding(.horizontal, Theme.space5)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    /// 卡片左右留出与整理页一致的页面边距，并给页头、日期行和底部按钮留空间。
    private func previewCardSize(in container: CGSize) -> CGSize {
        let width = max(container.width - Theme.space5 * 2, 180)
        let maxSize = PhotoDeleteAdaptiveLayout.reviewPhotoCardMaxSize(
            in: container,
            horizontalSizeClass: horizontalSizeClass
        )
        let reservedHeight: CGFloat = selectedAssetIDs == nil ? 150 : 210
        let height = min(max(container.height - reservedHeight, 220), maxSize.height)
        return CGSize(width: width, height: height)
    }

    private func toggleSelectedPreviewAsset() {
        guard let selectedAssetIDs else { return }

        HapticManager.impact(.light)
        var ids = selectedAssetIDs.wrappedValue
        if ids.contains(selectedAssetID) {
            ids.remove(selectedAssetID)
        } else {
            ids.insert(selectedAssetID)
        }
        selectedAssetIDs.wrappedValue = ids
    }

    private static func previewAssets(selectedAsset: PHAsset, assets: [PHAsset]) -> [PHAsset] {
        var seenIDs: Set<String> = []
        let source = assets.isEmpty ? [selectedAsset] : assets
        var ordered = source.filter { asset in
            seenIDs.insert(asset.localIdentifier).inserted
        }
        if !seenIDs.contains(selectedAsset.localIdentifier) {
            ordered.insert(selectedAsset, at: 0)
        }
        return ordered
    }
}

enum AdvancedPreviewPagingDirection {
    case previous
    case next
}

enum AdvancedPreviewPaging {
    static func selectedIndex(selectedIdentifier: String, identifiers: [String]) -> Int {
        identifiers.firstIndex(of: selectedIdentifier) ?? 0
    }

    static func positionText(selectedIdentifier: String, identifiers: [String]) -> String? {
        guard identifiers.count > 1 else { return nil }
        let index = selectedIndex(selectedIdentifier: selectedIdentifier, identifiers: identifiers)
        return "\(index + 1) / \(identifiers.count)"
    }

    static func adjacentIdentifier(
        selectedIdentifier: String,
        identifiers: [String],
        direction: AdvancedPreviewPagingDirection
    ) -> String? {
        guard identifiers.count > 1 else { return nil }
        let index = selectedIndex(selectedIdentifier: selectedIdentifier, identifiers: identifiers)

        switch direction {
        case .previous:
            guard index > 0 else { return nil }
            return identifiers[index - 1]
        case .next:
            guard index < identifiers.count - 1 else { return nil }
            return identifiers[index + 1]
        }
    }
}

private struct AdvancedAssetPreviewSelectionButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(isSelected ? Theme.primaryText : Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .fill(isSelected ? Theme.elevatedSurface : Theme.accent)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                            .stroke(isSelected ? Theme.accentSoftStroke : Color.clear, lineWidth: Theme.stroke)
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct AdvancedAssetPreviewPage: View {
    @Environment(\.displayScale) private var displayScale
    @AppStorage(AppConstants.reviewLivePhotoAutoPlayKey) private var reviewLivePhotoAutoPlay = false
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager
    let viewportSize: CGSize
    /// TabView keeps neighboring pages alive; autoplay must only run on the selected page.
    let isSelected: Bool

    @State private var image: UIImage?
    @State private var livePhoto: PHLivePhoto?
    @State private var isLoading = true
    @State private var requestID: PHImageRequestID?
    @State private var livePhotoRequestID: PHImageRequestID?
    @State private var loadingLivePhotoAssetID: String?
    @State private var failedToLoadLivePhoto = false
    @State private var isLivePhotoMotionEnabled = false
    @State private var livePhotoPlaybackTrigger = 0
    @State private var didConfigureLivePhotoMotion = false

    var body: some View {
        ZStack {
            if asset.mediaType == .video {
                PhotoAssetVideoPlayerView(
                    asset: asset,
                    photoLibraryManager: photoLibraryManager
                )
            } else if isLivePhotoMotionEnabled, let livePhoto {
                LivePhotoPreviewRepresentable(
                    livePhoto: livePhoto,
                    contentIdentifier: asset.localIdentifier,
                    autoPlay: AdvancedLivePhotoPreviewPolicy.shouldAutoPlay(
                        isSelected: isSelected,
                        motionEnabled: isLivePhotoMotionEnabled
                    ),
                    isMuted: true,
                    playbackTrigger: livePhotoPlaybackTrigger,
                    contentMode: .scaleAspectFit
                )
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(L10n.string("Live Photos"))
            } else if let image {
                // 预览页左右滑用于切换组内照片；不再内嵌可缩放 ScrollView，
                // 否则横向手势会被内部滚动吃掉。
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(Theme.secondaryText)
                    }

                    Text(isLoading ? L10n.string("Reading Photos") : L10n.string("Unable to load this photo"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.secondaryText)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if isLivePhotoAsset {
                LivePhotoMotionControlButton(
                    isEnabled: isLivePhotoMotionEnabled,
                    isLoading: livePhotoRequestID != nil && livePhoto == nil,
                    action: toggleLivePhotoMotion
                )
                .padding(.top, 14)
                .padding(.leading, 16)
            }
        }
        .onAppear {
            configureLivePhotoMotionIfNeeded()

            if asset.mediaType != .video {
                loadImage()
            }

            if AdvancedLivePhotoPreviewPolicy.shouldRequestLivePhoto(
                isLivePhoto: isLivePhotoAsset,
                motionEnabled: isLivePhotoMotionEnabled
            ) {
                loadLivePhoto()
            }
        }
        .onChange(of: isSelected) { selected in
            handleSelectionChange(isSelected: selected)
        }
        .onDisappear {
            photoLibraryManager.cancelImageRequest(requestID)
            photoLibraryManager.cancelImageRequest(livePhotoRequestID)
            requestID = nil
            livePhotoRequestID = nil
            loadingLivePhotoAssetID = nil
            livePhoto = nil
            failedToLoadLivePhoto = false
            isLivePhotoMotionEnabled = false
            livePhotoPlaybackTrigger = 0
            didConfigureLivePhotoMotion = false
        }
    }

    private var isLivePhotoAsset: Bool {
        photoLibraryManager.isLivePhoto(asset)
    }

    private func configureLivePhotoMotionIfNeeded() {
        guard isLivePhotoAsset, !didConfigureLivePhotoMotion else { return }
        didConfigureLivePhotoMotion = true
        isLivePhotoMotionEnabled = LivePhotoPlaybackDefaultPolicy.initialMotionEnabled(
            isLivePhoto: true,
            autoPlayPreference: reviewLivePhotoAutoPlay
        )
        // Only arm autoplay for the currently selected page. Neighbor pages may appear early
        // via TabView preloading; their trigger is bumped when they become selected.
        if AdvancedLivePhotoPreviewPolicy.shouldRestartPlaybackOnBecomingSelected(
            isSelected: isSelected,
            motionEnabled: isLivePhotoMotionEnabled
        ) {
            livePhotoPlaybackTrigger = 1
        } else {
            livePhotoPlaybackTrigger = 0
        }
    }

    private func handleSelectionChange(isSelected selected: Bool) {
        guard isLivePhotoAsset else { return }
        configureLivePhotoMotionIfNeeded()

        guard AdvancedLivePhotoPreviewPolicy.shouldRestartPlaybackOnBecomingSelected(
            isSelected: selected,
            motionEnabled: isLivePhotoMotionEnabled
        ) else {
            return
        }

        livePhotoPlaybackTrigger += 1
        failedToLoadLivePhoto = false
        loadLivePhoto()
    }

    private func loadImage() {
        guard requestID == nil, image == nil else { return }
        let targetSize = photoPreviewTargetSize(for: asset, viewport: viewportSize, displayScale: displayScale)
        requestID = photoLibraryManager.loadHighQualityPreview(
            for: asset,
            size: targetSize,
            networkAccessAllowed: true
        ) { loadedImage in
            image = loadedImage
            isLoading = false
            requestID = nil
        }
    }

    private func loadLivePhoto() {
        guard AdvancedLivePhotoPreviewPolicy.shouldRequestLivePhoto(
            isLivePhoto: isLivePhotoAsset,
            motionEnabled: isLivePhotoMotionEnabled
        ), livePhotoRequestID == nil, livePhoto == nil, !failedToLoadLivePhoto else {
            return
        }

        let requestedAssetID = asset.localIdentifier
        loadingLivePhotoAssetID = requestedAssetID
        let targetSize = photoPreviewTargetSize(for: asset, viewport: viewportSize, displayScale: displayScale)

        livePhotoRequestID = photoLibraryManager.loadLivePhotoResult(
            for: asset,
            size: targetSize,
            networkAccessAllowed: AdvancedLivePhotoPreviewPolicy.networkAccessAllowed,
            deliveryMode: AdvancedLivePhotoPreviewPolicy.deliveryMode
        ) { result in
            guard loadingLivePhotoAssetID == requestedAssetID else { return }

            if let loadedLivePhoto = result.livePhoto,
               AdvancedLivePhotoPreviewPolicy.shouldDisplayLivePhoto(isDegraded: result.isDegraded) {
                livePhoto = loadedLivePhoto
                isLoading = false
            } else if result.isFinal {
                failedToLoadLivePhoto = true
            }

            if result.isFinal {
                livePhotoRequestID = nil
                loadingLivePhotoAssetID = nil
            }
        }
    }

    private func toggleLivePhotoMotion() {
        guard isLivePhotoAsset else { return }
        HapticManager.impact(.light)
        isLivePhotoMotionEnabled = LivePhotoPlaybackDefaultPolicy.motionEnabledAfterManualAction(
            current: isLivePhotoMotionEnabled,
            previousLoadFailed: failedToLoadLivePhoto
        )

        guard isLivePhotoMotionEnabled else {
            photoLibraryManager.cancelImageRequest(livePhotoRequestID)
            livePhotoRequestID = nil
            loadingLivePhotoAssetID = nil
            return
        }
        livePhotoPlaybackTrigger += 1
        failedToLoadLivePhoto = false
        loadLivePhoto()
    }
}

private struct AdvancedSelectionActionBar: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                String(format: L10n.string("Add %lld items to delete"), Int64(count)),
                systemImage: "trash"
            )
            .frame(maxWidth: .infinity)
        }
        .photoDeletePrimaryButton()
        .padding(.horizontal, Theme.space5)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background {
            Theme.background
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

private enum AdvancedCleanupFilter: String, Hashable, Identifiable {
    case all
    case recommended
    case burst
    case videos
    case photos
    case large
    case long
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return L10n.string("All")
        case .recommended:
            return L10n.string("Recommended")
        case .burst:
            return L10n.string("Bursts")
        case .videos:
            return L10n.string("Videos")
        case .photos:
            return L10n.string("Images")
        case .large:
            return L10n.string("Large Files")
        case .long:
            return L10n.string("Longer")
        case .month:
            return L10n.string("This Month")
        }
    }

    static func options(for kind: AdvancedCleanupKind) -> [AdvancedCleanupFilter] {
        switch kind {
        case .similarPhotos:
            return [.all, .burst]
        case .largeFiles:
            return [.all]
        case .imageCompression:
            return [.all, .large]
        case .videoCompression:
            return [.all, .large, .long]
        case .videos:
            return [.all, .large, .long]
        case .screenRecordings:
            return [.all, .large, .long]
        }
    }
}

private struct AdvancedFilterPills: View {
    let kind: AdvancedCleanupKind
    @Binding var selection: AdvancedCleanupFilter

    var body: some View {
        let options = filters.map {
            FilterSegmentOption(value: $0, title: $0.title)
        }

        // 与筛选弹窗同一套玻璃分段 / 选择格，避免胶囊 pill 另立一套。
        if options.count <= 4 {
            FilterGlassSegmentedControl(options: options, selection: $selection)
        } else {
            FilterGlassChoiceGrid(options: options, selection: $selection)
        }
    }

    private var filters: [AdvancedCleanupFilter] {
        AdvancedCleanupFilter.options(for: kind)
    }
}

struct AdvancedCleanupDestination: View {
    @EnvironmentObject private var dataManager: DataManager
    let kind: AdvancedCleanupKind

    var body: some View {
        Group {
            switch kind {
            case .similarPhotos:
                AdvancedSimilarPhotoGroupsView()
                    .environmentObject(dataManager)
            case .imageCompression:
                if AppConstants.isImageCompressionVisible {
                    AdvancedImageCompressionView()
                        .environmentObject(dataManager)
                } else {
                    EmptyView()
                }
            case .videoCompression:
                AdvancedVideoCompressionView()
                    .environmentObject(dataManager)
            case .largeFiles, .videos:
                AdvancedAssetListView(mode: .cleanup(kind))
                    .environmentObject(dataManager)
            case .screenRecordings:
                CleanupAssetBrowserView(category: .screenRecordings)
                    .environmentObject(dataManager)
            }
        }
        .photoDeleteHidesMainTabBar()
    }
}

private extension View {
    func advancedDetailNavigation(title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            // 若后续再挂 `.toolbar { }`，必须在其后再次 `.photoDeleteHidesMainTabBar()`。
            .photoDeleteHidesMainTabBar()
    }
}

private struct AdvancedProgressRing<Content: View>: View {

    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        // 中性进度环：琥珀不用于「已完成」状态（style.md §2.3）。
        ZStack {
            Circle()
                .stroke(
                    Theme.primaryText.opacity(0.12),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    Theme.primaryText.opacity(0.55),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            content
        }
        .frame(width: size, height: size)
    }
}

private struct AdvancedDemoTag: View {
    var body: some View {
        Text(L10n.string("Demo"))
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Theme.warning)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.warning.opacity(0.14))
            )
    }
}

struct AdvancedEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Theme.space4) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .medium))
                .foregroundColor(Theme.secondaryText)

            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Theme.space6)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.space8)
        .photoDeleteCard()
    }
}

struct AdvancedLoadingState: View {
    let title: String

    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.system(size: 16.5, weight: .semibold))
                .foregroundColor(Theme.primaryText)
                .multilineTextAlignment(.center)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                .scaleEffect(1.1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .photoDeleteCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

/// 相似照片结果加载中的骨架：进入页面立即铺出摘要卡和分组卡的占位形状，不先显示转圈。
struct AdvancedSimilarGroupsLoadingSkeleton: View {
    var body: some View {
        VStack(spacing: 14) {
            AdvancedSimilarSummarySkeletonCard()

            ForEach(0..<4, id: \.self) { index in
                AdvancedSimilarGroupSkeletonCard(
                    titleWidth: index.isMultiple(of: 2) ? 132 : 104,
                    subtitleWidth: index.isMultiple(of: 2) ? 92 : 76
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.string("Analyzing"))
    }
}

private struct AdvancedSimilarSummarySkeletonCard: View {
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                skeletonBar(width: 148, height: 16)
                skeletonBar(width: 196, height: 11)
            }

            Spacer(minLength: 8)

            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: 88, height: 34)
        }
        .padding(14)
        .photoDeleteCard()
        .accessibilityHidden(true)
    }

    private func skeletonBar(width: CGFloat, height: CGFloat) -> some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.07))
            .frame(width: width, height: height)
    }
}

private struct AdvancedSimilarGroupSkeletonCard: View {
    let titleWidth: CGFloat
    let subtitleWidth: CGFloat

    private static let thumbnailSize: CGFloat = 74

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    skeletonBar(width: titleWidth, height: 15)
                    skeletonBar(width: subtitleWidth, height: 10)
                }

                Spacer(minLength: 8)

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 92, height: 34)
            }

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                        .fill(Color.white.opacity(0.055))
                        .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: Theme.stroke)
                        )
                }
            }
        }
        .padding(14)
        .photoDeleteCard()
        .accessibilityHidden(true)
    }

    private func skeletonBar(width: CGFloat, height: CGFloat) -> some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.07))
            .frame(width: width, height: height)
    }
}

private enum AdvancedAssetListMode {
    case cleanup(AdvancedCleanupKind)

    var id: String {
        switch self {
        case .cleanup(let kind):
            return "cleanup-\(kind.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .cleanup(let kind):
            return kind.title
        }
    }

    var icon: String {
        switch self {
        case .cleanup(let kind):
            return kind.icon
        }
    }
}

struct AdvancedPreviewAsset: Identifiable {
    let asset: PHAsset
    let assets: [PHAsset]

    init(asset: PHAsset, assets: [PHAsset] = []) {
        self.asset = asset
        self.assets = assets
    }

    var id: String {
        ([asset.localIdentifier] + assets.map(\.localIdentifier)).joined(separator: "|")
    }
}

enum AdvancedAssetFormatter {
    static func title(for asset: PHAsset, photoLibraryManager: PhotoLibraryManager) -> String {
        if asset.mediaType == .video {
            return L10n.string("Videos")
        }
        if photoLibraryManager.isScreenshot(asset) {
            return L10n.string("Screenshots")
        }
        return L10n.string("Photos")
    }

    static func metadata(for asset: PHAsset, photoLibraryManager: PhotoLibraryManager) -> String {
        var parts: [String] = []

        if asset.mediaType == .video {
            parts.append(String(format: L10n.string("Video %@"), formattedDuration(asset.duration)))
        } else if photoLibraryManager.isScreenshot(asset) {
            parts.append(L10n.string("Screenshots"))
        } else {
            parts.append(L10n.string("Images"))
        }

        if asset.pixelWidth > 0 && asset.pixelHeight > 0 {
            parts.append("\(asset.pixelWidth)×\(asset.pixelHeight)")
        }

        if let creationDate = asset.creationDate {
            parts.append(AppDateFormatter.string(from: creationDate, template: "yMd"))
        }

        return parts.joined(separator: " · ")
    }

    private static func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private enum AdvancedPeriodFormatter {
    static func title(for summary: PhotoPeriodSummary) -> String {
        switch summary.scope {
        case .day:
            return AppDateFormatter.string(from: summary.intervalStart, template: "yMMMd")
        case .week:
            return weekTitle(for: summary.intervalStart)
        case .month:
            return AppDateFormatter.string(from: summary.intervalStart, template: "yMMM")
        case .year:
            return AppDateFormatter.string(from: summary.intervalStart, template: "y")
        }
    }

    static func compactTitle(for summary: PhotoPeriodSummary) -> String {
        switch summary.scope {
        case .day:
            return AppDateFormatter.string(from: summary.intervalStart, template: "MMMd")
        case .week:
            return weekCompact(for: summary.intervalStart)
        case .month:
            return AppDateFormatter.string(from: summary.intervalStart, template: "MMM")
        case .year:
            return AppDateFormatter.string(from: summary.intervalStart, template: "y")
        }
    }

    static func chipTitle(for summary: PhotoPeriodSummary) -> String {
        switch summary.scope {
        case .day:
            return AppDateFormatter.string(from: summary.intervalStart, template: "Md")
        case .week:
            return weekChip(for: summary.intervalStart)
        case .month:
            return AppDateFormatter.string(from: summary.intervalStart, template: "MMM")
        case .year:
            return AppDateFormatter.string(from: summary.intervalStart, template: "y")
        }
    }

    static func subtitle(for summary: PhotoPeriodSummary) -> String {
        switch summary.scope {
        case .day:
            return L10n.string("This Day")
        case .week:
            let start = AppDateFormatter.string(from: summary.intervalStart, template: "Md")
            let endDate = Calendar.current.date(byAdding: .day, value: -1, to: summary.intervalEnd) ?? summary.intervalEnd
            let end = AppDateFormatter.string(from: endDate, template: "Md")
            return "\(start) - \(end)"
        case .month:
            return L10n.string("Monthly photo cleanup progress")
        case .year:
            return L10n.string("Yearly photo cleanup progress")
        }
    }

    private static func weekTitle(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(
            format: L10n.string("Week %lld of %lld"),
            Int64(components.weekOfYear ?? 0),
            Int64(components.yearForWeekOfYear ?? 0)
        )
    }

    private static func weekCompact(for date: Date) -> String {
        let week = Calendar.current.component(.weekOfYear, from: date)
        return String(format: L10n.string("Week No. %lld"), Int64(week))
    }

    private static func weekChip(for date: Date) -> String {
        let week = Calendar.current.component(.weekOfYear, from: date)
        return String(format: L10n.string("Week %lld"), Int64(week))
    }
}

#Preview {
    AdvancedView()
        .environmentObject(DataManager())
}
