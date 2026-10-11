import SwiftUI
import Photos
import PhotosUI

/// Browsing does not record a cleanup decision or stage a Photos operation.
struct AssetReadOnlyPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @AppStorage(AppConstants.reviewLivePhotoAutoPlayKey) private var reviewLivePhotoAutoPlay = false
    @AppStorage(AppConstants.reviewVideoMutedKey) private var reviewVideoMuted = true

    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager

    @State private var image: UIImage?
    @State private var livePhoto: PHLivePhoto?
    @State private var imageRequestID: PHImageRequestID?
    @State private var livePhotoRequestID: PHImageRequestID?
    @State private var isLoading = true
    @State private var loadGeneration = 0
    @State private var viewportSize: CGSize = .zero
    @State private var failedToLoadLivePhoto = false
    @State private var isLivePhotoMotionEnabled = false
    @State private var livePhotoPlaybackTrigger = 0

    private var isLivePhotoAsset: Bool {
        photoLibraryManager.isLivePhoto(asset)
    }

    private var shouldShowLivePhotoPlayback: Bool {
        isLivePhotoAsset && isLivePhotoMotionEnabled && livePhoto != nil && !failedToLoadLivePhoto
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black
                    previewContent(in: geometry.size)
                }
                .overlay(alignment: .bottomTrailing) {
                    if isLivePhotoAsset {
                        LivePhotoMotionControlButton(
                            isEnabled: isLivePhotoMotionEnabled,
                            isLoading: livePhotoRequestID != nil && livePhoto == nil
                        ) {
                            toggleLivePhotoMotion()
                        }
                        .padding(20)
                        .accessibilityIdentifier("cleanup-preview-live-motion")
                    }
                }
                .onAppear {
                    viewportSize = geometry.size
                    prepareInitialMotionPreference()
                    reload(in: geometry.size)
                }
                .onChange(of: geometry.size) { size in
                    viewportSize = size
                }
            }
            .background(.black)
            .navigationTitle(navigationTitle)
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
            invalidatePendingLoads()
        }
    }

    @ViewBuilder
    private func previewContent(in size: CGSize) -> some View {
        if asset.mediaType == .video {
            PhotoAssetVideoPlayerView(
                asset: asset,
                photoLibraryManager: photoLibraryManager,
                ignoresSafeArea: false,
                allowsPlayerInteraction: true
            )
        } else if shouldShowLivePhotoPlayback, let livePhoto {
            LivePhotoPreviewRepresentable(
                livePhoto: livePhoto,
                contentIdentifier: asset.localIdentifier,
                autoPlay: isLivePhotoMotionEnabled,
                isMuted: reviewVideoMuted,
                playbackTrigger: livePhotoPlaybackTrigger,
                contentMode: .scaleAspectFit
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(L10n.string("Live Photos"))
            .accessibilityIdentifier("cleanup-preview-live-photo")
        } else if let image {
            ZoomablePhotoPreview(image: image)
                .accessibilityLabel(
                    isLivePhotoAsset
                        ? L10n.string("Live Photos")
                        : L10n.string("Enlarged photo")
                )
        } else if isLoading {
            ProgressView().tint(.white)
        } else {
            Button(L10n.string("Retry")) { reload(in: size) }
                .tint(Theme.accent)
        }
    }

    private var navigationTitle: String {
        if isLivePhotoAsset {
            return L10n.string("Live Photos")
        }
        return asset.creationDate.map { AppDateFormatter.string(from: $0, template: "yMMMd") } ?? L10n.string("No date")
    }

    private func prepareInitialMotionPreference() {
        isLivePhotoMotionEnabled = LivePhotoPlaybackDefaultPolicy.initialMotionEnabled(
            isLivePhoto: isLivePhotoAsset,
            autoPlayPreference: reviewLivePhotoAutoPlay
        )
        livePhotoPlaybackTrigger = 0
        failedToLoadLivePhoto = false
        livePhoto = nil
    }

    private func reload(in size: CGSize) {
        invalidatePendingLoads()
        let generation = loadGeneration
        isLoading = true
        image = nil

        if asset.mediaType == .video {
            isLoading = false
            return
        }

        loadImage(in: size, generation: generation)
        if isLivePhotoAsset, isLivePhotoMotionEnabled {
            loadLivePhoto(in: size, generation: generation)
        }
    }

    private func loadImage(in size: CGSize, generation: Int) {
        let targetSize = photoPreviewTargetSize(for: asset, viewport: size, displayScale: displayScale)
        imageRequestID = photoLibraryManager.loadHighQualityPreview(
            for: asset,
            size: targetSize,
            networkAccessAllowed: true
        ) { loaded in
            guard generation == loadGeneration else { return }
            image = loaded
            isLoading = false
            imageRequestID = nil
        }
    }

    private func loadLivePhoto(in size: CGSize, generation: Int) {
        guard isLivePhotoAsset, livePhotoRequestID == nil, !failedToLoadLivePhoto else { return }
        let targetSize = photoPreviewTargetSize(for: asset, viewport: size, displayScale: displayScale)
        livePhotoRequestID = photoLibraryManager.loadLivePhotoResult(
            for: asset,
            size: targetSize,
            networkAccessAllowed: CandidateLivePhotoPreviewPolicy.networkAccessAllowed,
            deliveryMode: CandidateLivePhotoPreviewPolicy.deliveryMode
        ) { result in
            guard generation == loadGeneration else { return }

            if let loadedLivePhoto = result.livePhoto,
               CandidateLivePhotoPreviewPolicy.shouldDisplayLivePhoto(isDegraded: result.isDegraded) {
                livePhoto = loadedLivePhoto
                isLoading = false
            } else if result.isFinal, livePhoto == nil {
                failedToLoadLivePhoto = true
                isLoading = image == nil
            }

            if result.isFinal {
                livePhotoRequestID = nil
            }
        }
    }

    private func toggleLivePhotoMotion() {
        guard isLivePhotoAsset else { return }
        isLivePhotoMotionEnabled = LivePhotoPlaybackDefaultPolicy.motionEnabledAfterManualAction(
            current: isLivePhotoMotionEnabled,
            previousLoadFailed: failedToLoadLivePhoto
        )

        guard isLivePhotoMotionEnabled else { return }
        livePhotoPlaybackTrigger += 1
        failedToLoadLivePhoto = false
        if livePhoto == nil {
            let size = viewportSize == .zero ? CGSize(width: 390, height: 844) : viewportSize
            loadLivePhoto(in: size, generation: loadGeneration)
        }
    }

    private func invalidatePendingLoads() {
        loadGeneration += 1
        photoLibraryManager.cancelImageRequest(imageRequestID)
        photoLibraryManager.cancelImageRequest(livePhotoRequestID)
        imageRequestID = nil
        livePhotoRequestID = nil
    }
}
