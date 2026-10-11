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
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                    .padding(.top, 24)
                    .padding(.bottom, 4)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        pickerRow(allSummary, title: TimePeriodBrowser.allRowTitle(for: scope), isPrimary: true)
                        rowHairline
                        ForEach(detailSummaries) { summary in
                            pickerRow(summary, title: TimeOrganizeFormatter.title(for: summary), isPrimary: false)
                            rowHairline
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

    /// 数字样式：「本期全部」用珊瑚粉渐变高亮（与「待整理」卡同一组色），明细行白字。
    private func numberStyle(isPrimary: Bool) -> AnyShapeStyle {
        guard isPrimary else { return AnyShapeStyle(PhotoDeleteStyle.primaryText) }
                return AnyShapeStyle(
            LinearGradient(
                colors: [PhotoDeleteStyle.coralGradientTop, PhotoDeleteStyle.coralGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

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
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.primaryText)
                        .lineLimit(1)

                    Text(TimePeriodBrowser.rowSubtitle(for: summary))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(PhotoDeleteCountFormat.plain(summary.remainingCount))
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(numberStyle(isPrimary: isPrimary))

                    Text(L10n.string("To review"))
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.tertiaryText)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.tertiaryText)
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
            .fill(PhotoDeleteStyle.hairline)
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
