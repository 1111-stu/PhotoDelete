import Photos
import SwiftUI

struct ShareCardPreviewSheet: View {
    let asset: PHAsset
    let dataManager: DataManager
    let onSharePayload: (PhotoSharePayload) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    @AppStorage(AppConstants.shareCardTemplateKey) private var templateRaw = ShareCardTemplate.minimalFrame.rawValue
    @AppStorage(AppConstants.shareCardTicketPaletteKey) private var paletteRaw = ShareCardTicketPalette.default.id
    @AppStorage(AppConstants.shareCardShowDateKey) private var showDate = true
    @AppStorage(AppConstants.shareCardShowLocationKey) private var showLocation = true

    @State private var selectedTemplate: ShareCardTemplate = .minimalFrame
    @State private var selectedPalette: ShareCardTicketPalette = .default
    @State private var previewImage: UIImage?
    @State private var blockColor: Color = ShareCardColorExtraction.fallbackBlock
    @State private var isSharing = false
    @State private var loadTask: Task<Void, Never>?
    @State private var shareTask: Task<Void, Never>?
    @State private var didFailShare = false

    private var locationTitle: String? {
        dataManager.locationDisplayTextIfAvailable(for: asset)
    }

    private var meta: ShareCardMeta {
        ShareCardMeta.make(
            creationDate: asset.creationDate,
            locationTitle: locationTitle,
            barcodeSeed: asset.localIdentifier,
            showDate: showDate,
            showLocation: showLocation,
            blockColor: blockColor
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            previewPager
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            pageIndicator
                .padding(.top, 8)
                .padding(.bottom, 6)

            if selectedTemplate == .ticketStub {
                paletteRail
                    .padding(.horizontal, Theme.space5)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if selectedTemplate.showsCardChrome, showsMetaToggles {
                toggleRows
                    .padding(.horizontal, Theme.space5)
            }

            shareButton
                .padding(.horizontal, Theme.space5)
                .padding(.top, 10)
                .padding(.bottom, 30)
        }
        .background(Theme.elevatedSurface.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert(L10n.string("Operation failed. Try again later."), isPresented: $didFailShare) {
            Button(L10n.string("Got it"), role: .cancel) {}
        }
        .onAppear {
            selectedTemplate = ShareCardTemplate.normalized(templateRaw)
            selectedPalette = ShareCardTicketPalette.normalized(paletteRaw)
            loadPreviewImage()
        }
        .onChange(of: selectedTemplate) { _, newValue in
            templateRaw = newValue.rawValue
        }
        .onChange(of: selectedPalette) { _, newValue in
            paletteRaw = newValue.id
        }
        .onDisappear {
            loadTask?.cancel()
            shareTask?.cancel()
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTemplate)
    }

    private var header: some View {
        ZStack {
            Text(L10n.string("Card Preview"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.primaryText)

            HStack {
                Button(L10n.string("Cancel")) {
                    dismiss()
                }
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.secondaryText)
                Spacer()
            }
        }
        .padding(.horizontal, Theme.space4)
        .frame(height: 48)
    }

    private var previewPager: some View {
        TabView(selection: $selectedTemplate) {
            ForEach(ShareCardTemplate.allCases) { template in
                Group {
                    if template == .original {
                        originalPreview
                    } else {
                        ShareCardPreviewScaled(
                            template: template,
                            photo: previewImage,
                            meta: meta,
                            palette: selectedPalette
                        )
                    }
                }
                .padding(.horizontal, 24)
                .tag(template)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var originalPreview: some View {
        Group {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    // 预览圆角只是 sheet 里的观感；分享出去的仍是未裁切、未加圆角的原文件。
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous))
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.secondaryText))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pageIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                ForEach(ShareCardTemplate.allCases) { template in
                    Circle()
                        .fill(template == selectedTemplate ? Theme.primaryText : Theme.tertiaryText)
                        .frame(width: template == selectedTemplate ? 7 : 6,
                               height: template == selectedTemplate ? 7 : 6)
                }
            }
            Text(selectedTemplate.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selectedTemplate.title)
    }

    private var paletteRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(ShareCardTicketPalette.all) { palette in
                    Button {
                        HapticManager.impact(.light)
                        selectedPalette = palette
                    } label: {
                        ZStack {
                            ShareCardPaletteSwatch(palette: palette)
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                            if palette == selectedPalette {
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 2.5)
                                    .frame(width: 34, height: 34)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .scaleEffect(palette == selectedPalette ? 1.06 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(palette.name)
                    .accessibilityAddTraits(palette == selectedPalette ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
        }
    }

    /// 有数据才露开关；双缺则整段（含分隔线）不出现——对齐 PhotoDetailSheet 空行隐藏。
    private var showsMetaToggles: Bool {
        meta.hasDate || meta.hasLocation
    }

    @ViewBuilder
    private var toggleRows: some View {
        VStack(spacing: 0) {
            if meta.hasDate {
                shareToggleRow(title: L10n.string("Show Date"), isOn: $showDate)
            }
            if meta.hasDate, meta.hasLocation {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
            }
            if meta.hasLocation {
                shareToggleRow(title: L10n.string("Show Location"), isOn: $showLocation)
            }
        }
    }

    private func shareToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.primaryText)
            Spacer()
            // ON 用 secondaryText 浅灰轨（62%），避免 primaryText 近白满胶囊发糊；本 sheet 不染琥珀。
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.secondaryText)
        }
        .frame(height: 50)
    }

