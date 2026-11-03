//
//  BarOptions.swift
//  DuoTest
//
//  Which system bars the visualizer shows, so their effect on the safe area
//  can be compared live.
//

import SwiftUI

struct BarOptions: Equatable {
    /// Icon buttons in the navigation bar (they can move to a vertical bar).
    var toolbar = false
    /// A navigation title (text, so it stays horizontal).
    var title = false
    var tabBar = false
    /// When on, the app sets the navigation bar's visibility itself: visible
    /// while it has a toolbar or title, hidden otherwise. When off, the system
    /// decides (`.automatic`).
    var forceNavigationBar = true

    var navigationBarVisibility: Visibility {
        guard forceNavigationBar else { return .automatic }
        return toolbar || title ? .visible : .hidden
    }

    var tabBarVisibility: Visibility {
        tabBar ? .visible : .hidden
    }
}
