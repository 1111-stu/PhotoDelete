//
//  CleanupAchievements.swift
//  PhotoDelete
//
//  Created by PhotoDelete Team on 6/12/26.
//

import SwiftUI

enum CleanupAchievementTint: String, Equatable {
    case accent
    case positive
    case warning
    case destructive
    case favorite

    var color: Color {
        switch self {
        case .accent:
            return Theme.accent
        case .positive:
            return Theme.positive
        case .warning:
            return Theme.warning
        case .destructive:
            return Theme.destructive
        case .favorite:
            return Theme.iconTint(for: "favorite")
        }
    }
}

struct CleanupAchievement: Identifiable, Equatable {
    let id: String
    let category: CleanupAchievementCategory
    let titleKey: String
    let subtitleKey: String
    let systemImage: String
    let tint: CleanupAchievementTint

    var title: String {
        L10n.key(titleKey)
    }

    var subtitle: String {
        L10n.key(subtitleKey)
    }
}

struct CleanupAchievementProgress: Identifiable, Equatable {
    let achievement: CleanupAchievement
    let currentValue: Double
    let targetValue: Double
    let metric: CleanupAchievementMetric

    var id: String {
        achievement.id
    }

    var isUnlocked: Bool {
        currentValue >= targetValue
    }

    var progress: Double {
        guard targetValue > 0 else { return 1 }
        return min(max(currentValue / targetValue, 0), 1)
    }

    var remainingValue: Double {
        max(targetValue - currentValue, 0)
    }

    var remainingDescription: String {
        switch metric {
        case .sessions:
            return L10n.string("\(Int(ceil(remainingValue))) sessions remaining")
        case .deletedPhotos:
            return L10n.string("\(Int(ceil(remainingValue))) deletes remaining")
        case .spaceSavedMB:
            return L10n.string("\(CleanupStatsFormatter.space(remainingValue)) remaining")
        case .streakDays:
            return L10n.string("\(Int(ceil(remainingValue))) streak days remaining")
        }
    }

    var valueDescription: String {
        switch metric {
        case .sessions:
            return L10n.string("\(Int(currentValue))/\(Int(targetValue)) sessions")
        case .deletedPhotos:
            return L10n.string("\(Int(currentValue))/\(Int(targetValue)) photos")
        case .spaceSavedMB:
            return L10n.string("\(CleanupStatsFormatter.space(currentValue))/\(CleanupStatsFormatter.space(targetValue))")
        case .streakDays:
            return L10n.string("\(Int(currentValue))/\(Int(targetValue)) days")
        }
    }
}

enum CleanupAchievementMetric: Equatable {
    case sessions
    case deletedPhotos
    case spaceSavedMB
    case streakDays
}

enum CleanupAchievementCategory: String, CaseIterable, Identifiable, Equatable {
    case rhythm
    case deletion
    case space
    case streak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rhythm:
            return L10n.string("Rhythm")
        case .deletion:
            return L10n.string("Deleted Photos")
        case .space:
            return L10n.string("Deleted Content")
        case .streak:
            return L10n.string("Streak")
        }
    }
}

private struct CleanupAchievementDefinition {
    let achievement: CleanupAchievement
    let metric: CleanupAchievementMetric
    let targetValue: Double
}

