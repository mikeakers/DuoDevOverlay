//
//  OverlayPassThroughUITests.swift
//  DuoDevOverlayUIKitDemoUITests
//
//  The overlay over a plain UIKit app: touches outside the panel reach the
//  app, the panel still drags, and the overlay can be hidden and reinstalled.
//

import XCTest

final class OverlayPassThroughUITests: XCTestCase {
    private var app: XCUIApplication!
    private var panel: XCUIElement { app.descendants(matching: .any)["readoutPanel"].firstMatch }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(panel.waitForExistence(timeout: 10), "the overlay should be installed at launch")
        settle()
    }

    @MainActor
    func testTapOutsidePanelReachesApp() throws {
        // A row well clear of the panel and of the tab bar.
        let bottomLimit = app.frame.maxY - 120
        let row = try XCTUnwrap(app.cells.allElementsBoundByIndex.first { cell in
            cell.frame.minY > 0 && cell.frame.maxY < bottomLimit && !cell.frame.intersects(panel.frame)
        }, "no row is clear of the panel")
        let title = row.staticTexts.firstMatch.label

        // A real touch at the row's center, which goes through the overlay window.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5),
                      "tapping \(title) under the overlay should push its screen")
    }

    @MainActor
    func testPanelStillDrags() {
        let start = panel.frame
        let grab = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        grab.press(forDuration: 0.2, thenDragTo: grab.withOffset(CGVector(dx: 40, dy: 180)))
        settle()
        XCTAssertEqual(panel.frame.minX - start.minX, 40, accuracy: 12)
        XCTAssertEqual(panel.frame.minY - start.minY, 180, accuracy: 12)
    }

    // Bar buttons are found anywhere in the app: on the outer screen they move
    // to a vertical bar beside the content, outside the navigation bar.
    @MainActor
    func testHideThenReinstall() {
        app.buttons["Hide overlay"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5), "Hide overlay should remove the panel")

        app.buttons["Overlay"].firstMatch.tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "the Overlay button should reinstall it")
    }

    /// Issue #2: a host control showing the overlay's state must follow the
    /// panel's own Hide overlay button, so a single tap brings the overlay back.
    @MainActor
    func testHostButtonFollowsHideOverlay() {
        let overlayButton = app.buttons["Overlay"].firstMatch
        XCTAssertEqual(overlayButton.value as? String, "On")

        app.buttons["Hide overlay"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        XCTAssertEqual(overlayButton.value as? String, "Off",
                       "the host's button should hear that the panel uninstalled the overlay")

        overlayButton.tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "one tap should bring the overlay back")
        XCTAssertEqual(overlayButton.value as? String, "On")
    }

    @MainActor
    func testOverlayStaysAboveModal() {
        app.buttons["Modal"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Modal"].waitForExistence(timeout: 5))
        settle()

        // The panel is still on top, so its button takes the tap rather than the modal.
        app.buttons["Hide overlay"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Modal"].exists, "the modal should be untouched")
    }

    /// Lets placement animations finish.
    private func settle() {
        Thread.sleep(forTimeInterval: 1)
    }
}
