//
//  PhotoDetailSheet.swift
//  PhotoDelete
//

import SwiftUI
import Photos

/// 「照片详情」半屏弹窗：拍摄时间 / 位置 / 文件大小 / 分辨率 / 所属相册。
/// 与顶栏的"一瞥级"信息（1/19 + 时间·大小）分层：这里给全量参考信息。
struct PhotoDetailSheet: View {
    let asset: PHAsset
    @ObservedObject var dataManager: DataManager

    @State private var sizeText: String?

    private var rows: [(label: String, value: String?)] {
        let albums = dataManager.albumTitles(for: asset)
        return [
            (L10n.string("Captured"), PhotoAssetMetadataFormatter.detailCaptureDate(for: asset.creationDate)),
            (L10n.string("Position"), dataManager.locationDisplayTextIfAvailable(for: asset)),
            (L10n.string("File Size"), sizeText),
            (L10n.string("Resolution"), resolutionText),
            (L10n.string("In Albums"), albums.isEmpty ? nil : albums.joined(separator: "、"))
        ]
    }

    private var resolutionText: String? {
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { return nil }
        return "\(PhotoDeleteCountFormat.plain(asset.pixelWidth)) × \(PhotoDeleteCountFormat.plain(asset.pixelHeight))"
    }

    var body: some View {
        ZStack {
            PhotoDeleteStyle.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                Text(L10n.string("Photo Details"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(PhotoDeleteStyle.primaryText)
                    .padding(.top, 24)
                    .padding(.bottom, 6)

                ScrollView {
                    let visibleRows = rows.filter { $0.value != nil }
                    VStack(spacing: 0) {
                        ForEach(Array(visibleRows.enumerated()), id: \.offset) { index, row in
                            detailRow(row.label, row.value ?? "")
                            if index != visibleRows.count - 1 {
                                Rectangle()
                                    .fill(PhotoDeleteStyle.hairline)
                                    .frame(height: 1)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .task(id: asset.localIdentifier) {
            let bytes = PHAssetResource.assetResources(for: asset).compactMap { resource in
                (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value
            }.max()
            sizeText = bytes.flatMap {
                $0 > 0 ? ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) : nil
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(PhotoDeleteStyle.secondaryText)
                .flexibleHeaderContent()

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(PhotoDeleteStyle.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }
}

private extension View {
    /// 让标签不参与多余拉伸（与行内数值右对齐分工）。
    func flexibleHeaderContent() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
    }
}
