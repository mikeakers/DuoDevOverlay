//
//  ReadoutPanel.swift
//  DuoDevOverlay
//

import SwiftUI

// Swift 6.4.1 (Xcode 27.1) is the first toolchain with the iOS 27.1 SDK.
#if compiler(>=6.4.1)

/// The numbers: hinge, view size, size classes, insets and every region.
/// `accessory` is shown first, above a divider.
@available(iOS 27.1, *)
struct ReadoutPanel<Accessory: View>: View {
    let snapshot: RegionSnapshot
    let hinge: HingeInfo?
    let hingeReceived: Bool
    /// The panel never grows past this; its contents scroll instead.
    let maxSize: CGSize
    let accessory: Accessory

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            details
                .padding(10)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        // Only scroll when the contents overflow, so a drag normally moves the panel.
        .scrollDisabled(contentHeight <= maxSize.height)
        .font(.caption.monospaced())
        .frame(width: min(280, maxSize.width), height: min(contentHeight, maxSize.height))
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            // First, so it stays reachable even when the panel has to scroll.
            if Accessory.self != EmptyView.self {
                accessory
                Divider()
            }

            Text(verbatim: "Hinge  \(Readout.hinge(hinge, received: hingeReceived))")
            Text(verbatim: "View   \(Readout.size(snapshot.size))")
            Text(verbatim: "Class  \(Readout.sizeClass(horizontalSizeClass)) × \(Readout.sizeClass(verticalSizeClass))")
            Text(verbatim: "Safe   \(Readout.insets(snapshot.safeArea))")

            Divider()

            if snapshot.regions.isEmpty {
                Text(verbatim: "No reserved regions")
            }
            ForEach(snapshot.regions) { region in
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: region.label).bold()
                    Text(verbatim: "  frame   \(Readout.rect(region.frame))")
                    Text(verbatim: "  margins \(Readout.insets(region.margins))")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#endif
