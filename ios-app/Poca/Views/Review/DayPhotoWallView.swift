//
//  DayPhotoWallView.swift
//  PhotoDelete
//
//  随机整理里双指捏合进入的「回到那天」瀑布流：
//  按拍摄时间铺开同一天的全部照片，轻点一张就像泡泡一样碎掉并加入垃圾桶（可撤销）。
//

import SwiftUI
import Photos
import UIKit

struct DayPhotoWallView: View {
    @EnvironmentObject private var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppConstants.hasSeenDayWallHintKey) private var hasSeenDayWallHint = false

    let day: Date
    let sourceAssetID: String

    @State private var assets: [PHAsset] = []
    @State private var isLoaded = false
    @State private var poppedIDs: Set<String> = []
    @State private var poppingIDs: Set<String> = []
    @State private var highlightedID: String?
    @State private var toast: PhotoDeleteToast?
    @State private var showsTrash = false

    private var visibleAssets: [PHAsset] {
        assets.filter { !poppedIDs.contains($0.localIdentifier) }
    }

    private var popAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.14) : .easeIn(duration: 0.22)
    }

    var body: some View {
        VStack(spacing: 0) {
            minimalHeader

            content
        }
        .background(canvasBackground)
        // 和整理页一致：Toast 固定在页头下方，不压在底部内容上。
        .photoDeleteToast($toast, placement: .top(inset: 80))
        .fullScreenCover(isPresented: $showsTrash, onDismiss: reloadAfterTrash) {
            NavigationStack {
                PendingDeletionView()
                    .environmentObject(dataManager)
            }
        }
        .task {
            await loadAssetsIfNeeded()
        }
        .onAppear(perform: showFirstVisitHintIfNeeded)
    }

    // MARK: - 极简页头

    private var minimalHeader: some View {
        ZStack {
            Text(dayTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 64)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 12) {
                PhotoDeleteCircleIconButton(
                    systemName: "xmark",
                    accessibilityLabel: L10n.string("Close"),
                    accessibilityIdentifier: "day-wall-close"
                ) {
                    dismiss()
                }

                Spacer(minLength: 0)

                PhotoDeleteCircleIconButton(
                    systemName: "archivebox",
                    accessibilityLabel: L10n.string("Trash"),
                    accessibilityIdentifier: "day-wall-trash"
                ) {
                    showsTrash = true
                } badge: {
                    if dataManager.deleteCandidates.count > 0 {
                        PhotoDeleteCountBadge(count: dataManager.deleteCandidates.count)
                    }
                }
                .accessibilityValue(
                    String(
                        format: L10n.string("Trash, %lld photos pending deletion"),
                        dataManager.deleteCandidates.count
                    )
                )
            }
        }
        .padding(.horizontal, Theme.space5)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var canvasBackground: some View {
        ZStack {
            Theme.reviewCanvas

            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.055), location: 0),
                    .init(color: .clear, location: 0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var dayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return L10n.string("Today")
        }
        if calendar.isDateInYesterday(day) {
            return L10n.string("Yesterday")
        }
        return Self.compactDateFormatter.string(from: day)
    }

    /// 紧凑数字日期：2026-10-26。不走本地化模板，避免某些语言展开成「2026年10月26日」。
    private static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    private func showFirstVisitHintIfNeeded() {
        guard !hasSeenDayWallHint else { return }
        hasSeenDayWallHint = true
        toast = PhotoDeleteToast(
            message: L10n.string("Tap a photo to add it to Trash"),
            icon: "hand.tap",
            style: .neutral,
            duration: 3.2
        )
    }

    // MARK: - 瀑布流

    @ViewBuilder
    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if !isLoaded {
                    DayWallSkeleton()
                } else if visibleAssets.isEmpty {
                    emptyState
                } else {
                    DayWallGridLayout(spacing: 10) {
                        ForEach(visibleAssets, id: \.localIdentifier) { asset in
                            dayWallTile(asset)
                                .id(asset.localIdentifier)
                        }
                    }
                    .padding(.horizontal, Theme.space4)
                    .padding(.top, 6)
                    .padding(.bottom, 32)
                }
            }
            .onChange(of: isLoaded) { _, loaded in
                guard loaded else { return }
                scrollToSource(proxy: proxy)
            }
        }
    }

    private func dayWallTile(_ asset: PHAsset) -> some View {
        let id = asset.localIdentifier
        let isPopping = poppingIDs.contains(id)

        return Button {
            pop(asset)
        } label: {
            DayWallPhotoTile(
                asset: asset,
                photoLibraryManager: dataManager.photoLibraryManager,
                isHighlighted: highlightedID == id,
                isPopping: isPopping
            )
            .animation(popAnimation, value: isPopping)
            .zIndex(isPopping ? 1 : 0)
        }
        .buttonStyle(.plain)
        .disabled(isPopping)
        .accessibilityLabel(Text(accessibilityLabel(for: asset)))
        .accessibilityHint(Text(L10n.string("Mark to delete")))
    }

    private func accessibilityLabel(for asset: PHAsset) -> String {
        guard let date = asset.creationDate else {
            return L10n.string("Photos")
        }
        let time = AppDateFormatter.string(from: date, dateStyle: .none, timeStyle: .short)
        return "\(L10n.string("Photos")), \(time)"
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(Theme.positive)

            Text(L10n.string("Photos you added are in Trash. Clean them up whenever you're ready."))
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.space8)

            Button(L10n.string("Done")) {
                dismiss()
            }
            .photoDeleteSecondaryButton()
            .frame(maxWidth: 180)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }

    // MARK: - 数据

    private func loadAssetsIfNeeded() async {
        guard !isLoaded else { return }
        await reloadAssets()
    }

    private func reloadAfterTrash() {
        Task { await reloadAssets() }
    }

    private func reloadAssets() async {
        let day = day
        let deleteIDs = Set(dataManager.deleteCandidates.map(\.localIdentifier))
        let manager = dataManager
        let loaded = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let photos = manager.getPhotosForDay(day)
                    .filter { !deleteIDs.contains($0.localIdentifier) }
                    .sorted {
                        ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast)
                    }
                continuation.resume(returning: photos)
            }
        }
        assets = loaded
        isLoaded = true
    }

    /// 落到捏合时那张照片的位置，并短暂描一圈边，方便确认「回到的是这里」。
    private func scrollToSource(proxy: ScrollViewProxy) {
        guard assets.contains(where: { $0.localIdentifier == sourceAssetID }) else { return }

        DispatchQueue.main.async {
            proxy.scrollTo(sourceAssetID, anchor: .center)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.28)) {
                highlightedID = sourceAssetID
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.45)) {
                    highlightedID = nil
                }
            }
        }
    }

    // MARK: - 加入垃圾桶（泡泡破碎）

    private func pop(_ asset: PHAsset) {
        let id = asset.localIdentifier
        guard !poppedIDs.contains(id), !poppingIDs.contains(id) else { return }

        HapticManager.softImpact(intensity: 0.9)
        withAnimation(popAnimation) {
            _ = poppingIDs.insert(id)
        }

        dataManager.addToDeleteCandidates([asset], markAsReviewed: true)

        // 等碎纸屑飞完再让这一列补位。
        let delay: TimeInterval = reduceMotion ? 0.16 : 0.45
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.22)) {
                _ = poppedIDs.insert(id)
                poppingIDs.remove(id)
            }
        }
    }
}

