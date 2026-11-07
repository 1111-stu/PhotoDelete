import SwiftUI
import Photos

struct CleanupAssetBrowserView: View {
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var router: MainTabRouter
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .caption2) private var metadataSize = 11
    @StateObject private var model: AssetBrowserModel
    @State private var showsFilters = false
    let category: AssetCategoryID
    private let defaultQuery: AssetQuery

    init(category: AssetCategoryID) {
        self.category = category
        let query = AssetQuery(source: .category(category))
        defaultQuery = query
        _model = StateObject(wrappedValue: AssetBrowserModel(query: query))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !dataManager.photoLibraryManager.hasPhotoLibraryAccess {
                        accessState
                    } else if model.isLoading && model.result == nil {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 64)
                    } else if let result = model.result {
                        summary(result)
                        if result.assetIDs.isEmpty {
                            emptyState
                        } else {
                            assetSections(result, width: geometry.size.width)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
            .modifier(CleanupBrowserScrollActivity(onChange: model.setInteractionActive))
        }
        .background(PhotoDeleteScreenBackground())
        .navigationTitle(category.browserTitle)
        .navigationBarTitleDisplayMode(.inline)
        .photoDeletePushedToolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarTrailing) {
                    cleanupFilterButton
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    cleanupFilterButton
                }
            }
        }
        .safeAreaInset(edge: .bottom) { organizeButton }
        .sheet(isPresented: $showsFilters) {
            CleanupAssetFilterSheet(query: $model.query, defaultQuery: defaultQuery, summary: model.result?.summary)
        }
        .onAppear { model.start(dataManager: dataManager) }
        .onDisappear { model.stop() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { model.refresh() }
        }
    }

    private var cleanupFilterButton: some View {
        PhotoDeleteFilterToolbarButton(
            isActive: model.query != defaultQuery,
            accessibilityIdentifier: "cleanup-browser-filter"
        ) {
            showsFilters = true
        }
    }

    private func summary(_ result: AssetQueryResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))) {
                Text(summarySizeText(for: result))
                    .font(.largeTitle.bold()).monospacedDigit()
                    .foregroundStyle(Theme.primaryText)
                    .accessibilityIdentifier("cleanup-browser-size")
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                Text(String(format: L10n.string("%lld items"), Int64(result.summary.count)))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .accessibilityIdentifier("cleanup-browser-count")
            }
            Text(String(format: L10n.string("%lld to organize"), Int64(result.summary.pendingCount)))
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .accessibilityIdentifier("cleanup-browser-pending")
            if result.summary.unknownSizeCount > 0 {
                Text(result.isCalculatingSizes ? L10n.string("Reading file sizes") :
                     String(format: L10n.string("Known size %@ · %lld unknown"),
                            CleanupStatsFormatter.fileSize(result.summary.knownSizeMB), Int64(result.summary.unknownSizeCount)))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            if dataManager.photoLibraryManager.hasLimitedPhotoLibraryAccess {
                Button(L10n.string("Manage photo access")) { dataManager.managePhotoLibraryAccessSettings() }
                    .font(.caption).tint(Theme.accent)
            }
            if model.query != defaultQuery {
                Button(L10n.string("Clear filters")) { model.reset() }
                    .font(.caption).tint(Theme.accent)
            }
            Theme.hairline
                .frame(height: 1)
                .padding(.top, 10)
        }
        .padding(.horizontal, 4)
    }

    /// 精确大小还在读时先给同口径的估算总量，避免把部分合计当成总数。
    private func summarySizeText(for result: AssetQueryResult) -> String {
        if result.isCalculatingSizes {
            guard result.summary.estimatedSizeMB > 0 else { return L10n.string("Calculating") }
            return "≈ " + CleanupStatsFormatter.fileSize(result.summary.estimatedSizeMB)
        }
        if result.summary.knownSizeMB > 0 || result.summary.unknownSizeCount == 0 {
            return CleanupStatsFormatter.fileSize(result.summary.knownSizeMB)
        }
        return L10n.string("Unknown size")
    }

    private func assetSections(_ result: AssetQueryResult, width: CGFloat) -> some View {
        let usableWidth = min(width, 860) - 24
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : (usableWidth < 354 || metadataSize > 12 ? 2 : min(5, max(3, Int(usableWidth / 122))))
        return LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(result.sections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    if section.id != .ungrouped {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(sectionTitle(section.id))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.primaryText)
                            Spacer(minLength: 8)
                            Text(String(format: L10n.string("%lld items"), Int64(section.assetIDs.count)))
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.horizontal, 6)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 10) {
                        ForEach(section.assetIDs, id: \.self) { id in
                            if let asset = model.assetsByID[id], let metadata = result.metadataByID[id] {
                                CleanupAssetCard(asset: asset, metadata: metadata,
                                                 isPendingDeletion: dataManager.deleteCandidates.contains { $0.localIdentifier == id },
                                                 photoLibraryManager: dataManager.photoLibraryManager) {
                                    startOrganize(from: asset)
                                }
                                .onAppear { model.setVisibleAssetIDs(visibleIDs.union([id])); visibleIDs.insert(id) }
                                .onDisappear { visibleIDs.remove(id); model.setVisibleAssetIDs(visibleIDs) }
                            }
                        }
                    }
                }
            }
        }
    }

    @State private var visibleIDs: Set<String> = []

    private func sectionTitle(_ id: AssetQuerySectionID) -> String {
        switch id {
        case .ungrouped: return ""
        case .undated: return L10n.string("No date")
        case .day(let date): return AppDateFormatter.string(from: date, template: "yMMMd")
        case .month(let date): return AppDateFormatter.string(from: date, template: "yMMMM")
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.space4) {
            Image(systemName: category.emptyIcon)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
            Text(model.query == defaultQuery ? category.emptyTitle : L10n.string("No matching items"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)
            if model.query != defaultQuery {
                Button(L10n.string("Clear filters")) { model.reset() }
                    .tint(Theme.accent)
            }
        }
        .padding(Theme.space6)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.space8)
        .photoDeleteCard()
    }

    private var accessState: some View {
        VStack(spacing: Theme.space4) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
            Text(L10n.string("Photo access required"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
            Button(L10n.string("Manage photo access")) { dataManager.requestPhotoLibraryAccess() }
                .photoDeletePrimaryButton()
        }
        .padding(Theme.space6)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.space8)
        .photoDeleteCard()
    }

    /// 点中哪张就从哪张开始：队列按当前列表顺序取到结尾，已整理的照片不再排队，
    /// 但点中的那张始终作为起点（用户明确点了它）。
    private func startOrganize(from asset: PHAsset) {
        guard let result = model.result,
              let index = result.assetIDs.firstIndex(of: asset.localIdentifier) else { return }

        let ids = result.assetIDs[index...].filter { id in
            id == asset.localIdentifier || result.metadataByID[id]?.isReviewed == false
        }
        guard !ids.isEmpty else { return }

        HapticManager.impact(.light)
        router.pushExplicitReview(
            scope: ExplicitAssetReviewScope(orderedAssetIDs: ids),
            category: category.photoCategory
        )
    }

    private var organizeButton: some View {
        let ids = model.result?.pendingIDs ?? []
        return Button {
            guard !ids.isEmpty else { return }
            router.pushExplicitReview(
                scope: ExplicitAssetReviewScope(orderedAssetIDs: ids),
                category: category.photoCategory
            )
        } label: {
            Text(ids.isEmpty ? L10n.string("No items to organize") :
                 String(format: L10n.string("Start organizing · %lld items"), Int64(ids.count)))
                .frame(maxWidth: .infinity)
        }
        .photoDeletePrimaryButton()
        .disabled(ids.isEmpty || model.isLoading || model.result?.query != model.query || !dataManager.photoLibraryManager.hasPhotoLibraryAccess)
        .accessibilityIdentifier("cleanup-browser-start")
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Theme.background)
    }
}

