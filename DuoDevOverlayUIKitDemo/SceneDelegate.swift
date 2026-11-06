//
//  SceneDelegate.swift
//  DuoDevOverlayUIKitDemo
//

import DuoDevOverlay
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }

        let tabs = UITabBarController()
        tabs.viewControllers = [
            UINavigationController(rootViewController: RowsViewController(title: "Rows", symbol: "list.bullet")),
            UINavigationController(rootViewController: RowsViewController(title: "More", symbol: "ellipsis.circle")),
        ]

        let window = UIWindow(windowScene: scene)
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        self.window = window

        #if DEBUG
        DuoDevOverlay.install(in: scene)
        #endif
    }
}
