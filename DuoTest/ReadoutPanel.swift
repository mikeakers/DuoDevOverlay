//
//  ReadoutPanel.swift
//  DuoTest
//

import SwiftUI

struct ReadoutPanel: View {
    let snapshot: RegionSnapshot
    let hinge: HingeInfo?
    let hingeReceived: Bool
    @Binding var showToolbar: Bool

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

            Divider()

            Toggle("Show toolbar", isOn: $showToolbar)
        }
        .font(.caption.monospaced())
        .padding(10)
        .frame(width: 280, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }
}
