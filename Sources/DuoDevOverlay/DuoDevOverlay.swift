//
//  DuoDevOverlay.swift
//  DuoDevOverlay
//
//  Public entry point: put the overlay on a scene, or take it off.
//

import Foundation
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
    /// Posted on the main thread whenever the overlay is added to or removed
    /// from a scene, including when the panel's **Hide overlay** button
    /// removes it. The notification's `object` is the `UIWindowScene`; read
    /// ``isInstalled(in:)`` for the new state.
    ///
    /// ```swift
    /// NotificationCenter.default.addObserver(
    ///     self, selector: #selector(overlayDidChange),
    ///     name: DuoDevOverlay.didChangeNotification, object: windowScene)
    /// ```
    nonisolated public static let didChangeNotification = Notification.Name("DuoDevOverlayDidChange")

    /// Adds the overlay to `scene` and posts ``didChangeNotification``. Does
    /// nothing if `scene` already has it, or below iOS 27.1, where the
    /// reserved-region APIs don't exist. Built with a toolchain older than
    /// Xcode 27.1 (which lacks those APIs), it always does nothing, so apps
    /// can link the package unconditionally.
    public static func install(in scene: UIWindowScene) {
        // Swift 6.4.1 (Xcode 27.1) is the first toolchain with the iOS 27.1 SDK.
        #if compiler(>=6.4.1)
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
        postDidChange(for: scene)
        #endif
    }

    /// Removes the overlay from `scene`, if it has one, and posts
    /// ``didChangeNotification``.
    public static func uninstall(from scene: UIWindowScene) {
        guard let window = OverlayStore.window(for: scene) else { return }
        OverlayStore.setWindow(nil, for: scene)
        window.isHidden = true
        window.rootViewController = nil
        postDidChange(for: scene)
    }

    /// Whether `scene` currently has the overlay.
    public static func isInstalled(in scene: UIWindowScene) -> Bool {
        OverlayStore.window(for: scene) != nil
    }

    private static func postDidChange(for scene: UIWindowScene) {
        NotificationCenter.default.post(name: didChangeNotification, object: scene)
    }
}
