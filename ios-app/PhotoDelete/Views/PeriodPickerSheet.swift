//
//  PeriodPickerSheet.swift
//  PhotoDelete
//

import SwiftUI
import Photos

/// 周期选择弹窗（点首页 band 段弹出）：
/// 首行「本期全部」（数字琥珀），下面是更细周期——本周→每天 / 本月→过往月份 / 本年→过往年份。
/// 选任意一行 → 进入对应周期的整理。行结构与文案对齐 designs/home-prototype.html。
struct PeriodPickerSheet: View {
    @ObservedObject var dataManager: DataManager
    let scope: AdvancedTimeScope
    let onSelect: (AdvancedTimeScope, Date) -> Void

    private var allSummary: PhotoPeriodSummary {
        TimePeriodBrowser.currentSummary(
            for: scope,
            in: dataManager.periodSummariesByScope[scope] ?? []
        )
    }

    private var detailSummaries: [PhotoPeriodSummary] {
        TimePeriodBrowser.detailSummaries(
            for: scope,
            summariesByScope: dataManager.periodSummariesByScope
        )
    }

    var body: some View {
        ZStack {
            PhotoDeleteStyle.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                Text(TimePeriodBrowser.pickerTitle(for: scope))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                    .padding(.top, 24)
                    .padding(.bottom, 4)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        pickerRow(allSummary, title: TimePeriodBrowser.allRowTitle(for: scope), isPrimary: true)
                        rowHairline
                        ForEach(detailSummaries) { summary in
                            pickerRow(summary, title: TimeOrganizeFormatter.title(for: summary), isPrimary: false)
                            if summary.id != detailSummaries.last?.id {
                                rowHairline
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let detailScope = TimePeriodBrowser.detailScope(for: scope) {
                dataManager.refreshPhotoPeriodSummaries(for: [detailScope])
            }
        }
    }

    // MARK: - 行

    private func pickerRow(
        _ summary: PhotoPeriodSummary,
        title: String,
        isPrimary: Bool
    ) -> some View {
        Button {
            onSelect(summary.scope, summary.intervalStart)
        } label: {
            HStack(spacing: 12) {
                PeriodRowThumbnail(summary: summary, dataManager: dataManager)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.primaryText)
                        .lineLimit(1)

                    Text(TimePeriodBrowser.rowSubtitle(for: summary))
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(PhotoDeleteCountFormat.plain(summary.remainingCount))
                        .font(.system(size: 17, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(isPrimary ? PhotoDeleteStyle.accent : PhotoDeleteStyle.primaryText)

                    Text(L10n.string("待整理"))
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.tertiaryText)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.tertiaryText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("period-picker-row-\(summary.id)")
    }

    private var rowHairline: some View {
        Rectangle()
            .fill(PhotoDeleteStyle.hairline)
            .frame(height: 1)
            .padding(.horizontal, 20)
    }
}

/// 周期行左侧缩略图：取该周期最近 4 张照片拼 2×2 小图（对齐设计稿）。
private struct PeriodRowThumbnail: View {
    let summary: PhotoPeriodSummary
    let dataManager: DataManager

    @State private var assetIDs: [String] = []

    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]

    var body: some View {
        Group {
            if assetIDs.isEmpty {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(PhotoDeleteStyle.elevatedSurface)
            } else {
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(assetIDs.prefix(4), id: \.self) { assetID in
                        AlbumAssetThumbnail(
                            assetID: assetID,
                            photoLibraryManager: dataManager.photoLibraryManager,
                            cornerRadius: 0
                        )
                    }
                }
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onAppear {
            guard assetIDs.isEmpty else { return }
            assetIDs = dataManager
                .getPhotosForPeriod(summary.scope, containing: summary.intervalStart)
                .prefix(4)
                .map(\.localIdentifier)
        }
    }
}