enum CleanupAchievementEvaluator {
    private static let definitions: [CleanupAchievementDefinition] = [
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "first_cleanup",
                category: .rhythm,
                titleKey: "First Cleanup",
                subtitleKey: "Complete your first photo cleanup",
                systemImage: "sparkles",
                tint: .accent
            ),
            metric: .sessions,
            targetValue: 1
        ),
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "sessions_5",
                category: .rhythm,
                titleKey: "Building Rhythm",
                subtitleKey: "Complete 5 organizing sessions",
                systemImage: "checklist",
                tint: .accent
            ),
            metric: .sessions,
            targetValue: 5
        ),
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "sessions_20",
                category: .rhythm,
                titleKey: "Long-Term Organizer",
                subtitleKey: "Complete 20 organizing sessions",
                systemImage: "calendar",
                tint: .accent
            ),
            metric: .sessions,
            targetValue: 20
        ),
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "delete_10",
                category: .deletion,
                titleKey: "Light Start",
                subtitleKey: "Delete 10 photos total",
                systemImage: "trash",
                tint: .destructive
            ),
            metric: .deletedPhotos,
            targetValue: 10
        ),
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "delete_50",
                category: .deletion,
                titleKey: "Album Relief",
                subtitleKey: "Delete 50 photos total",
                systemImage: "photo.stack",
                tint: .destructive
            ),
            metric: .deletedPhotos,
            targetValue: 50
        ),
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "delete_100",
                category: .deletion,
                titleKey: "Cleanup Pro",
                subtitleKey: "Delete 100 photos total",
                systemImage: "checkmark.seal",
                tint: .accent
            ),
            metric: .deletedPhotos,
            targetValue: 100
        ),
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "delete_500",
                category: .deletion,
                titleKey: "Deep Cleanup",
                subtitleKey: "Delete 500 photos total",
                systemImage: "trash.slash",
                tint: .destructive
            ),
            metric: .deletedPhotos,
            targetValue: 500
        ),
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "save_100mb",
                category: .space,
                titleKey: "Clean Up 100 MB",
                subtitleKey: "About 100 MB of content deleted",
                systemImage: "internaldrive",
                tint: .positive
            ),
            metric: .spaceSavedMB,
            targetValue: 100
        ),
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "streak_3",
                category: .streak,
                titleKey: "3-Day Streak",
                subtitleKey: "Clean up photos for 3 days in a row",
                systemImage: "flame",
                tint: .warning
            ),
            metric: .streakDays,
            targetValue: 3
        ),
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "save_1gb",
                category: .space,
                titleKey: "Clean Up 1 GB",
                subtitleKey: "About 1 GB of content deleted",
                systemImage: "externaldrive.badge.checkmark",
                tint: .positive
            ),
            metric: .spaceSavedMB,
            targetValue: 1_000
        ),
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "save_10gb",
                category: .space,
                titleKey: "Clean Up 10 GB",
                subtitleKey: "About 10 GB of content deleted",
                systemImage: "externaldrive.fill",
                tint: .positive
            ),
            metric: .spaceSavedMB,
            targetValue: 10_000
        ),
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "save_100gb",
                category: .space,
                titleKey: "Clean Up 100 GB",
                subtitleKey: "About 100 GB of content deleted",
                systemImage: "archivebox.fill",
                tint: .positive
            ),
            metric: .spaceSavedMB,
            targetValue: 100_000
        ),
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "streak_7",
                category: .streak,
                titleKey: "7-Day Streak",
                subtitleKey: "Clean up photos for 7 days in a row",
                systemImage: "calendar.badge.checkmark",
                tint: .warning
            ),
            metric: .streakDays,
            targetValue: 7
        ),
        CleanupAchievementDefinition(
            achievement: CleanupAchievement(
                id: "streak_30",
                category: .streak,
                titleKey: "30-Day Streak",
                subtitleKey: "Clean up for 30 days in a row",
                systemImage: "flame.fill",
                tint: .warning
            ),
            metric: .streakDays,
            targetValue: 30
        )
    ]

    static func unlockedAchievements(summary: CleanupStatsSummary, streakDays: Int) -> [CleanupAchievement] {
        definitions
            .filter { value(for: $0.metric, summary: summary, streakDays: streakDays) >= $0.targetValue }
            .map(\.achievement)
    }

    static func allProgress(summary: CleanupStatsSummary, streakDays: Int) -> [CleanupAchievementProgress] {
        definitions.map { definition in
            CleanupAchievementProgress(
                achievement: definition.achievement,
                currentValue: value(for: definition.metric, summary: summary, streakDays: streakDays),
                targetValue: definition.targetValue,
                metric: definition.metric
            )
        }
    }

    static func closeProgress(
        summary: CleanupStatsSummary,
        streakDays: Int,
        limit: Int = 3
    ) -> [CleanupAchievementProgress] {
        guard limit > 0 else { return [] }

        let lockedProgress = allProgress(summary: summary, streakDays: streakDays)
            .enumerated()
            .filter { !$0.element.isUnlocked }
            .sorted { lhs, rhs in
                if lhs.element.progress == rhs.element.progress {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.progress > rhs.element.progress
            }
            .map(\.element)

        let closeProgress = lockedProgress.filter { $0.progress >= 0.5 }
        return Array((closeProgress.isEmpty ? lockedProgress : closeProgress).prefix(limit))
    }

    static func newlyUnlockedAchievements(
        previousSummary: CleanupStatsSummary,
        currentSummary: CleanupStatsSummary,
        previousStreakDays: Int,
        currentStreakDays: Int
    ) -> [CleanupAchievement] {
        definitions.compactMap { definition in
            let previousValue = value(
                for: definition.metric,
                summary: previousSummary,
                streakDays: previousStreakDays
            )
            let currentValue = value(
                for: definition.metric,
                summary: currentSummary,
                streakDays: currentStreakDays
            )
            guard previousValue < definition.targetValue, currentValue >= definition.targetValue else {
                return nil
            }
            return definition.achievement
        }
    }

    static func nextProgress(summary: CleanupStatsSummary, streakDays: Int) -> CleanupAchievementProgress? {
        definitions.compactMap { definition -> CleanupAchievementProgress? in
            let currentValue = value(for: definition.metric, summary: summary, streakDays: streakDays)
            guard currentValue < definition.targetValue else { return nil }
            return CleanupAchievementProgress(
                achievement: definition.achievement,
                currentValue: currentValue,
                targetValue: definition.targetValue,
                metric: definition.metric
            )
        }
        .max { lhs, rhs in
            if lhs.progress == rhs.progress {
                return lhs.targetValue > rhs.targetValue
            }
            return lhs.progress < rhs.progress
        }
    }

    private static func value(
        for metric: CleanupAchievementMetric,
        summary: CleanupStatsSummary,
        streakDays: Int
    ) -> Double {
        switch metric {
        case .sessions:
            return Double(summary.sessions)
        case .deletedPhotos:
            return Double(summary.deletedPhotos)
        case .spaceSavedMB:
            return summary.estimatedSpaceSavedMB
        case .streakDays:
            return Double(streakDays)
        }
    }
}
