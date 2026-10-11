import SwiftUI
import Photos

/// Browsing does not record a cleanup decision or stage a Photos operation.
struct AssetReadOnlyPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?
    @State private var isLoading = true
    @State private var loadGeneration = 0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black
                    if asset.mediaType == .video {
                        PhotoAssetVideoPlayerView(asset: asset, photoLibraryManager: photoLibraryManager,
                                                  ignoresSafeArea: false, allowsPlayerInteraction: true)
                    } else if let image {
                        ZoomablePhotoPreview(image: image)
                    } else if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Button(L10n.string("Retry")) { loadImage(in: geometry.size) }
                            .tint(Theme.accent)
                    }
                }
                .task { if asset.mediaType != .video { loadImage(in: geometry.size) } }
            }
            .background(.black)
            .navigationTitle(asset.creationDate.map { AppDateFormatter.string(from: $0, template: "yMMMd") } ?? L10n.string("No date"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.string("Close")) { dismiss() }
                        .accessibilityIdentifier("cleanup-preview-close")
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onDisappear {
            loadGeneration += 1
            photoLibraryManager.cancelImageRequest(requestID)
            requestID = nil
        }
    }

    private func loadImage(in size: CGSize) {
        photoLibraryManager.cancelImageRequest(requestID)
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        requestID = photoLibraryManager.loadImage(for: asset, size: CGSize(width: size.width * displayScale, height: size.height * displayScale)) { loaded in
            guard generation == loadGeneration else { return }
            image = loaded
            isLoading = false
        }
    }
}
