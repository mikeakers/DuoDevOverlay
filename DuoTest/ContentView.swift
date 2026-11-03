//
//  ContentView.swift
//  DuoTest
//
//  Created by Mike Akers on 11/2/26.
//

import SwiftUI

struct ContentView: View {
    @State private var showToolbar = false

    var body: some View {
        NavigationStack {
            RegionCanvas(showToolbar: $showToolbar)
                .toolbar(showToolbar ? .visible : .hidden, for: .navigationBar)
                .toolbar {
                    if showToolbar {
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
