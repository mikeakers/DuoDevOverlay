# Reserved-Region Visualizer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A single SwiftUI screen that draws iPhone Duo's safe-area insets (status bar, optional toolbar) and reserved regions (fold, cameras) live as the device changes pose and orientation, with a readout of the numbers.

**Architecture:** A full-screen `GeometryReader` (ignoring the safe area) turns its proxy into a plain `RegionSnapshot` value each layout pass; views draw the snapshot. All geometry and formatting lives in `RegionSnapshot.swift` as pure, unit-tested code; the view files only draw. Hinge state comes from `onHingeChange` and only feeds the readout.

**Tech Stack:** Swift 5 mode, SwiftUI (iOS 27.1+ `ReservedRegion` / `DeviceHinge` APIs), Swift Testing, Xcode 27.2 RC, iPhone Duo simulator.

**Spec:** `docs/superpowers/specs/2026-11-02-reserved-region-visualizer-design.md`

## Global Constraints

- Deployment target is iOS 27.2 — use iOS 27.1 APIs directly, no `#available` guards.
- SwiftUI only. No UIKit views, no new dependencies, no edits to `DuoTest.xcodeproj` (folder-based membership: files under `DuoTest/` and `DuoTestTests/` join their targets automatically).
- Target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `MemberImportVisibility`; test suites are marked `@MainActor`, and each file imports what it uses (`SwiftUI`, `Foundation` for `String(format:)`).
- Query reserved regions with both kinds, `options: .includeInactive`, `layoutDirectionBehavior: .fixed`.
- `frame` already includes `margins`; hardware rect = `frame` inset by `margins`. Never pad by margins twice.
- `DeviceHinge.Status` and `ReservedRegion.Kind` are structs — any `switch` needs `default`.
- Hinge drives the readout only, never layout.
- Out of scope: logging/export, UIKit version, camera, sample layouts / `ArrangementView`, RTL comparison.

All build/test commands assume:

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.2.0-Release.Candidate.app/Contents/Developer
export SIM=24D777C6-5C3A-4D1C-B22A-D3326828DC88   # "iPhone Duo", iOS 27.2
```

Unit tests: `xcodebuild test -project DuoTest.xcodeproj -scheme DuoTest -destination "platform=iOS Simulator,id=$SIM" -only-testing:DuoTestTests 2>&1 | grep -E '✔|✘|error:|passed|failed|TEST (SUCCEEDED|FAILED)'`

## Review Focus

1. **Flat device → inactive fold with zero width (or zero height).** Expect a visible dashed line, never a negative-size rect or an invisible shape. Pinned by `hardwareRectOfZeroWidthRegionIsZeroWidth` and `outlineOfZeroWidthRectIsALine` (Task 1).
2. **Region partly outside the view** (corner camera with negative origin). Expect it drawn where it is and still treated as an obstacle for the readout panel. Pinned by `regionWithNegativeOriginStillBlocksCorner` (Task 1).
3. **No hinge callback yet / device without a hinge.** Before the first `onHingeChange` call the readout must say "waiting for update", not "no hinge"; after a callback with `hinge == nil` it says "no hinge". Pinned by `hingeReadoutDistinguishesWaitingFromNoHinge` (Task 1).
4. **Safe-area insets reported as zero under `.ignoresSafeArea()`.** Expect real non-zero insets (status bar). Checked by screenshot in Task 3, with the concrete fallback written there.
5. **Every corner blocked, or the panel bigger than the safe area** (outer display, landscape). Expect the least-overlapping corner, no crash. Pinned by `allCornersBlockedPicksLeastOverlap` and `panelLargerThanSafeAreaStillReturnsACorner` (Task 1).

---

### Task 1: Model, geometry and formatting (pure, TDD)

**Files:**
- Create: `DuoTest/RegionSnapshot.swift`
- Test: `DuoTestTests/RegionSnapshotTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces (used by Tasks 2–3):
  - `enum RegionKind: String { case division, occlusion }`
  - `struct RegionInfo: Identifiable, Equatable { var id: String; var kind: RegionKind; var frame: CGRect; var margins: EdgeInsets; var isActive: Bool; var hardwareRect: CGRect { get }; var label: String { get } }`
  - `struct HingeInfo: Equatable { var status: DeviceHinge.Status; var degrees: Double; var statusName: String { get } }`
  - `struct InsetBand: Identifiable, Equatable { var edge: Edge; var rect: CGRect; var points: CGFloat; var id: Edge { get }; var isVertical: Bool { get }; var label: String { get } }`
  - `struct RegionSnapshot: Equatable { var size: CGSize; var safeArea: EdgeInsets; var regions: [RegionInfo]; var safeRect: CGRect { get }; var bands: [InsetBand] { get }; func panelOrigin(for panelSize: CGSize, padding: CGFloat = 12) -> CGPoint }`
  - `struct OutlineShape: Shape { var rect: CGRect }`
  - `enum Readout { static func points(_:) -> String; static func size(_:) -> String; static func rect(_:) -> String; static func insets(_:) -> String; static func sizeClass(_:) -> String; static func hinge(_ hinge: HingeInfo?, received: Bool) -> String }`