// MARK: - 单张缩略图

struct DayWallPhotoTile: View {
    let asset: PHAsset
    let photoLibraryManager: PhotoLibraryManager
    var isHighlighted = false
    var isPopping = false

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Color.clear
            .overlay {
                photoLayer
            }
            .overlay {
                // 碎纸屑不被圆角裁掉：它要飞出格子边缘。
                if isPopping && !reduceMotion {
                    ShredBurstView()
                }
            }
            .onDisappear {
                cancel()
            }
    }

    private var photoLayer: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Theme.elevatedSurface

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }

                if asset.mediaType == .video {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(.black.opacity(0.48), in: Circle())
                        .padding(6)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .stroke(Theme.accent, lineWidth: 2)
                    .opacity(isHighlighted ? 1 : 0)
            }
            .scaleEffect(isPopping && !reduceMotion ? 0.88 : 1)
            .opacity(isPopping ? 0 : 1)
            .blur(radius: isPopping && !reduceMotion ? 5 : 0)
            .task(id: "\(Int(proxy.size.width.rounded()))x\(Int(proxy.size.height.rounded()))") {
                load(size: proxy.size)
            }
        }
    }

    @MainActor
    private func load(size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        cancel()

        let target = CGSize(
            width: size.width * displayScale,
            height: size.height * displayScale
        )
        // browser 预览走 exact 缩放 + opportunistic（先快后清），比 fastFormat 明显更清晰。
        requestID = photoLibraryManager.loadBrowserPreviewResult(
            for: asset,
            size: target,
            networkAccessAllowed: true
        ) { result in
            if let loaded = result.image {
                image = loaded
            }
        }
    }

    private func cancel() {
        photoLibraryManager.cancelImageRequest(requestID)
        requestID = nil
    }
}

// MARK: - 碎纸屑

