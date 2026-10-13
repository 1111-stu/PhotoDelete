import SwiftUI
import Photos

/// 相册整理模式的底部胶片导轨，视觉与交互对齐 iOS 原生「照片」查看器：
/// 每一格都是同一个固定宽高比的竖幅卡片（不是照片各自的原始比例），只有当前生效的那一格放大成正方形；
/// 按住拖动时所有格保持同一尺寸（不放大），松手后当前格才带一点弹簧感放大；
/// 拖动导轨实时切换大图，滑大图 / 点缩略图时导轨居中跟随。
struct ReviewPhotoStrip: View {
    let photos: [PHAsset]
    let currentIndex: Int
    let photoLibraryManager: PhotoLibraryManager
    /// 用户正在拖动或惯性滚动导轨；父视图据此跳过切换动画、延后预加载。
    @Binding var isScrubbing: Bool
    let onSelect: (Int) -> Void

    /// 视口中心命中的照片下标（随滚动变化，仅在跨格时写入，避免逐帧刷新视图）。
    @State private var centeredIndex: Int?
    /// 本次停手前用户是否真的滚动过：区分「用户拖动后的收尾」与「程序化滚动结束」。
    @State private var didUserScrollSinceIdle = false

    /// 拖动中不放大：手指按在导轨上时所有格子保持同一尺寸（原生就是这样），
    /// 松手后当前格才放大成正方形；同时也让拖动期间完全没有布局重排。
    private var activeIndex: Int? {
        isScrubbing ? nil : currentIndex
    }

    var body: some View {
        let active = activeIndex
        let slotWidths = photos.indices.map { ReviewPhotoStripLayout.slotWidth(isCurrent: $0 == active) }
        ScrollViewReader { proxy in
            GeometryReader { geometry in
                let edgeInset = ReviewPhotoStripLayout.centeringInset(viewportWidth: geometry.size.width)
                let viewportWidth = geometry.size.width
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: ReviewPhotoStripLayout.spacing) {
                        ForEach(Array(photos.enumerated()), id: \.element.localIdentifier) { index, asset in
                            let isCurrent = index == active
                            Button {
                                onSelect(index)
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
                                .padding(.horizontal, isCurrent ? ReviewPhotoStripLayout.activeExtraMargin : 0)
                                // 放大 / 复原都带一点弹簧感（原生松手放大时的观感）。
                                .animation(ReviewPhotoStripLayout.morphAnimation, value: isCurrent)
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
                    .padding(.horizontal, edgeInset)
                }
                .coordinateSpace(name: ReviewPhotoStripLayout.edgeCoordinateSpace)
                .accessibilityIdentifier("review-photo-strip")
                .onScrollGeometryChange(for: Int?.self) { scrollGeometry in
                    ReviewPhotoStripLayout.centeredIndex(
                        offset: scrollGeometry.contentOffset.x,
                        viewportWidth: scrollGeometry.containerSize.width,
                        itemWidths: slotWidths,
                        spacing: ReviewPhotoStripLayout.spacing,
                        edgeInset: edgeInset
                    )
                } action: { _, index in
                    centeredIndex = index
                    // 拖动中实时切换（原生行为）；停手收尾在 phase 回调里补齐。
                    guard isScrubbing, let index, index != currentIndex else { return }
                    onSelect(index)
                }
                .onScrollPhaseChange { _, phase in
                    let isScrolling = phase == .interacting || phase == .decelerating
                    if isScrubbing != isScrolling {
                        isScrubbing = isScrolling
                    }
                    if isScrolling {
                        didUserScrollSinceIdle = true
                    } else if phase == .idle, didUserScrollSinceIdle {
                        didUserScrollSinceIdle = false
                        commitCenteredPhotoForSettledScroll()
                    }
                }
                .onChange(of: currentIndex) { index in
                    guard !isScrubbing, photos.indices.contains(index) else { return }
                    withAnimation(.easeOut(duration: ReviewPhotoStripLayout.centeringDuration)) {
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

    /// 惯性滚动停手后，把最后的居中结果补一次；索引变化会经由 currentIndex 回调居中。
    private func commitCenteredPhotoForSettledScroll() {
        guard let centeredIndex,
              photos.indices.contains(centeredIndex),
              centeredIndex != currentIndex else { return }
        onSelect(centeredIndex)
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
    /// 松手后当前格放大成正方形：带一点点弹簧的观感（原生行为）。
    static var morphAnimation: Animation { .spring(response: 0.3, dampingFraction: 0.75) }
    /// 导轨居中跟随的滑动时长。
    static let centeringDuration: TimeInterval = 0.2
    /// 贴近边缘的卡片渐进模糊 + 渐隐；越靠边越虚，溶进背景而不是被硬裁切。
    static let edgeFadeWidth: CGFloat = 20
    static let edgeBlurRadius: CGFloat = 5
    static let edgeFadeOpacity: Double = 0.65
    static let edgeCoordinateSpace = "reviewPhotoStrip"

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

    /// 布局槽宽 = 卡片宽 + 当前格的额外留白；滚动定位与居中判断都按槽宽计算。
    static func slotWidth(isCurrent: Bool) -> CGFloat {
        itemWidth(isCurrent: isCurrent) + (isCurrent ? activeExtraMargin * 2 : 0)
    }

    /// 内容两侧留白：让任意一格（含首尾）都能滚到视口正中，首尾与居中模型自洽。
    static func centeringInset(viewportWidth: CGFloat) -> CGFloat {
        max(0, viewportWidth / 2 - slotWidth(isCurrent: true) / 2)
    }

    /// 视口中心命中的照片下标；贴首尾时夹到首/末张。
    /// 内容窄于视口（无法滚动）或视口未布局时返回 nil，表示无需切换。
    static func centeredIndex(
        offset: CGFloat,
        viewportWidth: CGFloat,
        itemWidths: [CGFloat],
        spacing: CGFloat,
        edgeInset: CGFloat = 0
    ) -> Int? {
        guard !itemWidths.isEmpty, viewportWidth > 0 else { return nil }
        let contentWidth = edgeInset * 2 + itemWidths.reduce(0, +) + spacing * CGFloat(itemWidths.count - 1)
        guard contentWidth > viewportWidth else { return nil }
        if offset <= 0 { return 0 }
        if offset >= contentWidth - viewportWidth { return itemWidths.count - 1 }

        let center = offset + viewportWidth / 2
        var leading = edgeInset
        for (index, width) in itemWidths.enumerated() {
            if center < leading + width { return index }
            leading += width + spacing
        }
        return itemWidths.count - 1
    }
}
