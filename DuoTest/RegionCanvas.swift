//
//  RegionCanvas.swift
//  DuoTest
//
//  Full-screen view that reads the safe area, reserved regions and hinge,
//  and draws them.
//

import SwiftUI

extension RegionInfo {
    init(_ region: ReservedRegion) {
        self.init(id: region.id,
                  kind: region.kind == .division ? .division : .occlusion,
                  frame: region.frame,
                  margins: region.margins,
                  isActive: region.isActive)
    }
}

extension RegionSnapshot {
    /// Reads every region of both kinds, active and inactive, in physical
    /// (unmirrored) coordinates of the proxy's view. `safeArea` is passed in
    /// because a proxy under `.ignoresSafeArea()` reports zero insets.
    init(_ proxy: GeometryProxy, safeArea: EdgeInsets) {
        let kinds: [ReservedRegion.Kind] = [.division, .occlusion]
        let regions = kinds.flatMap { kind in
            proxy.reservedRegions(kind: kind, options: .includeInactive, layoutDirectionBehavior: .fixed)
        }
        self.init(size: proxy.size, safeArea: safeArea, regions: regions.map { RegionInfo($0) })
    }
}

struct RegionCanvas: View {
    @Binding var showToolbar: Bool

    @State private var hinge: HingeInfo?
    @State private var hingeReceived = false
    @State private var panelSize: CGSize = .zero

    var body: some View {
        GeometryReader { safeProxy in
        GeometryReader { proxy in
            // The outer reader is laid out inside the safe area, so its frame
            // *is* the safe rect; the insets are the gap between it and the
            // full-screen inner reader. (Its own `safeAreaInsets` describe the
            // insets around it, so they can't be subtracted from its frame.)
            let insets = RegionSnapshot.insets(full: proxy.frame(in: .global),
                                               safe: safeProxy.frame(in: .global))
            let snapshot = RegionSnapshot(proxy, safeArea: insets)
            let panelOrigin = snapshot.panelOrigin(for: panelSize)

            ZStack(alignment: .topLeading) {
                Color(white: 0.9)

                ForEach(snapshot.bands) { band in
                    BandView(band: band)
                }

                ForEach(snapshot.regions) { region in
                    RegionView(region: region)
                }

                ReadoutPanel(snapshot: snapshot, hinge: hinge, hingeReceived: hingeReceived,
                             maxSize: snapshot.panelMaxSize(), showToolbar: $showToolbar)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { panelSize = $0 }
                    .offset(x: panelOrigin.x, y: panelOrigin.y)
            }
            .animation(.snappy, value: snapshot)
            .animation(.snappy, value: panelOrigin)
        }
        .ignoresSafeArea()
        }
        .onHingeChange { _, newContext in
            hingeReceived = true
            hinge = newContext.hinge.map { HingeInfo(status: $0.status, degrees: $0.angle.degrees) }
        }
    }
}

private struct BandView: View {
    let band: InsetBand

    var body: some View {
        Rectangle()
            .fill(.blue.opacity(0.3))
            .overlay {
                Text(verbatim: band.label)
                    .font(.caption2.monospaced().bold())
                    .foregroundStyle(.blue)
                    .fixedSize()
                    .rotationEffect(band.isVertical ? .degrees(90) : .zero)
            }
            .frame(width: band.rect.width, height: band.rect.height)
            .offset(x: band.rect.minX, y: band.rect.minY)
    }
}

private struct RegionView: View {
    let region: RegionInfo

    private var color: Color { region.kind == .division ? .orange : .pink }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(color.opacity(region.isActive ? 0.35 : 0.08))
                .frame(width: region.frame.width, height: region.frame.height)
                .offset(x: region.frame.minX, y: region.frame.minY)

            OutlineShape(rect: region.hardwareRect)
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: region.isActive ? [] : [6, 4]))

            Text(verbatim: region.label)
                .font(.caption2.monospaced().bold())
                .foregroundStyle(color)
                .padding(2)
                .background(.white.opacity(0.7), in: .rect(cornerRadius: 3))
                .fixedSize()
                .offset(x: region.frame.minX + 4, y: max(region.frame.minY, 0) + 4)
        }
    }
}
