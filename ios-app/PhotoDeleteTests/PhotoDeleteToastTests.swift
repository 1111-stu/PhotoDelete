import Foundation
import Testing
@testable import PhotoDelete

struct PhotoDeleteToastTests {
    @Test func standardToastUsesUnifiedDwell() {
        let toast = PhotoDeleteToast(message: "Saved", icon: "checkmark", style: .positive)
        #expect(PhotoDeleteToastTiming.visibleDuration(for: toast) == 2.4)
    }

    @Test func undoToastStaysLonger() {
        let toast = PhotoDeleteToast(
            message: "Deleted",
            icon: "trash",
            style: .destructive,
            showsUndo: true
        )
        #expect(PhotoDeleteToastTiming.visibleDuration(for: toast) == 4.5)
    }

    @Test func explicitDurationOverridesDefaults() {
        let toast = PhotoDeleteToast(
            message: "Muted",
            icon: "speaker.slash.fill",
            style: .neutral,
            duration: 1.1
        )
        #expect(PhotoDeleteToastTiming.visibleDuration(for: toast) == 1.1)
    }

    @Test func explicitDurationWinsEvenWithUndo() {
        let toast = PhotoDeleteToast(
            message: "Saved",
            icon: "checkmark",
            style: .positive,
            showsUndo: true,
            duration: 2
        )
        #expect(PhotoDeleteToastTiming.visibleDuration(for: toast) == 2)
    }
}
