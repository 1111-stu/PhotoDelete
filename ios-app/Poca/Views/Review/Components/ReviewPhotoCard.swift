import SwiftUI
import Photos
import UIKit

struct ReviewPhotoDetailLine: View {
    let asset: PHAsset


    /// 只展示日期。照片大小要异步读原图数据，切换照片时必然晚一拍出现，
    /// 补上去的那一下会把居中整行撑开、看起来在左右跳，所以干脆不展示。
    var body: some View {
        Text(PhotoAssetMetadataFormatter.shortCaptureDate(for: asset.creationDate))
            .font(.system(size: 11, weight: .regular))
            .monospacedDigit()
            .foregroundColor(Theme.tertiaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
    }
}

/// 整理页照片框的承托面：对角渐变 + 参考图上的细斜纹。
struct ReviewPhotoSurfaceBackground: View {
    var cornerRadius: CGFloat = Theme.radiusMd

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Theme.reviewPhotoSurfaceTop,
                        Theme.reviewPhotoSurfaceBottom
                    ],
                    // 实测参考图：水平变化约为垂直的 0.54 倍，右上 ≈35%、左下 ≈65%。
                    startPoint: UnitPoint(x: 0, y: 0),
                    endPoint: UnitPoint(x: 0.64, y: 1.19)
                )
            )
            .overlay {
                ReviewPhotoSurfaceTexture()
                    .clipShape(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            }
    }
}

/// 参考图渐变上隐约可见的 145° 斜纹：约 36pt 间隔的宽柔光带。
/// 强度由固定哈希决定，保证同一条照片每次渲染完全一致。
private struct ReviewPhotoSurfaceTexture: View {
    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }

            let angle = CGFloat(145) * .pi / 180
            let along = CGVector(dx: cos(angle), dy: sin(angle))
            let across = CGVector(dx: -sin(angle), dy: cos(angle))
            let span = abs(size.width * across.dx) + abs(size.height * across.dy)
            let period: CGFloat = 36
            let lineLength = span * 1.6
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            var offset = -span / 2
            var index = 0
            while offset <= span / 2 {
                let hash = UInt64(bitPattern: Int64(index)) &* 0x9E37_79B9_7F4A_7C15
                let strength = CGFloat((hash >> 40) % 1_000) / 1_000
                let opacity = 0.0015 + strength * 0.003

                var path = Path()
                path.move(to: CGPoint(
                    x: center.x + across.dx * offset - along.dx * lineLength / 2,
                    y: center.y + across.dy * offset - along.dy * lineLength / 2
                ))
                path.addLine(to: CGPoint(
                    x: center.x + across.dx * offset + along.dx * lineLength / 2,
                    y: center.y + across.dy * offset + along.dy * lineLength / 2
                ))
                context.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 5)

                offset += period
                index += 1
            }
        }
        .blur(radius: 7)
        .allowsHitTesting(false)
    }
}

struct RealPhotoCard: View {
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager
    let isInDeleteCandidates: Bool
    let isBeingFiledToAlbum: Bool
    let isFiledToAlbum: Bool
    let isVideoPlaying: Bool
    let allowsLivePhotoPlayback: Bool
    let videoMuted: Bool
    let memoryCaption: PhotoMemoryCaption
    let metadataSummary: PhotoAssetMetadataSummary
    let displaySize: CGSize
    let targetSize: CGSize
    @State private var isScrubbingVideo = false
    let playbackControlsRevealToken: UUID?
    let onStopVideoPlayback: () -> Void

    private enum PreviewImageQuality {
        case none
        case fallbackThumbnail
        case screenPreview
    }

