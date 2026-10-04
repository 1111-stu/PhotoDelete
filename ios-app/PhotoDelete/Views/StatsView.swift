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

        return VStack(spacing: 16) {
            HStack {
                Text(L10n.string("使用统计"))
                    .photoDeleteSectionHeading()
                Spacer()
            }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    StatCard(
                        value: "\(stats.totalAssets)",
                        label: L10n.string("照片"),
                        color: PhotoDeleteStyle.accent
                    )
                    StatCard(
                        value: "\(stats.organizedAssets)",
                        label: L10n.string("已整理"),
                        color: PhotoDeleteStyle.positive
                    )
                    StatCard(
                        value: "\(stats.deletedAssets)",
                        label: L10n.string("已删除"),
                        color: PhotoDeleteStyle.destructive
                    )
                    StatCard(
                        value: stats.formattedSpaceSaved,
                        label: L10n.string("删除内容"),
                        color: PhotoDeleteStyle.warning
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)

                Divider()
                    .background(PhotoDeleteStyle.hairline)
                    .padding(.horizontal, 16)

                StatsStorageSummaryRow(storage: stats.storageSnapshot)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            .photoDeleteCard()
        }
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
