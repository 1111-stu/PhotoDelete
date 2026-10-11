//
//  ContentView.swift
//  PhotoDelete
//
//  Created by jackie xiao on 11/7/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage(AppConstants.hasCompletedOnboardingKey) private var hasCompletedOnboarding = false
    @StateObject private var dataManager = DataManager()

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
                .environmentObject(dataManager)
        } else {
            OnboardingFlowView(
                onSkip: {
                    hasCompletedOnboarding = true
                },
                onRequestPhotoAccess: { completion in
                    dataManager.requestPhotoLibraryAccess(
                        opensSettingsIfDenied: false
                    ) { _ in
                        completion()
                    }
                },
                onComplete: {
                    hasCompletedOnboarding = true
                }
            )
        }
    }
}

private struct OnboardingFlowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPage = 0
    @State private var animateVisual = false
    @State private var isRequestingPhotoAccess = false

    let onSkip: () -> Void
    let onRequestPhotoAccess: (@escaping () -> Void) -> Void
    let onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "photo.on.rectangle.angled",
            title: L10n.string("Make photo cleanup simple"),
            message: L10n.string("Swipe quickly to decide what stays. Photos you want to delete go into a pending list first, and nothing is deleted until you finish."),
            visual: .organize
        ),
        OnboardingPage(
            icon: "hand.draw",
            title: L10n.string("Swipe left to delete, right to keep"),
            message: L10n.string("Swipe left to delete, right to keep, and up to favorite. Confirm everything at the end."),
            visual: .swipe
        ),
        OnboardingPage(
            icon: "externaldrive",
            title: L10n.string("Free up more space"),
            message: L10n.string("Similar photos, large files, video compression, and image compression are grouped under Advanced Cleanup for the items that really take space."),
            visual: .advanced
        ),
        OnboardingPage(
            icon: "lock.shield",
            title: L10n.string("Photos are not uploaded"),
            message: L10n.string("No account is needed, and photos are never uploaded. The system asks for photo access only on the final step."),
            visual: .privacy
        )
    ]

    var body: some View {
        ZStack {
            PhotoDeleteScreenBackground()

            VStack(spacing: 0) {
                OnboardingHeaderView(onSkip: onSkip)

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(
                            page: page,
                            index: index,
                            animateVisual: animateVisual && selectedPage == index
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 18) {
                    OnboardingPageIndicator(
                        pageCount: pages.count,
                        selectedPage: selectedPage
                    )

                    Button(action: advance) {
                        HStack(spacing: 8) {
                            if isRequestingPhotoAccess {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text(selectedPage == pages.count - 1 ? L10n.string("Choose Photo Access") : L10n.string("Continue"))

                            if !isRequestingPhotoAccess {
                                Image(systemName: selectedPage == pages.count - 1 ? "photo.badge.plus" : "arrow.right")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                    }
                    .photoDeletePrimaryButton()
                    .padding(.horizontal, 28)
                    .disabled(isRequestingPhotoAccess)
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            guard !reduceMotion else {
                animateVisual = true
                return
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.78).delay(0.12)) {
                animateVisual = true
            }
        }
        .onChange(of: selectedPage) { _ in
            guard !reduceMotion else {
                animateVisual = true
                return
            }
            animateVisual = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) {
                    animateVisual = true
                }
            }
        }
    }

    private func advance() {
        if selectedPage < pages.count - 1 {
            selectedPage += 1
        } else {
            guard !isRequestingPhotoAccess else { return }
            isRequestingPhotoAccess = true
            onRequestPhotoAccess {
                isRequestingPhotoAccess = false
                onComplete()
            }
        }
    }
}

private struct OnboardingHeaderView: View {
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text(AppConstants.appDisplayName)
                    .font(.callout.weight(.semibold))
            } icon: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.callout.weight(.semibold))
            }
            .foregroundStyle(Theme.primaryText)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.elevatedSurface)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Theme.hairline, lineWidth: 1)
                    )
            )

            Spacer()

            Button(action: onSkip) {
                Text(L10n.string("Skip"))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .photoDeleteMinimumTapTarget()
            .accessibilityHint(L10n.string("You can show this intro again later from Settings."))
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
    }
}

