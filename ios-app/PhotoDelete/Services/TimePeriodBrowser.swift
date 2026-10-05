//
//  TimePeriodBrowser.swift
//  PhotoDelete
//

import Foundation

/// 时间周期浏览的纯逻辑（无视图依赖，可直接单测）：
/// 从各 scope 的摘要里切片出「周期选择弹窗」所需的行、匹配"当前周期"，
/// 并提供时间浏览页 / 弹窗共用的行格式化。
enum TimePeriodBrowser {

    // MARK: - 当前周期

    /// 匹配"包含 now 的那一期"摘要；没有则返回该 scope 的空摘要（与首页 band 行为一致）。
    static func currentSummary(
        for scope: AdvancedTimeScope,
        in summaries: [PhotoPeriodSummary],
        now: Date = Date()
    ) -> PhotoPeriodSummary {
        if let current = summaries.first(where: { now >= $0.intervalStart && now < $0.intervalEnd }) {
            return current
        }
        return .empty(scope: scope, containing: now)
    }

    // MARK: - 弹窗明细行

    /// 弹窗里「本期全部」下方要列的更细周期：
    /// 本周 → 本周内的每天；本月 → 过往月份；本年 → 过往年份。
    /// 只保留有照片（assetCount > 0）的周期，按开始时间倒序。
    static func detailSummaries(
        for scope: AdvancedTimeScope,
        now: Date = Date(),
        summariesByScope: [AdvancedTimeScope: [PhotoPeriodSummary]],
        calendar: Calendar = .current
    ) -> [PhotoPeriodSummary] {
        let boundary: Date
        let source: [PhotoPeriodSummary]
        let includeFuture: Bool

        switch scope {
        case .week:
            // 周内明细是"天"：取本周区间内的所有天。
            boundary = calendar.dateInterval(for: .week, containing: now).start
            source = summariesByScope[.day] ?? []
            includeFuture = true
        case .month:
            boundary = calendar.dateInterval(for: .month, containing: now).start
            source = summariesByScope[.month] ?? []
            includeFuture = false
        case .year:
            boundary = calendar.dateInterval(for: .year, containing: now).start
            source = summariesByScope[.year] ?? []
            includeFuture = false
        case .day:
            return []
        }

        let weekEnd = calendar.dateInterval(for: .week, containing: now).end
        return source
            .filter { summary in
                guard summary.assetCount > 0 else { return false }
                if scope == .week {
                    return summary.intervalStart >= boundary && summary.intervalStart < weekEnd
                }
                return includeFuture ? summary.intervalStart >= boundary : summary.intervalStart < boundary
            }
            .sorted { $0.intervalStart > $1.intervalStart }
    }

    /// 弹窗出现时需要预先刷新的 scope（明细行所属的维度）。
    static func detailScope(for scope: AdvancedTimeScope) -> AdvancedTimeScope? {
        switch scope {
        case .week: return .day
        case .month: return .month
        case .year: return .year
        case .day: return nil
        }
    }

    /// 弹窗标题：按周 / 按月 / 按年整理。
    static func pickerTitle(for scope: AdvancedTimeScope) -> String {
        switch scope {
        case .week: return L10n.string("按周整理")
        case .month: return L10n.string("按月整理")
        case .year: return L10n.string("按年整理")
        case .day: return AdvancedTimeScope.day.title
        }
    }

    /// 弹窗首行「本期全部」的标题。
    static func allRowTitle(for scope: AdvancedTimeScope) -> String {
        switch scope {
        case .week: return L10n.string("本周全部")
        case .month: return L10n.string("本月全部")
        case .year: return L10n.string("本年全部")
        case .day: return L10n.string("本日全部")
        }
    }

    /// 弹窗行的副标题：共 X 项 · Y（对齐设计稿；数字不带千分位）。
    static func rowSubtitle(for summary: PhotoPeriodSummary) -> String {
        String(
            format: L10n.string("共 %@ 项 · %@"),
            PhotoDeleteCountFormat.plain(summary.assetCount),
            summary.formattedEstimatedSize
        )
    }
}

/// 时间浏览页 / 周期弹窗共用的行格式化。
enum TimeOrganizeFormatter {
    static func title(for summary: PhotoPeriodSummary) -> String {
        switch summary.scope {
        case .day:
            return AppDateFormatter.string(from: summary.intervalStart, template: "MMMEd")
        case .week:
            return AdvancedTimeScope.week.title
        case .month:
            return AppDateFormatter.string(from: summary.intervalStart, template: "yMMM")
        case .year:
            return AppDateFormatter.string(from: summary.intervalStart, template: "y")
        }
    }

    static func subtitle(for summary: PhotoPeriodSummary) -> String {
        String(
            format: L10n.string("剩余 %lld 张 · 共 %lld 张"),
            Int64(summary.remainingCount),
            Int64(summary.assetCount)
        )
    }
}
