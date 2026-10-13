import SwiftUI
import Photos

/// 相册整理模式的底部胶片导轨，视觉与交互对齐 iOS 原生「照片」查看器：
/// 每一格都是同一个固定宽高比的竖幅卡片（不是照片各自的原始比例），只有当前生效的那一格放大成正方形；
/// 按住拖动时所有格收拢成同一尺寸，松手后吸附到最近一格，当前格带弹簧放大、两侧邻居被推开；
/// 拖动导轨实时切换大图并逐格「咔哒」，滑大图 / 点缩略图时导轨居中跟随。
///
/// 布局槽位始终等宽：当前格的放大与邻居让位只是视觉位移（offset），不改变滚动内容，
/// 所以放大 / 收拢永远不会把当前格推离中心，也不会和滚动动画互相拉扯。
struct ReviewPhotoStrip: View {
    let photos: [PHAsset]
    let currentIndex: Int
    let photoLibraryManager: PhotoLibraryManager
    /// 用户正在拖动或惯性滚动导轨；父视图据此跳过切换动画、延后预加载。
    @Binding var isScrubbing: Bool
    let onSelect: (Int) -> Void

    /// 视口中心命中的照片下标（随滚动变化，仅在跨格时写入，避免逐帧刷新视图）。
    @State private var centeredIndex: Int?

    /// 拖动中不放大：手指按在导轨上时所有格子保持同一尺寸（原生就是这样），松手吸附后当前格才放大。
    private var activeIndex: Int? {
        isScrubbing ? nil : currentIndex
    }

    var body: some View {
        let active = activeIndex
        let photoCount = photos.count
        ScrollViewReader { proxy in
            GeometryReader { geometry in
                let viewportWidth = geometry.size.width
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: ReviewPhotoStripLayout.spacing) {
                        ForEach(Array(photos.enumerated()), id: \.element.localIdentifier) { index, asset in
                            let isCurrent = index == active
                            Button {
                                select(index)
                            } label: {
                                AlbumAssetThumbnail(
                                    assetID: asset.localIdentifier,
                                    photoLibraryManager: photoLibraryManager,
                                    cornerRadius: ReviewPhotoStripLayout.cornerRadius,
                                    aspectRatio: ReviewPhotoStripLayout.itemAspectRatio(isCurrent: isCurrent)
                                )
                                .frame(
                                    width: ReviewPhotoStripLayout.itemWidth(isCurrent: isCurrent),
                                    height: ReviewPhotoStripLayout.itemHeight
                                )
                                .frame(width: ReviewPhotoStripLayout.slotWidth)
                                .offset(x: ReviewPhotoStripLayout.displacement(of: index, activeIndex: active))
                                .animation(ReviewPhotoStripLayout.morphAnimation(isExpanding: active != nil), value: active)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("review-photo-strip-item-\(index)")
                            .accessibilityAddTraits(isCurrent ? .isSelected : [])
                            // 贴近导轨左右边缘的卡片渐进模糊 + 渐隐，溶进背景而不是被硬裁切。
                            .visualEffect { content, proxy in
                                let frame = proxy.frame(in: .named(ReviewPhotoStripLayout.edgeCoordinateSpace))
                                let distanceToEdge = min(frame.minX, viewportWidth - frame.maxX)
                                let progress = ReviewPhotoStripLayout.edgeFadeProgress(distanceToEdge: distanceToEdge)
                                return content
                                    .blur(radius: progress * ReviewPhotoStripLayout.edgeBlurRadius)
                                    .opacity(1 - progress * ReviewPhotoStripLayout.edgeFadeOpacity)
                            }
                            .id(asset.localIdentifier)
                        }
                    }
                    .padding(.horizontal, ReviewPhotoStripLayout.centeringInset(viewportWidth: viewportWidth))
                }
                .scrollTargetBehavior(ReviewPhotoStripSnapBehavior(itemCount: photoCount))
                .coordinateSpace(name: ReviewPhotoStripLayout.edgeCoordinateSpace)
                .accessibilityIdentifier("review-photo-strip")
                .onScrollGeometryChange(for: Int?.self) { scrollGeometry in
                    ReviewPhotoStripLayout.centeredIndex(
                        offset: scrollGeometry.contentOffset.x,
                        itemCount: photoCount
                    )
                } action: { oldIndex, index in
                    centeredIndex = index
                    // 只有用户驱动的滚动才逐格切图 + 咔哒；程序化居中不打扰。
                    guard isScrubbing, let index, oldIndex != nil, index != oldIndex else { return }
                    HapticManager.selection()
                    if index != currentIndex {
                        onSelect(index)
                    }
                }
                .onScrollPhaseChange { _, phase in
                    handleScrollPhase(phase)
                }
                .onChange(of: currentIndex) { index in
                    guard !isScrubbing, photos.indices.contains(index) else { return }
                    withAnimation(ReviewPhotoStripLayout.centeringAnimation) {
                        proxy.scrollTo(photos[index].localIdentifier, anchor: .center)
                    }
                }
                .task {
                    // 进入页面时把当前照片带到视口中央（原生行为）；首项已在中央，无需滚动。
                    guard currentIndex > 0, photos.indices.contains(currentIndex) else { return }
                    await Task.yield()
                    proxy.scrollTo(photos[currentIndex].localIdentifier, anchor: .center)
                }
            }
        }
        .frame(height: ReviewPhotoStripLayout.containerHeight)
    }

    private func select(_ index: Int) {
        guard index != currentIndex else { return }
        HapticManager.selection()
        onSelect(index)
    }

    /// 吸附动画（.animating）是松手后的收尾，仍算拖动中；全部停稳才放大当前格。
    private func handleScrollPhase(_ phase: ScrollPhase) {
        let isUserDriven = phase == .interacting
            || phase == .decelerating
            || (isScrubbing && phase == .animating)
        if isUserDriven {
            guard !isScrubbing else { return }
            HapticManager.prepareSelection()
            isScrubbing = true
            return
        }
        guard isScrubbing else { return }
        if let centeredIndex, photos.indices.contains(centeredIndex), centeredIndex != currentIndex {
            onSelect(centeredIndex)
        }
        isScrubbing = false
        HapticManager.softImpact(intensity: ReviewPhotoStripLayout.settleHapticIntensity)
    }
}

