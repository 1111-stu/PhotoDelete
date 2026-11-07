//
//  PolaroidBoardMotion.swift
//  Poca
//
//  相纸墙悬挂微晃：倾斜跟随 + 轻摇惯性。多块板共享一份传感器。
//

import Combine
import CoreMotion
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class PolaroidBoardMotion: ObservableObject {
    static let shared = PolaroidBoardMotion()

    @Published private(set) var tiltX: CGFloat = 0
    @Published private(set) var tiltY: CGFloat = 0
    @Published private(set) var impulseX: CGFloat = 0
    @Published private(set) var impulseY: CGFloat = 0

    private let manager = CMMotionManager()
    private var clientCount = 0
    private var restX: Double?
    private var restY: Double?

    func retain() {
        clientCount += 1
        if clientCount == 1 {
            start()
        }
    }

    func release() {
        clientCount = max(0, clientCount - 1)
        if clientCount == 0 {
            stop()
        }
    }

    func swingX(hang: CGFloat) -> CGFloat {
        (tiltX * 4.2 + impulseX * 9) * hang
    }

    func swingY(hang: CGFloat) -> CGFloat {
        (tiltY * 1.6 + impulseY * 3.5) * hang
    }

    func swingRotation(hang: CGFloat) -> CGFloat {
        (tiltX * 2.1 + impulseX * 4.2) * hang
    }

    private func start() {
        stop()
        #if canImport(UIKit)
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        #endif
        guard manager.isDeviceMotionAvailable else { return }

        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            Task { @MainActor in
                self?.handle(motion)
            }
        }
    }

    private func handle(_ motion: CMDeviceMotion) {
        let gravityX = motion.gravity.x
        let gravityY = motion.gravity.y
        if restX == nil {
            restX = gravityX
            restY = gravityY
        }
        let deltaX = gravityX - (restX ?? 0)
        let deltaY = gravityY - (restY ?? 0)
        let targetX = CGFloat(max(-1, min(1, deltaX / 0.22)))
        let targetY = CGFloat(max(-1, min(1, deltaY / 0.22)))
        tiltX = tiltX * 0.82 + targetX * 0.18
        tiltY = tiltY * 0.82 + targetY * 0.18

        let acceleration = motion.userAcceleration
        let magnitude = sqrt(
            acceleration.x * acceleration.x
                + acceleration.y * acceleration.y
                + acceleration.z * acceleration.z
        )
        if magnitude > 0.18 {
            impulseX = max(-1.3, min(1.3, impulseX + CGFloat(acceleration.x) * 0.9))
            impulseY = max(-1.3, min(1.3, impulseY + CGFloat(acceleration.y) * 0.6))
        } else {
            impulseX *= 0.88
            impulseY *= 0.88
            if abs(impulseX) < 0.002 { impulseX = 0 }
            if abs(impulseY) < 0.002 { impulseY = 0 }
        }
    }

    private func stop() {
        manager.stopDeviceMotionUpdates()
        tiltX = 0
        tiltY = 0
        impulseX = 0
        impulseY = 0
        restX = nil
        restY = nil
    }
}
