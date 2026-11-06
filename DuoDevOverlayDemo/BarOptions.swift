//
//  BarOptions.swift
//  DuoDevOverlayDemo
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

    /// Visible while the bar has a toolbar or title, hidden otherwise. (On
    /// iPhone Duo this matches what `.automatic` does, so there's no switch
    /// for it.)
    var navigationBarVisibility: Visibility {
        toolbar || title ? .visible : .hidden
    }

    var tabBarVisibility: Visibility {
        tabBar ? .visible : .hidden
    }
}
