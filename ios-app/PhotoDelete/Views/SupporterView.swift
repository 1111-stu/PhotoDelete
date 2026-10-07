//
//  SupporterView.swift
//  PhotoDelete
//
//  Created by PhotoDelete Team on 11/7/25.
//

import StoreKit
import SwiftUI

struct SupporterView: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingOfferCodeRedemption = false
    @State private var selectedPlan: SupporterPurchasePlan = .annual

    private var entitlementStatusMessage: String? {
        switch purchaseManager.entitlementState {
        case .verifying:
            L10n.string("Checking purchase status...")
        case .cachedOffline:
            L10n.string("Unlocked supporter features remain available offline. Status is confirmed automatically when online.")
        case .unknown, .verified, .locked:
            nil
        }
    }

    private var showsBottomActionBar: Bool {
        !purchaseManager.hasPaidSupporterAccess
    }

    private var contentBottomPadding: CGFloat {
        showsBottomActionBar ? 320 : 40
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PhotoDeleteScreenBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        if purchaseManager.hasPaidSupporterAccess {
                            SupporterUnlockedContent(
                                purchaseDate: purchaseManager.supporterPurchaseDate,
                                expirationDate: purchaseManager.supporterExpirationDate,
                                accessKind: purchaseManager.supporterAccessKind,
                                accessNotice: purchaseManager.isUsingCachedSupporterAccess ? entitlementStatusMessage : nil,
                                isLoading: purchaseManager.isLoading,
                                errorMessage: purchaseManager.errorMessage,
                                onRestore: {
                                    Task { await purchaseManager.restorePurchases() }
                                },
                                onRedeemCode: presentOfferCodeRedemption
                            )
                        } else if purchaseManager.isUsingTrialSupporterAccess {
                            SupporterTrialContent(
                                remainingDays: purchaseManager.supporterTrialDaysRemaining
                            )
                        } else {
                            SupporterPaywallContent(
                                canStartTrial: purchaseManager.canStartSupporterTrial
                            )
                        }
                    }
                    .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    .padding(.top, 20)
            .padding(.bottom, max(contentBottomPadding, PhotoDeleteStyle.Metrics.bottomChromeSpacing))
                    .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                    .frame(maxWidth: .infinity)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsBottomActionBar {
                    SupporterBottomActionBar(
                        isTrialActive: purchaseManager.isUsingTrialSupporterAccess,
                        canStartTrial: purchaseManager.canStartSupporterTrial,
                        selectedPlan: $selectedPlan,
                        annualPriceText: purchaseManager.supporterAnnualPriceText,
                        lifetimePriceText: purchaseManager.supporterLifetimePriceText,
                        isLoading: purchaseManager.isLoading,
                        statusMessage: purchaseManager.supporterTrialStatusText ?? entitlementStatusMessage,
                        errorMessage: purchaseManager.errorMessage,
                        onStartTrial: {
                            purchaseManager.startSupporterTrial()
                        },
                        onPurchase: {
                            Task { await purchaseManager.purchaseSupporter(plan: selectedPlan) }
                        },
                        onRestore: {
                            Task { await purchaseManager.restorePurchases() }
                        },
                        onRedeemCode: presentOfferCodeRedemption
                    )
                }
            }
            .navigationTitle(L10n.string("OnePhoto Pro"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if #available(iOS 16.3, *) {
                        Button(L10n.string("Redeem Code")) {
                            presentOfferCodeRedemption()
                        }
                        .foregroundColor(PhotoDeleteStyle.accent)
                        .accessibilityIdentifier("supporter-redeem-code-button")
                    }

                    Button(L10n.string("Done")) {
                        dismiss()
                    }
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                }
            }
        }
        .task {
            await purchaseManager.activateStoreKit()
        }
        .offerCodeRedemption(isPresented: $showingOfferCodeRedemption) { result in
            purchaseManager.handleOfferCodeRedemptionCompletion(result)
        }
    }

    private func presentOfferCodeRedemption() {
        showingOfferCodeRedemption = true
    }
}

private struct SupporterTrialContent: View {
    let remainingDays: Int

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(PhotoDeleteStyle.elevatedSurface)
                        .frame(width: 70, height: 70)

                    Image(systemName: "timer")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.accent)
                }

                VStack(spacing: 8) {
                    Text(L10n.string("3-Day Free Trial"))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.primaryText)

                    Text(String(format: L10n.string("%lld days left. Advanced cleanup and long-term statistics are available during the trial."), remainingDays))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }
            .padding(24)
            .photoDeleteCard()

            SupporterPlanComparisonCard()
        }
    }
}

