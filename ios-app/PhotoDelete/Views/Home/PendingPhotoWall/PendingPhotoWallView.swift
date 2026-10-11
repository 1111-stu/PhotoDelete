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
        ZStack(alignment: .top) {
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
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8).onChanged { _ in
                    dismissYearMenuIfNeeded()
                }
            )

            if isYearMenuExpanded {
                // 点空白收起年份菜单（不挡顶栏工具条）。
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture(perform: dismissYearMenuIfNeeded)

                PendingPhotoWallYearMenu(
                    years: yearMenuOptions,
                    selectedYear: snapshot.selectedYear,
                    onSelect: { year in
                        selectedYear = year
                        rebuildSnapshot(preferredYear: year)
                        dismissYearMenuIfNeeded()
                    }
                )
                .padding(.horizontal, 72)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .toolbar { wallToolbar }
        // 与相册详情页一致：系统导航栏液态玻璃；强制 dark，避免 ultraThinMaterial 在近黑画布上发灰。
        .toolbarColorScheme(.dark, for: .navigationBar)
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

    @ToolbarContentBuilder
    private var wallToolbar: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) {
                wallBackButton
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .principal) {
                yearPillButton
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .topBarTrailing) {
                wallBinButton
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigationBarLeading) {
                wallBackButton
            }
            ToolbarItem(placement: .principal) {
                yearPillButton
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                wallBinButton
            }
        }
    }

    private var wallBackButton: some View {
        Button {
            dismissYearMenuIfNeeded()
            dismiss()
        } label: {
            Image(systemName: "arrow.left")
                .font(.system(size: Theme.textSizeLg, weight: .bold, design: .rounded))
                .foregroundColor(Theme.primaryText)
                .frame(width: Theme.sizeChrome, height: Theme.sizeChrome)
        }
        .modifier(ReviewGlassCircleChrome())
        .accessibilityLabel(L10n.string("Back"))
    }

    private var yearPillButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                isYearMenuExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text(yearPillLabel)
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .monospacedDigit()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.tertiaryText)
                    .rotationEffect(.degrees(isYearMenuExpanded ? 180 : 0))
            }
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .frame(height: Theme.sizeChrome)
        }
        .modifier(ReviewGlassCapsuleChrome())
        .accessibilityLabel(L10n.string("Select year"))
        .accessibilityValue(yearPillLabel)
    }

    private var wallBinButton: some View {
        Button {
            dismissYearMenuIfNeeded()
            router.push(.trashBin)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "archivebox")
                    .font(.system(size: Theme.textSizeLg, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.primaryText)
                    .frame(width: Theme.sizeChrome, height: Theme.sizeChrome)

                let binCount = dataManager.deleteCandidates.count
                if binCount > 0 {
                    Text(binCount > 99 ? "99+" : PhotoDeleteCountFormat.plain(binCount))
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Capsule(style: .continuous).fill(Theme.destructive))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Theme.background, lineWidth: 2.5)
                        )
                        .offset(x: 2, y: -2)
                }
            }
        }
        .modifier(ReviewGlassCircleChrome())
        .accessibilityLabel(L10n.string("Collection bin"))
        .accessibilityValue(L10n.string("\(dataManager.deleteCandidates.count) to delete"))
    }

    private func dismissYearMenuIfNeeded() {
        guard isYearMenuExpanded else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            isYearMenuExpanded = false
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
