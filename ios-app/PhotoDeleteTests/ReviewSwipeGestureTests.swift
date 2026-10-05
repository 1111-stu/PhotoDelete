import Foundation
import Testing
@testable import PhotoDelete

struct ReviewSwipeGestureTests {
    @Test func verticalDragKeepsItsAxisWhenFingerMovesDiagonally() {
        let axis = ReviewSwipeGesture.dragAxis(for: CGSize(width: 2, height: -12))
        let final = ReviewSwipeGesture.constrainedTranslation(CGSize(width: 180, height: -60), to: axis)
        let predicted = ReviewSwipeGesture.constrainedTranslation(CGSize(width: 240, height: -120), to: axis)
        #expect(final == CGSize(width: 0, height: -60))
        #expect(ReviewSwipeGesture.committedSwipeDirection(translation: final, predictedEndTranslation: predicted) == .up)
    }

    @Test func horizontalDragCannotBecomeDeleteOnRelease() {
        let axis = ReviewSwipeGesture.dragAxis(for: CGSize(width: -12, height: 2))
        let final = ReviewSwipeGesture.constrainedTranslation(CGSize(width: -60, height: -180), to: axis)
        #expect(ReviewSwipeGesture.committedSwipeDirection(translation: final, predictedEndTranslation: final) == .left)
    }

    @Test func shortDragDoesNotCommitEvenWithLargePrediction() {
        let final = CGSize(width: 0, height: -18)
        #expect(ReviewSwipeGesture.committedSwipeDirection(
            translation: final, predictedEndTranslation: CGSize(width: 0, height: -300)
        ) == nil)
    }

    @Test func verticalFlickCanCommitBeforeDistanceThreshold() {
        #expect(ReviewSwipeGesture.committedSwipeDirection(
            translation: CGSize(width: 0, height: 30),
            predictedEndTranslation: CGSize(width: 0, height: 110)
        ) == .down)
    }
}