private struct OnboardingPageIndicator: View {
    let pageCount: Int
    let selectedPage: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == selectedPage ? Theme.accent : Theme.hairline)
                    .frame(width: index == selectedPage ? 24 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selectedPage)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.string("Intro pages"))
        .accessibilityValue(
            Text(
                String(
                    format: L10n.string("Page %lld of %lld"),
                    Int64(selectedPage + 1),
                    Int64(pageCount)
                )
            )
        )
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let message: String
    let visual: OnboardingVisual
    var linkTitle: String?
    var linkURL: URL?
}

private enum OnboardingVisual {
    case organize
    case swipe
    case advanced
    case privacy
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let index: Int
    let animateVisual: Bool

    var body: some View {
        GeometryReader { geometry in
            let verticalPadding = min(max(geometry.size.height * 0.035, 14), 26)
            let contentSpacing = min(max(geometry.size.height * 0.035, 22), 28)
            let visualWidth = min(max(geometry.size.width - 54, 248), 322)
            let visualHeight = min(max(geometry.size.height * 0.36, 220), 292)

            ScrollView {
                VStack(spacing: contentSpacing) {
                    OnboardingVisualView(page: page, animate: animateVisual)
                        .frame(width: visualWidth, height: visualHeight)
                        .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text(page.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                            .multilineTextAlignment(.center)

                        Text(page.message)
                            .font(.body)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        if let linkTitle = page.linkTitle, let linkURL = page.linkURL {
                            Link(destination: linkURL) {
                                Label(linkTitle, systemImage: "arrow.up.right")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                    .labelStyle(.titleAndIcon)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
                .frame(
                    minHeight: max(0, geometry.size.height - verticalPadding * 2),
                    alignment: .center
                )
                .padding(.vertical, verticalPadding)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scrollIndicators(.hidden)
        }
    }
}

private struct OnboardingVisualView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let page: OnboardingPage
    let animate: Bool

    var body: some View {
        Group {
            switch page.visual {
            case .organize:
                OrganizeIntroVisual(animate: animate)
            case .swipe:
                SwipeIntroVisual(animate: animate)
            case .advanced:
                AdvancedCleanupIntroVisual(animate: animate)
            case .privacy:
                PrivacyIntroVisual(animate: animate)
            }
        }
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
            }
        }
    }
}

private struct OrganizeIntroVisual: View {
    let animate: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
                .frame(width: 254, height: 238)

            VStack(spacing: 18) {
                ZStack {
                    MiniPhotoCard(symbol: "photo", tint: Theme.secondaryText)
                        .rotationEffect(.degrees(animate ? -10 : -4))
                        .offset(x: animate ? -46 : -22, y: animate ? 12 : 2)

                    MiniPhotoCard(symbol: "sparkles", tint: Theme.accent)
                        .rotationEffect(.degrees(animate ? 10 : 3))
                        .offset(x: animate ? 44 : 20, y: animate ? -10 : 0)

                    MiniPhotoCard(symbol: "checkmark.circle", tint: Theme.positive)
                        .scaleEffect(animate ? 0.9 : 1)
                        .offset(y: animate ? 48 : 0)
                }
                .frame(height: 162)

                HStack(spacing: 8) {
                    Image(systemName: "tray.full")
                    Text(L10n.string("Pending review"))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.primaryText.opacity(0.78))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(Theme.elevatedSurface)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Theme.hairline, lineWidth: 1)
                        )
                )
            }

            Capsule(style: .continuous)
                .fill(Theme.accent)
                .frame(width: animate ? 124 : 34, height: 5)
                .offset(y: 104)
        }
        .animation(.spring(response: 0.76, dampingFraction: 0.78), value: animate)
    }
}

