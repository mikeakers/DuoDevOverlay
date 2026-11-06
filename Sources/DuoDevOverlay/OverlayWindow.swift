//
//  OverlayWindow.swift
//  DuoDevOverlay
//
//  The window the overlay lives in. It sits just above the app's window and
//  lets every touch outside the readout panel through to the app.
//

import ObjectiveC
import SwiftUI
import UIKit

final class OverlayWindow: UIWindow {
    /// The readout panel's frame in this window's coordinates. Touches
    /// outside it go to the windows below. `.null` until the panel is laid out.
    var panelFrame: CGRect = .null

    /// Never key, even when UIKit picks a new key window after another one
    /// hides, so the app keeps the keyboard and its `keyWindow` presentations
    /// never land in this mostly untouchable window.
    override var canBecomeKey: Bool { false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard panelFrame.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// Each scene's overlay window, attached to the scene itself. The window
/// lives exactly as long as its scene, so a disconnected scene can't leak it,
/// and a new scene at a reused address can't inherit it. (The window refers
/// back to its scene only weakly, so there's no cycle.)
enum OverlayStore {
    private static var key: UInt8 = 0

    static func window(for owner: AnyObject) -> UIWindow? {
        objc_getAssociatedObject(owner, &key) as? UIWindow
    }

    static func setWindow(_ window: UIWindow?, for owner: AnyObject) {
        objc_setAssociatedObject(owner, &key, window, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

/// Hosts the overlay, but leaves the status bar, orientation and home
/// indicator to the app's own view controllers.
@available(iOS 27.1, *)
final class OverlayHostingController<Content: View>: UIHostingController<Content> {
    /// The topmost view controller of the app's own window in this scene.
    private var appController: UIViewController? {
        guard let scene = view.window?.windowScene else { return nil }
        let appWindows = scene.windows.filter { !($0 is OverlayWindow) }
        var top = (appWindows.first(where: \.isKeyWindow) ?? appWindows.first)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// Follows a `childFor…` chain down from the app's top view controller,
    /// the way UIKit does for its own window.
    private func deciding(_ child: (UIViewController) -> UIViewController?) -> UIViewController? {
        var controller = appController
        while let current = controller, let next = child(current) {
            controller = next
        }
        return controller
    }

    override var prefersStatusBarHidden: Bool {
        deciding(\.childForStatusBarHidden)?.prefersStatusBarHidden ?? false
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        deciding(\.childForStatusBarStyle)?.preferredStatusBarStyle ?? .default
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        deciding(\.childForHomeIndicatorAutoHidden)?.prefersHomeIndicatorAutoHidden ?? false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        appController?.supportedInterfaceOrientations ?? .all
    }
}