private struct SupporterPaywallContent: View {
    let canStartTrial: Bool

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(PhotoDeleteStyle.elevatedSurface)
                        .frame(width: 70, height: 70)

                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.accent)
                }

                VStack(spacing: 8) {
                    Text(L10n.string("OnePhoto Pro"))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.primaryText)

                    Text(heroSubtitle)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }
            .padding(24)
            .photoDeleteCard()

            SupporterPlanComparisonCard()
        }
    }

    private var heroSubtitle: String {
        if canStartTrial {
            return L10n.string("Try advanced features free for 3 days, then choose Annual or Lifetime Pro.")
        }

        return L10n.string("Annual Pro and Lifetime Pro both unlock the full timeline, compression, and similar-photo cleanup.")
    }
}

private struct SupporterBottomActionBar: View {
    let isTrialActive: Bool
    let canStartTrial: Bool
    @Binding var selectedPlan: SupporterPurchasePlan
    let annualPriceText: String
    let lifetimePriceText: String
    let isLoading: Bool
    let statusMessage: String?
    let errorMessage: String?
    let onStartTrial: () -> Void
    let onPurchase: () -> Void
    let onRestore: () -> Void
    let onRedeemCode: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 11) {
                Capsule(style: .continuous)
                    .fill(PhotoDeleteStyle.hairline)
                    .frame(width: 38, height: 4)
                    .padding(.bottom, 2)

                HStack(spacing: 10) {
                    planButton(
                        plan: .annual,
                        title: L10n.string("Annual Pro"),
                        price: annualPriceText,
                        detail: L10n.string("Per year · Auto-renews")
                    )
                    planButton(
                        plan: .lifetime,
                        title: L10n.string("Lifetime Pro"),
                        price: lifetimePriceText,
                        detail: L10n.string("One purchase · Lifetime access")
                    )
                }

                if isTrialActive {
                    purchaseButton(style: .primary)
                } else if canStartTrial {
                    Button(action: onStartTrial) {
                        Label(L10n.string("Start 3-Day Free Trial"), systemImage: "timer")
                            .labelStyle(.titleAndIcon)
                    }
                    .photoDeletePrimaryButton()
                    .disabled(isLoading)

                    purchaseButton(style: .secondary)
                } else {
                    purchaseButton(style: .primary)
                }

                SupporterPurchaseAuxiliaryActionsRow(
                    isLoading: isLoading,
                    onRestore: onRestore,
                    onRedeemCode: onRedeemCode
                )

                Text(billingDisclosure)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                SupporterLegalLinksRow()

                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.warning)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: 360)
        .background(
            RoundedRectangle(cornerRadius: PhotoDeleteStyle.cardRadius, style: .continuous)
                .fill(PhotoDeleteStyle.background.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: PhotoDeleteStyle.cardRadius, style: .continuous)
                        .stroke(PhotoDeleteStyle.hairline, lineWidth: PhotoDeleteStyle.Metrics.cardStrokeWidth)
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private func purchaseButton(style: PurchaseButtonStyle) -> some View {
        let loadingTint: Color = style == .primary ? PhotoDeleteStyle.primaryButtonText : PhotoDeleteStyle.accent

        Button(action: onPurchase) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: loadingTint))
                        .scaleEffect(0.78)
                }
                Text(isLoading ? L10n.string("Processing...") : purchaseButtonTitle)
            }
        }
        .modifier(PurchaseButtonModifier(style: style))
        .disabled(isLoading)
    }

    private var purchaseButtonTitle: String {
        switch selectedPlan {
        case .annual:
            String(format: L10n.string("Start Annual Pro %@/year"), annualPriceText)
        case .lifetime:
            String(format: L10n.string("Unlock Lifetime Pro %@"), lifetimePriceText)
        }
    }

    private var billingDisclosure: String {
        if isTrialActive || canStartTrial {
            return L10n.string("The 3-day trial does not charge you. Annual Pro auto-renews and can be canceled anytime in Apple ID settings. Basic cleanup is always free.")
        }

        return String(
            format: L10n.string("Annual Pro is %@/year. Billing starts when you confirm and renews automatically unless canceled in Apple ID settings. Lifetime Pro is a one-time purchase. Basic cleanup remains free."),
            annualPriceText
        )
    }

    private func planButton(
        plan: SupporterPurchasePlan,
        title: String,
        price: String,
        detail: String
    ) -> some View {
        let isSelected = selectedPlan == plan

        return Button {
            selectedPlan = plan
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(isSelected ? PhotoDeleteStyle.accent : PhotoDeleteStyle.primaryText)

                Text(price)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)

                Text(detail)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                    .fill(isSelected ? PhotoDeleteStyle.accent.opacity(0.1) : PhotoDeleteStyle.elevatedSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                            .stroke(isSelected ? PhotoDeleteStyle.accent : PhotoDeleteStyle.hairline, lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel("\(title); \(price); \(detail)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SupporterPurchaseAuxiliaryActionsRow: View {
    let isLoading: Bool
    let onRestore: () -> Void
    let onRedeemCode: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            auxiliaryButton(
                title: L10n.string("Restore Purchase"),
                systemImage: "arrow.clockwise",
                action: onRestore
            )

            if #available(iOS 16.3, *) {
                auxiliaryButton(
                    title: L10n.string("Redeem Code"),
                    systemImage: "ticket",
                    action: onRedeemCode
                )
                .accessibilityIdentifier("supporter-redeem-code-action")
            }
        }
    }

    private func auxiliaryButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: PhotoDeleteStyle.Metrics.thumbnailRadius, style: .continuous)
                        .fill(PhotoDeleteStyle.elevatedSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: PhotoDeleteStyle.Metrics.thumbnailRadius, style: .continuous)
                                .stroke(PhotoDeleteStyle.hairline, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(title)
    }
}

