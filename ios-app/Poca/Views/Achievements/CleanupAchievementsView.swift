//
//  CleanupAchievementsView.swift
//  Poca
//
//  Created by Poca Team on 6/12/26.
//

import SwiftUI
import Photos

struct CleanupAchievementsEntryCard: View {
    @ObservedObject var statsStore: CleanupStatsStore

    private var unlockedCount: Int {
        statsStore.unlockedAchievements.count
    }

    private var totalCount: Int {
        statsStore.achievementProgresses.count
    }

    private var nextProgress: CleanupAchievementProgress? {
        statsStore.nextAchievementProgress
    }

    var body: some View {
        HStack(spacing: 12) {
            PocaIconTile(
                icon: "seal.fill",
                tint: Theme.warning,
                size: 42,
                cornerRadius: 12
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(L10n.string("Cleanup Achievements"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.primaryText)

                    Text(L10n.string("\(unlockedCount)/\(totalCount)"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.warning)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Theme.warning.opacity(0.14))
                        )
                }

                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.tertiaryText)
        }
        .padding(15)
        .photoDeleteCard()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.string("Cleanup achievements, \(unlockedCount) of \(totalCount) unlocked"))
    }

    private var subtitle: String {
        if let nextProgress {
            return L10n.string("Next goal: \(nextProgress.achievement.title), \(nextProgress.remainingDescription).")
        }
        return L10n.string("All badges unlocked. Keep the cleanup rhythm going.")
    }
}

struct CleanupAchievementsView: View {
    @EnvironmentObject var dataManager: DataManager
    @ObservedObject var statsStore: CleanupStatsStore
    var showsDoneButton = false
    var showsHistory = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingClearConfirmation = false

    private var allProgress: [CleanupAchievementProgress] {
        statsStore.achievementProgresses
    }

    private var unlockedProgress: [CleanupAchievementProgress] {
        allProgress.filter(\.isUnlocked)
    }

    private var nextProgress: CleanupAchievementProgress? {
        statsStore.nextAchievementProgress
    }

    private var summary: CleanupStatsSummary {
        statsStore.summary
    }

    private var groupedAllProgress: [CleanupAchievementCategoryProgressGroup] {
        CleanupAchievementCategory.allCases.compactMap { category in
            let items = allProgress.filter { $0.achievement.category == category }
            return items.isEmpty ? nil : CleanupAchievementCategoryProgressGroup(category: category, items: items)
        }
    }

