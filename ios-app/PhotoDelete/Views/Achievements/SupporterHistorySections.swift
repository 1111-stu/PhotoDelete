//
//  SupporterHistorySections.swift
//  PhotoDelete
//
//  清理历史 / 月度统计区块，被成就页（CleanupAchievementsView）使用。
//  仍走琥珀语境（PhotoDeleteStyle），不要换成付费页的 PaywallDS。
//

import SwiftUI

struct SupporterMetricCard: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(PhotoDeleteStyle.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .photoDeleteCard()
    }
}

struct SupporterMonthlySection: View {
    let summaries: [CleanupMonthlySummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("Monthly Stats"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.primaryText)

            if summaries.isEmpty {
                SupporterEmptyText(L10n.string("Monthly records appear here after your first cleanup."))
            } else {
                VStack(spacing: 0) {
                    ForEach(summaries.prefix(6)) { summary in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(summary.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(PhotoDeleteStyle.primaryText)

                                Text(L10n.string("\(summary.sessions) sessions · \(summary.organizedPhotos) reviewed"))
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                            }

                            Spacer()

                            Text(L10n.string("Deleted content: about \(summary.formattedSpaceSaved)"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(PhotoDeleteStyle.positive)
                        }
                        .padding(.vertical, 12)

                        if summary.id != summaries.prefix(6).last?.id {
                            SupporterDivider()
                        }
                    }
                }
            }
        }
        .padding(18)
        .photoDeleteCard()
    }
}

struct SupporterHistorySection: View {
    let sessions: [CleanupSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("Cleanup History"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.primaryText)

            if sessions.isEmpty {
                SupporterEmptyText(L10n.string("Local cleanup records appear after you confirm deletions or favorites."))
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { session in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(PhotoDeleteStyle.positive)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.formattedDate)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(PhotoDeleteStyle.primaryText)

                                Text(L10n.string("Deleted \(session.deletedPhotos) · Favorited \(session.favoritedPhotos)"))
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                            }

                            Spacer()

                            Text(L10n.string("Deleted content: about \(session.formattedSpaceSaved)"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(PhotoDeleteStyle.positive)
                        }
                        .padding(.vertical, 12)

                        if session.id != sessions.last?.id {
                            SupporterDivider()
                        }
                    }
                }
            }
        }
        .padding(18)
        .photoDeleteCard()
    }
}

struct SupporterDivider: View {
    var body: some View {
        Divider()
            .background(PhotoDeleteStyle.hairline)
            .padding(.leading, 16)
    }
}

private struct SupporterEmptyText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(PhotoDeleteStyle.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}
