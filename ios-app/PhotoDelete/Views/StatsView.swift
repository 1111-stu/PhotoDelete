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

/// 「使用统计」（回望页）。信息架构（2026-10-05 按 style.md 重构）：
/// 整理进度（单卡 + 中性进度条）→ 清理历史（近 6 个月柱状图，点柱钻取）→ 清空记录。
///
/// 已移除：
/// - 2×2 指标宫格：照片/已删除/已整理/节省空间 四项全部与上方进度卡重复（同一数据第二次展示），且四色数字违反"深色卡至多一个琥珀值"；
/// - 手机存储卡：与首页「预计可释放」职责重复（既定决策已删），且系统存储与本机整理成绩无因果；
/// - 独立的「月度统计」段：与清理历史同源（sessions 的按月聚合），合并为按月份分组的单一历史列表；
/// - 「最近整理」段：已独立成页（`RecentOrganizedPhotosView`，入口在首页右上角）。
private struct StatsScreen: View {
    @ObservedObject var dataManager: DataManager
    @ObservedObject var statsStore: CleanupStatsStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingClearConfirmation = false
    @State private var selectedMonth: HistoryMonth?

    var body: some View {
        ZStack {
            PhotoDeleteScreenBackground()

            ScrollView {
                VStack(spacing: PhotoDeleteStyle.sectionSpacing) {
                    progressSection
                    cleanupHistorySection

                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Text(L10n.string("清空统计记录"))
                            .frame(maxWidth: .infinity)
                    }
                    .photoDeleteDestructiveButton()
                }
                .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                .padding(.top, PhotoDeleteStyle.rootContentTopSpacing)
                .padding(.bottom, 36)
                .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(L10n.string("使用统计"))
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(L10n.string("清空本机统计记录？"), isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button(L10n.string("清空统计记录"), role: .destructive) {
                statsStore.clearAll()
            }
            Button(L10n.string("取消"), role: .cancel) {}
        } message: {
            Text(L10n.string("只会清空删图的本机统计，不会影响照片。"))
        }
        .sheet(item: $selectedMonth) { month in
            monthDetailSheet(month)
        }
    }

    // MARK: - 整理进度（单卡）

    private var progressSection: some View {
        let stats = dataManager.makeSettingsStatsSummary()

        return VStack(alignment: .leading, spacing: 9) {
            PhotoDeleteSectionHeader(title: L10n.string("整理进度"))

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.string("已整理"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(PhotoDeleteStyle.secondaryText)

                        Text(PhotoDeleteCountFormat.plain(stats.organizedAssets))
                            .font(.system(size: 42, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(PhotoDeleteStyle.primaryText)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(L10n.string("共 \(stats.totalAssets) 张"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(PhotoDeleteStyle.secondaryText)

                        Text(organizedProgressText(for: stats))
                            .font(.system(size: 17, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(PhotoDeleteStyle.primaryText)
                    }
                }

                // 中性进度条：琥珀不用于「已完成」状态（style.md §2.3）。
                ProgressView(value: organizedProgress(for: stats))
                    .progressViewStyle(LinearProgressViewStyle(tint: PhotoDeleteStyle.primaryText.opacity(0.55)))
                    .frame(height: 6)
                    .clipShape(Capsule(style: .continuous))

                HStack {
                    Text(L10n.string("删除内容约 \(stats.formattedSpaceSaved)"))
                    Spacer()
                    Text(L10n.string("已删除 \(stats.deletedAssets) 张"))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(PhotoDeleteStyle.secondaryText)
            }
            .padding(18)
            .photoDeleteCard(radius: 22)
        }
    }

    private func organizedProgress(for stats: AdvancedLibraryStats) -> Double {
        guard stats.totalAssets > 0 else { return 0 }
        return min(max(Double(stats.organizedAssets) / Double(stats.totalAssets), 0), 1)
    }

    private func organizedProgressText(for stats: AdvancedLibraryStats) -> String {
        L10n.percent(Int((organizedProgress(for: stats) * 100).rounded()))
    }

    // MARK: - 清理历史（按月分组，合并原「月度统计 + 清理历史」）

    private struct HistoryMonth: Identifiable {
        let monthKey: String
        let sessions: [CleanupSession]
        var id: String { monthKey }
    }

    private var cleanupHistorySection: some View {
        let recent = Array(statsStore.sessions.prefix(50))
        let months = Array(
            Dictionary(grouping: recent, by: \.monthKey)
                .map { HistoryMonth(monthKey: $0.key, sessions: $0.value) }
                .sorted { $0.monthKey < $1.monthKey }   // 时间正序
                .suffix(6)                               // 近 6 个月
        )

        return VStack(alignment: .leading, spacing: 9) {
            PhotoDeleteSectionHeader(title: L10n.string("清理历史"))

            if months.isEmpty {
                Text(L10n.string("确认删除或收藏后，会在本机留下清理记录。"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .photoDeleteCard(radius: 22)
            } else {
                monthChart(months)
                    .padding(EdgeInsets(top: 16, leading: 14, bottom: 12, trailing: 14))
                    .photoDeleteCard(radius: 22)
            }
        }
    }

    // MARK: - 月度柱状图（近 6 个月，点柱钻取当月明细）

    private func monthChart(_ months: [HistoryMonth]) -> some View {
        let counts = months.map(monthDeletedCount)
        let maxCount = max(counts.max() ?? 0, 1)

        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(months) { month in
                monthBar(
                    month: month,
                    count: monthDeletedCount(month),
                    maxCount: maxCount,
                    isLatest: month.id == months.last?.id
                )
            }
        }
    }

    private func monthBar(month: HistoryMonth, count: Int, maxCount: Int, isLatest: Bool) -> some View {
        let theme = PhotoDeleteTheme.current
        let barHeight: CGFloat = count > 0 ? max(6, 96 * CGFloat(count) / CGFloat(maxCount)) : 4

        return Button {
            selectedMonth = month
        } label: {
            VStack(spacing: 6) {
                Text(count > 0 ? PhotoDeleteCountFormat.plain(count) : " ")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .frame(height: 12)

                // 粉色系柱体：与「待整理」卡同一组珊瑚渐变；当月全饱和，其余降透明度。
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.coralGradientTop, theme.coralGradientBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(isLatest ? 1 : 0.65)
                    .frame(maxWidth: 44)
                    .frame(height: barHeight)

                Text(shortMonthTitle(for: month.monthKey))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("\(monthTitle(for: month.monthKey))，删除 \(count) 张"))
    }

    private func monthDeletedCount(_ month: HistoryMonth) -> Int {
        month.sessions.reduce(0) { $0 + $1.deletedPhotos }
    }

    /// 点柱钻取：当月逐条明细（原先铺在页面上的 list 信息保留在这里）。
    private func monthDetailSheet(_ month: HistoryMonth) -> some View {
        let ordered = month.sessions.sorted { $0.date > $1.date }

        return NavigationStack {
            ZStack {
                PhotoDeleteScreenBackground()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(ordered) { session in
                            historyRow(session)
                            if session.id != ordered.last?.id {
                                historySeparator
                            }
                        }
                    }
                    .photoDeleteCard(radius: 22)
                    .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    .padding(.top, 16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(monthTitle(for: month.monthKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("完成")) {
                        selectedMonth = nil
                    }
                    .foregroundColor(PhotoDeleteStyle.accent)
                }
            }
        }
    }

    private func historyRow(_ session: CleanupSession) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.formattedDate)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)

                Text(L10n.string("删除 \(session.deletedPhotos) 张 · 收藏 \(session.favoritedPhotos) 张"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
            }

            Spacer(minLength: 8)

            Text(L10n.string("删除内容约 \(session.formattedSpaceSaved)"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var historySeparator: some View {
        Rectangle()
            .fill(PhotoDeleteStyle.hairline)
            .frame(height: 1)
            .padding(.horizontal, 18)
    }

    private static let shortMonthFormatter: DateFormatter = AppDateFormatter.configuredFormatter(template: "MMM")

    private func monthTitle(for monthKey: String) -> String {
        guard let date = monthDate(for: monthKey) else { return monthKey }
        return CleanupStatsFormatter.month.string(from: date)
    }

    private func shortMonthTitle(for monthKey: String) -> String {
        guard let date = monthDate(for: monthKey) else { return monthKey }
        return Self.shortMonthFormatter.string(from: date)
    }

    private func monthDate(for monthKey: String) -> Date? {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        return Calendar.current.date(from: components)
    }
}
