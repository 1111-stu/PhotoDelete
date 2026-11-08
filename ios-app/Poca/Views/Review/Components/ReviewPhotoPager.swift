import SwiftUI
import Photos

struct ReviewHorizontalPage: Identifiable {
    let offset: Int
    let asset: PHAsset
    var id: String { asset.localIdentifier }
}

/// Owns high-frequency gesture state so finger tracking never rebuilds the review page.
struct ReviewPhotoPager<Content: View>: View {
    let pages: [ReviewHorizontalPage]
    let currentID: String
    /// 手势与翻页的固定容器。卡片本身按照片比例在其中居中。
    let slotSize: CGSize
    /// 当前这张卡片在 slot 内的实际尺寸（视频进度条热区要贴住的底边）。
    let contentCardSize: CGSize
    let pageStride: CGFloat
    let canDelete: Bool
    let isVideoPlaying: Bool
    let isEnabled: Bool
    let onBrowse: (Int) -> Void
    /// 已在本轮最后一张仍向「下一张」滑时回调（触发本轮结算）。
    let onBrowsePastEnd: () -> Void
    let onDelete: () -> Void
    let onFile: () -> Void
    @ViewBuilder let content: (PHAsset, Bool) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset = CGSize.zero
    @State private var axis: ReviewDragAxis?
    @State private var scale: CGFloat = 1
    @State private var isSettling = false
    @State private var preparedCommit = false
    @State private var settlementTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            ForEach(pages) { page in
                content(page.asset, page.offset == 0)
                    .overlay {
                        if page.offset == 0, offset.height > ReviewSwipeMotion.previewStartDistance {
                            ReviewAlbumDragHint(progress: min(
                                (offset.height - ReviewSwipeMotion.previewStartDistance) /
                                    (ReviewSwipeMotion.commitDistance - ReviewSwipeMotion.previewStartDistance),
                                1
                            ))
                            .allowsHitTesting(false)
                        }
                    }
                    .scaleEffect(page.offset == 0 ? scale : 1)
                    .offset(
                        x: CGFloat(page.offset) * pageStride + (page.offset == 0 ? offset.width : horizontalShift),
                        y: page.offset == 0 ? offset.height : 0
                    )
                    .zIndex(page.offset == 0 ? 1 : 0)
            }
        }
        .frame(width: slotSize.width, height: slotSize.height)
        .contentShape(Rectangle())
        // Photos move inside this viewport; measurements and scrubber hit regions do not.
        .coordinateSpace(name: ReviewSwipeMotion.coordinateSpace)
        .simultaneousGesture(gesture)
        .onChange(of: currentID) { _ in cancelSettlement() }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { cancelSettlement() }
        }
        .onDisappear { cancelSettlement() }
    }

    private var horizontalShift: CGFloat {
        offset.height == 0 ? offset.width : 0
    }

    private var releaseAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.18, dampingFraction: 0.86)
    }

    private func isScrubberGesture(_ value: DragGesture.Value) -> Bool {
        // 卡片在 slot 里垂直居中：把起点换算到「卡片自身坐标系」再判断底部进度条热区。
        let cardTop = max((slotSize.height - contentCardSize.height) / 2, 0)
        let locationInCard = CGPoint(
            x: value.startLocation.x,
            y: value.startLocation.y - cardTop
        )
        return InlineVideoScrubGestureRegion.contains(
            startLocation: locationInCard,
            cardSize: contentCardSize,
            isVideoPlaying: isVideoPlaying,
            reservedBottomHeight: ReviewSwipeMotion.inlineVideoScrubberReservedHeight
        )
    }

    private var gesture: some Gesture {
        DragGesture(
            minimumDistance: ReviewSwipeMotion.minimumDragDistance,
            coordinateSpace: .named(ReviewSwipeMotion.coordinateSpace)
        )
        .onChanged { value in
            guard isEnabled, !isSettling, !isScrubberGesture(value) else { return }
            let locked = axis ?? ReviewSwipeGesture.dragAxis(for: value.translation)
            let translation = ReviewSwipeGesture.constrainedTranslation(value.translation, to: locked)
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                axis = locked
                offset = visualOffset(translation, axis: locked)
                scale = dragScale(for: offset)
            }
            if locked == .vertical, abs(translation.height) > ReviewSwipeMotion.commitDistance, !preparedCommit {
                preparedCommit = true
                HapticManager.impact(.light)
            }
        }
        .onEnded { value in
            guard isEnabled, !isSettling, !isScrubberGesture(value) else { return }
            let locked = axis ?? ReviewSwipeGesture.dragAxis(for: value.translation)
            axis = nil
            preparedCommit = false
            let translation = ReviewSwipeGesture.constrainedTranslation(value.translation, to: locked)
            let predicted = ReviewSwipeGesture.constrainedTranslation(value.predictedEndTranslation, to: locked)
            guard let direction = ReviewSwipeGesture.committedSwipeDirection(
                translation: translation, predictedEndTranslation: predicted
            ) else {
                settleHome()
                return
            }
            switch direction {
            case .left: settlePage(step: 1)
            case .right: settlePage(step: -1)
            case .up: settleDelete()
            case .down:
                settleHome()
                onFile()
            }
        }
    }

    private func visualOffset(_ translation: CGSize, axis: ReviewDragAxis) -> CGSize {
        switch axis {
        case .horizontal:
            let step = translation.width < 0 ? 1 : -1
            return CGSize(
                width: pages.contains(where: { $0.offset == step }) ? translation.width :
                    ReviewSwipeGesture.rubberBanded(translation.width, limit: ReviewSwipeMotion.browseClamp, resistance: ReviewSwipeMotion.actionDragResistance),
                height: 0
            )
        case .vertical:
            return CGSize(width: 0, height: ReviewSwipeGesture.rubberBanded(
                translation.height,
                limit: translation.height < 0 ? ReviewSwipeMotion.actionDragLimit : ReviewSwipeMotion.closeClamp,
                resistance: ReviewSwipeMotion.actionDragResistance
            ))
        }
    }

    private func dragScale(for translation: CGSize) -> CGFloat {
        guard !reduceMotion, translation.height < 0 else { return 1 }
        let progress = min(max(
            (-translation.height - ReviewSwipeMotion.directionLockDistance) /
                (ReviewSwipeMotion.commitDistance - ReviewSwipeMotion.directionLockDistance), 0
        ), 1)
        return 1 - progress * 0.12
    }

    private func settleHome() {
        withAnimation(releaseAnimation) {
            offset = .zero
            scale = 1
        }
    }

    private func settlePage(step: Int) {
        guard pages.contains(where: { $0.offset == step }) else {
            if step > 0 {
                onBrowsePastEnd()
            }
            settleHome()
            return
        }
        withAnimation(releaseAnimation) {
            offset = CGSize(width: step < 0 ? pageStride : -pageStride, height: 0)
            scale = 1
        }
        finishSettlement(after: reduceMotion ? 0.12 : 0.24) { onBrowse(step) }
    }

    private func settleDelete() {
        guard canDelete else {
            settleHome()
            return
        }
        if reduceMotion {
            cancelSettlement()
            onDelete()
            return
        }
        withAnimation(.easeIn(duration: 0.28)) {
            offset = CGSize(width: 160, height: -340)
            scale = 0.08
        }
        finishSettlement(after: 0.3, action: onDelete)
    }

    private func finishSettlement(after duration: TimeInterval, action: @escaping () -> Void) {
        isSettling = true
        settlementTask?.cancel()
        settlementTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) }
            catch { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                resetMotion()
                action()
            }
        }
    }

    private func cancelSettlement() {
        settlementTask?.cancel()
        settlementTask = nil
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { resetMotion() }
    }

    private func resetMotion() {
        offset = .zero
        scale = 1
        axis = nil
        preparedCommit = false
        isSettling = false
    }
}
