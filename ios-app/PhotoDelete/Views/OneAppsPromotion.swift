//
//  OneAppsPromotion.swift
//  PhotoDelete
//
//  One Apps Studio catalog entry + dedicated "More Apps" page.
//  Layout mirrors OneAppsKit's catalog link → catalog page pattern.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum OneAppsPromotionCatalog {
    static let studioURL = URL(string: "https://oneapps.studio")!
    static let appsURL = URL(string: "https://oneapps.studio/apps")!

    /// Public One Apps products plus related MakerJackie apps we still promote.
    static let apps: [OneAppsPromotionItem] = [
        .init(
            id: "onescan",
            name: "OneScan",
            systemImage: "doc.viewfinder",
            assetImageName: "OneAppsIcon_onescan",
            subtitleKey: "PDF scanning",
            summaryKey: "Scan paper documents, keep recent scans locally, and export clear PDFs when needed.",
            appStoreURL: URL(string: "https://apps.apple.com/app/id6788495535"),
            productURL: URL(string: "https://oneapps.studio/apps/onescan")!
        ),
        .init(
            id: "onehabit",
            name: "OneHabit",
            systemImage: "checkmark.circle",
            assetImageName: "OneAppsIcon_onehabit",
            subtitleKey: "Habit tracking",
            summaryKey: "Build habits that fit real life with flexible plans, clear progress, and iCloud sync.",
            appStoreURL: URL(string: "https://apps.apple.com/app/id6788409678"),
            productURL: URL(string: "https://oneapps.studio/apps/onehabit")!
        ),
        .init(
            id: "onefocus",
            name: "OneFocus",
            systemImage: "timer",
            assetImageName: "OneAppsIcon_onefocus",
            subtitleKey: "Focus across Apple devices",
            summaryKey: "Start one focus session across iPhone, iPad, and Mac with honest protection status.",
            appStoreURL: URL(string: "https://apps.apple.com/app/id6790143964"),
            productURL: URL(string: "https://oneapps.studio/apps/onefocus")!
        ),
        .init(
            id: "onetune",
            name: "OneTune",
            systemImage: "tuningfork",
            assetImageName: "OneAppsIcon_onetune",
            subtitleKey: "Tuner and metronome",
            summaryKey: "An offline instrument tuner with visual guidance, a metronome, and common chords.",
            appStoreURL: URL(string: "https://apps.apple.com/app/id6789659103"),
            productURL: URL(string: "https://oneapps.studio/apps/onetune")!
        ),
        .init(
            id: "oneuke",
            name: "OneUke",
            systemImage: "guitars.fill",
            assetImageName: "OneAppsIcon_oneuke",
            subtitleKey: "Ukulele for absolute beginners",
            summaryKey: "Start with tuning, rhythm, and chords, then play your first familiar melody.",
            appStoreURL: URL(string: "https://apps.apple.com/app/id6783200326"),
            productURL: URL(string: "https://oneapps.studio/apps/oneuke")!
        ),
        .init(
            id: "onemarkup",
            name: "OneMarkup",
            systemImage: "text.page.badge.magnifyingglass",
            assetImageName: "OneAppsIcon_onemarkup",
            subtitleKey: "Markdown & HTML editor",
            summaryKey: "Open, edit, and share Markdown, HTML, SVG, and plain text. Content is processed locally and works offline.",
            appStoreURL: URL(string: "https://apps.apple.com/app/id6792251542"),
            productURL: URL(string: "https://oneapps.studio/apps/onemarkup")!
        ),
        .init(
            id: "onevoice",
            name: "OneVoice",
            systemImage: "waveform",
            assetImageName: "OneAppsIcon_onevoice",
            subtitleKey: "Record and transcribe voice",
            summaryKey: "Record, transcribe offline, and sync across Apple devices with iCloud.",
            appStoreURL: URL(string: "https://apps.apple.com/app/id6789639056"),
            productURL: URL(string: "https://oneapps.studio/apps/onevoice")!
        ),
        .init(
            id: "oneround",
            name: "OneRound",
            systemImage: "person.2.circle.fill",
            assetImageName: "OneAppsIcon_oneround",
            subtitleKey: "Local two-player games",
            summaryKey: "Ten illustrated games for two nearby iPhones, with no internet or account required.",
            appStoreURL: nil,
            productURL: URL(string: "https://oneapps.studio/apps/oneround")!
        ),
        .init(
            id: "oneposture",
            name: "OnePosture",
            systemImage: "figure.stand",
            assetImageName: "OneAppsIcon_oneposture",
            subtitleKey: "Local posture reminders",
            summaryKey: "Monitor posture on your device with fewer false alerts and reliable reminders.",
            appStoreURL: nil,
            productURL: URL(string: "https://oneapps.studio/apps/oneposture")!
        ),
        .init(
            id: "onezen",
            name: "OneZen",
            systemImage: "leaf.fill",
            assetImageName: "OneZenAppIcon",
            subtitleKey: "Meditation, breathing, and focus",
            summaryKey: "Short meditation and breathing practices to help you settle more quickly.",
            appStoreURL: URL(string: "https://apps.apple.com/app/id6780318004"),
            productURL: URL(string: "https://oneapps.studio")!
        )
    ]

    static func open(_ item: OneAppsPromotionItem) {
        open(item.destinationURL)
    }

    static func openStudio() {
        open(studioURL)
    }

    static func openAllApps() {
        open(appsURL)
    }

    private static func open(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

struct OneAppsPromotionItem: Identifiable, Equatable {
    let id: String
    let name: String
    let systemImage: String
    var assetImageName: String? = nil
    let subtitleKey: String
    let summaryKey: String
    let appStoreURL: URL?
    let productURL: URL

    var destinationURL: URL {
        appStoreURL ?? productURL
    }

    var subtitle: String {
        L10n.key(subtitleKey)
    }

    var summary: String {
        L10n.key(summaryKey)
    }
}

// MARK: - Settings entry (card only)

/// Settings entry that matches OneAppsKit's "More Apps" catalog link.
struct OneAppsPromotionSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.string("More Apps"))
                    .settingsSectionHeading()
                Spacer()
            }

            NavigationLink {
                OneAppsCatalogPage()
            } label: {
                HStack(spacing: 12) {
                    Image("OneAppsStudioLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(SettingsChrome.divider, lineWidth: 1)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.string("One Apps Studio"))
                            .settingsRowTitle()
                            .lineLimit(1)

                        Text(L10n.string("A series of simple, useful apps"))
                            .settingsRowValue()
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SettingsChrome.muted)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(minHeight: SettingsChrome.rowMinHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .settingsGroupedCard()
            .accessibilityIdentifier("settings-oneapps-catalog-entry")
            .accessibilityHint(L10n.string("Opens the full app list"))
        }
    }
}

