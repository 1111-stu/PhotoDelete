import XCTest
import SwiftUI
@testable import PhotoDelete

final class ProEntrySnapshotTests: XCTestCase {

    @MainActor
    func testRenderProEntryBanner() throws {
        try render(name: "pro-entry-free", type: nil)
        try render(name: "pro-entry-yearly", type: .yearly)
    }

    @MainActor
    private func render(name: String, type: SubscriptionManager.SubscriptionType?) throws {
        let card = ProEntryBanner(subscriptionType: type) {}
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(width: 402, alignment: .top)
            .background(Theme.background)
            .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(width: 402, height: nil)

        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
