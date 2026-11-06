import Foundation
import Testing
import UIKit
@testable import DuoDevOverlay

/// The store keeps an overlay window for exactly as long as its owner (a
/// scene, in the app) lives.
@MainActor
struct OverlayStoreTests {
    @Test func windowIsFoundForItsOwner() {
        let owner = NSObject()
        let window = UIWindow(frame: .zero)
        OverlayStore.setWindow(window, for: owner)
        #expect(OverlayStore.window(for: owner) === window)
        OverlayStore.setWindow(nil, for: owner)
        #expect(OverlayStore.window(for: owner) == nil)
    }

    @Test func windowIsReleasedWithItsOwner() {
        weak var released: UIWindow?
        do {
            let owner = NSObject()
            let window = UIWindow(frame: .zero)
            OverlayStore.setWindow(window, for: owner)
            released = window
        }
        #expect(released == nil, "a disconnected scene's overlay window should not outlive it")
    }

    @Test func aNewOwnerNeverInheritsAnOldOwnersWindow() {
        // Freed objects' addresses get reused; a new scene must start empty.
        for _ in 0..<50 {
            autoreleasepool {
                let owner = NSObject()
                OverlayStore.setWindow(UIWindow(frame: .zero), for: owner)
            }
            let fresh = NSObject()
            #expect(OverlayStore.window(for: fresh) == nil)
        }
    }
}