    private var shareButton: some View {
        Button(action: handleShare) {
            ZStack {
                // 白胶囊主 CTA：elevatedSurface 上的反色 pill，不用琥珀渐变。
                Capsule(style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)

                if isSharing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.onAccent))
                } else {
                    Text(L10n.string("Share"))
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .disabled(isSharing || previewImage == nil)
        .opacity(previewImage == nil ? 0.55 : 1)
    }

    private func loadPreviewImage() {
        loadTask?.cancel()
        loadTask = Task {
            let size = CGSize(width: 900 * displayScale, height: 1200 * displayScale)
            let image = await ShareCardRenderer.loadImage(
                for: asset,
                targetSize: size,
                photoLibraryManager: dataManager.photoLibraryManager
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                previewImage = image
                blockColor = ShareCardColorExtraction.blockColor(from: image)
            }
        }
    }

    private func handleShare() {
        guard !isSharing else { return }
        isSharing = true
        HapticManager.impact(.light)
        shareTask?.cancel()
        shareTask = Task {
            do {
                let payload: PhotoSharePayload
                if selectedTemplate == .original {
                    payload = try await dataManager.photoLibraryManager.prepareSharePayload(for: asset)
                } else {
                    let exportSize = CGSize(
                        width: selectedTemplate.designSize.width * 2,
                        height: selectedTemplate.designSize.height * 2
                    )
                    let fullImage = await ShareCardRenderer.loadImage(
                        for: asset,
                        targetSize: exportSize,
                        photoLibraryManager: dataManager.photoLibraryManager
                    ) ?? previewImage
                    guard let fullImage else { throw ShareCardRenderError.renderFailed }
                    var exportMeta = meta
                    exportMeta.blockColor = ShareCardColorExtraction.blockColor(from: fullImage)
                    payload = try await MainActor.run {
                        try ShareCardRenderer.renderPayload(
                            template: selectedTemplate,
                            photo: fullImage,
                            meta: exportMeta,
                            palette: selectedPalette
                        )
                    }
                }
                guard !Task.isCancelled else {
                    payload.cleanup()
                    return
                }
                await MainActor.run {
                    isSharing = false
                    onSharePayload(payload)
                    dismiss()
                }
            } catch is CancellationError {
                await MainActor.run { isSharing = false }
            } catch {
                await MainActor.run {
                    isSharing = false
                    didFailShare = true
                }
            }
        }
    }
}

private struct ShareCardPaletteSwatch: View {
    let palette: ShareCardTicketPalette

    var body: some View {
        // Full mat fill — rail already clips to Circle; selected ring stays on the parent ZStack.
        palette.mat
    }
}
