//
//  BarSwitches.swift
//  DuoDevOverlayDemo
//
//  The demo's own switches, shown at the top of the readout panel.
//

import SwiftUI

struct BarSwitches: View {
    @Binding var options: BarOptions

    var body: some View {
        Toggle("Toolbar", isOn: $options.toolbar)
        Toggle("Nav title", isOn: $options.title)
        Toggle("Tab bar", isOn: $options.tabBar)
    }
}
