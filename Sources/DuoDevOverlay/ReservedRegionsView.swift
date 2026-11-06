//
//  ReservedRegionsView.swift
//  DuoDevOverlay
//
//  Full-screen, transparent view that reads the safe area, reserved regions
//  and hinge, and draws them with a draggable readout panel.
//

import SwiftUI

@available(iOS 27.1, *)
extension RegionInfo {
    init(_ region: ReservedRegion) {
        self.init(id: region.id,
                  kind: region.kind == .division ? .division : .occlusion,
                  frame: region.frame,
                  margins: region.margins,
                  isActive: region.isActive)
    }
}

@available(iOS 27.1, *)
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

/// Draws the safe-area insets and reserved regions of the screen it covers,
/// with a readout panel that can be dragged and double-tapped back to its
/// automatic place. The view is transparent: put it over your content.
/// `accessory` appears at the top of the readout panel.
@available(iOS 27.1, *)
public struct ReservedRegionsView<Accessory: View>: View {
    private let accessory: Accessory
    private let onPanelFrameChange: (CGRect) -> Void

    @State private var hinge: HingeInfo?
    @State private var hingeReceived = false
    @State private var panelSize: CGSize = .zero
    @State private var panelPlacement: PanelPlacement = .automatic
    @GestureState private var panelDrag: CGSize = .zero

    public init(@ViewBuilder accessory: () -> Accessory) {
        self.init(onPanelFrameChange: { _ in }, accessory: accessory)
    }

    /// `onPanelFrameChange` receives the panel's frame in global coordinates
    /// whenever it moves or resizes.
    init(onPanelFrameChange: @escaping (CGRect) -> Void, @ViewBuilder accessory: () -> Accessory) {
        self.accessory = accessory()
        self.onPanelFrameChange = onPanelFrameChange
    }

    public var body: some View {
        GeometryReader { safeProxy in
        GeometryReader { proxy in
            // The outer reader is laid out inside the safe area, so its frame
            // *is* the safe rect; the insets are the gap between it and the
            // full-screen inner reader.
            let insets = RegionSnapshot.insets(full: proxy.frame(in: .global),
                                               safe: safeProxy.frame(in: .global))
            let snapshot = RegionSnapshot(proxy, safeArea: insets)
            // Where the panel rests, and where it is right now while dragged.
            let restingOrigin = snapshot.panelOrigin(for: panelSize, placement: panelPlacement)
            let panelOrigin = snapshot.clampedPanelOrigin(
                CGPoint(x: restingOrigin.x + panelDrag.width, y: restingOrigin.y + panelDrag.height),
                panelSize: panelSize)

            ZStack(alignment: .topLeading) {
                Color.clear

                Group {
                    ForEach(snapshot.bands) { band in
                        BandView(band: band)
                    }
                    ForEach(snapshot.regions) { region in
                        RegionView(region: region)
                    }
                }
                .allowsHitTesting(false)

                ReadoutPanel(snapshot: snapshot, hinge: hinge, hingeReceived: hingeReceived,
                             maxSize: snapshot.panelMaxSize(), accessory: accessory)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("readoutPanel")
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { panelSize = $0 }
                    // Inside `.offset`, so the global frame includes where the
                    // panel is drawn. (Read outside it, the frame stays put.)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onPanelFrameChange($0) }
                    .gesture(
                        DragGesture(minimumDistance: 8, coordinateSpace: .global)
                            .updating($panelDrag) { value, drag, _ in drag = value.translation }
                            .onEnded { value in
                                panelPlacement = .manual(CGPoint(x: restingOrigin.x + value.translation.width,
                                                                 y: restingOrigin.y + value.translation.height))
                            }
                    )
                    .onTapGesture(count: 2) { panelPlacement = .automatic }
                    .offset(x: panelOrigin.x, y: panelOrigin.y)
            }
            .animation(.snappy, value: snapshot)
            // Animate when the resting place changes (fold, rotate, reset),
            // but not while following a finger.
            .animation(.snappy, value: restingOrigin)
        }
        .ignoresSafeArea()
        }
        .onHingeChange { _, newContext in
            hingeReceived = true
            hinge = newContext.hinge.map { HingeInfo(status: $0.status, degrees: $0.angle.degrees) }
        }
    }
}

@available(iOS 27.1, *)
extension ReservedRegionsView where Accessory == EmptyView {
    public init() {
        self.init { EmptyView() }
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
