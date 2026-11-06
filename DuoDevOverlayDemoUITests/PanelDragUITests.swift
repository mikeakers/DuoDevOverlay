//
//  PanelDragUITests.swift
//  DuoDevOverlayDemoUITests
//
//  Drives the readout panel's drag and double-tap with real touches.
//

import XCTest

final class PanelDragUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDraggingMovesPanelAndDoubleTapResetsIt() throws {
        let app = XCUIApplication()
        app.launch()

        let panel = app.descendants(matching: .any)["readoutPanel"].firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        settle()
        let start = panel.frame

        // Grab the readout text near the bottom of the panel, below the switches.
        let grab = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        grab.press(forDuration: 0.2, thenDragTo: grab.withOffset(CGVector(dx: 40, dy: 180)))
        settle()
        let moved = panel.frame
        XCTAssertEqual(moved.minX - start.minX, 40, accuracy: 12, "panel should follow the drag horizontally")
        XCTAssertEqual(moved.minY - start.minY, 180, accuracy: 12, "panel should follow the drag vertically")

        // Switches still work after the panel has moved.
        let tabBar = app.switches["Tab bar"]
        XCTAssertEqual(tabBar.value as? String, "0")
        tabBar.switches.firstMatch.tap()
        XCTAssertEqual(tabBar.value as? String, "1")
        tabBar.switches.firstMatch.tap()

        // Double-tap returns it to automatic placement.
        panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).doubleTap()
        settle()
        XCTAssertEqual(panel.frame.minX, start.minX, accuracy: 2)
        XCTAssertEqual(panel.frame.minY, start.minY, accuracy: 2)
    }

    /// Lets placement animations finish.
    private func settle() {
        Thread.sleep(forTimeInterval: 1)
    }
}
