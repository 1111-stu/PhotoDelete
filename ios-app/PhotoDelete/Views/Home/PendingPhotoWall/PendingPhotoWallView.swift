//
//  PendingPhotoWallView.swift
//  PhotoDelete
//
//  首页「待整理」入口：按年浏览未整理日封面，点天/月进当月滑动整理。
//

import SwiftUI

struct PendingPhotoWallView: View {
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var router: MainTabRouter
    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var snapshot = PendingPhotoWallSnapshot(
        years: [],
        months: [],
        selectedYear: Calendar.current.component(.year, from: Date()),
        totalPendingInLibrary: 0
    )
    /// 按月显示方式：默认日历；只有用户点过的月才会进相纸墙，互不影响。
    @State private var displayModeByMonthID: [String: PendingPhotoWallDisplayMode] = [:]
    @State private var isYearMenuExpanded = false
    @State private var showingRecentOrganized = false
    @State private var rebuildGeneration = 0

    private var yearPillLabel: String {
        AppDateFormatter.string(
            from: Calendar.current.date(from: DateComponents(year: snapshot.selectedYear, month: 1, day: 1)) ?? Date(),
            template: "y"
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let topInset = geometry.safeAreaInsets.top
            // 顶栏控件行高 + 少量间距；不再用高大渐变挡首月。
            let chromeContentTop = topInset + 8
            let listTopPadding = chromeContentTop + Theme.sizeChrome + 16

            ZStack(alignment: .top) {
                Theme.background.ignoresSafeArea()

                // Dynamic Island / 状态栏：纯黑垫底，避免漏光。
                Color.black
                    .frame(height: topInset)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if shouldShowPreparing {
                            OrganizeLoadingCard(
                                title: L10n.string("Organizing timeline"),
                                message: L10n.string("Dates, months, and years appear after loading."),
                                progress: dataManager.photoLibraryManager.loadingProgress
                            )
                            .padding(.top, 8)
                        } else if snapshot.isLibraryEmpty {
                            PendingPhotoWallEmptyState(
                                isWholeLibrary: true,
                                onViewHistory: { showingRecentOrganized = true }
                            )
                        } else if snapshot.isSelectedYearEmpty {
                            PendingPhotoWallEmptyState(
                                isWholeLibrary: false,
                                onViewHistory: { showingRecentOrganized = true }
                            )
                        } else {
                            ForEach(snapshot.months) { month in
                                let mode = displayMode(for: month)
                                PendingPhotoWallMonthSection(
                                    title: monthTitle(for: month),
                                    remainingCount: month.remainingCount,
                                    displayMode: mode,
                                    onSelectMode: { next in
                                        displayModeByMonthID[month.id] = next
                                    },
                                    onOrganizeMonth: {
                                        router.push(SwipeViewDestination.wallMonth(month.monthStart, startFromDay: nil))
                                    }
                                ) {
                                    monthContent(month, mode: mode)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, listTopPadding)
                    .padding(.bottom, 96)
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        guard isYearMenuExpanded else { return }
                        withAnimation(.easeOut(duration: 0.16)) {
                            isYearMenuExpanded = false
                        }
                    }
                )

                PendingPhotoWallChrome(
                    yearLabel: yearPillLabel,
                    years: yearMenuOptions,
                    selectedYear: snapshot.selectedYear,
                    binCount: dataManager.deleteCandidates.count,
                    isYearMenuExpanded: $isYearMenuExpanded,
                    onBack: { dismiss() },
                    onSelectYear: { year in
                        selectedYear = year
                        rebuildSnapshot(preferredYear: year)
                    },
                    onOpenBin: { router.push(.trashBin) }
                )
                .padding(.top, chromeContentTop)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingRecentOrganized) {
            RecentOrganizedPhotosView(dataManager: dataManager)
        }
        .onAppear {
            rebuildSnapshot(preferredYear: selectedYear)
        }
        .onChange(of: dataManager.cleanupStatsRevision) {
            rebuildSnapshot(preferredYear: selectedYear)
        }
        .onChange(of: dataManager.deleteCandidates.count) {
            rebuildSnapshot(preferredYear: selectedYear)
        }
        .onReceive(dataManager.photoLibraryManager.$allPhotos) { _ in
            rebuildSnapshot(preferredYear: selectedYear)
        }
        .onReceive(dataManager.$reviewedAssetIDs) { _ in
            rebuildSnapshot(preferredYear: selectedYear)
        }
    }

    private func displayMode(for month: PendingPhotoWallMonth) -> PendingPhotoWallDisplayMode {
        displayModeByMonthID[month.id] ?? .calendar
    }

    @ViewBuilder
    private func monthContent(
        _ month: PendingPhotoWallMonth,
        mode: PendingPhotoWallDisplayMode
    ) -> some View {
        switch mode {
        case .calendar:
            PendingPhotoWallCalendarGrid(
                month: month,
                today: Date(),
                photoLibraryManager: dataManager.photoLibraryManager,
                onSelectDay: { cell in
                    router.push(SwipeViewDestination.wallMonth(cell.date, startFromDay: cell.date))
                }
            )
        case .polaroid:
            PendingPhotoWallPolaroidBoard(
                month: month,
                photoLibraryManager: dataManager.photoLibraryManager,
                onSelectDay: { cell in
                    router.push(SwipeViewDestination.wallMonth(cell.date, startFromDay: cell.date))
                }
            )
        }
    }

    private var shouldShowPreparing: Bool {
        let manager = dataManager.photoLibraryManager
        return dataManager.isPreparingLibrary
            || manager.isLoading
            || (manager.hasPhotoLibraryAccess && !manager.hasLoadedPhotoLibrary)
    }

    private var yearMenuOptions: [PendingPhotoWallYearOption] {
        if snapshot.years.isEmpty {
            return [PendingPhotoWallYearOption(year: selectedYear, remainingCount: 0)]
        }
        return snapshot.years
    }

    private func monthTitle(for month: PendingPhotoWallMonth) -> String {
        AppDateFormatter.string(from: month.monthStart, template: "MMM")
    }

    /// 全库扫描放到后台；主线程只接结果，避免切年/回墙时卡顿。
    private func rebuildSnapshot(preferredYear: Int) {
        rebuildGeneration += 1
        let generation = rebuildGeneration
        let photos = dataManager.photoLibraryManager.allPhotos
        let reviewed = dataManager.reviewedAssetIDs
        let deleteIDs = Set(dataManager.deleteCandidates.map(\.localIdentifier))
        let favoriteIDs = Set(dataManager.favoriteCandidates.map(\.localIdentifier))

        Task.detached(priority: .userInitiated) {
            let built = PendingPhotoWallBuilder.build(
                photos: photos,
                reviewedIDs: reviewed,
                deleteCandidateIDs: deleteIDs,
                favoriteCandidateIDs: favoriteIDs,
                selectedYear: preferredYear
            )
            await MainActor.run {
                guard generation == rebuildGeneration else { return }
                snapshot = built
                selectedYear = built.selectedYear
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PendingPhotoWallView()
            .environmentObject(DataManager())
            .environmentObject(MainTabRouter())
    }
}
#endif