private struct SwipeIntroVisual: View {
    let animate: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.surface.opacity(0.72))
                .frame(width: 194, height: 212)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )

            MiniPhotoCard(symbol: "photo", tint: Theme.primaryText.opacity(0.72), width: 122, height: 162)
                .overlay(
                    VStack {
                        Spacer()
                        HStack(spacing: 22) {
                            Image(systemName: "arrow.left")
                            Image(systemName: "arrow.up")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .padding(.bottom, 17)
                    }
                )
                .rotationEffect(.degrees(animate ? -5 : 4))
                .offset(x: animate ? -20 : 20, y: animate ? -4 : 5)

            swipeDestination(
                symbol: "arrow.left",
                direction: L10n.string("Swipe left"),
                action: L10n.string("Delete"),
                color: Theme.destructive,
                x: -118,
                y: 12
            )
            swipeDestination(
                symbol: "arrow.right",
                direction: L10n.string("Swipe right"),
                action: L10n.string("Keep"),
                color: Theme.positive,
                x: 118,
                y: 12
            )
            swipeDestination(
                symbol: "arrow.up",
                direction: L10n.string("Swipe up"),
                action: L10n.string("Favorite"),
                color: Theme.accent,
                x: 0,
                y: -106
            )
        }
        .animation(.spring(response: 0.72, dampingFraction: 0.84), value: animate)
    }

    private func swipeDestination(symbol: String, direction: String, action: String, color: Color, x: CGFloat, y: CGFloat) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))

            VStack(spacing: 1) {
                Text(direction)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.secondaryText)

                Text(action)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        }
        .foregroundColor(color)
        .frame(width: 82, height: 68)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(color.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(color.opacity(0.28), lineWidth: 1)
                )
        )
        .scaleEffect(animate ? 1 : 0.88)
        .opacity(animate ? 1 : 0.52)
        .offset(x: x, y: y)
        .animation(.spring(response: 0.72, dampingFraction: 0.86), value: animate)
    }
}

private struct AdvancedCleanupIntroVisual: View {
    let animate: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
                .frame(width: 262, height: 236)

            VStack(spacing: 10) {
                advancedToolRow(
                    icon: "square.stack.3d.down.right",
                    title: L10n.string("Similar Photos"),
                    tint: Theme.accent,
                    delayIndex: 0
                )

                advancedToolRow(
                    icon: "externaldrive",
                    title: L10n.string("Large Files"),
                    tint: Theme.warning,
                    delayIndex: 1
                )

                advancedToolRow(
                    icon: "video.badge.checkmark",
                    title: L10n.string("Video Compression"),
                    tint: Theme.positive,
                    delayIndex: 2
                )

                advancedToolRow(
                    icon: "photo.badge.arrow.down",
                    title: L10n.string("Image Compression"),
                    tint: Theme.accent,
                    delayIndex: 3
                )
            }
            .padding(.horizontal, 28)
        }
        .animation(.spring(response: 0.72, dampingFraction: 0.86), value: animate)
    }

    private func advancedToolRow(icon: String, title: String, tint: Color, delayIndex: Int) -> some View {
        HStack(spacing: 12) {
            PhotoDeleteIconTile(icon: icon, tint: tint, size: 34, cornerRadius: 10)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.primaryText)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
        )
        .offset(y: animate ? 0 : 16)
        .opacity(animate ? 1 : 0.35)
        .animation(.spring(response: 0.62, dampingFraction: 0.84).delay(Double(delayIndex) * 0.06), value: animate)
    }
}

private struct PrivacyIntroVisual: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animate: Bool

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Theme.accent.opacity(0.08 + Double(index) * 0.04), lineWidth: 1)
                    .frame(width: CGFloat(160 + index * 48), height: CGFloat(160 + index * 48))
                    .scaleEffect(animate ? 1.03 : 0.94)
                    .opacity(animate ? 1 : 0.5)
            }

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
                .frame(width: 210, height: 230)

            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.elevatedSurface)
                        .frame(width: 116, height: 94)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Theme.hairline, lineWidth: 1)
                        )

                    Image(systemName: "lock.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .scaleEffect(animate ? 1 : 0.92)
                        .shadow(color: Theme.accent.opacity(0.22), radius: animate ? 18 : 6, x: 0, y: 0)
                }

                HStack(spacing: 8) {
                    Image(systemName: "iphone")
                    Text(L10n.string("Done on your phone"))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.primaryText.opacity(0.76))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.72, dampingFraction: 0.86), value: animate)
    }
}

private struct MiniPhotoCard: View {
    let symbol: String
    let tint: Color
    var width: CGFloat = 112
    var height: CGFloat = 146

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Theme.elevatedSurface,
                        Theme.surface
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundColor(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .frame(width: width, height: height)
            .shadow(color: Theme.floatingShadow, radius: 12, x: 0, y: 7)
    }
}

#Preview {
    ContentView()
}
