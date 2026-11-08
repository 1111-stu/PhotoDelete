import Foundation

enum InlineVideoScrubGestureRegion {
    static func contains(
        startLocation: CGPoint,
        cardSize: CGSize,
        isVideoPlaying: Bool,
        reservedBottomHeight: CGFloat
    ) -> Bool {
        guard isVideoPlaying,
              cardSize.width > 0,
              cardSize.height > 0,
              reservedBottomHeight > 0 else {
            return false
        }

        let reservedHeight = min(reservedBottomHeight, cardSize.height)
        return startLocation.y >= cardSize.height - reservedHeight
    }
}

enum ReviewSwipeMotion {
    static let minimumDragDistance: CGFloat = 8
    static let previewStartDistance: CGFloat = 14
    static let directionLockDistance: CGFloat = 12
    /// Vertical action commit (up=delete stage, down=album). Kept a bit harder than paging.
    static let commitDistance: CGFloat = 56
    static let predictedCommitDistance: CGFloat = 96
    static let minimumPredictedCommitDrag: CGFloat = 28
    /// Horizontal browse/page commit. Slightly more sensitive than vertical actions.
    static let browseCommitDistance: CGFloat = 46
    static let browsePredictedCommitDistance: CGFloat = 80
    static let browseMinimumPredictedCommitDrag: CGFloat = 22
    static let browseClamp: CGFloat = 160
    static let closeClamp: CGFloat = 188
    static let actionDragLimit: CGFloat = 300
    static let actionDragResistance: CGFloat = 0.78
    static let coordinateSpace = "photo-review-card"
    static let inlineVideoScrubberReservedHeight: CGFloat = 78
}
enum ReviewDragAxis {
    case horizontal
    case vertical
}
enum ReviewSwipeDirection {
    case left, right, up, down
}


/// 整理页卡片尺寸：槽位固定（手势区/翻页步长依赖它），卡片在槽位里按照片自身比例缩放。
enum ReviewPhotoCardSizing {
    static func cardSize(assetAspectRatio ratio: CGFloat, in slot: CGSize) -> CGSize {
        guard slot.width > 0, slot.height > 0, ratio.isFinite, ratio > 0 else { return slot }
        let heightAtFullWidth = slot.width / ratio
        if heightAtFullWidth <= slot.height {
            return CGSize(width: slot.width, height: heightAtFullWidth)
        }
        return CGSize(width: slot.height * ratio, height: slot.height)
    }
}

enum ReviewSwipeGesture {
    static func dragAxis(for translation: CGSize) -> ReviewDragAxis {
        abs(translation.width) >= abs(translation.height) ? .horizontal : .vertical
    }

    static func constrainedTranslation(_ translation: CGSize, to axis: ReviewDragAxis) -> CGSize {
        switch axis {
        case .horizontal: return CGSize(width: translation.width, height: 0)
        case .vertical: return CGSize(width: 0, height: translation.height)
        }
    }

    static func rubberBanded(_ value: CGFloat, limit: CGFloat, resistance: CGFloat) -> CGFloat {
        let distance = abs(value)
        guard distance > limit else { return value }
        let sign: CGFloat = value < 0 ? -1 : 1
        return sign * (limit + (distance - limit) * resistance)
    }

    static func committedSwipeDirection(translation: CGSize, predictedEndTranslation: CGSize) -> ReviewSwipeDirection? {
        if let direction = dominantSwipeDirection(
            for: translation,
            horizontalThreshold: ReviewSwipeMotion.browseCommitDistance,
            verticalThreshold: ReviewSwipeMotion.commitDistance
        ) {
            return direction
        }

        guard let predictedDirection = dominantSwipeDirection(
            for: predictedEndTranslation,
            horizontalThreshold: ReviewSwipeMotion.browsePredictedCommitDistance,
            verticalThreshold: ReviewSwipeMotion.predictedCommitDistance
        ) else {
            return nil
        }

        // Allow a short, fast flick to commit; ignore accidental micro-drags.
        // Horizontal paging uses a slightly lower floor so flicks feel snappier.
        let minimumDrag: CGFloat
        switch predictedDirection {
        case .left, .right:
            minimumDrag = ReviewSwipeMotion.browseMinimumPredictedCommitDrag
        case .up, .down:
            minimumDrag = ReviewSwipeMotion.minimumPredictedCommitDrag
        }
        guard primaryDistance(for: predictedDirection, in: translation) >= minimumDrag else {
            return nil
        }

        return predictedDirection
    }

    static func primaryDistance(for direction: ReviewSwipeDirection, in translation: CGSize) -> CGFloat {
        switch direction {
        case .left, .right:
            return abs(translation.width)
        case .up, .down:
            return abs(translation.height)
        }
    }

    static func dominantSwipeDirection(
        for translation: CGSize,
        horizontalThreshold: CGFloat,
        verticalThreshold: CGFloat
    ) -> ReviewSwipeDirection? {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)

        if horizontalDistance >= verticalDistance, horizontalDistance > horizontalThreshold {
            return translation.width < 0 ? .left : .right
        }

        if verticalDistance > verticalThreshold {
            return translation.height < 0 ? .up : .down
        }

        return nil
    }

}
