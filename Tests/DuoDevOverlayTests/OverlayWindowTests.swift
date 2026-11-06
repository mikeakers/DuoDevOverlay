import Testing
import UIKit
@testable import DuoDevOverlay

@MainActor
struct OverlayWindowTests {
    private func makeWindow(panel: CGRect) -> OverlayWindow {
        let window = OverlayWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.isHidden = false
        window.panelFrame = panel
        return window
    }

    @Test func touchOutsidePanelPassesThrough() {
        let window = makeWindow(panel: CGRect(x: 12, y: 60, width: 280, height: 300))
        #expect(window.hitTest(CGPoint(x: 350, y: 600), with: nil) == nil)
    }

    @Test func touchInsidePanelIsHandledByTheOverlay() {
        let window = makeWindow(panel: CGRect(x: 12, y: 60, width: 280, height: 300))
        #expect(window.hitTest(CGPoint(x: 100, y: 100), with: nil) != nil)
    }

    @Test func beforeThePanelIsLaidOutEveryTouchPassesThrough() {
        let window = makeWindow(panel: .null)
        #expect(window.hitTest(CGPoint(x: 100, y: 100), with: nil) == nil)
    }
}
