//
//  OverlayWindow.swift
//  DuoDevOverlay
//
//  The window the overlay lives in. It sits just above the app's window and
//  lets every touch outside the readout panel through to the app.
//

import SwiftUI
import UIKit

final class OverlayWindow: UIWindow {
    /// The readout panel's frame in this window's coordinates. Touches
    /// outside it go to the windows below. `.null` until the panel is laid out.
    var panelFrame: CGRect = .null

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard panelFrame.contains(point) else { return nil }
        return super.hitTest(point, with: event)
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
