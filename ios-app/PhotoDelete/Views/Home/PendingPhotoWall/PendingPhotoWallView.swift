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

    @AppStorage(AppConstants.pendingPhotoWallDisplayModeKey)
    private var displayModeRaw = PendingPhotoWallDisplayMode.calendar.rawValue

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var snapshot = PendingPhotoWallSnapshot(
        years: [],
        months: [],
        selectedYear: Calendar.current.component(.year, from: Date()),
        totalPendingInLibrary: 0
    )
    @State private var showingYearSheet = false
    @State private var showingRecentOrganized = false

    private var displayMode: PendingPhotoWallDisplayMode {
        PendingPhotoWallDisplayMode(rawValue: displayModeRaw) ?? .calendar
    }

    private var yearPillLabel: String {
        AppDateFormatter.string(
            from: Calendar.current.date(from: DateComponents(year: snapshot.selectedYear, month: 1, day: 1)) ?? Date(),
            template: "y"
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

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
                            PendingPhotoWallMonthSection(
                                title: monthTitle(for: month),
                                remainingCount: month.remainingCount,
                                displayMode: displayMode,
                                onSelectMode: { mode in
                                    displayModeRaw = mode.rawValue
                                },
                                onOrganizeMonth: {
                                    router.push(SwipeViewDestination.wallMonth(month.monthStart, startFromDay: nil))
                                }
                            ) {
                                switch displayMode {
                                case .calendar:
                                    PendingPhotoWallCalendarGrid(
                                        month: month,
                                        today: Date(),
                                        photoLibraryManager: dataManager.photoLibraryManager,
                                        onSelectDay: { cell in
                                            router.push(
                                                SwipeViewDestination.wallMonth(cell.date, startFromDay: cell.date)
                                            )
                                        }
                                    )
                                case .polaroid:
                                    PendingPhotoWallPolaroidBoard(
                                        month: month,
                                        photoLibraryManager: dataManager.photoLibraryManager,
                                        onSelectDay: { cell in
                                            router.push(
                                                SwipeViewDestination.wallMonth(cell.date, startFromDay: cell.date)
                                            )
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 126)
                .padding(.bottom, 96)
            }

            topChrome
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingYearSheet) {
            PendingPhotoWallYearSheet(
                years: yearSheetOptions,
                selectedYear: snapshot.selectedYear,
                onSelect: { year in
                    selectedYear = year
                    showingYearSheet = false
                    rebuildSnapshot(preferredYear: year)
                },
                onDone: { showingYearSheet = false }
            )
        }
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

    private var topChrome: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Theme.background,
                    Theme.background.opacity(0.92),
                    Theme.background.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 158)
            .overlay(alignment: .top) {
                PendingPhotoWallChrome(
                    yearLabel: yearPillLabel,
                    binCount: dataManager.deleteCandidates.count,
                    onBack: { dismiss() },
                    onSelectYear: { showingYearSheet = true },
                    onOpenBin: { router.push(.trashBin) }
                )
                .padding(.top, 8)
            }
        }
        .allowsHitTesting(true)
    }

    private var shouldShowPreparing: Bool {
        let manager = dataManager.photoLibraryManager
        return dataManager.isPreparingLibrary
            || manager.isLoading
            || (manager.hasPhotoLibraryAccess && !manager.hasLoadedPhotoLibrary)
    }

    private var yearSheetOptions: [PendingPhotoWallYearOption] {
        if snapshot.years.isEmpty {
            return [PendingPhotoWallYearOption(year: selectedYear, remainingCount: 0)]
        }
        return snapshot.years
    }

    private func monthTitle(for month: PendingPhotoWallMonth) -> String {
        AppDateFormatter.string(from: month.monthStart, template: "MMM")
    }

    private func rebuildSnapshot(preferredYear: Int) {
        let photos = dataManager.photoLibraryManager.allPhotos
        let reviewed = dataManager.reviewedAssetIDs
        let deleteIDs = Set(dataManager.deleteCandidates.map(\.localIdentifier))
        let favoriteIDs = Set(dataManager.favoriteCandidates.map(\.localIdentifier))

        let built = PendingPhotoWallBuilder.build(
            photos: photos,
            reviewedIDs: reviewed,
            deleteCandidateIDs: deleteIDs,
            favoriteCandidateIDs: favoriteIDs,
            selectedYear: preferredYear
        )
        snapshot = built
        selectedYear = built.selectedYear
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
