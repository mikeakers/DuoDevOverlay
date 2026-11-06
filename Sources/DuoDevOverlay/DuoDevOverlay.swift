//
//  DuoDevOverlay.swift
//  DuoDevOverlay
//
//  Public entry point: put the overlay on a scene, or take it off.
//

import SwiftUI
import UIKit

/// A debug overlay that draws the safe-area insets and reserved regions (the
/// iPhone Duo's fold, cameras and status block) over your app, with a
/// draggable readout panel.
///
/// ```swift
/// #if DEBUG
/// DuoDevOverlay.install(in: windowScene)
/// #endif
/// ```
///
/// The overlay has its own window above the app's, so it stays on top of
/// modals and root-view-controller swaps, and every touch outside the panel
/// reaches the app. It sees window-level geometry only: insets that your own
/// navigation and tab bars add inside your view controllers don't appear.
@MainActor
public enum DuoDevOverlay {
    /// Adds the overlay to `scene`. Does nothing if `scene` already has it,
    /// or below iOS 27.1, where the reserved-region APIs don't exist.
    public static func install(in scene: UIWindowScene) {
        guard #available(iOS 27.1, *) else { return }
        guard OverlayStore.window(for: scene) == nil else { return }

        let window = OverlayWindow(windowScene: scene)
        window.windowLevel = .normal + 1
        window.backgroundColor = .clear

        let overlay = ReservedRegionsView(onPanelFrameChange: { [weak window] frame in
            window?.panelFrame = frame
        }) {
            Button("Hide overlay") { [weak scene] in
                if let scene { uninstall(from: scene) }
            }
        }
        let controller = OverlayHostingController(rootView: overlay)
        controller.view.backgroundColor = .clear
        window.rootViewController = controller

        // Shown but never made key, so the app keeps the keyboard and focus.
        window.isHidden = false
        OverlayStore.setWindow(window, for: scene)
    }

    /// Removes the overlay from `scene`, if it has one.
    public static func uninstall(from scene: UIWindowScene) {
        guard let window = OverlayStore.window(for: scene) else { return }
        OverlayStore.setWindow(nil, for: scene)
        window.isHidden = true
        window.rootViewController = nil
    }

    /// Whether `scene` currently has the overlay.
    public static func isInstalled(in scene: UIWindowScene) -> Bool {
        OverlayStore.window(for: scene) != nil
    }
}