- [ ] **Step 1: Write the failing tests**

Create `DuoTestTests/RegionSnapshotTests.swift`:

```swift
import Testing
import SwiftUI
@testable import DuoTest

@MainActor
struct RegionInfoTests {
    @Test func hardwareRectInsetsFrameByMargins() {
        let fold = RegionInfo(id: "fold", kind: .division,
                              frame: CGRect(x: 380, y: 0, width: 40, height: 700),
                              margins: EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8),
                              isActive: true)
        #expect(fold.hardwareRect == CGRect(x: 392, y: 0, width: 20, height: 700))
    }

    @Test func hardwareRectNeverGoesNegativeOrLeavesFrame() {
        let frame = CGRect(x: 100, y: 50, width: 20, height: 10)
        let region = RegionInfo(id: "r", kind: .occlusion, frame: frame,
                                margins: EdgeInsets(top: 8, leading: 30, bottom: 8, trailing: 30),
                                isActive: true)
        let hardware = region.hardwareRect
        #expect(hardware.width == 0)
        #expect(hardware.height == 0)
        #expect(hardware.minX >= frame.minX && hardware.maxX <= frame.maxX)
        #expect(hardware.minY >= frame.minY && hardware.maxY <= frame.maxY)
    }

    @Test func hardwareRectOfZeroWidthRegionIsZeroWidth() {
        let flatFold = RegionInfo(id: "fold", kind: .division,
                                  frame: CGRect(x: 400, y: 0, width: 0, height: 700),
                                  margins: EdgeInsets(), isActive: false)
        #expect(flatFold.hardwareRect == CGRect(x: 400, y: 0, width: 0, height: 700))
    }

    @Test func labelNamesKindAndMarksInactive() {
        var region = RegionInfo(id: "c", kind: .occlusion, frame: .zero, margins: EdgeInsets(), isActive: true)
        #expect(region.label == "occlusion")
        region.isActive = false
        #expect(region.label == "occlusion · inactive")
    }
}

@MainActor
struct OutlineShapeTests {
    @Test func outlineOfZeroWidthRectIsALine() {
        let path = OutlineShape(rect: CGRect(x: 400, y: 0, width: 0, height: 700))
            .path(in: CGRect(x: 0, y: 0, width: 800, height: 700))
        #expect(!path.isEmpty)
        #expect(path.boundingRect == CGRect(x: 400, y: 0, width: 0, height: 700))
    }

    @Test func outlineOfNormalRectIsThatRect() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        let path = OutlineShape(rect: rect).path(in: CGRect(x: 0, y: 0, width: 800, height: 700))
        #expect(path.boundingRect == rect)
    }
}

@MainActor
struct InsetBandTests {
    @Test func asymmetricInsetsProduceOnlyNonZeroBands() {
        let snapshot = RegionSnapshot(size: CGSize(width: 800, height: 600),
                                      safeArea: EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 54),
                                      regions: [])
        let bands = snapshot.bands
        #expect(bands.map(\.edge) == [.bottom, .trailing])
        #expect(bands[0].rect == CGRect(x: 0, y: 580, width: 800, height: 20))
        #expect(bands[1].rect == CGRect(x: 746, y: 0, width: 54, height: 600))
        #expect(bands[1].isVertical)
        #expect(!bands[0].isVertical)
        #expect(bands[1].label == "trailing 54pt")
    }

    @Test func allFourEdgesInOrder() {
        let snapshot = RegionSnapshot(size: CGSize(width: 400, height: 800),
                                      safeArea: EdgeInsets(top: 59, leading: 10, bottom: 34, trailing: 12.5),
                                      regions: [])
        #expect(snapshot.bands.map(\.edge) == [.top, .bottom, .leading, .trailing])
        #expect(snapshot.bands[0].rect == CGRect(x: 0, y: 0, width: 400, height: 59))
        #expect(snapshot.bands[2].rect == CGRect(x: 0, y: 0, width: 10, height: 800))
        #expect(snapshot.bands[3].label == "trailing 12.5pt")
    }

    @Test func noInsetsNoBands() {
        let snapshot = RegionSnapshot(size: CGSize(width: 800, height: 600), safeArea: EdgeInsets(), regions: [])
        #expect(snapshot.bands.isEmpty)
    }
}

@MainActor
struct PanelPlacementTests {
    let screen = CGSize(width: 800, height: 600)
    let panel = CGSize(width: 200, height: 100)

    func region(_ frame: CGRect, active: Bool = true) -> RegionInfo {
        RegionInfo(id: UUID().uuidString, kind: .occlusion, frame: frame, margins: EdgeInsets(), isActive: active)
    }

    @Test func noRegionsPrefersTopLeading() {
        let snapshot = RegionSnapshot(size: screen, safeArea: EdgeInsets(), regions: [])
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 12, y: 12))
    }

    @Test func respectsSafeArea() {
        let snapshot = RegionSnapshot(size: screen,
                                      safeArea: EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 54),
                                      regions: [region(CGRect(x: 0, y: 0, width: 120, height: 80))])
        // Top-leading is blocked by the camera; top-trailing sits inside the trailing inset.
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 534, y: 42))
    }

    @Test func avoidsCameraAndFold() {
        let fold = RegionInfo(id: "fold", kind: .division, frame: CGRect(x: 380, y: 0, width: 40, height: 600),
                              margins: EdgeInsets(), isActive: true)
        let snapshot = RegionSnapshot(size: screen, safeArea: EdgeInsets(),
                                      regions: [fold, region(CGRect(x: 0, y: 0, width: 120, height: 60))])
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 588, y: 12))
    }

    @Test func inactiveRegionsDoNotBlock() {
        let snapshot = RegionSnapshot(size: screen, safeArea: EdgeInsets(),
                                      regions: [region(CGRect(x: 0, y: 0, width: 120, height: 60), active: false)])
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 12, y: 12))
    }

    @Test func regionWithNegativeOriginStillBlocksCorner() {
        let snapshot = RegionSnapshot(size: screen, safeArea: EdgeInsets(),
                                      regions: [region(CGRect(x: -20, y: -20, width: 100, height: 60))])
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 588, y: 12))
    }

    @Test func allCornersBlockedPicksLeastOverlap() {
        let snapshot = RegionSnapshot(size: screen, safeArea: EdgeInsets(), regions: [
            region(CGRect(x: 0, y: 0, width: 300, height: 200)),     // covers top-leading
            region(CGRect(x: 500, y: 0, width: 300, height: 200)),   // covers top-trailing
            region(CGRect(x: 0, y: 400, width: 300, height: 200)),   // covers bottom-leading
            region(CGRect(x: 700, y: 500, width: 100, height: 100)), // clips bottom-trailing
        ])
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 588, y: 488))
    }

    @Test func panelLargerThanSafeAreaStillReturnsACorner() {
        let snapshot = RegionSnapshot(size: CGSize(width: 150, height: 80), safeArea: EdgeInsets(), regions: [])
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 12, y: 12))
    }
}

@MainActor
struct ReadoutTests {
    @Test func pointsDropTrailingZeroAndRoundToOneDecimal() {
        #expect(Readout.points(54) == "54")
        #expect(Readout.points(12.5) == "12.5")
        #expect(Readout.points(33.333) == "33.3")
        #expect(Readout.points(-20) == "-20")
    }

    @Test func rectSizeAndInsets() {
        #expect(Readout.rect(CGRect(x: 380, y: 0, width: 40.5, height: 700)) == "380,0 40.5×700")
        #expect(Readout.size(CGSize(width: 800, height: 600)) == "800×600")
        #expect(Readout.insets(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 54)) == "T0 L0 B20 R54")
    }

    @Test func sizeClassNames() {
        #expect(Readout.sizeClass(.compact) == "compact")
        #expect(Readout.sizeClass(.regular) == "regular")
        #expect(Readout.sizeClass(nil) == "–")
    }

    @Test func hingeReadoutDistinguishesWaitingFromNoHinge() {
        #expect(Readout.hinge(nil, received: false) == "waiting for update")
        #expect(Readout.hinge(nil, received: true) == "no hinge")
        let hinge = HingeInfo(status: .partiallyOpen, degrees: 92.4)
        #expect(Readout.hinge(hinge, received: true) == "partially open 92°")
    }

    @Test func hingeStatusNames() {
        #expect(HingeInfo(status: .closed, degrees: 0).statusName == "closed")
        #expect(HingeInfo(status: .fullyOpen, degrees: 180).statusName == "fully open")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the unit-test command from Global Constraints.
Expected: build failure — `cannot find 'RegionInfo' in scope` (and the other new types).

- [ ] **Step 3: Write the implementation**

Create `DuoTest/RegionSnapshot.swift`:

```swift
//
//  RegionSnapshot.swift
//  DuoTest
//
//  Plain values describing everything the visualizer draws, plus the pure
//  geometry and formatting it needs. No views live here.
//