// MARK: - Dedicated catalog page

struct OneAppsCatalogPage: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            PhotoDeleteScreenBackground()

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(OneAppsPromotionCatalog.apps) { app in
                        NavigationLink {
                            OneAppsCatalogDetailPage(item: app)
                        } label: {
                            OneAppsCatalogAppRow(item: app)
                        }
                        .buttonStyle(.plain)
                    }

                    studioFooterCard
                        .padding(.top, 8)
                }
                .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 28)
                .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(L10n.string("More Apps"))
        .navigationBarTitleDisplayMode(.large)
    }

    private var studioFooterCard: some View {
        Button(action: OneAppsPromotionCatalog.openStudio) {
            VStack(spacing: 14) {
                Image("OneAppsStudioLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PhotoDeleteStyle.hairline, lineWidth: 1)
                    )
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text(L10n.string("One Apps Studio"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(PhotoDeleteStyle.primaryText)

                    Text(L10n.string("Independent apps that are focused, simple, and easy to use."))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(L10n.string("Each app solves one small pain point, with unlimited core features and no ads."))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.tertiaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 6) {
                    Text(L10n.string("Visit OneApps.Studio"))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(PhotoDeleteStyle.accent)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .photoDeleteCard()
        .accessibilityIdentifier("settings-oneapps-studio-link")
    }
}

// MARK: - App detail

struct OneAppsCatalogDetailPage: View {
    let item: OneAppsPromotionItem
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack {
            PhotoDeleteScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        OneAppsCatalogIcon(item: item, size: 64)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.name)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(PhotoDeleteStyle.primaryText)

                            Text(item.subtitle)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(PhotoDeleteStyle.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text(item.summary)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(PhotoDeleteStyle.primaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .photoDeleteCard()

                    Button {
                        OneAppsPromotionCatalog.open(item)
                    } label: {
                        HStack(spacing: 8) {
                            Text(
                                item.appStoreURL == nil
                                    ? L10n.string("View product page")
                                    : L10n.string("View on the App Store")
                            )
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .photoDeletePrimaryButton()
                    .accessibilityIdentifier("settings-oneapps-\(item.id)-open")
                }
                .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 28)
                .frame(maxWidth: PhotoDeleteAdaptiveLayout.readableContentMaxWidth(horizontalSizeClass: horizontalSizeClass))
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shared rows / icons

private struct OneAppsCatalogAppRow: View {
    let item: OneAppsPromotionItem

    var body: some View {
        HStack(spacing: 14) {
            OneAppsCatalogIcon(item: item, size: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(PhotoDeleteStyle.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PhotoDeleteStyle.tertiaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .contentShape(Rectangle())
        .photoDeleteCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.name))
        .accessibilityValue(Text(item.subtitle))
        .accessibilityIdentifier("settings-oneapps-\(item.id)-row")
    }
}

private struct OneAppsCatalogIcon: View {
    let item: OneAppsPromotionItem
    let size: CGFloat

    var body: some View {
        Group {
            if let assetImageName = item.assetImageName {
                Image(assetImageName)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: item.systemImage)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(PhotoDeleteStyle.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PhotoDeleteStyle.accent.opacity(0.12))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .stroke(PhotoDeleteStyle.hairline, lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }
}
