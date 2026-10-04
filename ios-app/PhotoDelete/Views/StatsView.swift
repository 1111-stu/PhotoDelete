//
//  StatsView.swift
//  PhotoDelete
//

import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var dataManager: DataManager

    var body: some View {
        StatsScreen(
            dataManager: dataManager,
            statsStore: dataManager.cleanupStatsStore
        )
    }
}

private struct StatsScreen: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var statsStore: CleanupStatsStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingClearConfirmation = false

    var body: some View {
        ZStack {
            PhotoDeleteScreenBackground()

            ScrollView {
                    VStack(spacing: PhotoDeleteStyle.sectionSpacing) {
                        usageSection
                        RecentOrganizedPhotosSection(dataManager: dataManager)
                        SupporterMonthlySection(summaries: statsStore.monthlySummaries)
                        SupporterHistorySection(sessions: Array(statsStore.sessions.prefix(50)))

                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Text(L10n.string("清空统计记录"))
                                .frame(maxWidth: .infinity)
                        }
                        .photoDeleteSecondaryButton()
                    }
                    .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    .padding(.top, PhotoDeleteStyle.rootContentTopSpacing)
                    .padding(.bottom, 36)
                    .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        .navigationTitle(L10n.string("统计"))
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(L10n.string("清空本机统计记录？"), isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button(L10n.string("清空统计记录"), role: .destructive) {
                statsStore.clearAll()
            }
            Button(L10n.string("取消"), role: .cancel) {}
        } message: {
            Text(L10n.string("只会清空删图的本机统计，不会影响照片。"))
        }
    }

    private var usageSection: some View {
        let stats = dataManager.makeSettingsStatsSummary()

        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("整理进度"))
                .photoDeleteSectionHeading()
                .foregroundColor(PhotoDeleteStyle.primaryText)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.string("已整理"))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(PhotoDeleteStyle.secondaryText)

                        Text("\(stats.organizedAssets)")
                            .font(.system(size: 42, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(PhotoDeleteStyle.primaryText)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(L10n.string("共 \(stats.totalAssets) 张"))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(PhotoDeleteStyle.secondaryText)
                        Text(organizedProgressText(for: stats))
                            .font(.headline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundColor(PhotoDeleteStyle.accent)
                    }
                }

                ProgressView(value: organizedProgress(for: stats))
                    .progressViewStyle(LinearProgressViewStyle(tint: PhotoDeleteStyle.accent))
                    .frame(height: 6)
                    .clipShape(Capsule(style: .continuous))

                HStack {
                    Text(L10n.string("删除内容约 \(stats.formattedSpaceSaved)"))
                    Spacer()
                    Text(L10n.string("已删除 \(stats.deletedAssets) 张"))
                }
                .font(.caption.weight(.medium))
                .foregroundColor(PhotoDeleteStyle.secondaryText)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(PhotoDeleteStyle.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(PhotoDeleteStyle.cardStroke, lineWidth: 1)
                    )
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                statsMetric(value: "\(stats.totalAssets)", label: L10n.string("照片"), tint: PhotoDeleteStyle.primaryText)
                statsMetric(value: "\(stats.deletedAssets)", label: L10n.string("已删除"), tint: PhotoDeleteStyle.destructive)
                statsMetric(value: "\(stats.organizedAssets)", label: L10n.string("已整理"), tint: PhotoDeleteStyle.positive)
                statsMetric(value: stats.formattedSpaceSaved, label: L10n.string("节省空间"), tint: PhotoDeleteStyle.warning)
            }

            VStack(spacing: 0) {
                StatsStorageSummaryRow(storage: stats.storageSnapshot)
                    .padding(18)
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(PhotoDeleteStyle.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(PhotoDeleteStyle.cardStroke, lineWidth: 1)
                    )
            )
        }
    }

    private func organizedProgress(for stats: AdvancedLibraryStats) -> Double {
        guard stats.totalAssets > 0 else { return 0 }
        return min(max(Double(stats.organizedAssets) / Double(stats.totalAssets), 0), 1)
    }

    private func organizedProgressText(for stats: AdvancedLibraryStats) -> String {
        L10n.percent(Int((organizedProgress(for: stats) * 100).rounded()))
    }

    private func statsMetric(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(PhotoDeleteStyle.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PhotoDeleteStyle.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PhotoDeleteStyle.hairline, lineWidth: 1)
                )
        )
    }
}

private struct StatsStorageSummaryRow: View {
    let storage: DeviceStorageSnapshot

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "internaldrive")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PhotoDeleteStyle.accent)
                    .frame(width: 22)

                Text(L10n.string("手机存储空间"))
                    .photoDeletePrimaryLabel(.body.weight(.semibold))

                Spacer()

                Text("\(Int(storage.usedFraction * 100))%")
                    .photoDeleteSecondaryLabel(.subheadline.weight(.semibold))
            }

            ProgressView(value: storage.usedFraction)
                .progressViewStyle(LinearProgressViewStyle(tint: PhotoDeleteStyle.accent))
                .clipShape(Capsule(style: .continuous))

            HStack {
                Text(L10n.string("已用 \(storage.formattedUsed)"))
                Spacer()
                Text(L10n.string("可用 \(storage.formattedFree)"))
            }
            .font(.caption)
            .foregroundStyle(PhotoDeleteStyle.tertiaryText)
        }
    }
}
