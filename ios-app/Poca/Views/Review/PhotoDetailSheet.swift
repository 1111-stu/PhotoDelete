//
//  PhotoDetailSheet.swift
//  Poca
//

import SwiftUI
import Photos
import UIKit

/// 「照片详情」半屏弹窗：顶部当前照片预览 + 拍摄时间 / 位置 / 文件大小 / 分辨率 / 所属相册。
/// 对齐系统照片：详情面板里能看到照片本身，信息只是补充。
struct PhotoDetailSheet: View {
    let asset: PHAsset
    @ObservedObject var dataManager: DataManager

    @State private var sizeText: String?
    @State private var previewImage: UIImage?
    @State private var previewRequestID: PHImageRequestID?

    private var rows: [(label: String, value: String?)] {
        [
            (L10n.string("Captured"), PhotoAssetMetadataFormatter.detailCaptureDate(for: asset.creationDate)),
            (L10n.string("Position"), dataManager.locationDisplayTextIfAvailable(for: asset)),
            (L10n.string("File Size"), sizeText),
            (L10n.string("Resolution"), resolutionText)
        ]
    }

    private var resolutionText: String? {
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { return nil }
        return "\(PocaCountFormat.plain(asset.pixelWidth)) × \(PocaCountFormat.plain(asset.pixelHeight))"
    }

    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                Text(L10n.string("Photo Details"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Theme.primaryText)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 18) {
                        photoPreview

                        let visibleRows = rows.filter { $0.value != nil }
                        VStack(spacing: 0) {
                            ForEach(Array(visibleRows.enumerated()), id: \.offset) { index, row in
                                detailRow(row.label, row.value ?? "")
                                if index != visibleRows.count - 1 {
                                    Rectangle()
                                        .fill(Theme.hairline)
                                        .frame(height: 1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task(id: asset.localIdentifier) {
            previewImage = nil
            loadPreviewImage()
            sizeText = nil
            if let cached = dataManager.cachedAssetFileSizeEstimate(for: asset), cached.isReliable {
                sizeText = CleanupStatsFormatter.fileSize(cached.sizeMB)
                return
            }
            do {
                let state = try await AssetSizeLoader.shared.estimate(for: asset, dataManager: dataManager)
                switch state {
                case .knownMB(let value):
                    sizeText = CleanupStatsFormatter.fileSize(value)
                case .iCloud:
                    sizeText = "iCloud"
                case .pending, .loading, .unavailable:
                    sizeText = nil
                }
            } catch is CancellationError {
                return
            } catch {
                sizeText = nil
            }
        }
        .onDisappear {
            cancelPreviewRequest()
        }
    }

    /// 系统照片的做法：信息面板顶部放当前照片，信息往下排。
    @ViewBuilder
    private var photoPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(Color.black)

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Theme.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
        .accessibilityLabel(L10n.string("Photo Preview"))
    }

    /// 按原始比例估一个不喧宾夺主的预览高度。
    private var previewHeight: CGFloat {
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { return 220 }
        let aspectRatio = CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth)
        return min(max(320 * aspectRatio, 160), 320)
    }

    private func loadPreviewImage() {
        cancelPreviewRequest()
        let targetSize = CGSize(width: 1200, height: 1200)
        previewRequestID = dataManager.photoLibraryManager.loadHighQualityPreview(
            for: asset,
            size: targetSize,
            networkAccessAllowed: true
        ) { image in
            previewImage = image
            previewRequestID = nil
        }
    }

    private func cancelPreviewRequest() {
        if let previewRequestID {
            dataManager.photoLibraryManager.cancelImageRequest(previewRequestID)
        }
        previewRequestID = nil
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.primaryText)
                .lineLimit(1)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Theme.secondaryText)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 13)
    }
}
