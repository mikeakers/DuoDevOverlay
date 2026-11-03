//
//  ContentView.swift
//  DuoTest
//
//  Created by Mike Akers on 11/2/26.
//

import SwiftUI

struct ContentView: View {
    @State private var options = BarOptions()

    var body: some View {
        // The TabView is always present; the tab-bar switch only hides or
        // shows the bar, so flipping it doesn't rebuild the screen.
        TabView {
            Tab("Regions", systemImage: "square.dashed") {
                RegionTab(options: $options)
            }
            Tab("Insets", systemImage: "rectangle.inset.filled") {
                RegionTab(options: $options)
            }
            Tab("Hinge", systemImage: "book") {
                RegionTab(options: $options)
            }
        }
    }
}

/// One tab: the region canvas inside a navigation stack whose bars follow
/// `options`.
private struct RegionTab: View {
    @Binding var options: BarOptions

    var body: some View {
        NavigationStack {
            RegionCanvas(options: $options)
                .navigationTitle(options.title ? "Regions" : "")
                .toolbar(options.navigationBarVisibility, for: .navigationBar)
                .toolbar(options.tabBarVisibility, for: .tabBar)
                .toolbar {
                    if options.toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close", systemImage: "xmark") {}
                        }
                        ToolbarItemGroup(placement: .primaryAction) {
                            Button("Share", systemImage: "square.and.arrow.up") {}
                            Button("Favorite", systemImage: "star") {}
                            Button("More", systemImage: "ellipsis") {}
                        }
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