    var body: some View {
        ZStack {
            PocaScreenBackground()

            ScrollView {
                VStack(spacing: Theme.space6) {
                    if AppConstants.achievementsEnabled {
                        archiveSummarySection
                        nextBadgeSection
                        badgeWallSection
                    }

                    if showsHistory {
                        historySection
                    }
                }
                .padding(.horizontal, Theme.space5)
                .padding(.top, Theme.space2)
                .padding(.bottom, Theme.space24)
                .frame(maxWidth: PocaAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(showsHistory ? L10n.string("Achievements & History") : L10n.string("Cleanup Achievements"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
        .confirmationDialog(L10n.string("Clear local stats?"), isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button(L10n.string("Clear Stats"), role: .destructive) {
                statsStore.clearAll()
            }
            Button(L10n.string("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("This only clears Poca's local stats. Your photos are not affected."))
        }
    }

    private var archiveSummarySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(showsHistory ? L10n.string("Cleanup Archive") : L10n.string("Cleanup Achievements"))
                    .photoDeleteSectionHeading()

                Spacer()
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    PocaIconTile(
                        icon: "seal.fill",
                        tint: Theme.warning,
                        size: 38,
                        cornerRadius: Theme.radiusSm
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.string("Badges, cleanup streaks, and deleted content progress"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.primaryText)
                            .lineLimit(2)

                        Text(L10n.string("All records stay on this device."))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Theme.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text("\(unlockedProgress.count)/\(allProgress.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(Theme.warning)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)

                Divider()
                    .background(Theme.hairline)
                    .padding(.horizontal, 16)

                HStack(spacing: 8) {
                    StatCard(
                        value: "\(unlockedProgress.count)/\(allProgress.count)",
                        label: L10n.string("Earned"),
                        color: Theme.warning
                    )
                    StatCard(
                        value: "\(summary.sessions)",
                        label: L10n.string("Cleanup Sessions"),
                        color: Theme.accent
                    )
                    StatCard(
                        value: "\(summary.deletedPhotos)",
                        label: L10n.string("Total Deleted"),
                        color: Theme.destructive
                    )
                    StatCard(
                        value: summary.formattedSpaceSaved,
                        label: L10n.string("Total Deleted Content"),
                        color: Theme.positive
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .photoDeleteCard()
        }
        .accessibilityElement(children: .combine)
    }

    private var nextBadgeSection: some View {
        VStack(spacing: 16) {
            PocaSectionHeader(title: L10n.string("Next Badge"))

            VStack(spacing: 0) {
                if let nextProgress {
                    CleanupAchievementNextRow(progress: nextProgress)
                } else {
                    CleanupAchievementAllUnlockedRow()
                }
            }
            .photoDeleteCard()
        }
    }

    private var badgeWallSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                PocaSectionHeader(title: L10n.string("Milestone Badges"))

                Text(L10n.string("Light up each cleanup badge by category"))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .padding(.horizontal, 6)
            }

            if groupedAllProgress.isEmpty {
                CleanupAchievementEmptyCard(
                    title: L10n.string("No Badges"),
                    subtitle: L10n.string("Cleanup records will appear here.")
                )
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(groupedAllProgress) { group in
                        CleanupAchievementCategoryGroup(
                            title: group.category.title,
                            progressItems: group.items
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(spacing: 16) {
            RecentOrganizedPhotosSection(dataManager: dataManager)

            SupporterMonthlySection(summaries: statsStore.monthlySummaries)

            SupporterHistorySection(sessions: Array(statsStore.sessions.prefix(50)))

            Button(role: .destructive) {
                showingClearConfirmation = true
            } label: {
                Text(L10n.string("Clear Stats"))
                    .frame(maxWidth: .infinity)
            }
            .photoDeleteDestructiveButton()
        }
    }
}

struct RecentOrganizedPhotosSection: View {
    @ObservedObject var dataManager: DataManager
    @State private var previewAsset: CandidatePreviewAsset?
    @State private var showingClearConfirmation = false

    private var items: [RecentOrganizedPhotoItem] {
        dataManager.recentOrganizedPhotoItems()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 3) {
                    PocaSectionHeader(title: L10n.string("Recently Organized"))

                    Text(L10n.string("Tap Organize Again to remove it from pending deletion and return it to review."))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                }

                if !items.isEmpty {
                    Button(L10n.string("Clear"), role: .destructive) {
                        showingClearConfirmation = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.trailing, 6)
                }
            }

            if items.isEmpty {
                Text(L10n.string("Recently organized photos appear here so you can revise them."))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(items) { item in
                            RecentOrganizedPhotoCard(
                                item: item,
                                photoLibraryManager: dataManager.photoLibraryManager,
                                onPreview: {
                                    previewAsset = CandidatePreviewAsset(asset: item.asset)
                                },
                                onReopen: {
                                    HapticManager.impact(.light)
                                    dataManager.reopenForOrganizing(item.asset)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(18)
        .photoDeleteCard()
        .sheet(item: $previewAsset) { item in
            CandidatePhotoPreviewView(
                asset: item.asset,
                photoLibraryManager: dataManager.photoLibraryManager
            )
        }
        .confirmationDialog(
            L10n.string("Clear recent organization history?"),
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.string("Clear History"), role: .destructive) {
                dataManager.clearRecentOrganizedPhotoHistory()
            }
            Button(L10n.string("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("This clears only local history and won’t change photos or pending deletion."))
        }
    }
}

private struct RecentOrganizedPhotoCard: View {
    let item: RecentOrganizedPhotoItem
    let photoLibraryManager: PhotoLibraryManager
    let onPreview: () -> Void
    let onReopen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onPreview) {
                RecentOrganizedPhotoThumbnail(
                    asset: item.asset,
                    photoLibraryManager: photoLibraryManager
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("View photo larger"))

            Label(item.record.action.title, systemImage: actionIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(actionTint)
                .lineLimit(1)

            Button(L10n.string("Organize Again"), action: onReopen)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.accent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                        .fill(Theme.accent.opacity(0.12))
                )
        }
        .frame(width: 116)
    }

    private var actionIcon: String {
        switch item.record.action {
        case .kept:
            return "checkmark"
        case .queuedForDeletion:
            return "trash"
        case .favorited:
            return "heart.fill"
        case .unfavorited:
            return "heart.slash"
        case .filedToAlbum:
            return "folder.fill"
        }
    }

    private var actionTint: Color {
        switch item.record.action {
        case .queuedForDeletion:
            return Theme.destructive
        case .favorited, .unfavorited:
            return Theme.iconTint(for: "favorite")
        case .filedToAlbum:
            return Theme.accent
        case .kept:
            return Theme.positive
        }
    }
}

private struct RecentOrganizedPhotoThumbnail: View {
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.elevatedSurface)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
                    .tint(Theme.accent)
            }
        }
        .frame(width: 116, height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear(perform: loadImage)
        .onDisappear {
            photoLibraryManager.cancelImageRequest(requestID)
        }
    }

    private func loadImage() {
        requestID = photoLibraryManager.loadFastThumbnail(
            for: asset,
            size: CGSize(width: 232, height: 184)
        ) { loadedImage in
            image = loadedImage
            requestID = nil
        }
    }
}

private struct CleanupAchievementCategoryProgressGroup: Identifiable {
    let category: CleanupAchievementCategory
    let items: [CleanupAchievementProgress]

    var id: String { category.id }
}

private struct CleanupAchievementNextRow: View {
    let progress: CleanupAchievementProgress

    var body: some View {
        HStack(spacing: 12) {
            CleanupAchievementMedal(progress: progress, size: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(progress.achievement.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(progress.remainingDescription)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            Text(progress.valueDescription)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(progress.achievement.tint.color)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: Theme.sizeRow)
        .accessibilityElement(children: .combine)
    }
}

private struct CleanupAchievementAllUnlockedRow: View {
    var body: some View {
        HStack(spacing: 12) {
            PocaIconTile(
                icon: "checkmark.seal.fill",
                tint: Theme.positive,
                size: 38,
                cornerRadius: Theme.radiusSm
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.string("All Badges Unlocked"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.primaryText)

                Text(L10n.string("Every cleanup milestone is complete."))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: Theme.sizeRow)
        .accessibilityElement(children: .combine)
    }
}

private struct CleanupAchievementCategoryGroup: View {
    let title: String
    let progressItems: [CleanupAchievementProgress]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var badgeMinimumWidth: CGFloat = 80

    private var unlockedCount: Int {
        progressItems.filter(\.isUnlocked).count
    }

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 10)]
        }

        return [GridItem(.adaptive(minimum: max(78, badgeMinimumWidth), maximum: 96), spacing: 8)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)

                Spacer()

                Text("\(unlockedCount)/\(progressItems.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
            }

            LazyVGrid(
                columns: columns,
                spacing: 8
            ) {
                ForEach(progressItems) { progress in
                    CleanupAchievementBadgeTile(progress: progress)
                }
            }
        }
        .padding(14)
        .photoDeleteCard()
    }
}

private struct CleanupAchievementBadgeTile: View {
    let progress: CleanupAchievementProgress

    @ScaledMetric(relativeTo: .body) private var medalSize: CGFloat = 42
    @ScaledMetric(relativeTo: .body) private var tileMinHeight: CGFloat = 92

    var body: some View {
        VStack(spacing: 7) {
            CleanupAchievementMedal(progress: progress, size: medalSize)

            Text(progress.achievement.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .center)

            Text(progress.isUnlocked ? L10n.string("Unlocked") : progress.valueDescription)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(progress.isUnlocked ? progress.achievement.tint.color : Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, minHeight: tileMinHeight)
        .padding(.vertical, 4)
        .opacity(progress.isUnlocked ? 1 : 0.58)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(progress.achievement.title); \(progress.achievement.subtitle); \(progress.valueDescription)"))
    }
}

private struct CleanupAchievementMedal: View {
    let progress: CleanupAchievementProgress
    var size: CGFloat = 56
    var isFeatured = false

    private var tint: Color {
        progress.achievement.tint.color
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    progress.isUnlocked
                    ? AnyShapeStyle(LinearGradient(
                        colors: [tint.opacity(0.98), tint.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    : AnyShapeStyle(Theme.surface)
                )
                .overlay(
                    Circle()
                        .stroke(
                            progress.isUnlocked ? tint.opacity(0.36) : Theme.cardStroke,
                            lineWidth: progress.isUnlocked ? 1.5 : 1
                        )
                )
                .shadow(
                    color: progress.isUnlocked ? tint.opacity(isFeatured ? 0.26 : 0.18) : .clear,
                    radius: isFeatured ? 10 : 6,
                    y: isFeatured ? 5 : 3
                )

            Image(systemName: progress.achievement.systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: max(size * 0.38, 18), weight: .semibold))
                .foregroundColor(progress.isUnlocked ? .white : tint.opacity(0.78))
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            statusMarker
        }
    }

    @ViewBuilder
    private var statusMarker: some View {
        let markerSize = max(size * 0.28, 15)

        if progress.isUnlocked {
            Image(systemName: "checkmark")
                .font(.system(size: markerSize * 0.54, weight: .bold))
                .foregroundColor(.white)
                .frame(width: markerSize, height: markerSize)
                .background(Circle().fill(Theme.positive))
                .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
        } else {
            Image(systemName: "lock.fill")
                .font(.system(size: markerSize * 0.48, weight: .bold))
                .foregroundColor(Theme.tertiaryText)
                .frame(width: markerSize, height: markerSize)
                .background(Circle().fill(Theme.elevatedSurface))
                .overlay(Circle().stroke(Theme.surface, lineWidth: 1.5))
        }
    }
}

private struct CleanupAchievementEmptyCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            PocaIconTile(
                icon: "seal",
                tint: Theme.tertiaryText,
                size: 38,
                cornerRadius: Theme.radiusSm
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.primaryText)

                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
            }

            Spacer()
        }
        .padding(14)
        .photoDeleteCard(radius: 16)
    }
}
