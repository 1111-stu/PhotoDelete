import Foundation
import Testing
@testable import Poca

struct PocaToastTests {
    @Test func standardToastUsesUnifiedDwell() {
        let toast = PocaToast(message: "Saved", icon: "checkmark", style: .positive)
        #expect(PocaToastTiming.visibleDuration(for: toast) == 2.4)
    }

    @Test func undoToastStaysLonger() {
        let toast = PocaToast(
            message: "Deleted",
            icon: "trash",
            style: .destructive,
            showsUndo: true
        )
        #expect(PocaToastTiming.visibleDuration(for: toast) == 4.5)
    }

    @Test func explicitDurationOverridesDefaults() {
        let toast = PocaToast(
            message: "Muted",
            icon: "speaker.slash.fill",
            style: .neutral,
            duration: 1.1
        )
        #expect(PocaToastTiming.visibleDuration(for: toast) == 1.1)
    }

    @Test func explicitDurationWinsEvenWithUndo() {
        let toast = PocaToast(
            message: "Saved",
            icon: "checkmark",
            style: .positive,
            showsUndo: true,
            duration: 2
        )
        #expect(PocaToastTiming.visibleDuration(for: toast) == 2)
    }
}