import Foundation
import SwiftUI

enum RegionKind: String {
    case division
    case occlusion
}

/// A reserved region copied out of `ReservedRegion` (which has no public
/// initializer) so it can be built in tests.
struct RegionInfo: Identifiable, Equatable {
    var id: String
    var kind: RegionKind
    /// Includes `margins`, per Apple's reference.
    var frame: CGRect
    var margins: EdgeInsets
    var isActive: Bool

    /// The bare hardware area: `frame` inset by `margins`. Never negative in
    /// size and never outside `frame`.
    var hardwareRect: CGRect {
        let width = max(0, frame.width - margins.leading - margins.trailing)
        let height = max(0, frame.height - margins.top - margins.bottom)
        let x = frame.minX + min(max(0, margins.leading), frame.width - width)
        let y = frame.minY + min(max(0, margins.top), frame.height - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    var label: String {
        isActive ? kind.rawValue : "\(kind.rawValue) · inactive"
    }
}

struct HingeInfo: Equatable {
    var status: DeviceHinge.Status
    var degrees: Double

    var statusName: String {
        switch status {
        case .closed: "closed"
        case .partiallyOpen: "partially open"
        case .fullyOpen: "fully open"
        default: "unknown"
        }
    }
}

/// A safe-area inset drawn as a band along one edge.
struct InsetBand: Identifiable, Equatable {
    var edge: Edge
    var rect: CGRect
    var points: CGFloat

    var id: Edge { edge }

    var isVertical: Bool { edge == .leading || edge == .trailing }

    var label: String {
        let name = switch edge {
        case .top: "top"
        case .bottom: "bottom"
        case .leading: "leading"
        case .trailing: "trailing"
        }
        return "\(name) \(Readout.points(points))pt"
    }
}

struct RegionSnapshot: Equatable {
    var size: CGSize
    var safeArea: EdgeInsets
    var regions: [RegionInfo]

    static let empty = RegionSnapshot(size: .zero, safeArea: EdgeInsets(), regions: [])

    var safeRect: CGRect {
        CGRect(x: safeArea.leading,
               y: safeArea.top,
               width: max(0, size.width - safeArea.leading - safeArea.trailing),
               height: max(0, size.height - safeArea.top - safeArea.bottom))
    }

    /// One band per edge with a non-zero inset, in the order top, bottom,
    /// leading, trailing.
    var bands: [InsetBand] {
        var result: [InsetBand] = []
        if safeArea.top > 0 {
            result.append(InsetBand(edge: .top,
                                    rect: CGRect(x: 0, y: 0, width: size.width, height: safeArea.top),
                                    points: safeArea.top))
        }
        if safeArea.bottom > 0 {
            result.append(InsetBand(edge: .bottom,
                                    rect: CGRect(x: 0, y: size.height - safeArea.bottom,
                                                 width: size.width, height: safeArea.bottom),
                                    points: safeArea.bottom))
        }
        if safeArea.leading > 0 {
            result.append(InsetBand(edge: .leading,
                                    rect: CGRect(x: 0, y: 0, width: safeArea.leading, height: size.height),
                                    points: safeArea.leading))
        }
        if safeArea.trailing > 0 {
            result.append(InsetBand(edge: .trailing,
                                    rect: CGRect(x: size.width - safeArea.trailing, y: 0,
                                                 width: safeArea.trailing, height: size.height),
                                    points: safeArea.trailing))
        }
        return result
    }

    /// Where the readout panel goes: the first safe-area corner (top-leading,
    /// top-trailing, bottom-leading, bottom-trailing) clear of every active
    /// region, or else the corner with the least overlap.
    func panelOrigin(for panelSize: CGSize, padding: CGFloat = 12) -> CGPoint {
        let safe = safeRect
        let left = safe.minX + padding
        let right = max(left, safe.maxX - padding - panelSize.width)
        let top = safe.minY + padding
        let bottom = max(top, safe.maxY - padding - panelSize.height)
        let candidates = [
            CGPoint(x: left, y: top),
            CGPoint(x: right, y: top),
            CGPoint(x: left, y: bottom),
            CGPoint(x: right, y: bottom),
        ]
        let obstacles = regions.filter(\.isActive).map(\.frame)

        func overlap(_ origin: CGPoint) -> CGFloat {
            let panel = CGRect(origin: origin, size: panelSize)
            return obstacles.reduce(0) { total, obstacle in
                let shared = panel.intersection(obstacle)
                return shared.isNull ? total : total + shared.width * shared.height
            }
        }

        // `min(by:)` keeps the first of equal elements, so ties go to the
        // earlier (preferred) corner.
        return candidates.min { overlap($0) < overlap($1) } ?? candidates[0]
    }
}

/// Strokes a rect given in the container's coordinates. A zero-width or
/// zero-height rect becomes a line, so a flat fold stays visible.
struct OutlineShape: Shape {
    var rect: CGRect

    var animatableData: CGRect.AnimatableData {
        get { rect.animatableData }
        set { rect.animatableData = newValue }
    }

    func path(in _: CGRect) -> Path {
        var path = Path()
        if rect.width == 0 || rect.height == 0 {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            path.addRect(rect)
        }
        return path
    }
}

enum Readout {
    static func points(_ value: CGFloat) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", Double(rounded))
    }

    static func size(_ size: CGSize) -> String {
        "\(points(size.width))×\(points(size.height))"
    }

    static func rect(_ rect: CGRect) -> String {
        "\(points(rect.minX)),\(points(rect.minY)) \(points(rect.width))×\(points(rect.height))"
    }

    static func insets(_ insets: EdgeInsets) -> String {
        "T\(points(insets.top)) L\(points(insets.leading)) B\(points(insets.bottom)) R\(points(insets.trailing))"
    }

    static func sizeClass(_ sizeClass: UserInterfaceSizeClass?) -> String {
        switch sizeClass {
        case .compact: "compact"
        case .regular: "regular"
        case nil: "–"
        @unknown default: "unknown"
        }
    }

    static func hinge(_ hinge: HingeInfo?, received: Bool) -> String {
        guard received else { return "waiting for update" }
        guard let hinge else { return "no hinge" }
        return "\(hinge.statusName) \(Int(hinge.degrees.rounded()))°"
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the unit-test command.
Expected: every suite passes (`RegionInfoTests`, `OutlineShapeTests`, `InsetBandTests`, `PanelPlacementTests`, `ReadoutTests`, plus the template's `DuoTestTests`), `** TEST SUCCEEDED **`.

If the compiler reports a member as not visible (MemberImportVisibility), add the named module's import (e.g. `import CoreGraphics`) to the file reporting it and re-run.

- [ ] **Step 5: Commit**

```bash
git add DuoTest/RegionSnapshot.swift DuoTestTests/RegionSnapshotTests.swift
git commit -m "Add region snapshot model with geometry and readout formatting"
```

---

### Task 2: Draw the snapshot full screen

**Files:**
- Create: `DuoTest/RegionCanvas.swift`
- Create: `DuoTest/ReadoutPanel.swift`
- Modify: `DuoTest/ContentView.swift` (whole file — replace the template body)

**Interfaces:**
- Consumes (Task 1): `RegionSnapshot`, `RegionInfo`, `RegionKind`, `InsetBand`, `HingeInfo`, `OutlineShape`, `Readout`.
- Produces: `struct RegionCanvas: View { init(showToolbar: Binding<Bool>) }`, `struct ReadoutPanel: View { init(snapshot: RegionSnapshot, hinge: HingeInfo?, hingeReceived: Bool, showToolbar: Binding<Bool>) }`, `RegionSnapshot.init(_ proxy: GeometryProxy)`, `RegionInfo.init(_ region: ReservedRegion)`.

This task is view code over already-tested values; it is verified by building here and by looking in Task 3.

- [ ] **Step 1: Create the canvas**

Create `DuoTest/RegionCanvas.swift`:

```swift
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
        self.init(id: String(describing: region.id),
                  kind: region.kind == .division ? .division : .occlusion,
                  frame: region.frame,
                  margins: region.margins,
                  isActive: region.isActive)
    }
}

extension RegionSnapshot {
    /// Reads every region of both kinds, active and inactive, in physical
    /// (unmirrored) coordinates of the proxy's view.
    init(_ proxy: GeometryProxy) {
        let kinds: [ReservedRegion.Kind] = [.division, .occlusion]
        let regions = kinds.flatMap { kind in
            proxy.reservedRegions(kind: kind, options: .includeInactive, layoutDirectionBehavior: .fixed)
        }
        self.init(size: proxy.size, safeArea: proxy.safeAreaInsets, regions: regions.map(RegionInfo.init))
    }
}

struct RegionCanvas: View {
    @Binding var showToolbar: Bool

    @State private var hinge: HingeInfo?
    @State private var hingeReceived = false
    @State private var panelSize: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let snapshot = RegionSnapshot(proxy)
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
                             showToolbar: $showToolbar)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { panelSize = $0 }
                    .offset(x: panelOrigin.x, y: panelOrigin.y)
            }
            .animation(.snappy, value: snapshot)
            .animation(.snappy, value: panelOrigin)
        }
        .ignoresSafeArea()
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
```

- [ ] **Step 2: Create the readout panel**

Create `DuoTest/ReadoutPanel.swift`:

```swift
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
```

- [ ] **Step 3: Replace ContentView**

Replace the whole of `DuoTest/ContentView.swift` with:

```swift
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
                .navigationTitle("Regions")
                .navigationBarTitleDisplayMode(.inline)
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
```

- [ ] **Step 4: Build and re-run the unit tests**

Run the unit-test command (it builds the app first).
Expected: `** TEST SUCCEEDED **`, no compiler errors or warnings in the new files. Fix any compile error before moving on; do not change Task 1's tested behavior to make the views compile.

- [ ] **Step 5: Commit**

```bash
git add DuoTest/RegionCanvas.swift DuoTest/ReadoutPanel.swift DuoTest/ContentView.swift
git commit -m "Draw safe-area bands, reserved regions and readout full screen"
```

---

### Task 3: Run it on the iPhone Duo simulator and look

**Files:**
- Modify (only if check 2 fails): `DuoTest/RegionCanvas.swift`

**Interfaces:**
- Consumes: the app from Task 2.
- Produces: screenshots in the session scratchpad and a short report to the user.

- [ ] **Step 1: Build, install and launch**

```bash
xcodebuild build -project DuoTest.xcodeproj -scheme DuoTest \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$TMPDIR/DuoTest-DD" 2>&1 | tail -3
xcrun simctl boot "$SIM" 2>/dev/null; open -a Simulator
xcrun simctl install "$SIM" "$TMPDIR/DuoTest-DD/Build/Products/Debug-iphonesimulator/DuoTest.app"
xcrun simctl launch "$SIM" com.runway30.DuoTest
```

Expected: `** BUILD SUCCEEDED **`, then a process id printed by `launch`.

- [ ] **Step 2: Screenshot and check**

```bash
sleep 3; xcrun simctl io "$SIM" screenshot "<scratchpad>/duo-launch.png"
```

Open the screenshot and check:
1. A blue band labeled with a non-zero size sits along the status-bar edge.
2. The readout's `Safe` line shows that same non-zero inset.
3. At least one magenta occlusion region (outer camera) is drawn and listed.
4. The readout panel does not sit on top of any active region.
5. The `Hinge` line shows either a status or "waiting for update".

- [ ] **Step 3 (only if checks 1–2 show all-zero insets): apply the safe-area fallback**

In `RegionCanvas.body`, read insets from a reader that respects the safe area and pass them in. Replace the body's `GeometryReader { proxy in let snapshot = RegionSnapshot(proxy) ...` opening with an outer reader:

```swift
GeometryReader { safeProxy in
    GeometryReader { proxy in
        let snapshot = RegionSnapshot(proxy, safeArea: safeProxy.safeAreaInsets)
        // ... rest of the existing ZStack unchanged ...
    }
    .ignoresSafeArea()
}
```

(removing the original outer `.ignoresSafeArea()`), and add this initializer next to `init(_ proxy:)`:

```swift
init(_ proxy: GeometryProxy, safeArea: EdgeInsets) {
    self.init(proxy)
    self.safeArea = safeArea
}
```

Re-run Task 2 Step 4, then Steps 1–2 here. Commit with message `Read safe-area insets from a safe-area-respecting reader`.

- [ ] **Step 4: Toggle the toolbar and screenshot again**

Tap "Show toolbar" in the simulator (or ask the user to), then:

```bash
xcrun simctl io "$SIM" screenshot "<scratchpad>/duo-toolbar.png"
```

Expected: the toolbar appears (vertically on a closed/landscape Duo), and the band on its edge is wider than in `duo-launch.png`.

- [ ] **Step 5: Hand over to the user for pose checks**

`simctl` cannot fold or rotate the Duo, so report to the user: what was verified from screenshots (with paths), what wasn't, and ask them to open, fold, lay flat and rotate in the Simulator's Device Hub controls and watch for: the orange fold appearing when partially folded; what the fold becomes when flat (dashed region vs dashed line vs gone); hinge status/angle updating.