    @State private var image: UIImage?
    @State private var imageQuality = PreviewImageQuality.none
    @State private var isLoading = true
    @State private var thumbnailFallbackWorkItem: DispatchWorkItem?
    @State private var thumbnailRequestID: PHImageRequestID?
    @State private var previewRequestID: PHImageRequestID?
    @State private var fallbackRequestID: PHImageRequestID?
    @State private var livePhotoRequestID: PHImageRequestID?
    @State private var livePhoto: PHLivePhoto?
    @State private var failedToLoadLivePhoto = false
    @State private var isLivePhotoMotionEnabled = false
    @State private var livePhotoPlaybackTrigger = 0
    @State private var loadingAssetIdentifier: String?
    @State private var isShowingDegradedPreview = false
    @State private var isDownloadingFromCloud = false
    @State private var cloudDownloadProgress: Double?

    var body: some View {
        ZStack {
            if isVideoPlaying {
                PhotoAssetVideoPlayerView(
                    asset: asset,
                    photoLibraryManager: photoLibraryManager,
                    isMuted: videoMuted,
                    allowsPlayerInteraction: false,
                    allowsSurfaceTapToRevealControls: true,
                    playbackControlsRevealToken: playbackControlsRevealToken,
                    onScrubbingChanged: { isScrubbingVideo = $0 }
                )
                .frame(width: displaySize.width, height: displaySize.height)
                .clipShape(Rectangle())
                .overlay(
                    candidateOverlay,
                    alignment: .center
                )
            } else if shouldShowLivePhotoPlayback, let livePhoto {
                ZStack {
                    ReviewPhotoSurfaceBackground()

                    LivePhotoPreviewRepresentable(
                        livePhoto: livePhoto,
                        contentIdentifier: asset.localIdentifier,
                        autoPlay: isLivePhotoMotionEnabled,
                        isMuted: videoMuted,
                        playbackTrigger: livePhotoPlaybackTrigger,
                        contentMode: .scaleAspectFit
                    )
                    .allowsHitTesting(false)
                    .frame(width: displaySize.width, height: displaySize.height)
                }
                .frame(width: displaySize.width, height: displaySize.height)
                .clipped()
                .cornerRadius(0)
                .overlay(
                    overlayContent,
                    alignment: .topTrailing
                )
                .overlay(
                    previewStatusOverlay,
                    alignment: .bottom
                )
            } else if let image = image {
                ZStack {
                    ReviewPhotoSurfaceBackground()

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: displaySize.width, height: displaySize.height)
                }
                    .frame(width: displaySize.width, height: displaySize.height)
                    .clipped()
                    .cornerRadius(0)
                    .overlay(
                        overlayContent,
                        alignment: .topTrailing
                    )
                    .overlay(
                        candidateOverlay,
                        alignment: .center
                    )
                    .overlay(
                        previewStatusOverlay,
                        alignment: .bottom
                    )
            } else {
                ReviewPhotoSurfaceBackground()
                    .frame(width: displaySize.width, height: displaySize.height)
                    .overlay(
                        VStack(spacing: 10) {
                            if isLoading || isDownloadingFromCloud {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                                    .scaleEffect(1.2)
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(Theme.secondaryText)
                            }

                            if isDownloadingFromCloud {
                                Text(L10n.string("Downloading photo from iCloud"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.secondaryText)
                            }
                        }
                    )
                    .frame(width: displaySize.width, height: displaySize.height)
            }
        }
        // 照片、视频、实况照片都统一裁到卡片圆角轮廓，避免直角顶出描边。
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
        .overlay {
            // 满血照片不再压白描边（亮照片上会像一圈 halation）；只在占位/加载态保留轮廓。
            if image == nil, !isVideoPlaying, livePhoto == nil {
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Theme.reviewPhotoStroke,
                                Theme.reviewPhotoStrokeFade
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: Theme.stroke
                    )
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("review-photo-card")
        .accessibilityLabel(L10n.string("Current Photo"))
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(L10n.string("Use accessibility actions to delete, favorite, or skip."))
        .inlineVideoCloseAccessibility(isActive: isVideoPlaying, action: onStopVideoPlayback)
        .onAppear {
            loadImage()
        }
        .onDisappear {
            thumbnailFallbackWorkItem?.cancel()
            thumbnailFallbackWorkItem = nil
            photoLibraryManager.cancelImageRequest(thumbnailRequestID)
            photoLibraryManager.cancelImageRequest(previewRequestID)
            photoLibraryManager.cancelImageRequest(fallbackRequestID)
            photoLibraryManager.cancelImageRequest(livePhotoRequestID)
            loadingAssetIdentifier = nil
            livePhoto = nil
            livePhotoRequestID = nil
            isLivePhotoMotionEnabled = false
            livePhotoPlaybackTrigger = 0
            imageQuality = .none
            resetPreviewLoadingState()
        }
    }

    private var shouldShowLivePhotoPlayback: Bool {
        isLivePhotoMotionEnabled &&
            photoLibraryManager.isLivePhoto(asset) &&
            !isInDeleteCandidates &&
            !isBeingFiledToAlbum &&
            !isFiledToAlbum
    }

    @ViewBuilder
    private var overlayContent: some View {
        VStack(spacing: 8) {
            if asset.mediaType == .video {
                ZStack {
                    Circle()
                        .fill(Theme.background.opacity(0.62))
                        .frame(width: 30, height: 30)

                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }

            if photoLibraryManager.isLivePhoto(asset) {
                LivePhotoMotionControlButton(
                    isEnabled: isLivePhotoMotionEnabled,
                    action: toggleLivePhotoMotion
                )
            }

            if photoLibraryManager.isScreenshot(asset) {
                ZStack {
                    Circle()
                        .fill(Theme.background.opacity(0.62))
                        .frame(width: 30, height: 30)

                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(12)
    }

    /// 入册/归类只用 Toast 反馈，不再给照片盖对勾遮罩。
    @ViewBuilder
    private var candidateOverlay: some View {
        if isInDeleteCandidates {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .fill(Theme.background.opacity(0.72))

                VStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 38, weight: .medium))
                        .foregroundColor(Theme.destructive)

                    Text(L10n.string("To delete"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.primaryText)
                }
            }
            .frame(width: displaySize.width, height: displaySize.height)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var previewStatusOverlay: some View {
        if !isInDeleteCandidates,
           !isBeingFiledToAlbum,
           !isFiledToAlbum,
           isShowingDegradedPreview || isDownloadingFromCloud {
            HStack(spacing: 8) {
                if let cloudDownloadProgress {
                    ProgressView(value: cloudDownloadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Theme.accent))
                        .frame(width: 48)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                        .scaleEffect(0.72)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(isDownloadingFromCloud ? L10n.string("Downloading photo from iCloud") : L10n.string("Loading full-quality preview"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.primaryText)

                    Text(L10n.string("Preview may look blurry"))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Theme.secondaryText)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Theme.primaryText.opacity(0.08), lineWidth: 1)
            )
            .padding(.bottom, 14)
            .accessibilityElement(children: .combine)
        }
    }

    private func loadImage() {
        thumbnailFallbackWorkItem?.cancel()
        thumbnailFallbackWorkItem = nil
        photoLibraryManager.cancelImageRequest(thumbnailRequestID)
        photoLibraryManager.cancelImageRequest(previewRequestID)
        photoLibraryManager.cancelImageRequest(fallbackRequestID)
        photoLibraryManager.cancelImageRequest(livePhotoRequestID)
        isLoading = true
        image = nil
        imageQuality = .none
        thumbnailRequestID = nil
        fallbackRequestID = nil
        livePhoto = nil
        livePhotoRequestID = nil
        failedToLoadLivePhoto = false
        resetPreviewLoadingState()
        let requestedAssetID = asset.localIdentifier
        loadingAssetIdentifier = requestedAssetID
        isLivePhotoMotionEnabled = LivePhotoPlaybackDefaultPolicy.initialMotionEnabled(
            isLivePhoto: photoLibraryManager.isLivePhoto(asset),
            autoPlayPreference: allowsLivePhotoPlayback
        )
        livePhotoPlaybackTrigger = isLivePhotoMotionEnabled ? 1 : 0

        let thumbnailSize = CGSize(
            width: min(targetSize.width, 1_100),
            height: min(targetSize.height, 1_500)
        )

        previewRequestID = photoLibraryManager.loadSwipePreviewResult(
            for: asset,
            size: targetSize,
            networkAccessAllowed: true
        ) { result in
            guard loadingAssetIdentifier == requestedAssetID else { return }
            if result.isInCloud || result.progress != nil {
                self.isDownloadingFromCloud = true
                self.cloudDownloadProgress = result.progress
            }

            if result.isDegraded {
                self.isShowingDegradedPreview = self.imageQuality != .none
            }

            if let loadedImage = result.image {
                if result.isDegraded {
                    self.isShowingDegradedPreview = self.imageQuality != .none
                } else {
                    self.image = loadedImage
                    self.imageQuality = .screenPreview
                    self.isLoading = false
                    self.cancelThumbnailFallback()
                }
            }

            if result.isFinal {
                self.isDownloadingFromCloud = false
                self.cloudDownloadProgress = nil
                self.isShowingDegradedPreview = false
                if self.imageQuality != .screenPreview {
                    self.loadFallbackImage(for: requestedAssetID)
                }
                self.previewRequestID = nil
            } else if result.image != nil {
                self.isShowingDegradedPreview = self.imageQuality != .screenPreview
            } else if result.isInCloud, self.image == nil {
                self.isLoading = true
            }
        }

        scheduleThumbnailFallback(for: requestedAssetID, size: thumbnailSize)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            guard loadingAssetIdentifier == requestedAssetID,
                  isShowingDegradedPreview,
                  imageQuality != .screenPreview,
                  fallbackRequestID == nil else { return }
            loadFallbackImage(for: requestedAssetID)
        }

        if isLivePhotoMotionEnabled {
            loadLivePhoto(for: requestedAssetID)
        }
    }

    private func scheduleThumbnailFallback(for requestedAssetID: String, size: CGSize) {
        guard imageQuality == .none else { return }

        let workItem = DispatchWorkItem {
            guard loadingAssetIdentifier == requestedAssetID,
                  imageQuality == .none,
                  thumbnailRequestID == nil else {
                return
            }

            thumbnailFallbackWorkItem = nil
            thumbnailRequestID = photoLibraryManager.loadFastThumbnail(for: asset, size: size) { loadedImage in
                guard loadingAssetIdentifier == requestedAssetID else { return }
                if let loadedImage, imageQuality == .none {
                    self.image = loadedImage
                    self.imageQuality = .fallbackThumbnail
                    self.isLoading = false
                    self.isShowingDegradedPreview = self.previewRequestID != nil || self.fallbackRequestID != nil
                }
                self.thumbnailRequestID = nil
            }
        }

        thumbnailFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: workItem)
    }

    private func cancelThumbnailFallback() {
        thumbnailFallbackWorkItem?.cancel()
        thumbnailFallbackWorkItem = nil
        photoLibraryManager.cancelImageRequest(thumbnailRequestID)
        thumbnailRequestID = nil
    }

    private func resetPreviewLoadingState() {
        isShowingDegradedPreview = false
        isDownloadingFromCloud = false
        cloudDownloadProgress = nil
    }

    private var accessibilityValue: String {
        var values: [String] = []
        if asset.mediaType == .video {
            values.append(L10n.string("Videos"))
            if isVideoPlaying {
                values.append(L10n.string("Video Preview"))
            }
        } else {
            values.append(L10n.string("Photos"))
        }

        values.append(memoryCaption.title)
        if let subtitle = memoryCaption.subtitle {
            values.append(subtitle)
        }
        values.append(metadataSummary.captureDateText)
        if let locationText = metadataSummary.locationText {
            values.append(locationText)
        }

        if photoLibraryManager.isScreenshot(asset) {
            values.append(L10n.string("Screenshots"))
        }

        if photoLibraryManager.isLivePhoto(asset) {
            values.append(L10n.string("Live Photos"))
        }

        if photoLibraryManager.isFavorite(asset) {
            values.append(L10n.string("Favorite"))
        }

        if isDownloadingFromCloud {
            values.append(L10n.string("Downloading photo from iCloud"))
        } else if isShowingDegradedPreview {
            values.append(L10n.string("Loading full-quality preview"))
        }

        if isInDeleteCandidates {
            values.append(L10n.string("To delete"))
        } else if isBeingFiledToAlbum {
            values.append(L10n.string("Filing"))
        } else if isFiledToAlbum {
            values.append(L10n.string("Filed"))
        }

        return values.joined(separator: "，")
    }

    private func loadFallbackImage(for requestedAssetID: String) {
        guard fallbackRequestID == nil else { return }
        isDownloadingFromCloud = true
        cloudDownloadProgress = nil

        fallbackRequestID = photoLibraryManager.loadHighQualityPreview(
            for: asset,
            size: targetSize,
            networkAccessAllowed: true
        ) { loadedImage in
            guard loadingAssetIdentifier == requestedAssetID else { return }
            if let loadedImage {
                self.image = loadedImage
                self.imageQuality = .screenPreview
                self.isLoading = false
                self.cancelThumbnailFallback()
                self.resetPreviewLoadingState()
            } else if self.previewRequestID == nil {
                self.resetPreviewLoadingState()
            }
            self.fallbackRequestID = nil
        }
    }

    private func loadLivePhoto(for requestedAssetID: String) {
        guard livePhotoRequestID == nil, !failedToLoadLivePhoto else { return }
        let livePhotoSize = CGSize(
            width: min(max(targetSize.width, displaySize.width * 2), 1_600),
            height: min(max(targetSize.height, displaySize.height * 2), 1_600)
        )

        livePhotoRequestID = photoLibraryManager.loadLivePhotoResult(
            for: asset,
            size: livePhotoSize
        ) { result in
            guard loadingAssetIdentifier == requestedAssetID else { return }

            if let loadedLivePhoto = result.livePhoto {
                livePhoto = loadedLivePhoto
                isLoading = false
            } else if result.isFinal, livePhoto == nil {
                failedToLoadLivePhoto = true
            }

            if result.isFinal {
                livePhotoRequestID = nil
            }
        }
    }

    private func toggleLivePhotoMotion() {
        guard photoLibraryManager.isLivePhoto(asset) else { return }
        HapticManager.impact(.light)
        isLivePhotoMotionEnabled = LivePhotoPlaybackDefaultPolicy.motionEnabledAfterManualAction(
            current: isLivePhotoMotionEnabled,
            previousLoadFailed: failedToLoadLivePhoto
        )

        guard isLivePhotoMotionEnabled else { return }
        livePhotoPlaybackTrigger += 1
        failedToLoadLivePhoto = false
        loadLivePhoto(for: asset.localIdentifier)
    }
}

struct LivePhotoMotionControlButton: View {
    let isEnabled: Bool
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.background.opacity(isEnabled ? 0.72 : 0.62))
                    .frame(width: 30, height: 30)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.62)
                } else {
                    Image(systemName: isEnabled ? "livephoto" : "livephoto.slash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .photoDeleteMinimumTapTarget()
        .accessibilityLabel(
            isLoading
                ? L10n.string("Reading Photos")
                : (isEnabled ? L10n.string("Turn Live Photo Motion Off") : L10n.string("Play Live Photo"))
        )
        .accessibilityIdentifier("live-photo-motion-toggle")
    }
}

private extension View {
    @ViewBuilder
    func inlineVideoCloseAccessibility(isActive: Bool, action: @escaping () -> Void) -> some View {
        if isActive {
            self.accessibilityAction(named: Text(L10n.string("Stop playback"))) {
                action()
            }
        } else {
            self
        }
    }
}