struct SupporterLegalLinksRow: View {
    var body: some View {
        HStack(spacing: 8) {
            Link(L10n.string("Privacy Policy"), destination: AppConstants.privacyPolicyURL)
                .accessibilityIdentifier("supporter-privacy-policy-link")

            Text("·")
                .accessibilityHidden(true)

            Link(L10n.string("Terms of Use"), destination: AppConstants.termsOfUseURL)
                .accessibilityIdentifier("supporter-terms-of-use-link")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(PhotoDeleteStyle.secondaryText)
    }
}

private enum PurchaseButtonStyle {
    case primary
    case secondary
}

private struct PurchaseButtonModifier: ViewModifier {
    let style: PurchaseButtonStyle

    func body(content: Content) -> some View {
        switch style {
        case .primary:
            content.photoDeletePrimaryButton()
        case .secondary:
            content.photoDeleteSecondaryButton()
        }
    }
}

private struct SupporterUnlockedContent: View {
    let purchaseDate: Date?
    let expirationDate: Date?
    let accessKind: SupporterAccessKind?
    let accessNotice: String?
    let isLoading: Bool
    let errorMessage: String?
    let onRestore: () -> Void
    let onRedeemCode: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            SupporterBadgeCard(accessKind: accessKind)

            SupporterPurchaseStatusCard(
                purchaseDate: purchaseDate,
                expirationDate: expirationDate,
                accessKind: accessKind
            )

            if let accessNotice {
                SupporterEntitlementNotice(message: accessNotice)
            }

            VStack(spacing: 10) {
                SupporterPurchaseAuxiliaryActionsRow(
                    isLoading: isLoading,
                    onRestore: onRestore,
                    onRedeemCode: onRedeemCode
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.warning)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .photoDeleteCard()

            SupporterPlanComparisonCard()
        }
    }
}

private struct SupporterEntitlementNotice: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.accent)

            Text(message)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(PhotoDeleteStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .photoDeleteCard()
    }
}

private struct SupporterBadgeCard: View {
    let accessKind: SupporterAccessKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(PhotoDeleteStyle.accent.opacity(0.18))
                        .frame(width: 54, height: 54)

                    Image(systemName: "seal.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(accessKind == .annual ? L10n.string("Annual Pro Active") : L10n.string("Lifetime Pro Unlocked"))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.primaryText)

                    Text(accessKind == .annual ? L10n.string("All advanced features are available while your subscription is active.") : L10n.string("One purchase gives you lifetime access to all advanced features."))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .photoDeleteCard()
    }
}

