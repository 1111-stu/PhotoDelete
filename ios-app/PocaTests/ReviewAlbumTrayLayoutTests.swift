import Foundation
import Testing
@testable import Poca

struct ReviewAlbumTrayLayoutTests {
    @Test func folderPaletteCountMatchesPrototype() {
        #expect(Theme.albumFolderPalettes.count == 6)
    }

    @Test func paletteIndexIsStableForTheSameAlbumID() {
        for id in ["flow", "xhs", "wechat", "travel", "family", "shots"] {
            let first = ReviewAlbumTrayLayout.paletteIndex(for: id)
            let second = ReviewAlbumTrayLayout.paletteIndex(for: id)
            #expect(first == second)
        }
    }

    @Test func knownAlbumIDsKeepTheirPrototypeColorSlot() {
        // Snapshot: changing the hash must not silently reshuffle folder colors.
        #expect(ReviewAlbumTrayLayout.paletteIndex(for: "flow") == 1)
        #expect(ReviewAlbumTrayLayout.paletteIndex(for: "xhs") == 0)
        #expect(ReviewAlbumTrayLayout.paletteIndex(for: "wechat") == 5)
        #expect(ReviewAlbumTrayLayout.paletteIndex(for: "travel") == 1)
        #expect(ReviewAlbumTrayLayout.paletteIndex(for: "family") == 3)
        #expect(ReviewAlbumTrayLayout.paletteIndex(for: "shots") == 2)
    }

    @Test func paletteIndexStaysInRangeForUnicodeIDs() {
        for id in ["café-📷", "相册", "", "a-very-long-album-identifier-\(UUID().uuidString)"] {
            let index = ReviewAlbumTrayLayout.paletteIndex(for: id)
            #expect(index >= 0)
            #expect(index < Theme.albumFolderPalettes.count)
        }
    }

    @Test func trayMetricsMatchThePrototype() {
        #expect(Theme.radiusXl == 32)
        #expect(ReviewAlbumTrayLayout.sideMargin == 16)
        #expect(ReviewAlbumTrayLayout.bottomMargin == 16)
        #expect(ReviewAlbumTrayLayout.topBandHeight == 28)
        #expect(ReviewAlbumTrayLayout.closeVisualSize == 24)
        #expect(ReviewAlbumTrayLayout.closeHitSize == 44)
        #expect(ReviewAlbumTrayLayout.folderSize == 82)
        #expect(ReviewAlbumTrayLayout.cardWidth == 82)
        #expect(ReviewAlbumTrayLayout.railSpacing == 12)
        #expect(ReviewAlbumTrayLayout.pressScale == 0.97)
    }
}
