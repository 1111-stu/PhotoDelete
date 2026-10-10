import Photos
import SwiftUI

struct ReviewAlbumFilingSheet: View {
    let albums: [AlbumInfo]
    let selectedAlbumIDs: Set<String>
    let onToggle: (AlbumInfo) -> Void
    let onContinue: () -> Void

    @EnvironmentObject private var dataManager: DataManager
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                ScrollView {
                    LazyVStack(spacing: PhotoDeleteStyle.albumListCardSpacing) {
                        if filteredAlbums.isEmpty {
                            emptyState
                                .padding(.top, 36)
                        } else {
                            ForEach(filteredAlbums) { album in
                                FilingAlbumRow(
                                    album: album,
                                    isSelected: selectedAlbumIDs.contains(album.id),
                                    photoLibraryManager: dataManager.photoLibraryManager,
                                    onToggle: { onToggle(album) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
                    .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)

                continueButton
            }
            .background(Color.black)
            .navigationTitle(L10n.string("Which album?"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(PhotoDeleteStyle.tertiaryText)

            TextField(L10n.string("Search albums"), text: $searchText)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(PhotoDeleteStyle.primaryText)
                .tint(PhotoDeleteStyle.accent)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PhotoDeleteStyle.tertiaryText)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("Clear"))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PhotoDeleteStyle.elevatedSurface)
        )
        .accessibilityElement(children: .contain)
    }

    private var continueButton: some View {
        let isEnabled = !selectedAlbumIDs.isEmpty

        return Button(action: onContinue) {
            Text(isEnabled ? L10n.string("Done and Continue") : L10n.string("Nothing selected"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isEnabled ? PhotoDeleteStyle.primaryButtonText : PhotoDeleteStyle.primaryText.opacity(0.55))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: PhotoDeleteStyle.controlRadius, style: .continuous)
                        .fill(isEnabled ? PhotoDeleteStyle.accent : PhotoDeleteStyle.secondaryText.opacity(0.28))
                )
        }
        .buttonStyle(FilingContinueButtonStyle())
        .disabled(!isEnabled)
        .padding(.horizontal, PhotoDeleteStyle.screenHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color.black)
        .accessibilityIdentifier("review-album-filing-continue")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: searchText.isEmpty ? "rectangle.stack" : "magnifyingglass")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(PhotoDeleteStyle.tertiaryText)

            Text(searchText.isEmpty ? L10n.string("No Albums Yet") : L10n.string("No Albums Found"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PhotoDeleteStyle.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var filteredAlbums: [AlbumInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return albums }
        return albums.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}

// MARK: - Row

private struct FilingAlbumRow: View {
    let album: AlbumInfo
    let isSelected: Bool
    let photoLibraryManager: PhotoLibraryManager
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                FilingAlbumThumbnail(
                    assetID: album.thumbnailAsset?.localIdentifier,
                    emptyIcon: album.type.icon,
                    photoLibraryManager: photoLibraryManager
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PhotoDeleteStyle.primaryText)
                        .lineLimit(1)

                    Text(L10n.photoCount(album.photosCount))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(PhotoDeleteStyle.secondaryText)
                        .monospacedDigit()
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? PhotoDeleteStyle.accent : PhotoDeleteStyle.tertiaryText)
                    .frame(width: 28, height: 28)
                    .animation(.easeOut(duration: 0.14), value: isSelected)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: PhotoDeleteStyle.albumListCardMinHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PhotoDeleteStyle.albumListCardRadius, style: .continuous)
                    .fill(PhotoDeleteStyle.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: PhotoDeleteStyle.albumListCardRadius, style: .continuous)
                            .strokeBorder(
                                isSelected ? PhotoDeleteStyle.accent.opacity(0.42) : Color.clear,
                                lineWidth: 1
                            )
                    }
            )
            .contentShape(RoundedRectangle(cornerRadius: PhotoDeleteStyle.albumListCardRadius, style: .continuous))
        }
        .buttonStyle(FilingAlbumRowButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel("\(album.title), \(L10n.photoCount(album.photosCount))")
        .accessibilityHint(
            isSelected
                ? L10n.string("Deselect")
                : String(format: L10n.string("Add to %@"), album.title)
        )
    }
}

private struct FilingAlbumThumbnail: View {
    let assetID: String?
    let emptyIcon: String
    let photoLibraryManager: PhotoLibraryManager

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    private let size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(PhotoDeleteStyle.elevatedSurface)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.low)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .transaction { $0.animation = nil }
            } else {
                Image(systemName: emptyIcon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(PhotoDeleteStyle.secondaryText)
            }
        }
        .frame(width: size, height: size)
        .task(id: assetID) {
            await load()
        }
        .onDisappear {
            cancel()
        }
    }

    @MainActor
    private func load() async {
        cancel()
        guard let assetID else {
            image = nil
            return
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = assets.firstObject else {
            image = nil
            return
        }

        let scale = UIScreen.main.scale
        let target = CGSize(width: size * scale, height: size * scale)
        let manager = photoLibraryManager
        let requestBox = FilingThumbnailRequestBox()

        let loaded: UIImage? = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                var hasResumed = false
                let resumeOnce: (UIImage?) -> Void = { image in
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: image)
                }

                let id = manager.loadAlbumListThumbnail(for: asset, size: target) { image in
                    resumeOnce(image)
                }
                requestBox.id = id
                requestID = id
            }
        } onCancel: {
            if let id = requestBox.id {
                manager.cancelImageRequest(id)
            }
        }

        guard !Task.isCancelled else { return }
        image = loaded
    }

    private func cancel() {
        if let requestID {
            photoLibraryManager.cancelImageRequest(requestID)
        }
        requestID = nil
    }
}

// MARK: - Button styles

private struct FilingAlbumRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct FilingContinueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private final class FilingThumbnailRequestBox: @unchecked Sendable {
    var id: PHImageRequestID?
}
