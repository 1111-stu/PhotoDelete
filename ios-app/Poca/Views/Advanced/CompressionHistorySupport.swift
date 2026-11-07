//
//  CompressionHistorySupport.swift
//  PhotoDelete
//
//  压缩对比 Sheet、历史列表（分页）与会话明细。
//

import Photos
import SwiftUI

// MARK: - History browsers

struct CompressionImageHistoryBrowser: View {
    @Environment(\.dismiss) private var dismiss
    let sessions: [ImageCompressionSession]
    let photoLibraryManager: PhotoLibraryManager
    let onDeleteOriginals: (ImageCompressionSession) -> Void
    let onPreview: (PHAsset) -> Void
    @State private var visibleLimit = 10

    private let pageStep = 10

    private var visibleSessions: [ImageCompressionSession] {
        Array(sessions.prefix(visibleLimit))
    }

    private var totalSavedMB: Double {
        sessions.reduce(0) { $0 + $1.savedSizeMB }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    AdvancedEmptyState(
                        icon: "checkmark.circle",
                        title: L10n.string("No compression history yet"),
                        subtitle: L10n.string("Compressed images will appear in recent compression history.")
                    )
                    .padding(Theme.space5)
                } else {
                    List {
                        Section {
                            Text(
                                String(
                                    format: L10n.string("%lld sessions · saved %@"),
                                    Int64(sessions.count),
                                    CleanupStatsFormatter.space(totalSavedMB)
                                )
                            )
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))
                        }

                        Section {
                            ForEach(visibleSessions) { session in
                                NavigationLink {
                                    CompressionImageSessionDetail(
                                        session: session,
                                        photoLibraryManager: photoLibraryManager,
                                        onDeleteOriginals: { onDeleteOriginals(session) },
                                        onPreview: onPreview
                                    )
                                } label: {
                                    CompressionHistorySessionRow(
                                        dateText: session.formattedDate,
                                        summaryText: String(
                                            format: L10n.string("%lld images · %@ → %@"),
                                            Int64(session.imageCount),
                                            session.formattedOriginalSize,
                                            session.formattedCompressedSize
                                        ),
                                        savedText: session.formattedSavedSize,
                                        emphasizeSaved: session.savedSizeMB > 0
                                    )
                                }
                            }
                        }

                        if visibleLimit < sessions.count {
                            Section {
                                Button(L10n.string("Load more")) {
                                    visibleLimit = min(visibleLimit + pageStep, sessions.count)
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L10n.string("Recent compression history"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                FilterSheetPlainToolbarItem(placement: .confirmationAction) {
                    FilterSheetToolbar.doneButton { dismiss() }
                }
            }
        }
    }
}

struct CompressionVideoHistoryBrowser: View {
    @Environment(\.dismiss) private var dismiss
    let sessions: [VideoCompressionSession]
    let photoLibraryManager: PhotoLibraryManager
    let onDeleteOriginals: (VideoCompressionSession) -> Void
    let onPreview: (PHAsset) -> Void
    @State private var visibleLimit = 10

    private let pageStep = 10

    private var visibleSessions: [VideoCompressionSession] {
        Array(sessions.prefix(visibleLimit))
    }

    private var totalSavedMB: Double {
        sessions.reduce(0) { $0 + $1.savedSizeMB }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    AdvancedEmptyState(
                        icon: "video.badge.checkmark",
                        title: L10n.string("No compression history yet"),
                        subtitle: L10n.string("Finished videos stay in recent compression history.")
                    )
                    .padding(Theme.space5)
                } else {
                    List {
                        Section {
                            Text(
                                String(
                                    format: L10n.string("%lld sessions · saved %@"),
                                    Int64(sessions.count),
                                    CleanupStatsFormatter.space(totalSavedMB)
                                )
                            )
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))
                        }

                        Section {
                            ForEach(visibleSessions) { session in
                                NavigationLink {
                                    CompressionVideoSessionDetail(
                                        session: session,
                                        photoLibraryManager: photoLibraryManager,
                                        onDeleteOriginals: { onDeleteOriginals(session) },
                                        onPreview: onPreview
                                    )
                                } label: {
                                    CompressionHistorySessionRow(
                                        dateText: session.formattedDate,
                                        summaryText: String(
                                            format: L10n.string("%lld videos · %@ → %@"),
                                            Int64(session.videoCount),
                                            session.formattedOriginalSize,
                                            session.formattedCompressedSize
                                        ),
                                        savedText: session.formattedSavedSize,
                                        emphasizeSaved: session.savedSizeMB > 0
                                    )
                                }
                            }
                        }