/// 照片被点掉时炸出的一小把纸屑：细长碎片、旋转、带一点重力。
/// TimelineView 驱动 Canvas，不依赖隐式动画；Reduce Motion 下不出现。
private struct ShredBurstView: View {
    @State private var startDate = Date()

    private let duration: TimeInterval = 0.45
    private let particleCount = 18

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                let progress = min(max(elapsed / duration, 0), 1)
                guard progress < 1, size.width > 0, size.height > 0 else { return }

                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let minSide = min(size.width, size.height)
                let eased = 1 - pow(1 - progress, 3)
                let gravity = minSide * CGFloat(0.22 * pow(progress, 2))
                let fade = pow(1 - progress, 1.1)

                for index in 0..<particleCount {
                    let seedAngle = Double((index * 37) % 100) / 100
                    let seedDistance = Double((index * 61) % 100) / 100
                    let seedSpin = Double((index * 83) % 100) / 100

                    let angle = (Double(index) / Double(particleCount)) * .pi * 2 + seedAngle * 0.7
                    let distance = Double(minSide) * (0.18 + 0.55 * seedDistance) * eased
                    let point = CGPoint(
                        x: center.x
                            + CGFloat(cos(angle) * distance)
                            + size.width * 0.05 * CGFloat(eased),
                        y: center.y
                            + CGFloat(sin(angle) * distance)
                            - size.height * 0.04 * CGFloat(eased)
                            + gravity
                    )

                    let width = CGFloat((2.2 + 2.6 * seedDistance) * (1 - progress * 0.25))
                    let height = CGFloat((4.5 + 5.5 * seedAngle) * (1 - progress * 0.25))
                    let rotation = seedAngle * .pi * 2 + (seedSpin - 0.5) * progress * 7
                    let opacity = fade * (0.65 + seedDistance * 0.3)

                    let color: Color
                    switch index % 5 {
                    case 0:
                        color = Theme.accent.opacity(opacity)
                    case 1:
                        color = Color.white.opacity(opacity * 0.55)
                    default:
                        color = Color.white.opacity(opacity)
                    }

                    var scrap = context
                    scrap.translateBy(x: point.x, y: point.y)
                    scrap.rotate(by: .radians(rotation))
                    scrap.fill(
                        Path(
                            roundedRect: CGRect(
                                x: -width / 2,
                                y: -height / 2,
                                width: width,
                                height: height
                            ),
                            cornerRadius: 0.8
                        ),
                        with: .color(color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 网格布局

/// 等大方格网格：列数按宽度自适应（iPhone 竖屏 3 列），行优先排布。
/// 删掉一张后后续图片整体前移一格，不会留下列尾空洞。
struct DayWallGridLayout: Layout {
    var spacing: CGFloat = 10
    /// 目标单格宽度；实际列数按容器宽度取最接近这个宽度的整数列。
    var targetColumnWidth: CGFloat = 116
    var minColumns = 2
    var maxColumns = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 0
        guard width > 0, !subviews.isEmpty else { return .zero }
        return CGSize(width: width, height: metrics(for: width, count: subviews.count).height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        guard !subviews.isEmpty else { return }
        let metrics = metrics(for: bounds.width, count: subviews.count)

        for (index, subview) in subviews.enumerated() {
            let row = index / metrics.columns
            let column = index % metrics.columns
            subview.place(
                at: CGPoint(
                    x: bounds.minX + CGFloat(column) * (metrics.cell + spacing),
                    y: bounds.minY + CGFloat(row) * (metrics.cell + spacing)
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: metrics.cell, height: metrics.cell)
            )
        }
    }

    private func metrics(
        for width: CGFloat,
        count: Int
    ) -> (columns: Int, cell: CGFloat, height: CGFloat) {
        guard width > 0, count > 0 else { return (minColumns, 0, 0) }

        let columns = columnCount(for: width)
        let cell = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        let rows = Int(ceil(Double(count) / Double(columns)))
        let height = CGFloat(rows) * cell + CGFloat(max(rows - 1, 0)) * spacing
        return (columns, cell, height)
    }

    private func columnCount(for width: CGFloat) -> Int {
        let raw = Int(((width + spacing) / (targetColumnWidth + spacing)).rounded())
        return min(max(raw, minColumns), maxColumns)
    }
}

// MARK: - 占位骨架

/// 进入页面先铺占位骨架，不做转圈 loading；骨架保持静止，不加扫光。
private struct DayWallSkeleton: View {
    var body: some View {
        DayWallGridLayout(spacing: 10) {
            ForEach(0..<9, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                    .fill(Theme.elevatedSurface)
            }
        }
        .padding(.horizontal, Theme.space4)
        .padding(.top, 6)
        .allowsHitTesting(false)
    }
}