private extension AssetCategoryID {
    var photoCategory: PhotoCategory {
        switch self {
        case .all: return .all
        case .unclassified: return .unclassified
        case .videos: return .videos
        case .screenshots: return .screenshots
        case .screenRecordings: return .screenRecordings
        case .livePhotos: return .livePhotos
        case .favorites: return .favorites
        }
    }
    var browserTitle: String { photoCategory.title }
    var emptyIcon: String {
        switch self {
        case .screenshots: return "photo"
        case .livePhotos: return "livephoto"
        case .videos, .screenRecordings: return "video"
        default: return "photo"
        }
    }
    var emptyTitle: String {
        switch self {
        case .screenRecordings: return L10n.string("No screen recordings")
        case .screenshots: return L10n.string("No screenshots")
        case .livePhotos: return L10n.string("No live photos")
        default: return L10n.string("No videos")
        }
    }
}

struct CleanupAssetCard: View {
    let asset: PHAsset
    let metadata: AssetQueryMetadata
    let isPendingDeletion: Bool
    let photoLibraryManager: PhotoLibraryManager
    let onPreview: () -> Void
    @ScaledMetric(relativeTo: .caption2) private var metadataSize = 11

    var body: some View {
        Button(action: onPreview) {
            VStack(spacing: 7) {
                AlbumAssetThumbnail(assetID: asset.localIdentifier, photoLibraryManager: photoLibraryManager)
                    .id("\(asset.localIdentifier)-\(asset.modificationDate?.timeIntervalSince1970 ?? 0)")
                    .overlay {
                        if asset.mediaType == .video {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
                                .frame(width: 34, height: 34).background(.black.opacity(0.5), in: Circle())
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if asset.mediaType == .video {
                            Text(durationText).font(.caption2.weight(.medium)).monospacedDigit()
                                .foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 3)
                                .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 5))
                                .padding(5)
                        } else if asset.mediaSubtypes.contains(.photoLive) {
                            Image(systemName: "livephoto")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 3)
                                .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 5))
                                .padding(5)
                                .accessibilityLabel(L10n.string("Live Photos"))
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if metadata.isReviewed || isPendingDeletion {
                            Label(isPendingDeletion ? L10n.string("Pending deletion") : L10n.string("Reviewed"), systemImage: "checkmark")
                                .font(.caption2).lineLimit(1).foregroundStyle(.white)
                                .padding(4).background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 5))
                                .padding(5)
                        }
                    }
                HStack(spacing: 4) {
                    Text(shortDate).foregroundStyle(Theme.secondaryText)
                    Spacer(minLength: 0)
                    Text(sizeText(for: metadata)).foregroundStyle(Theme.primaryText)
                }
                .font(.system(size: metadataSize)).monospacedDigit().lineLimit(1).fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 3)
            }
            .padding(6)
            .photoDeleteCard(radius: Theme.radiusMd)
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(fullDate), \(sizeText(for: metadata))\(asset.mediaType == .video ? ", \(durationText)" : "")\(isPendingDeletion ? ", \(L10n.string("Pending deletion"))" : metadata.isReviewed ? ", \(L10n.string("Reviewed"))" : "")")
        .accessibilityIdentifier("cleanup-asset-\(asset.localIdentifier)")
    }

    private func sizeText(for metadata: AssetQueryMetadata) -> String {
        if metadata.size.isCalculating, metadata.estimatedSizeMB > 0 {
            return "≈ " + CleanupStatsFormatter.fileSize(metadata.estimatedSizeMB)
        }
        return metadata.size.cardText
    }

    private var shortDate: String {
        guard let date = metadata.creationDate else { return L10n.string("No date") }
        return AppDateFormatter.string(from: date, template: "yyMMdd")
    }
    private var fullDate: String {
        guard let date = metadata.creationDate else { return L10n.string("No date") }
        return AppDateFormatter.string(from: date, dateStyle: .long, timeStyle: .none)
    }
    private var durationText: String {
        let seconds = max(0, Int(metadata.duration.isFinite ? metadata.duration : 0))
        return seconds >= 3600 ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

extension AssetQuerySizeState {
    var cardText: String {
        switch self {
        case .pending, .loading: return "…"
        case .unavailable: return "—"
        default: return displayText
        }
    }
    var displayText: String {
        switch self {
        case .pending, .loading: return L10n.string("Calculating")
        case .knownMB(let value): return CleanupStatsFormatter.fileSize(value)
        case .iCloud: return "iCloud"
        case .unavailable: return L10n.string("Unknown size")
        }
    }
}

private struct CleanupBrowserScrollActivity: ViewModifier {
    let onChange: (Bool) -> Void
    @State private var settlement: Task<Void, Never>?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { _, phase in
                onChange(phase != .idle)
            }
        } else {
            content.simultaneousGesture(DragGesture(minimumDistance: 3)
                .onChanged { _ in
                    settlement?.cancel()
                    onChange(true)
                }
                .onEnded { _ in
                    settlement = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 700_000_000)
                        guard !Task.isCancelled else { return }
                        onChange(false)
                    }
                })
                .onDisappear {
                    settlement?.cancel()
                    onChange(false)
                }
        }
    }
}
