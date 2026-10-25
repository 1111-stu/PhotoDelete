//
//  PeriodPickerSheet.swift
//  PhotoDelete
//

import SwiftUI
import Photos

/// 周期选择弹窗（点首页卡右区弹出）：
/// 只列同粒度的其他周期——本周→本周每天 / 本月→过往月份 / 本年→过往年份。
/// 「本期全部」由卡片主体直接承载，这里不再重复。选任意一行 → 进入对应周期的整理。
struct PeriodPickerSheet: View {
    @ObservedObject var dataManager: DataManager
    let scope: AdvancedTimeScope
    let onSelect: (AdvancedTimeScope, Date) -> Void

    private var detailSummaries: [PhotoPeriodSummary] {
        TimePeriodBrowser.detailSummaries(
            for: scope,
            summariesByScope: dataManager.periodSummariesByScope
        )
    }

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                Text(TimePeriodBrowser.pickerTitle(for: scope))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Theme.primaryText)
                    .padding(.top, 24)
                    .padding(.bottom, 4)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if detailSummaries.isEmpty {
                            Text(L10n.string("No other periods"))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Theme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                        } else {
                            ForEach(Array(detailSummaries.enumerated()), id: \.element.id) { index, summary in
                                pickerRow(summary, title: TimeOrganizeFormatter.title(for: summary))
                                if index < detailSummaries.count - 1 {
                                    rowHairline
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
        // 固定高度（不提供可伸缩档位）：列表超出时在弹窗内部滚动。
        .presentationDetents([.medium])
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
        title: String
    ) -> some View {
        Button {
            onSelect(summary.scope, summary.intervalStart)
        } label: {
            HStack(spacing: 12) {
                PeriodRowThumbnail(summary: summary, dataManager: dataManager)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(1)

                    Text(TimePeriodBrowser.rowSubtitle(for: summary))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(PhotoDeleteCountFormat.plain(summary.remainingCount))
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(Theme.primaryText)

                    Text(L10n.string("To review"))
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(Theme.tertiaryText)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.tertiaryText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("period-picker-row-\(summary.id)")
    }

    private var rowHairline: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
            .padding(.horizontal, 20)
    }
}

/// 周期行左侧缩略图：该周期最新的一张照片（单图，圆角 11）。
private struct PeriodRowThumbnail: View {
    let summary: PhotoPeriodSummary
    let dataManager: DataManager

    @State private var assetID: String?

    var body: some View {
        AlbumAssetThumbnail(
            assetID: assetID,
            photoLibraryManager: dataManager.photoLibraryManager,
            cornerRadius: 12
        )
        .frame(width: 52, height: 52)
        .onAppear {
            guard assetID == nil else { return }
            assetID = dataManager
                .getPhotosForPeriod(summary.scope, containing: summary.intervalStart)
                .first?
                .localIdentifier
        }
    }
}
