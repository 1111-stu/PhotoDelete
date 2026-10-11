//
//  TimeOrganizeView.swift
//  PhotoDelete
//
//  Created by PhotoDelete Team on 6/21/26.
//

import SwiftUI

struct TimeOrganizeView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedScope: AdvancedTimeScope = .year
    @State private var visiblePeriodLimit = 24

    // 年 / 月 / 日三档维度：从首页「更多」进来后可选择具体某年、某月、某天进入整理。
    private let visibleScopes: [AdvancedTimeScope] = [.year, .month, .day]
    private let periodLimitStep = 24

    var body: some View {
        ZStack {
            PhotoDeleteScreenBackground()

            ScrollView {
                LazyVStack(spacing: 16) {
                    if visibleScopes.count > 1 {
                        Picker(L10n.string("Time Range"), selection: $selectedScope) {
                            ForEach(visibleScopes) { scope in
                                Text(scope.title)
                                    .tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if shouldShowPreparingState {
                        OrganizeLoadingCard(
                            title: L10n.string("Organizing timeline"),
                            message: L10n.string("Dates, months, and years appear after loading."),
                            progress: dataManager.photoLibraryManager.loadingProgress
                        )
                    } else if visibleSummaries.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(visibleSummaries.enumerated()), id: \.element.id) { index, summary in
                                NavigationLink(value: SwipeViewDestination.period(summary.scope, summary.intervalStart)) {
                                    TimePeriodRow(summary: summary)
                                }
                                .buttonStyle(.plain)

                                if index != visibleSummaries.count - 1 {
                                    Divider()
                                        .background(Theme.hairline)
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .photoDeleteCard()

                        if hasMorePeriods {
                            Button(action: showMorePeriods) {
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
                .padding(.horizontal, Theme.space5)
                .padding(.top, Theme.space2)
                .padding(.bottom, Theme.space24)
                .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(L10n.string("Time"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            refreshSummaries()
        }
        .onChange(of: selectedScope) { _ in
            visiblePeriodLimit = periodLimitStep
            refreshSummaries()
        }
        .onChange(of: dataManager.cleanupStatsRevision) { _ in
            refreshSummaries(resetCachedScopes: true)
        }
        .onReceive(dataManager.photoLibraryManager.$allPhotos) { _ in
            refreshSummaries(resetCachedScopes: true)
        }
    }

    private var allVisibleSummaries: [PhotoPeriodSummary] {
        VisibleListPagination.filteredItems(
            dataManager.periodSummariesByScope[selectedScope] ?? [],
            include: { $0.assetCount > 0 }
        )
    }

    private var visibleSummaries: [PhotoPeriodSummary] {
        VisibleListPagination.visibleItems(allVisibleSummaries, limit: visiblePeriodLimit)
    }

    private var hasMorePeriods: Bool {
        VisibleListPagination.hasMore(totalCount: allVisibleSummaries.count, limit: visiblePeriodLimit)
    }

    private var shouldShowPreparingState: Bool {
        dataManager.isPreparingLibrary ||
            dataManager.photoLibraryManager.isLoading ||
            (
                dataManager.photoLibraryManager.hasPhotoLibraryAccess &&
                !dataManager.photoLibraryManager.hasLoadedPhotoLibrary &&
                dataManager.periodSummariesByScope.isEmpty
            ) ||
            (dataManager.isLoadingPeriodSummaries && visibleSummaries.isEmpty)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 44, weight: .medium))
                .foregroundColor(Theme.secondaryText)

            Text(L10n.string("No photos to organize by time yet"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Theme.primaryText)

            Text(L10n.string("No photos with capture dates are available in the current access range."))
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .photoDeleteCard()
    }

    private func refreshSummaries(resetCachedScopes: Bool = false) {
        guard dataManager.photoLibraryManager.hasPhotoLibraryAccess else {
            return
        }

        dataManager.refreshPhotoPeriodSummaries(
            for: [selectedScope],
            resetCachedScopes: resetCachedScopes
        )
    }

    private func showMorePeriods() {
        withAnimation(.easeInOut(duration: 0.18)) {
            visiblePeriodLimit = VisibleListPagination.advancedLimit(
                totalCount: allVisibleSummaries.count,
                currentLimit: visiblePeriodLimit,
                step: periodLimitStep
            )
        }
    }
}

private struct TimePeriodRow: View {
    let summary: PhotoPeriodSummary

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(TimeOrganizeFormatter.title(for: summary))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)

                Text(TimeOrganizeFormatter.subtitle(for: summary))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            Text(L10n.shortPhotoCount(summary.assetCount))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.secondaryText)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct OrganizeLoadingCard: View {
    let title: String
    let message: String
    let progress: Double

    var body: some View {
        VStack(spacing: 16) {
            if progress > 0.01 {
                ProgressView(value: min(max(progress, 0), 1))
                    .progressViewStyle(LinearProgressViewStyle(tint: Theme.accent))
                    .frame(maxWidth: 230)
                    .clipShape(Capsule(style: .continuous))
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                    .scaleEffect(1.05)
            }

            VStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.primaryText)

                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .photoDeleteCard()
    }
}

// TimeOrganizeFormatter 已抽到 Services/TimePeriodBrowser.swift（时间浏览页与周期弹窗共用）。

#Preview {
    NavigationStack {
        TimeOrganizeView()
            .environmentObject(DataManager())
    }
}
