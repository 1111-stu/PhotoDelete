//
//  EmptyRecentlyDeletedGuideView.swift
//  PhotoDelete
//
//  Guides users to empty system Recently Deleted so storage is actually freed.
//  OnePhoto cannot permanently purge that album via public PhotoKit APIs.
//

import SwiftUI

struct EmptyRecentlyDeletedGuideView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    private var reclaim: PendingReclaimState {
        dataManager.pendingReclaim
    }

    var body: some View {
        ZStack {
            PhotoDeleteScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    stepsCard
                    footnote
                }
                .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(L10n.string("Empty Recently Deleted"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button(action: openPhotosApp) {
                    Label(L10n.string("Open Photos"), systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .photoDeletePrimaryButton()

                if reclaim.hasPendingItems {
                    Button {
                        dataManager.clearPendingReclaim()
                        dismiss()
                    } label: {
                        Label(L10n.string("I've emptied it"), systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .photoDeleteSecondaryButton()
                }
            }
            .modifier(CleanupReviewFooterStyle())
        }
        .onAppear {
            dataManager.refreshPendingReclaimIfNeeded()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: reclaim.hasPendingItems ? "trash.fill" : "trash.slash")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(PhotoDeleteStyle.warning)
                    .frame(width: 52, height: 52)
                    .background(PhotoDeleteStyle.warning.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    if reclaim.hasPendingItems {
                        Text(L10n.string("About \(reclaim.formattedSpace) still in Recently Deleted"))
                            .font(.title3.weight(.bold))
                            .foregroundColor(PhotoDeleteStyle.primaryText)
                        Text(L10n.string("\(reclaim.itemCount) items from OnePhoto deletions"))
                            .font(.subheadline)
                            .foregroundColor(PhotoDeleteStyle.secondaryText)
                    } else {
                        Text(L10n.string("No tracked items to reclaim"))
                            .font(.title3.weight(.bold))
                            .foregroundColor(PhotoDeleteStyle.primaryText)
                        Text(L10n.string("After you confirm deletions in OnePhoto, space estimates appear here until you empty Recently Deleted."))
                            .font(.subheadline)
                            .foregroundColor(PhotoDeleteStyle.secondaryText)
                    }
                }
            }

            Text(L10n.string("Deleted photos stay in the system Recently Deleted album for 30 days. Empty that album in Photos to free storage now."))
                .font(.subheadline)
                .foregroundColor(PhotoDeleteStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .photoDeleteCard()
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("How to empty it"))
                .font(.headline.weight(.semibold))
                .foregroundColor(PhotoDeleteStyle.primaryText)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(guideSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(PhotoDeleteStyle.accent, in: Circle())

                        Text(step)
                            .font(.subheadline)
                            .foregroundColor(PhotoDeleteStyle.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(18)
        .photoDeleteCard()
    }

    private var footnote: some View {
        Text(L10n.string("OnePhoto can't empty Recently Deleted for you — Apple keeps that step in the Photos app."))
            .font(.footnote)
            .foregroundColor(PhotoDeleteStyle.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var guideSteps: [String] {
        if #available(iOS 26.0, *) {
            return [
                L10n.string("Open the Photos app and tap Collections."),
                L10n.string("Scroll to Utilities, then open Recently Deleted."),
                L10n.string("Unlock with Face ID, Touch ID, or your passcode if asked."),
                L10n.string("Tap Select, then Delete All, and confirm.")
            ]
        }
        return [
            L10n.string("Open the Photos app and go to Albums."),
            L10n.string("Scroll to Utilities, then open Recently Deleted."),
            L10n.string("Unlock with Face ID, Touch ID, or your passcode if asked."),
            L10n.string("Tap Select, then Delete All, and confirm.")
        ]
    }

    private func openPhotosApp() {
        // Open Photos at its root. Deep-linking into Recently Deleted is undocumented
        // and intentionally deferred until product decides on App Review risk.
        let candidates = ["photos-navigation://", "photos://"].compactMap(URL.init(string:))
        for url in candidates {
            UIApplication.shared.open(url)
            return
        }
    }
}