private struct SupporterPurchaseStatusCard: View {
    let purchaseDate: Date?
    let expirationDate: Date?
    let accessKind: SupporterAccessKind?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.positive)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.string("Purchase status"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)

                Text(statusText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .photoDeleteCard()
    }

    private var statusText: String {
        if accessKind == .annual {
            guard let expirationDate else {
                return L10n.string("Annual Pro is active. Subscription status is updated automatically by the App Store.")
            }
            return String(
                format: L10n.string("Annual Pro is currently active through %@. Renewal status is provided by the App Store."),
                CleanupStatsFormatter.sessionDate.string(from: expirationDate)
            )
        }

        guard let purchaseDate else {
            return L10n.string("Lifetime Pro is unlocked. All advanced features are available permanently.")
        }
        return String(
            format: L10n.string("Lifetime Pro was unlocked on %@ and remains available permanently."),
            CleanupStatsFormatter.sessionDate.string(from: purchaseDate)
        )
    }
}

private struct SupporterMetricCard: View {
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
        .init(titleID: .similarPhotoCleanup, free: .notIncluded, supporter: .included),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.string("Plan Comparison"))
                .font(.headline)
                .foregroundColor(PhotoDeleteStyle.primaryText)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

            HStack(spacing: 10) {
                Text(L10n.string("Feature"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(L10n.string("Free"))
                    .frame(width: 64)
                Text(L10n.string("Pro"))
                    .frame(width: 64)
            }
            .font(.caption.bold())
            .foregroundColor(PhotoDeleteStyle.secondaryText)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            ForEach(Self.features) { row in
                SupporterPlanComparisonRow(model: row)
                if row.id != Self.features.last?.id {
                    SupporterDivider()
                }
            }
        }
        .photoDeleteCard()
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
        HStack(spacing: 10) {
            Text(model.title)
                .font(.subheadline)
                .foregroundColor(PhotoDeleteStyle.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            availabilityCell(model.free)
            availabilityCell(model.supporter)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func availabilityCell(_ availability: SupporterPlanAvailability) -> some View {
        Image(systemName: availability.systemImage)
            .font(.system(size: 15, weight: .semibold))
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
        case .included: return PhotoDeleteStyle.accent
        case .notIncluded: return PhotoDeleteStyle.tertiaryText
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .included: return L10n.string("Included")
        case .notIncluded: return L10n.string("Not Included")
        }
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

struct SupporterBenefitsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PhotoDeleteScreenBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        Text(L10n.string("Random, swipe, and time-based cleanup are free. Supporters also unlock the full timeline, image and video compression, large-file cleanup, and similar-photo cleanup."))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(PhotoDeleteStyle.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        SupporterPlanComparisonCard()
                    }
                    .padding(PhotoDeleteStyle.screenHorizontalPadding)
                }
            }
            .navigationTitle(L10n.string("Feature differences"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) {
                        dismiss()
                    }
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                }
            }
        }
    }
}

struct CleanupHistoryView: View {
    @ObservedObject var statsStore: CleanupStatsStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearConfirmation = false

    private var summary: CleanupStatsSummary {
        statsStore.summary
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PhotoDeleteScreenBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            SupporterMetricCard(value: "\(summary.organizedPhotos)", label: L10n.string("Total Reviewed"), tint: PhotoDeleteStyle.accent)
                            SupporterMetricCard(value: "\(summary.deletedPhotos)", label: L10n.string("Total Deleted"), tint: PhotoDeleteStyle.destructive)
                            SupporterMetricCard(value: summary.formattedSpaceSaved, label: L10n.string("Deleted Content"), tint: PhotoDeleteStyle.positive)
                            SupporterMetricCard(value: "\(summary.sessions)", label: L10n.string("Cleanup Sessions"), tint: PhotoDeleteStyle.warning)
                        }

                        SupporterMonthlySection(summaries: statsStore.monthlySummaries)

                        SupporterHistorySection(sessions: Array(statsStore.sessions.prefix(50)))

                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Text(L10n.string("Clear Stats"))
                                .frame(maxWidth: .infinity)
                        }
                        .photoDeleteSecondaryButton()
                    }
                    .padding(PhotoDeleteStyle.screenHorizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(L10n.string("Cleanup History"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("Done")) {
                        dismiss()
                    }
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                }
            }
        }
        .confirmationDialog(L10n.string("Clear local stats?"), isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button(L10n.string("Clear Stats"), role: .destructive) {
                statsStore.clearAll()
            }
            Button(L10n.string("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("This only clears OnePhoto's local stats. Your photos are not affected."))
        }
    }
}

#Preview {
    SupporterView()
        .environmentObject(DataManager())
        .environmentObject(PurchaseManager())
}
