//
//  SupporterBenefitsSheet.swift
//  Poca
//
//  「功能差异」弹窗与免费 vs Pro 对比表。
//  同时被付费页（社会证明位）与进阶页（锁定态的「查看功能差异」）复用。
//

import SwiftUI

struct SupporterBenefitsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PaywallDS.Color.pageBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: PaywallDS.Space.xl) {
                        Text(L10n.string("Random, swipe, and time-based cleanup are free. Supporters also unlock the full timeline, image and video compression, large-file cleanup, and similar-photo cleanup."))
                            .font(PaywallDS.Font.caption)
                            .foregroundStyle(PaywallDS.Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        SupporterPlanComparisonCard()
                    }
                    .padding(PaywallLayout.pageHorizontalPadding)
                }
            }
            .navigationTitle(L10n.string("Feature differences"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) {
                        dismiss()
                    }
                    .foregroundColor(PaywallDS.Color.textSecondary)
                }
            }
        }
    }
}

struct SupporterPlanComparisonCard: View {
    static let features: [SupporterPlanComparisonFeature] = [
        .init(titleID: .randomReview, free: .included, supporter: .included),
        .init(titleID: .basicSwipeReview, free: .included, supporter: .included),
        .init(titleID: .confirmedDeleteAndFavorite, free: .included, supporter: .included),
        .init(titleID: .basicTimeOrganizing, free: .included, supporter: .included),
        .init(titleID: .localCleanupHistory, free: .included, supporter: .included),
        .init(titleID: .basicSpaceSavedStats, free: .included, supporter: .included),
        .init(titleID: .fullTimeList, free: .notIncluded, supporter: .included),
        .init(titleID: .largeFileCleanup, free: .notIncluded, supporter: .included),
        .init(titleID: .imageCompression, free: .notIncluded, supporter: .included),
        .init(titleID: .videoCompression, free: .notIncluded, supporter: .included),
        .init(titleID: .similarPhotoCleanup, free: .notIncluded, supporter: .included)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.string("Plan Comparison"))
                .font(PaywallDS.Font.calloutSemibold)
                .foregroundColor(PaywallDS.Color.textPrimary)
                .padding(.horizontal, PaywallDS.Space.xl)
                .padding(.top, PaywallDS.Space.xl)
                .padding(.bottom, PaywallDS.Space.lg)

            HStack(spacing: PaywallDS.Space.md) {
                Text(L10n.string("Feature"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.string("Free"))
                    .frame(width: 64)
                Text(L10n.string("Pro"))
                    .frame(width: 64)
            }
            .font(PaywallDS.Font.caption2Bold)
            .foregroundColor(PaywallDS.Color.textSecondary)
            .padding(.horizontal, PaywallDS.Space.xl)
            .padding(.bottom, PaywallDS.Space.md)

            ForEach(Self.features) { row in
                SupporterPlanComparisonRow(model: row)
                if row.id != Self.features.last?.id {
                    PaywallDivider()
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: PaywallDS.Radius.listContainer, style: .continuous)
                .fill(PaywallDS.Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: PaywallDS.Radius.listContainer, style: .continuous)
                        .stroke(PaywallDS.Color.borderSubtle, lineWidth: PaywallDS.Stroke.border)
                )
        )
    }
}

struct SupporterPlanComparisonFeature: Identifiable, Equatable {
    let titleID: SupporterPlanFeatureTitle
    let free: SupporterPlanAvailability
    let supporter: SupporterPlanAvailability

    var id: String { titleID.rawValue }
    var title: String { titleID.localizedTitle }
}

enum SupporterPlanFeatureTitle: String {
    case randomReview = "随机整理"
    case basicSwipeReview = "基础滑动整理"
    case confirmedDeleteAndFavorite = "确认后删除和收藏"
    case basicTimeOrganizing = "按时间整理"
    case localCleanupHistory = "本机清理历史"
    case basicSpaceSavedStats = "基础节省空间统计"
    case fullTimeList = "完整时间列表"
    case largeFileCleanup = "大文件清理"
    case imageCompression = "图片压缩"
    case videoCompression = "视频压缩"
    case similarPhotoCleanup = "相似照片清理"

    var localizedTitle: String {
        switch self {
        case .randomReview: return L10n.string("Random Review")
        case .basicSwipeReview: return L10n.string("Basic Swipe Cleanup")
        case .confirmedDeleteAndFavorite: return L10n.string("Delete and Favorite After Confirmation")
        case .basicTimeOrganizing: return L10n.string("Organize by Time")
        case .localCleanupHistory: return L10n.string("Local cleanup history")
        case .basicSpaceSavedStats: return L10n.string("Basic Deleted Content Stats")
        case .fullTimeList: return L10n.string("Full Time Lists")
        case .largeFileCleanup: return L10n.string("Large File Cleanup")
        case .imageCompression: return L10n.string("Image Compression")
        case .videoCompression: return L10n.string("Video Compression")
        case .similarPhotoCleanup: return L10n.string("Similar Photo Cleanup")
        }
    }
}

private struct SupporterPlanComparisonRow: View {
    let model: SupporterPlanComparisonFeature

    var body: some View {
        HStack(spacing: PaywallDS.Space.md) {
            Text(model.title)
                .font(PaywallDS.Font.captionMedium)
                .foregroundColor(PaywallDS.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            availabilityCell(model.free)
            availabilityCell(model.supporter)
        }
        .padding(.horizontal, PaywallDS.Space.xl)
        .padding(.vertical, PaywallDS.Space.lg)
        .accessibilityElement(children: .combine)
    }

    private func availabilityCell(_ availability: SupporterPlanAvailability) -> some View {
        Image(systemName: availability.systemImage)
            .font(PaywallDS.Font.calloutSemibold)
            .foregroundColor(availability.tint)
            .frame(width: 64)
            .frame(minHeight: 24)
            .accessibilityLabel(availability.accessibilityLabel)
    }
}

enum SupporterPlanAvailability: Equatable {
    case included
    case notIncluded

    var systemImage: String {
        switch self {
        case .included: return "checkmark.circle.fill"
        case .notIncluded: return "minus"
        }
    }

    var tint: Color {
        switch self {
        case .included: return PaywallDS.Color.accent
        case .notIncluded: return PaywallDS.Color.textTertiary
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .included: return L10n.string("Included")
        case .notIncluded: return L10n.string("Not Included")
        }
    }
}

/// 付费页语境下的发丝分割线（白 12%）。
/// 成就页用的是琥珀语境的 `SupporterDivider`，两者不要互相替换。
struct PaywallDivider: View {
    var body: some View {
        Rectangle()
            .fill(PaywallDS.Color.borderSubtle)
            .frame(height: PaywallDS.Stroke.border)
            .padding(.leading, PaywallDS.Space.xl)
    }
}
