//
//  AlbumReorderLongPressGesture.swift
//  Poca
//
//  iOS 18+ long-press→drag for album reorder inside ScrollView.
//
//  Industry / Apple guidance:
//  - Do not use per-tile SwiftUI LongPress.sequenced(Drag) or DragGesture(minimumDistance: 0);
//    those claim the pan at `.first(pressing)` and freeze scrolling (see AlbumScroll logs).
//  - Use `UIGestureRecognizerRepresentable` + `UILongPressGestureRecognizer` on the tile
//    (not a SwiftUI `Button` — Button swallows `.gesture` and long-press never begins).
//  - Attach with `.gesture(...)`. Pending press fails when movement > allowableMovement so
//    ScrollView keeps scrolling; after `.began`, the same recognizer drives drag.
//

import OSLog
import SwiftUI
import UIKit

/// Temporary scroll/gesture diagnostics. Filter Xcode console by `AlbumScroll`.
enum AlbumScrollDebug {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Poca",
        category: "AlbumScroll"
    )

    static func log(_ message: String) {
        let line = "[AlbumScroll] \(message)"
        print(line)
        logger.notice("\(message, privacy: .public)")
    }
}

/// Long-press then drag, ScrollView-safe on iOS 18+.
struct AlbumReorderLongPressGesture: UIGestureRecognizerRepresentable {
    var minimumPressDuration: TimeInterval
    var allowableMovement: CGFloat
    var isEnabled: Bool
    var viewportSpaceName: String
    var contentSpaceName: String
    var onBegan: (_ viewport: CGPoint, _ content: CGPoint) -> Void
    var onChanged: (_ viewport: CGPoint, _ content: CGPoint) -> Void
    var onEnded: (_ viewport: CGPoint, _ content: CGPoint) -> Void
    var onCancelled: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(parent: self, converter: converter)
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = minimumPressDuration
        // Fail the pending press when the user scrolls; after `.began`, UILongPress
        // keeps delivering `.changed` for the same finger.
        recognizer.allowableMovement = allowableMovement
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = context.coordinator
        recognizer.isEnabled = isEnabled
        AlbumScrollDebug.log(
            "UIKit18 recognizer created duration=\(minimumPressDuration) slop=\(Int(allowableMovement)) enabled=\(isEnabled)"
        )
        return recognizer
    }

    func updateUIGestureRecognizer(
        _ recognizer: UILongPressGestureRecognizer,
        context: Context
    ) {
        context.coordinator.parent = self
        recognizer.minimumPressDuration = minimumPressDuration
        recognizer.allowableMovement = allowableMovement
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UILongPressGestureRecognizer,
        context: Context
    ) {
        let converter = context.coordinator.converter
        let viewport = converter.location(in: .named(viewportSpaceName))
        let content = converter.location(in: .named(contentSpaceName))

        switch recognizer.state {
        case .began:
            AlbumScrollDebug.log(
                "UIKit18 began viewport=(\(Int(viewport.x)),\(Int(viewport.y))) content=(\(Int(content.x)),\(Int(content.y)))"
            )
            onBegan(viewport, content)
        case .changed:
            onChanged(viewport, content)
        case .ended:
            AlbumScrollDebug.log(
                "UIKit18 ended viewport=(\(Int(viewport.x)),\(Int(viewport.y)))"
            )
            onEnded(viewport, content)
        case .cancelled, .failed:
            AlbumScrollDebug.log("UIKit18 cancelled/failed state=\(recognizer.state.rawValue)")
            onCancelled()
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: AlbumReorderLongPressGesture
        let converter: CoordinateSpaceConverter

        init(parent: AlbumReorderLongPressGesture, converter: CoordinateSpaceConverter) {
            self.parent = parent
            self.converter = converter
        }

        /// Allow ScrollView's pan while the press is still pending (FB18199844).
        /// Quick pans exceed `allowableMovement` and fail this recognizer; a still
        /// long-press reaches `.began` and then drives reorder via `.changed`.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