                        if visibleLimit < sessions.count {
                            Section {
                                Button(L10n.string("Load more")) {
                                    visibleLimit = min(visibleLimit + pageStep, sessions.count)
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L10n.string("Recent compression history"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                FilterSheetPlainToolbarItem(placement: .confirmationAction) {
                    FilterSheetToolbar.doneButton { dismiss() }
                }
            }
        }
    }
}

private struct CompressionHistorySessionRow: View {
    let dateText: String
    let summaryText: String
    let savedText: String
    let emphasizeSaved: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                Text(summaryText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Text(savedText)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(emphasizeSaved ? Theme.secondaryText : Theme.tertiaryText)
        }
        .padding(.vertical, 4)
    }
}

private struct CompressionImageSessionDetail: View {
    let session: ImageCompressionSession
    let photoLibraryManager: PhotoLibraryManager
    let onDeleteOriginals: () -> Void
    let onPreview: (PHAsset) -> Void

    private var remainingOriginalCount: Int {
        session.items.filter { item in
            !item.isOriginalDeleted
                && PHAsset.fetchAssets(withLocalIdentifiers: [item.originalAssetIdentifier], options: nil).firstObject != nil
        }.count
    }

    var body: some View {
        List {
            Section {
                Text("\(session.formattedOriginalSize) → \(session.formattedCompressedSize)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                HStack {
                    Text(L10n.string("Can Save"))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(session.formattedSavedSize)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                }
                .font(.subheadline)
            }

            Section {
                ForEach(session.items) { item in
                    AdvancedImageCompressionHistoryItemRow(
                        item: item,
                        photoLibraryManager: photoLibraryManager,
                        onPreview: onPreview
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }

            if remainingOriginalCount > 0 {
                Section {
                    Button(role: .destructive, action: onDeleteOriginals) {
                        Text(String(format: L10n.string("Delete remaining originals · %lld"), Int64(remainingOriginalCount)))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(session.formattedDate)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CompressionVideoSessionDetail: View {
    let session: VideoCompressionSession
    let photoLibraryManager: PhotoLibraryManager
    let onDeleteOriginals: () -> Void
    let onPreview: (PHAsset) -> Void

    private var remainingOriginalCount: Int {
        session.items.filter { item in
            !item.isOriginalDeleted
                && PHAsset.fetchAssets(withLocalIdentifiers: [item.originalAssetIdentifier], options: nil).firstObject != nil
        }.count
    }

    var body: some View {
        List {
            Section {
                Text("\(session.formattedOriginalSize) → \(session.formattedCompressedSize)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                HStack {
                    Text(L10n.string("Can Save"))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(session.formattedSavedSize)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                }
                .font(.subheadline)
            }

            Section {
                ForEach(session.items) { item in
                    AdvancedVideoCompressionHistoryItemRow(
                        item: item,
                        photoLibraryManager: photoLibraryManager,
                        onPreview: onPreview
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }

            if remainingOriginalCount > 0 {
                Section {
                    Button(role: .destructive, action: onDeleteOriginals) {
                        Text(String(format: L10n.string("Delete remaining originals · %lld"), Int64(remainingOriginalCount)))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(session.formattedDate)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Comparison

struct AdvancedImageCompressionComparisonSheet: View {
    @Environment(\.dismiss) private var dismiss
    let result: AdvancedImageCompressionResult
    let photoLibraryManager: PhotoLibraryManager
    @State private var previewAsset: AdvancedPreviewAsset?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(
                        "\(result.formattedOriginalSize) → \(result.formattedCompressedSize) · \(L10n.string("Can Save")) \(result.formattedSavedSize)"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)

                    ForEach(result.items) { item in
                        AdvancedImageCompressionComparisonRow(
                            item: item,
                            photoLibraryManager: photoLibraryManager
                        ) { asset in
                            previewAsset = AdvancedPreviewAsset(asset: asset)
                        }
                    }
                }
                .padding(Theme.space5)
                .padding(.vertical, 16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L10n.string("Image Comparison"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                FilterSheetPlainToolbarItem(placement: .confirmationAction) {
                    FilterSheetToolbar.doneButton { dismiss() }
                }
            }
        }
        .sheet(item: $previewAsset) { item in
            AdvancedAssetPreviewView(
                asset: item.asset,
                photoLibraryManager: photoLibraryManager
            )
        }
    }
}

struct AdvancedImageCompressionComparisonRow: View {
    let item: AdvancedImageCompressionResultItem
    let photoLibraryManager: PhotoLibraryManager
    let onPreview: (PHAsset) -> Void

    private var originalAsset: PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [item.originalAssetIdentifier], options: nil).firstObject
    }

    private var compressedAsset: PHAsset? {
        guard let createdAssetIdentifier = item.createdAssetIdentifier else { return nil }
        return PHAsset.fetchAssets(withLocalIdentifiers: [createdAssetIdentifier], options: nil).firstObject
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                comparisonButton(
                    label: L10n.string("Original Image"),
                    size: CleanupStatsFormatter.space(item.originalSizeMB),
                    asset: originalAsset,
                    fallbackIcon: "photo"
                )

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)

                comparisonButton(
                    label: L10n.string("After Compression"),
                    size: CleanupStatsFormatter.space(item.compressedSizeMB),
                    asset: compressedAsset,
                    fallbackIcon: "photo"
                )
            }

            Text(String(format: L10n.string("Reduced %@"), CleanupStatsFormatter.space(item.savedSizeMB)))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(12)
        .photoDeleteCard()
    }

    private func comparisonButton(
        label: String,
        size: String,
        asset: PHAsset?,
        fallbackIcon: String
    ) -> some View {
        Button {
            if let asset { onPreview(asset) }
        } label: {
            VStack(spacing: 8) {
                if let asset {
                    AdvancedAssetThumbnail(
                        asset: asset,
                        photoLibraryManager: photoLibraryManager,
                        size: 82
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.elevatedSurface)
                        .frame(width: 82, height: 82)
                        .overlay(
                            Image(systemName: fallbackIcon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        )
                }

                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                    Text(size)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                    .fill(Theme.elevatedSurface)
            )
        }
        .buttonStyle(.plain)
        .disabled(asset == nil)
    }
}

struct AdvancedVideoCompressionComparisonSheet: View {
    @Environment(\.dismiss) private var dismiss
    let result: AdvancedVideoCompressionResult
    let photoLibraryManager: PhotoLibraryManager
    @State private var previewAsset: AdvancedPreviewAsset?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(
                        "\(result.formattedOriginalSize) → \(result.formattedCompressedSize) · \(L10n.string("Can Save")) \(result.formattedSavedSize)"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)

                    ForEach(result.items) { item in
                        AdvancedVideoCompressionComparisonRow(
                            item: item,
                            photoLibraryManager: photoLibraryManager
                        ) { asset in
                            previewAsset = AdvancedPreviewAsset(asset: asset)
                        }
                    }
                }
                .padding(Theme.space5)
                .padding(.vertical, 16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L10n.string("Video Compression"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                FilterSheetPlainToolbarItem(placement: .confirmationAction) {
                    FilterSheetToolbar.doneButton { dismiss() }
                }
            }
        }
        .sheet(item: $previewAsset) { item in
            AdvancedAssetPreviewView(
                asset: item.asset,
                photoLibraryManager: photoLibraryManager
            )
        }
    }
}

struct AdvancedVideoCompressionComparisonRow: View {
    let item: AdvancedVideoCompressionResultItem
    let photoLibraryManager: PhotoLibraryManager
    let onPreview: (PHAsset) -> Void

    private var originalAsset: PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [item.originalAssetIdentifier], options: nil).firstObject
    }

    private var compressedAsset: PHAsset? {
        guard let createdAssetIdentifier = item.createdAssetIdentifier else { return nil }
        return PHAsset.fetchAssets(withLocalIdentifiers: [createdAssetIdentifier], options: nil).firstObject
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                comparisonButton(
                    label: L10n.string("Original Video"),
                    size: CleanupStatsFormatter.space(item.originalSizeMB),
                    asset: originalAsset,
                    fallbackIcon: "video"
                )

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)

                comparisonButton(
                    label: L10n.string("After Compression"),
                    size: CleanupStatsFormatter.space(item.compressedSizeMB),
                    asset: compressedAsset,
                    fallbackIcon: "video"
                )
            }

            Text(String(format: L10n.string("Reduced %@"), CleanupStatsFormatter.space(item.savedSizeMB)))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(12)
        .photoDeleteCard()
    }

    private func comparisonButton(
        label: String,
        size: String,
        asset: PHAsset?,
        fallbackIcon: String
    ) -> some View {
        Button {
            if let asset { onPreview(asset) }
        } label: {
            VStack(spacing: 8) {
                if let asset {
                    AdvancedAssetThumbnail(
                        asset: asset,
                        photoLibraryManager: photoLibraryManager,
                        size: 82
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.elevatedSurface)
                        .frame(width: 82, height: 82)
                        .overlay(
                            Image(systemName: fallbackIcon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        )
                }

                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                    Text(size)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                    .fill(Theme.elevatedSurface)
            )
        }
        .buttonStyle(.plain)
        .disabled(asset == nil)
    }
}

// MARK: - History item rows

struct AdvancedImageCompressionHistoryItemRow: View {
    let item: ImageCompressionSessionItem
    let photoLibraryManager: PhotoLibraryManager
    let onPreview: ((PHAsset) -> Void)?

    private var originalAsset: PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [item.originalAssetIdentifier], options: nil).firstObject
    }

    private var compressedAsset: PHAsset? {
        guard let createdAssetIdentifier = item.createdAssetIdentifier else { return nil }
        return PHAsset.fetchAssets(withLocalIdentifiers: [createdAssetIdentifier], options: nil).firstObject
    }

    private var canPreviewCompressedAsset: Bool {
        compressedAsset != nil && onPreview != nil
    }

    private var isOriginalDeleted: Bool {
        item.isOriginalDeleted || originalAsset == nil
    }

    @ViewBuilder
    var body: some View {
        if let compressedAsset, let onPreview {
            Button {
                onPreview(compressedAsset)
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 10) {
            thumbnail(for: compressedAsset)

            VStack(alignment: .leading, spacing: 4) {
                Text(title(for: compressedAsset, fallback: L10n.string("Compressed image deleted")))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)

                Text("\(item.formattedOriginalSize) → \(item.formattedCompressedSize)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)

                Text(isOriginalDeleted ? L10n.string("Original image deleted") : L10n.string("Original still kept"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(item.formattedSavedSize)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)

            if canPreviewCompressedAsset {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func thumbnail(for asset: PHAsset?) -> some View {
        if let asset {
            AdvancedAssetThumbnail(
                asset: asset,
                photoLibraryManager: photoLibraryManager,
                size: 44
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.elevatedSurface)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "questionmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                )
        }
    }

    private func title(for asset: PHAsset?, fallback: String) -> String {
        guard let asset else { return fallback }
        return AdvancedAssetFormatter.title(for: asset, photoLibraryManager: photoLibraryManager)
    }
}

struct AdvancedVideoCompressionHistoryItemRow: View {
    let item: VideoCompressionSessionItem
    let photoLibraryManager: PhotoLibraryManager
    let onPreview: ((PHAsset) -> Void)?

    private var originalAsset: PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [item.originalAssetIdentifier], options: nil).firstObject
    }

    private var compressedAsset: PHAsset? {
        guard let createdAssetIdentifier = item.createdAssetIdentifier else { return nil }
        return PHAsset.fetchAssets(withLocalIdentifiers: [createdAssetIdentifier], options: nil).firstObject
    }

    private var canPreviewCompressedAsset: Bool {
        compressedAsset != nil && onPreview != nil
    }

    private var isOriginalDeleted: Bool {
        item.isOriginalDeleted || originalAsset == nil
    }

    @ViewBuilder
    var body: some View {
        if let compressedAsset, let onPreview {
            Button {
                onPreview(compressedAsset)
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 10) {
            thumbnail(for: compressedAsset)

            VStack(alignment: .leading, spacing: 4) {
                Text(title(for: compressedAsset, fallback: L10n.string("Compressed video deleted")))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)

                Text("\(item.formattedOriginalSize) → \(item.formattedCompressedSize)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)

                Text(isOriginalDeleted ? L10n.string("Original video deleted") : L10n.string("Original video still kept"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(item.formattedSavedSize)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)

            if canPreviewCompressedAsset {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func thumbnail(for asset: PHAsset?) -> some View {
        if let asset {
            AdvancedAssetThumbnail(
                asset: asset,
                photoLibraryManager: photoLibraryManager,
                size: 44
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.elevatedSurface)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "questionmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                )
        }
    }

    private func title(for asset: PHAsset?, fallback: String) -> String {
        guard let asset else { return fallback }
        return AdvancedAssetFormatter.title(for: asset, photoLibraryManager: photoLibraryManager)
    }
}

// MARK: - Shared metric (hub / legacy)

struct AdvancedVideoCompressionMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                .fill(Theme.elevatedSurface)
        )
    }
}