/// 松手后的落点吸附到最近一格的中心：快速甩动照常惯性滑行，只把终点对齐到格子上。
struct ReviewPhotoStripSnapBehavior: ScrollTargetBehavior {
    let itemCount: Int

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.x = ReviewPhotoStripLayout.snappedOffset(
            proposed: target.rect.minX,
            itemCount: itemCount
        )
    }
}

/// 导轨几何与纯逻辑。尺寸按 iOS 原生「照片」查看器底部胶片条量取：
/// 卡片高 : 工具栏圆钮 ≈ 0.66，普通格固定 2:3 竖幅，只有当前格是正方形且两侧额外留白。
enum ReviewPhotoStripLayout {
    static let itemHeight: CGFloat = 32
    static let containerHeight: CGFloat = 40
    /// 普通格固定 2:3 竖幅（照片按 aspectFill 居中裁切，不随各自原始比例变化）。
    static let itemAspect: CGFloat = 2.0 / 3.0
    /// 当前格两侧多留出的间距，形成原生那种「当前项被隔离」的观感。
    static let activeExtraMargin: CGFloat = 11
    static let spacing: CGFloat = 3
    static let cornerRadius: CGFloat = 4
    /// 停稳那一下的落定触感，比逐格咔哒更轻更软。
    static let settleHapticIntensity: CGFloat = 0.55
    /// 贴近边缘的卡片渐进模糊 + 渐隐；越靠边越虚，溶进背景而不是被硬裁切。
    static let edgeFadeWidth: CGFloat = 20
    static let edgeBlurRadius: CGFloat = 5
    static let edgeFadeOpacity: Double = 0.65
    static let edgeCoordinateSpace = "reviewPhotoStrip"

    /// 放大带一点回弹（原生松手后的「啵」感）；按下收拢要干脆，不回弹。
    static func morphAnimation(isExpanding: Bool) -> Animation {
        isExpanding ? .spring(duration: 0.38, bounce: 0.24) : .smooth(duration: 0.2)
    }

    /// 导轨居中跟随大图：不过冲，避免整条导轨来回晃。
    static let centeringAnimation: Animation = .smooth(duration: 0.32)

    /// 0 = 完全清晰（距边缘 >= edgeFadeWidth），1 = 已到导轨边缘。
    static func edgeFadeProgress(distanceToEdge: CGFloat) -> Double {
        Double(min(max(1 - distanceToEdge / edgeFadeWidth, 0), 1))
    }

    static func itemAspectRatio(isCurrent: Bool) -> CGFloat {
        isCurrent ? 1 : itemAspect
    }

    static func itemWidth(isCurrent: Bool) -> CGFloat {
        itemHeight * itemAspectRatio(isCurrent: isCurrent)
    }

    /// 布局槽宽：所有格等宽，当前格的放大溢出槽位、由邻居让位承接。
    static var slotWidth: CGFloat { itemWidth(isCurrent: false) }

    /// 相邻两格中心的距离，也是逐格滚动的步长。
    static var pitch: CGFloat { slotWidth + spacing }

    /// 当前格放大时，两侧每一格各自被推开的距离：半个放大增量 + 额外隔离留白。
    static var neighborShift: CGFloat {
        (itemWidth(isCurrent: true) - slotWidth) / 2 + activeExtraMargin
    }

    /// 某一格相对布局槽位的视觉位移：当前格左侧整体左移、右侧整体右移，当前格自身不动。
    static func displacement(of index: Int, activeIndex: Int?) -> CGFloat {
        guard let activeIndex, index != activeIndex else { return 0 }
        return index < activeIndex ? -neighborShift : neighborShift
    }

    /// 内容两侧留白：让任意一格（含首尾）都能滚到视口正中，第 i 格居中时偏移恰为 i × pitch。
    static func centeringInset(viewportWidth: CGFloat) -> CGFloat {
        max(0, viewportWidth / 2 - slotWidth / 2)
    }

    /// 第 index 格居中时的滚动偏移。
    static func contentOffset(for index: Int) -> CGFloat {
        CGFloat(index) * pitch
    }

    /// 视口中心最近的照片下标；越界（橡皮筋）时夹到首/末张，没有照片时返回 nil。
    static func centeredIndex(offset: CGFloat, itemCount: Int) -> Int? {
        guard itemCount > 0 else { return nil }
        let nearest = Int((offset / pitch).rounded())
        return min(max(nearest, 0), itemCount - 1)
    }

    /// 惯性滚动的预计落点吸附到最近一格的居中偏移。
    static func snappedOffset(proposed: CGFloat, itemCount: Int) -> CGFloat {
        guard let index = centeredIndex(offset: proposed, itemCount: itemCount) else { return proposed }
        return contentOffset(for: index)
    }
}
