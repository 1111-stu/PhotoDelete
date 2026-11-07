import Photos
import SwiftUI
import UIKit

enum ShareCardRenderError: Error {
    case renderFailed
    case writeFailed
}

enum ShareCardRenderer {
    @MainActor
    static func renderPayload(
        template: ShareCardTemplate,
        photo: UIImage,
        meta: ShareCardMeta,
        palette: ShareCardTicketPalette
    ) throws -> PhotoSharePayload {
        let size = template.designSize
        let content = ShareCardView(
            template: template,
            photo: photo,
            meta: meta,
            palette: palette
        )
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.proposedSize = .init(size)

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw ShareCardRenderError.renderFailed
        }

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PocaShare", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let fileURL = directoryURL.appendingPathComponent("ShareCard.png", isDirectory: false)
        do {
            try data.write(to: fileURL, options: .atomic)
            return PhotoSharePayload(fileURL: fileURL, temporaryDirectoryURL: directoryURL)
        } catch {
            try? FileManager.default.removeItem(at: directoryURL)
            throw ShareCardRenderError.writeFailed
        }
    }

    static func loadImage(
        for asset: PHAsset,
        targetSize: CGSize,
        photoLibraryManager: PhotoLibraryManager
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            var resumed = false
            _ = photoLibraryManager.loadHighQualityPreview(
                for: asset,
                size: targetSize,
                networkAccessAllowed: true
            ) { image in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }
}
